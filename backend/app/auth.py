"""JWT Authentication module."""
from datetime import datetime, timedelta
from typing import Optional
import secrets

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPBasicCredentials, HTTPBasic
from jose import JWTError, jwt
from passlib.context import CryptContext
from pydantic import BaseModel

from .config import settings

# Password hashing - use sha256_crypt as fallback (bcrypt has version issues)
pwd_context = CryptContext(
    schemes=["sha256_crypt"],
    deprecated="auto",
)

# Security schemes
bearer_scheme = HTTPBearer(auto_error=False)
basic_scheme = HTTPBasic(auto_error=False)


# Pydantic models
class Token(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int


class TokenData(BaseModel):
    user_id: Optional[str] = None
    user_type: str = "rider"  # rider, driver, admin
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
    is_verified: bool = False
    created_at: str


# In-memory user store (replace with database in production)
_users: dict = {}
_refresh_tokens: dict = {}


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a password against its hash."""
    return pwd_context.verify(plain_password[:72], hashed_password)


def get_password_hash(password: str) -> str:
    """Hash a password."""
    # Truncate to 72 bytes for bcrypt compatibility
    return pwd_context.hash(password[:72])


def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    """Create a JWT access token."""
    to_encode = data.copy()
    expire = datetime.utcnow() + (expires_delta or timedelta(minutes=settings.access_token_expire_minutes))
    to_encode.update({"exp": expire, "type": "access"})
    return jwt.encode(to_encode, settings.secret_key, algorithm=settings.algorithm)


def create_refresh_token(data: dict) -> str:
    """Create a JWT refresh token."""
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(days=settings.refresh_token_expire_days)
    to_encode.update({"exp": expire, "type": "refresh"})
    token = jwt.encode(to_encode, settings.secret_key, algorithm=settings.algorithm)
    
    # Store refresh token
    user_id = data.get("sub")
    if user_id:
        _refresh_tokens[token] = user_id
    
    return token


def verify_token(token: str, token_type: str = "access") -> Optional[TokenData]:
    """Verify a JWT token and return token data."""
    try:
        payload = jwt.decode(token, settings.secret_key, algorithms=[settings.algorithm])
        
        if payload.get("type") != token_type:
            return None
        
        user_id: str = payload.get("sub")
        user_type: str = payload.get("user_type", "rider")
        exp = payload.get("exp")
        
        if user_id is None:
            return None
        
        return TokenData(user_id=user_id, user_type=user_type, exp=datetime.fromtimestamp(exp) if exp else None)
    except JWTError:
        return None


def create_tokens(user_id: str, user_type: str = "rider") -> Token:
    """Create access and refresh tokens for a user."""
    access_token = create_access_token(
        data={"sub": user_id, "user_type": user_type}
    )
    refresh_token = create_refresh_token(
        data={"sub": user_id, "user_type": user_type}
    )
    
    return Token(
        access_token=access_token,
        refresh_token=refresh_token,
        expires_in=settings.access_token_expire_minutes * 60,
    )


# User management (temporary in-memory, will be replaced by database)
def create_user(user_data: UserCreate) -> dict:
    """Create a new user."""
    user_id = f"u_{secrets.token_hex(8)}"
    
    if user_data.phone in [u["phone"] for u in _users.values()]:
        raise ValueError("Phone number already registered")
    
    user = {
        "id": user_id,
        "phone": user_data.phone,
        "name": user_data.name,
        "password_hash": get_password_hash(user_data.password),
        "user_type": user_data.user_type,
        "is_verified": False,
        "created_at": datetime.utcnow().isoformat(),
    }
    
    _users[user_id] = user
    return user


def get_user_by_phone(phone: str) -> Optional[dict]:
    """Get user by phone number."""
    for user in _users.values():
        if user["phone"] == phone:
            return user
    return None


def get_user_by_id(user_id: str) -> Optional[dict]:
    """Get user by ID."""
    return _users.get(user_id)


def authenticate_user(phone: str, password: str) -> Optional[dict]:
    """Authenticate a user with phone and password."""
    user = get_user_by_phone(phone)
    if not user:
        return None
    if not verify_password(password, user["password_hash"]):
        return None
    return user


# Dependency for protected routes
async def get_current_user(
    bearer_token: Optional[str] = Depends(bearer_scheme),
    basic_creds: Optional[HTTPBasicCredentials] = Depends(basic_scheme),
) -> dict:
    """
    Get current authenticated user.
    Supports both JWT Bearer tokens and Basic Auth (for backward compatibility).
    """
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
    
    # Fall back to Basic Auth (for backward compatibility)
    if basic_creds:
        if (secrets.compare_digest(basic_creds.username, settings.basic_user) and 
            secrets.compare_digest(basic_creds.password, settings.basic_pass)):
            # Return a mock user for basic auth
            return {
                "id": "basic_auth_user",
                "phone": "0000000000",
                "name": "Demo User",
                "user_type": "rider",
                "is_verified": True,
            }
    
    raise credentials_exception


async def get_current_active_user(current_user: dict = Depends(get_current_user)) -> dict:
    """Get current active user (not disabled)."""
    # Add any disabled check here if needed
    return current_user


async def require_admin(current_user: dict = Depends(get_current_user)) -> dict:
    """Require admin user."""
    if current_user.get("user_type") != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin access required",
        )
    return current_user


async def require_driver(current_user: dict = Depends(get_current_user)) -> dict:
    """Require driver user."""
    if current_user.get("user_type") not in ["driver", "admin"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Driver access required",
        )
    return current_user


def refresh_access_token(refresh_token: str) -> Optional[Token]:
    """Refresh access token using refresh token."""
    token_data = verify_token(refresh_token, token_type="refresh")
    
    if not token_data or not token_data.user_id:
        return None
    
    # Verify refresh token is still valid
    if refresh_token not in _refresh_tokens:
        return None
    
    user = get_user_by_id(token_data.user_id)
    if not user:
        return None
    
    # Create new tokens
    return create_tokens(user["id"], user.get("user_type", "rider"))


def revoke_refresh_token(refresh_token: str) -> bool:
    """Revoke a refresh token."""
    if refresh_token in _refresh_tokens:
        del _refresh_tokens[refresh_token]
        return True
    return False

