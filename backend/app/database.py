"""Database module supporting both SQLite and PostgreSQL."""
import json
import random
import string
from datetime import datetime
from typing import Dict, List, Optional
from contextlib import contextmanager

from sqlalchemy import create_engine, Column, String, Float, Integer, Boolean, Text, DateTime, ForeignKey
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session, relationship

from .config import settings

# Create engine based on configuration
if settings.use_postgres:
    engine = create_engine(
        settings.database_url,
        pool_pre_ping=True,
        pool_size=10,
        max_overflow=20,
        echo=settings.database_echo,
    )
else:
    engine = create_engine(
        settings.database_url,
        connect_args={"check_same_thread": False},
        echo=settings.database_echo,
    )

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


# SQLAlchemy Models
class User(Base):
    __tablename__ = "users"
    
    id = Column(String(50), primary_key=True)
    phone = Column(String(20), unique=True, nullable=False, index=True)
    name = Column(String(100), nullable=False)
    email = Column(String(100), unique=True, nullable=True)
    password_hash = Column(String(255), nullable=False)
    user_type = Column(String(20), default="rider")  # rider, driver, admin
    is_verified = Column(Boolean, default=False)
    is_active = Column(Boolean, default=True)
    profile_image = Column(String(255), nullable=True)
    referral_code = Column(String(20), unique=True, nullable=True)
    referred_by = Column(String(20), nullable=True)
    wallet_balance = Column(Float, default=0.0)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class Driver(Base):
    __tablename__ = "drivers"
    
    id = Column(String(50), primary_key=True)
    user_id = Column(String(50), ForeignKey("users.id"), nullable=True)
    name = Column(String(100), nullable=False)
    phone = Column(String(20), nullable=True)
    rating = Column(Float, default=4.8)
    total_trips = Column(Integer, default=0)
    lat = Column(Float, nullable=True)
    lng = Column(Float, nullable=True)
    vehicle_make = Column(String(50), nullable=True)
    vehicle_model = Column(String(50), nullable=True)
    vehicle_color = Column(String(30), nullable=True)
    license_plate = Column(String(20), nullable=True)
    vehicle_year = Column(Integer, nullable=True)
    is_online = Column(Boolean, default=False)
    is_active = Column(Boolean, default=True)
    is_verified = Column(Boolean, default=False)
    documents_verified = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow)


class Job(Base):
    __tablename__ = "jobs"
    
    id = Column(String(50), primary_key=True)
    rider_id = Column(String(50), ForeignKey("users.id"), nullable=True)
    driver_id = Column(String(50), ForeignKey("drivers.id"), nullable=True)
    status = Column(String(30), default="searching")
    pickup_text = Column(String(255), nullable=True)
    drop_text = Column(String(255), nullable=True)
    pickup_lat = Column(Float, nullable=True)
    pickup_lng = Column(Float, nullable=True)
    drop_lat = Column(Float, nullable=True)
    drop_lng = Column(Float, nullable=True)
    distance_km = Column(Float, nullable=True)
    driver_lat = Column(Float, nullable=True)
    driver_lng = Column(Float, nullable=True)
    driver_json = Column(Text, nullable=True)
    waypoints_json = Column(Text, nullable=True)
    fare_usd = Column(Float, nullable=True)
    base_fare = Column(Float, nullable=True)
    distance_fare = Column(Float, nullable=True)
    stop_fee = Column(Float, default=0.0)
    promo_discount = Column(Float, default=0.0)
    payment_method = Column(String(30), default="cash")
    payment_status = Column(String(20), default="pending")
    rider_name = Column(String(100), nullable=True)
    rider_phone = Column(String(20), nullable=True)
    scheduled_time = Column(DateTime, nullable=True)
    started_at = Column(DateTime, nullable=True)
    completed_at = Column(DateTime, nullable=True)
    cancel_reason = Column(String(255), nullable=True)
    preferences_json = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class Rating(Base):
    __tablename__ = "ratings"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    job_id = Column(String(50), ForeignKey("jobs.id"), nullable=True)
    driver_id = Column(String(50), ForeignKey("drivers.id"), nullable=False)
    rider_id = Column(String(50), ForeignKey("users.id"), nullable=True)
    rating = Column(Float, nullable=False)
    comment = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)


class PromoCode(Base):
    __tablename__ = "promo_codes"
    
    code = Column(String(20), primary_key=True)
    discount_percent = Column(Integer, nullable=False)
    max_discount = Column(Float, nullable=True)
    min_fare = Column(Float, default=0.0)
    max_uses = Column(Integer, nullable=True)
    used_count = Column(Integer, default=0)
    is_active = Column(Boolean, default=True)
    expires_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)


class Location(Base):
    __tablename__ = "locations"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    name = Column(String(100), nullable=False)
    address = Column(String(255), nullable=True)
    area = Column(String(100), nullable=True)
    lat = Column(Float, nullable=True)
    lng = Column(Float, nullable=True)
    category = Column(String(50), nullable=True)
    popularity = Column(Integer, default=0)


class Referral(Base):
    __tablename__ = "referrals"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    referrer_code = Column(String(20), unique=True, nullable=False)
    referrer_id = Column(String(50), ForeignKey("users.id"), nullable=True)
    referrer_name = Column(String(100), nullable=False)
    referrer_phone = Column(String(20), nullable=True)
    total_referrals = Column(Integer, default=0)
    total_credits = Column(Float, default=0.0)
    created_at = Column(DateTime, default=datetime.utcnow)


class ReferralSignup(Base):
    __tablename__ = "referral_signups"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    referral_code = Column(String(20), ForeignKey("referrals.referrer_code"), nullable=False)
    referee_id = Column(String(50), ForeignKey("users.id"), nullable=True)
    referee_name = Column(String(100), nullable=False)
    referee_phone = Column(String(20), nullable=True)
    credit_applied = Column(Float, default=0.0)
    created_at = Column(DateTime, default=datetime.utcnow)


class DriverEarning(Base):
    __tablename__ = "driver_earnings"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    driver_id = Column(String(50), ForeignKey("drivers.id"), nullable=False)
    job_id = Column(String(50), ForeignKey("jobs.id"), nullable=True)
    amount = Column(Float, nullable=False)
    commission = Column(Float, default=0.0)
    net_amount = Column(Float, nullable=False)
    type = Column(String(20), default="ride")
    created_at = Column(DateTime, default=datetime.utcnow)


# Database dependency
@contextmanager
def get_db():
    """Get database session."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def get_db_session() -> Session:
    """Get a new database session."""
    return SessionLocal()


# Initialize database
def init_db():
    """Create all tables and seed initial data."""
    Base.metadata.create_all(bind=engine)
    
    with get_db() as db:
        _seed_initial_data(db)


def _seed_initial_data(db: Session):
    """Seed initial data if tables are empty."""
    
    # Seed drivers
    if db.query(Driver).count() == 0:
        drivers = [
            Driver(id="d1", name="Tendai", rating=4.9, lat=-17.829, lng=31.052, 
                   vehicle_make="Bajaj", vehicle_model="Boxer", vehicle_color="Green", 
                   license_plate="MBK-2489", is_active=True, is_verified=True),
            Driver(id="d2", name="Rudo", rating=4.8, lat=-17.825, lng=31.048,
                   vehicle_make="TVS", vehicle_model="Apache", vehicle_color="Red",
                   license_plate="MBK-7777", is_active=True, is_verified=True),
            Driver(id="d3", name="Kuda", rating=4.7, lat=-17.831, lng=31.055,
                   vehicle_make="Honda", vehicle_model="CB125", vehicle_color="Blue",
                   license_plate="MBK-1234", is_active=True, is_verified=True),
            Driver(id="d4", name="Nyasha", rating=4.6, lat=-17.827, lng=31.050,
                   vehicle_make="Bajaj", vehicle_model="Pulsar", vehicle_color="Black",
                   license_plate="MBK-5678", is_active=True, is_verified=True),
        ]
        db.add_all(drivers)
    
    # Seed promo codes
    if db.query(PromoCode).count() == 0:
        promos = [
            PromoCode(code="FAMBA50", discount_percent=50, max_discount=5.00, 
                     expires_at=datetime(2025, 12, 31, 23, 59, 59)),
            PromoCode(code="RIDE25", discount_percent=25, max_discount=3.00,
                     expires_at=datetime(2026, 1, 15, 23, 59, 59)),
            PromoCode(code="FIRST10", discount_percent=10, max_discount=2.00,
                     expires_at=datetime(2026, 6, 30, 23, 59, 59)),
        ]
        db.add_all(promos)
    
    # Seed locations
    if db.query(Location).count() == 0:
        locations = [
            Location(name="First Street Mall", address="Corner First St & Jason Moyo", area="CBD", lat=-17.8292, lng=31.0522, category="shopping", popularity=100),
            Location(name="Meikles Hotel", address="Jason Moyo Ave", area="CBD", lat=-17.8285, lng=31.0515, category="hotel", popularity=90),
            Location(name="Eastgate Mall", address="Robert Mugabe Rd", area="CBD", lat=-17.8310, lng=31.0545, category="shopping", popularity=95),
            Location(name="Joina City", address="Jason Moyo & Inez Terrace", area="CBD", lat=-17.8295, lng=31.0530, category="shopping", popularity=85),
            Location(name="Rainbow Towers", address="Pennefather Ave", area="CBD", lat=-17.8320, lng=31.0490, category="hotel", popularity=80),
            Location(name="Avondale Shops", address="King George Rd", area="Avondale", lat=-17.7920, lng=31.0420, category="shopping", popularity=88),
            Location(name="Sam Levy's Village", address="Borrowdale Rd", area="Borrowdale", lat=-17.7850, lng=31.0650, category="shopping", popularity=92),
            Location(name="UZ Campus Gate", address="Mt Pleasant", area="Mt Pleasant", lat=-17.7830, lng=31.0530, category="education", popularity=98),
            Location(name="Borrowdale Village", address="Borrowdale Rd", area="Borrowdale", lat=-17.7600, lng=31.0800, category="shopping", popularity=75),
            Location(name="Eastlea Shopping Centre", address="Chiremba Rd", area="Eastlea", lat=-17.8450, lng=31.0700, category="shopping", popularity=72),
            Location(name="Westgate Shopping Mall", address="Westgate", area="Westgate", lat=-17.8050, lng=30.9800, category="shopping", popularity=82),
            Location(name="Harare International Airport", address="Airport Rd", area="Airport", lat=-17.9318, lng=31.0928, category="transport", popularity=99),
            Location(name="Mbare Musika", address="Mbare", area="Mbare", lat=-17.8600, lng=31.0350, category="transport", popularity=85),
            Location(name="Parirenyatwa Hospital", address="Mazowe St", area="CBD", lat=-17.8200, lng=31.0400, category="hospital", popularity=88),
            Location(name="Causeway", address="Samora Machel Ave", area="CBD", lat=-17.8270, lng=31.0500, category="government", popularity=75),
        ]
        db.add_all(locations)
    
    db.commit()


# Job counter for generating IDs
_job_counter = 1000


# CRUD Operations
def create_job(data: dict) -> dict:
    """Create a new job."""
    global _job_counter
    _job_counter += 1
    job_id = f"J{_job_counter}"
    
    with get_db() as db:
        job = Job(
            id=job_id,
            status="searching",
            pickup_text=data.get("pickup_text"),
            drop_text=data.get("drop_text"),
            pickup_lat=data.get("pickup_lat"),
            pickup_lng=data.get("pickup_lng"),
            drop_lat=data.get("drop_lat"),
            drop_lng=data.get("drop_lng"),
            distance_km=data.get("distance_km"),
            rider_name=data.get("rider_name"),
            fare_usd=data.get("fare_usd"),
            payment_method=data.get("payment_method", "cash"),
            scheduled_time=data.get("scheduled_time"),
        )
        db.add(job)
        db.commit()
        db.refresh(job)
        return _job_to_dict(job)


def get_job(job_id: str) -> Optional[dict]:
    """Get job by ID."""
    with get_db() as db:
        job = db.query(Job).filter(Job.id == job_id).first()
        if not job:
            return None
        return _job_to_dict(job)


def update_job(job_id: str, **updates) -> Optional[dict]:
    """Update a job."""
    with get_db() as db:
        job = db.query(Job).filter(Job.id == job_id).first()
        if not job:
            return None
        
        # Handle driver object specially
        if "driver" in updates:
            updates["driver_json"] = json.dumps(updates.pop("driver"))
        
        for key, value in updates.items():
            if hasattr(job, key):
                setattr(job, key, value)
        
        job.updated_at = datetime.utcnow()
        db.commit()
        db.refresh(job)
        return _job_to_dict(job)


def list_jobs(limit: int = 100) -> List[dict]:
    """List recent jobs."""
    with get_db() as db:
        jobs = db.query(Job).order_by(Job.created_at.desc()).limit(limit).all()
        return [_job_to_dict(j) for j in jobs]


def _job_to_dict(job: Job) -> dict:
    """Convert Job model to dictionary."""
    result = {
        "id": job.id,
        "status": job.status,
        "pickup_text": job.pickup_text,
        "drop_text": job.drop_text,
        "pickup_lat": job.pickup_lat,
        "pickup_lng": job.pickup_lng,
        "drop_lat": job.drop_lat,
        "drop_lng": job.drop_lng,
        "distance_km": job.distance_km,
        "driver_lat": job.driver_lat,
        "driver_lng": job.driver_lng,
        "fare_usd": job.fare_usd,
        "payment_method": job.payment_method,
        "rider_name": job.rider_name,
        "scheduled_time": job.scheduled_time.isoformat() if job.scheduled_time else None,
        "cancel_reason": job.cancel_reason,
        "created_at": job.created_at.isoformat() if job.created_at else None,
    }
    
    # Parse driver JSON
    if job.driver_json:
        result["driver"] = json.loads(job.driver_json)
    else:
        result["driver"] = None
    
    return result


# Driver operations
_driver_index = 0


def get_all_drivers() -> List[dict]:
    """Get all active drivers."""
    with get_db() as db:
        drivers = db.query(Driver).filter(Driver.is_active == True).all()
        return [_driver_to_dict(d) for d in drivers]


def get_driver_by_id(driver_id: str) -> Optional[dict]:
    """Get driver by ID."""
    if not driver_id:
        return None
    with get_db() as db:
        driver = db.query(Driver).filter(Driver.id == driver_id).first()
        return _driver_to_dict(driver) if driver else None


def get_next_driver() -> dict:
    """Get the next driver in rotation."""
    global _driver_index
    drivers = get_all_drivers()
    if not drivers:
        return {
            "id": "d1", "name": "Tendai", "rating": 4.9,
            "lat": -17.829, "lng": 31.052,
            "vehicle_make": "Bajaj", "vehicle_model": "Boxer",
            "vehicle_color": "Green", "license_plate": "MBK-2489",
        }
    return drivers[_driver_index % len(drivers)]


def pick_driver() -> dict:
    """Pick a driver and advance rotation."""
    global _driver_index
    driver = get_next_driver()
    _driver_index += 1
    return driver


def _driver_to_dict(driver: Driver) -> dict:
    """Convert Driver model to dictionary."""
    return {
        "id": driver.id,
        "name": driver.name,
        "rating": driver.rating,
        "lat": driver.lat,
        "lng": driver.lng,
        "vehicle_make": driver.vehicle_make,
        "vehicle_model": driver.vehicle_model,
        "vehicle_color": driver.vehicle_color,
        "license_plate": driver.license_plate,
        "is_online": driver.is_online,
        "total_trips": driver.total_trips,
    }


# Rating operations
def add_rating(data: dict) -> dict:
    """Add a new rating."""
    with get_db() as db:
        rating = Rating(
            job_id=data.get("job_id"),
            driver_id=data.get("driver_id"),
            rider_id=data.get("rider_id"),
            rating=data.get("rating"),
            comment=data.get("comment"),
        )
        db.add(rating)
        
        # Update driver average rating
        driver = db.query(Driver).filter(Driver.id == data.get("driver_id")).first()
        if driver:
            avg = db.query(Rating).filter(Rating.driver_id == driver.id).with_entities(
                db.func.avg(Rating.rating)
            ).scalar()
            if avg:
                driver.rating = round(avg, 2)
        
        db.commit()
        return {"ok": True, "id": rating.id}


def list_ratings() -> List[dict]:
    """List all ratings."""
    with get_db() as db:
        ratings = db.query(Rating).order_by(Rating.created_at.desc()).limit(100).all()
        return [{
            "id": r.id,
            "job_id": r.job_id,
            "driver_id": r.driver_id,
            "rating": r.rating,
            "comment": r.comment,
            "created_at": r.created_at.isoformat() if r.created_at else None,
        } for r in ratings]


# Promo code operations
def validate_promo(code: str) -> dict:
    """Validate a promo code."""
    with get_db() as db:
        promo = db.query(PromoCode).filter(
            PromoCode.code == code.upper(),
            PromoCode.is_active == True,
        ).first()
        
        if promo and (not promo.expires_at or promo.expires_at > datetime.utcnow()):
            return {
                "valid": True,
                "code": promo.code,
                "discount": promo.discount_percent,
                "max_discount": promo.max_discount,
                "message": f"{promo.discount_percent}% off applied!",
            }
        
        return {
            "valid": False,
            "code": code,
            "message": "Invalid or expired promo code",
        }


# Location operations
def search_locations(query: str, limit: int = 10) -> List[dict]:
    """Search locations."""
    with get_db() as db:
        locations = db.query(Location).filter(
            (Location.name.ilike(f"%{query}%")) |
            (Location.address.ilike(f"%{query}%")) |
            (Location.area.ilike(f"%{query}%"))
        ).order_by(Location.popularity.desc()).limit(limit).all()
        
        return [_location_to_dict(loc) for loc in locations]


def get_popular_locations(limit: int = 10) -> List[dict]:
    """Get popular locations."""
    with get_db() as db:
        locations = db.query(Location).order_by(Location.popularity.desc()).limit(limit).all()
        return [_location_to_dict(loc) for loc in locations]


def _location_to_dict(loc: Location) -> dict:
    return {
        "id": loc.id,
        "name": loc.name,
        "address": loc.address,
        "area": loc.area,
        "lat": loc.lat,
        "lng": loc.lng,
        "category": loc.category,
        "popularity": loc.popularity,
    }


# Referral operations
def generate_referral_code(name: str) -> str:
    """Generate unique referral code."""
    prefix = ''.join(c.upper() for c in name[:3] if c.isalpha())
    suffix = ''.join(random.choices(string.digits, k=4))
    return f"{prefix}{suffix}"


def create_referral(name: str, phone: str = None) -> dict:
    """Create a new referral code."""
    with get_db() as db:
        code = generate_referral_code(name)
        
        # Ensure uniqueness
        while db.query(Referral).filter(Referral.referrer_code == code).first():
            code = generate_referral_code(name)
        
        referral = Referral(
            referrer_code=code,
            referrer_name=name,
            referrer_phone=phone,
        )
        db.add(referral)
        db.commit()
        db.refresh(referral)
        
        return {
            "id": referral.id,
            "referrer_code": referral.referrer_code,
            "referrer_name": referral.referrer_name,
            "referrer_phone": referral.referrer_phone,
            "total_referrals": referral.total_referrals,
            "total_credits": referral.total_credits,
            "created_at": referral.created_at.isoformat(),
        }


def get_referral(code: str) -> Optional[dict]:
    """Get referral by code."""
    with get_db() as db:
        ref = db.query(Referral).filter(Referral.referrer_code == code.upper()).first()
        if not ref:
            return None
        return {
            "referrer_code": ref.referrer_code,
            "referrer_name": ref.referrer_name,
            "total_referrals": ref.total_referrals,
            "total_credits": ref.total_credits,
        }


def apply_referral(code: str, referee_name: str, referee_phone: str = None) -> dict:
    """Apply a referral code."""
    with get_db() as db:
        ref = db.query(Referral).filter(Referral.referrer_code == code.upper()).first()
        if not ref:
            return {"ok": False, "message": "Invalid referral code"}
        
        credit = 2.00
        
        signup = ReferralSignup(
            referral_code=code.upper(),
            referee_name=referee_name,
            referee_phone=referee_phone,
            credit_applied=credit,
        )
        db.add(signup)
        
        ref.total_referrals += 1
        ref.total_credits += credit
        
        db.commit()
        
        return {
            "ok": True,
            "message": f"Referral applied! You got ${credit:.2f} credit.",
            "credit": credit,
            "referrer": ref.referrer_name,
        }


def get_referral_stats(code: str) -> dict:
    """Get referral statistics."""
    with get_db() as db:
        ref = db.query(Referral).filter(Referral.referrer_code == code.upper()).first()
        if not ref:
            return {"ok": False, "message": "Referral code not found"}
        
        signups = db.query(ReferralSignup).filter(
            ReferralSignup.referral_code == code.upper()
        ).order_by(ReferralSignup.created_at.desc()).limit(10).all()
        
        return {
            "ok": True,
            "code": ref.referrer_code,
            "total_referrals": ref.total_referrals,
            "total_credits": ref.total_credits,
            "recent_signups": [{
                "referee_name": s.referee_name,
                "credit_applied": s.credit_applied,
                "created_at": s.created_at.isoformat(),
            } for s in signups],
        }


# Driver earnings operations
def record_driver_earning(driver_id: str, job_id: str, amount: float, commission_rate: float = 0.15) -> dict:
    """Record driver earning."""
    with get_db() as db:
        commission = amount * commission_rate
        net = amount - commission
        
        earning = DriverEarning(
            driver_id=driver_id,
            job_id=job_id,
            amount=amount,
            commission=commission,
            net_amount=net,
            type="ride",
        )
        db.add(earning)
        db.commit()
        
        return {
            "id": earning.id,
            "driver_id": driver_id,
            "amount": amount,
            "commission": commission,
            "net_amount": net,
        }


def get_driver_earnings(driver_id: str, days: int = 30) -> dict:
    """Get driver earnings summary."""
    with get_db() as db:
        earnings = db.query(DriverEarning).filter(
            DriverEarning.driver_id == driver_id
        ).order_by(DriverEarning.created_at.desc()).limit(50).all()
        
        total = db.query(
            db.func.count(DriverEarning.id),
            db.func.sum(DriverEarning.amount),
            db.func.sum(DriverEarning.commission),
            db.func.sum(DriverEarning.net_amount),
            db.func.avg(DriverEarning.net_amount),
        ).filter(DriverEarning.driver_id == driver_id).first()
        
        today = datetime.utcnow().strftime("%Y-%m-%d")
        today_stats = db.query(
            db.func.count(DriverEarning.id),
            db.func.sum(DriverEarning.net_amount),
        ).filter(
            DriverEarning.driver_id == driver_id,
            db.func.date(DriverEarning.created_at) == today,
        ).first()
        
        return {
            "driver_id": driver_id,
            "summary": {
                "total_trips": total[0] or 0,
                "total_earnings": round(total[1] or 0, 2),
                "total_commission": round(total[2] or 0, 2),
                "net_earnings": round(total[3] or 0, 2),
                "avg_per_trip": round(total[4] or 0, 2),
            },
            "today": {
                "trips": today_stats[0] or 0,
                "earnings": round(today_stats[1] or 0, 2),
            },
            "history": [{
                "id": e.id,
                "job_id": e.job_id,
                "amount": e.amount,
                "commission": e.commission,
                "net_amount": e.net_amount,
                "type": e.type,
                "created_at": e.created_at.isoformat(),
            } for e in earnings],
        }


def get_all_drivers_earnings() -> List[dict]:
    """Get earnings leaderboard."""
    with get_db() as db:
        drivers = db.query(Driver).filter(Driver.is_active == True).all()
        
        result = []
        for d in drivers:
            stats = db.query(
                db.func.count(DriverEarning.id),
                db.func.sum(DriverEarning.net_amount),
            ).filter(DriverEarning.driver_id == d.id).first()
            
            result.append({
                "id": d.id,
                "name": d.name,
                "rating": d.rating,
                "total_trips": stats[0] or 0,
                "net_earnings": round(stats[1] or 0, 2),
            })
        
        return sorted(result, key=lambda x: x["net_earnings"], reverse=True)


# Initialize on import
init_db()
