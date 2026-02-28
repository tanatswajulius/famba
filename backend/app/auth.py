"""JWT Authentication module — persisted to database."""
from datetime import datetime, timedelta
from typing import Optional
import secrets

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPBasicCredentials, HTTPBasic
from jose import JWTError, jwt
from passlib.context import CryptContext
from pydantic import BaseModel

from .config import settings
from .database import db_create_user, db_get_user_by_id, db_get_user_by_phone

# Password hashing
pwd_context = CryptContext(schemes=["sha256_crypt"], deprecated="auto")

# Security schemes
bearer_scheme = HTTPBearer(auto_error=False)
basic_scheme = HTTPBasic(auto_error=False)


# ==================== Pydantic models ====================

class Token(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int


class TokenData(BaseModel):
    user_id: Optional[str] = None
    user_type: str = "rider"
    exp: Optional[datetime] = None


class UserCreate(BaseModel):
    phone: str
    name: str
    password: str
    user_type: str = "rider"


class UserLogin(BaseModel):
    phone: str
    password: str


class UserResponse(BaseModel):
    id: str
    phone: str
    name: str
    user_type: str
    role: str = "user"
    is_verified: bool = False
    wallet_balance: float = 0.0
    created_at: str


# Refresh tokens kept in-memory (short-lived, session-scoped)
_refresh_tokens: dict = {}


# ==================== Password helpers ====================

def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password[:72], hashed_password)


def get_password_hash(password: str) -> str:
    return pwd_context.hash(password[:72])


# ==================== Token helpers ====================

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    to_encode = data.copy()
    expire = datetime.utcnow() + (expires_delta or timedelta(minutes=settings.access_token_expire_minutes))
    to_encode.update({"exp": expire, "type": "access"})
    return jwt.encode(to_encode, settings.secret_key, algorithm=settings.algorithm)


def create_refresh_token(data: dict) -> str:
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(days=settings.refresh_token_expire_days)
    to_encode.update({"exp": expire, "type": "refresh"})
    token = jwt.encode(to_encode, settings.secret_key, algorithm=settings.algorithm)
    user_id = data.get("sub")
    if user_id:
        _refresh_tokens[token] = user_id
    return token


def verify_token(token: str, token_type: str = "access") -> Optional[TokenData]:
    try:
        payload = jwt.decode(token, settings.secret_key, algorithms=[settings.algorithm])
        if payload.get("type") != token_type:
            return None
        user_id: str = payload.get("sub")
        user_type: str = payload.get("user_type", "rider")
        exp = payload.get("exp")
        if user_id is None:
            return None
        return TokenData(
            user_id=user_id, user_type=user_type,
            exp=datetime.fromtimestamp(exp) if exp else None,
        )
    except JWTError:
        return None


def create_tokens(user_id: str, user_type: str = "rider") -> Token:
    access_token = create_access_token(data={"sub": user_id, "user_type": user_type})
    refresh_token = create_refresh_token(data={"sub": user_id, "user_type": user_type})
    return Token(
        access_token=access_token,
        refresh_token=refresh_token,
        expires_in=settings.access_token_expire_minutes * 60,
    )


# ==================== User management (database-backed) ====================

def create_user(user_data: UserCreate) -> dict:
    """Create a new user, persisted to database."""
    if db_get_user_by_phone(user_data.phone):
        raise ValueError("Phone number already registered")

    user_id = f"u_{secrets.token_hex(8)}"
    password_hash = get_password_hash(user_data.password)

    return db_create_user(
        user_id=user_id,
        phone=user_data.phone,
        name=user_data.name,
        password_hash=password_hash,
        user_type=user_data.user_type,
    )


def get_user_by_phone(phone: str) -> Optional[dict]:
    return db_get_user_by_phone(phone)


def get_user_by_id(user_id: str) -> Optional[dict]:
    return db_get_user_by_id(user_id)


def authenticate_user(phone: str, password: str) -> Optional[dict]:
    user = get_user_by_phone(phone)
    if not user:
        return None
    if not verify_password(password, user["password_hash"]):
        return None
    return user


# ==================== Route dependencies ====================

async def get_current_user(
    bearer_token: Optional[str] = Depends(bearer_scheme),
    basic_creds: Optional[HTTPBasicCredentials] = Depends(basic_scheme),
) -> dict:
    """Get current authenticated user (JWT or Basic Auth fallback)."""
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )

    # Try JWT Bearer token first
    if bearer_token and bearer_token.credentials:
        token_data = verify_token(bearer_token.credentials)
        if token_data and token_data.user_id:
            user = get_user_by_id(token_data.user_id)
            if user:
                return user

    # Fall back to Basic Auth (for admin dashboard / legacy clients)
    if basic_creds:
        if (secrets.compare_digest(basic_creds.username, settings.basic_user) and
                secrets.compare_digest(basic_creds.password, settings.basic_pass)):
            return {
                "id": "basic_auth_user",
                "phone": "0000000000",
                "name": "Demo User",
                "user_type": "admin",
                "is_verified": True,
                "wallet_balance": 0.0,
            }

    raise credentials_exception


async def get_current_active_user(current_user: dict = Depends(get_current_user)) -> dict:
    return current_user


async def require_admin(current_user: dict = Depends(get_current_user)) -> dict:
    if current_user.get("user_type") != "admin":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin access required")
    return current_user


async def require_driver(current_user: dict = Depends(get_current_user)) -> dict:
    if current_user.get("user_type") not in ["driver", "admin"]:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Driver access required")
    return current_user


def refresh_access_token(refresh_token: str) -> Optional[Token]:
    token_data = verify_token(refresh_token, token_type="refresh")
    if not token_data or not token_data.user_id:
        return None
    if refresh_token not in _refresh_tokens:
        return None
    user = get_user_by_id(token_data.user_id)
    if not user:
        return None
    return create_tokens(user["id"], user.get("user_type", "rider"))


def revoke_refresh_token(refresh_token: str) -> bool:
    if refresh_token in _refresh_tokens:
        del _refresh_tokens[refresh_token]
        return True
    return False
