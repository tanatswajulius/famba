"""Database module supporting both SQLite and PostgreSQL."""
import json
import random
import string
from datetime import datetime
from typing import Dict, List, Optional
from contextlib import contextmanager

from sqlalchemy import create_engine, Column, String, Float, Integer, Boolean, Text, DateTime, ForeignKey, func
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


# ==================== SQLAlchemy Models ====================

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


# ==================== FOOD DELIVERY Models ====================

class Restaurant(Base):
    __tablename__ = "restaurants"

    id = Column(String(50), primary_key=True)
    name = Column(String(100), nullable=False)
    description = Column(Text, nullable=True)
    address = Column(String(255), nullable=True)
    area = Column(String(100), nullable=True)
    lat = Column(Float, nullable=True)
    lng = Column(Float, nullable=True)
    phone = Column(String(20), nullable=True)
    image_url = Column(String(255), nullable=True)
    category = Column(String(50), default="restaurant")  # fast_food, restaurant, cafe, grocery, bakery
    cuisine = Column(String(100), nullable=True)  # e.g. "Zimbabwean, Grills, Fast Food"
    rating = Column(Float, default=4.5)
    total_orders = Column(Integer, default=0)
    delivery_fee = Column(Float, default=1.00)
    min_order = Column(Float, default=2.00)
    avg_prep_time_min = Column(Integer, default=25)
    opening_time = Column(String(10), default="08:00")
    closing_time = Column(String(10), default="22:00")
    is_open = Column(Boolean, default=True)
    is_active = Column(Boolean, default=True)
    is_featured = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow)


class MenuItem(Base):
    __tablename__ = "menu_items"

    id = Column(Integer, primary_key=True, autoincrement=True)
    restaurant_id = Column(String(50), ForeignKey("restaurants.id"), nullable=False)
    name = Column(String(100), nullable=False)
    description = Column(Text, nullable=True)
    price = Column(Float, nullable=False)
    image_url = Column(String(255), nullable=True)
    category = Column(String(50), default="main")  # main, side, drink, dessert, combo
    is_available = Column(Boolean, default=True)
    is_popular = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow)


class FoodOrder(Base):
    __tablename__ = "food_orders"

    id = Column(String(50), primary_key=True)
    rider_id = Column(String(50), ForeignKey("users.id"), nullable=True)
    restaurant_id = Column(String(50), ForeignKey("restaurants.id"), nullable=False)
    driver_id = Column(String(50), ForeignKey("drivers.id"), nullable=True)
    status = Column(String(30), default="placed")  # placed, confirmed, preparing, ready, picked_up, delivering, delivered, cancelled
    items_json = Column(Text, nullable=False)  # JSON array of {menu_item_id, name, qty, price}
    subtotal = Column(Float, nullable=False)
    delivery_fee = Column(Float, default=1.00)
    discount = Column(Float, default=0.0)
    total = Column(Float, nullable=False)
    delivery_address = Column(String(255), nullable=True)
    delivery_lat = Column(Float, nullable=True)
    delivery_lng = Column(Float, nullable=True)
    payment_method = Column(String(30), default="cash")
    payment_status = Column(String(20), default="pending")
    rider_name = Column(String(100), nullable=True)
    rider_phone = Column(String(20), nullable=True)
    driver_json = Column(Text, nullable=True)
    special_instructions = Column(Text, nullable=True)
    estimated_delivery_min = Column(Integer, nullable=True)
    confirmed_at = Column(DateTime, nullable=True)
    picked_up_at = Column(DateTime, nullable=True)
    delivered_at = Column(DateTime, nullable=True)
    cancel_reason = Column(String(255), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


# ==================== WALLET Models ====================

class WalletTransaction(Base):
    __tablename__ = "wallet_transactions"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(String(50), ForeignKey("users.id"), nullable=False)
    type = Column(String(30), nullable=False)  # top_up, ride_payment, food_payment, referral_credit, refund, withdrawal
    amount = Column(Float, nullable=False)  # positive = credit, negative = debit
    balance_after = Column(Float, nullable=False)
    reference_id = Column(String(50), nullable=True)  # job_id or order_id
    description = Column(String(255), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)


# ==================== DISPUTE Model ====================

class Dispute(Base):
    __tablename__ = "disputes"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(String(50), ForeignKey("users.id"), nullable=True)
    job_id = Column(String(50), ForeignKey("jobs.id"), nullable=True)
    order_id = Column(String(50), ForeignKey("food_orders.id"), nullable=True)
    type = Column(String(30), nullable=False)  # wrong_item, late_delivery, driver_issue, payment, other
    description = Column(Text, nullable=False)
    status = Column(String(20), default="open")  # open, investigating, resolved, rejected
    resolution = Column(Text, nullable=True)
    refund_amount = Column(Float, default=0.0)
    created_at = Column(DateTime, default=datetime.utcnow)
    resolved_at = Column(DateTime, nullable=True)


# ==================== DRIVER DOCUMENT Model ====================

class DriverDocument(Base):
    __tablename__ = "driver_documents"

    id = Column(Integer, primary_key=True, autoincrement=True)
    driver_id = Column(String(50), ForeignKey("drivers.id"), nullable=False)
    doc_type = Column(String(30), nullable=False)  # national_id, drivers_license, vehicle_registration, insurance
    doc_number = Column(String(100), nullable=True)
    file_url = Column(String(255), nullable=True)
    status = Column(String(20), default="pending")  # pending, approved, rejected
    rejection_reason = Column(String(255), nullable=True)
    submitted_at = Column(DateTime, default=datetime.utcnow)
    reviewed_at = Column(DateTime, nullable=True)
    reviewed_by = Column(String(50), nullable=True)


# ==================== FOOD RATING Model ====================

class FoodOrderRating(Base):
    __tablename__ = "food_order_ratings"

    id = Column(Integer, primary_key=True, autoincrement=True)
    order_id = Column(String(50), ForeignKey("food_orders.id"), nullable=False)
    restaurant_id = Column(String(50), ForeignKey("restaurants.id"), nullable=False)
    rider_id = Column(String(50), ForeignKey("users.id"), nullable=True)
    food_rating = Column(Float, nullable=False)
    delivery_rating = Column(Float, nullable=True)
    comment = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)


# ==================== CHAT Message Model ====================

class ChatMessageModel(Base):
    __tablename__ = "chat_messages"

    id = Column(Integer, primary_key=True, autoincrement=True)
    job_id = Column(String(50), ForeignKey("jobs.id"), nullable=True)
    order_id = Column(String(50), ForeignKey("food_orders.id"), nullable=True)
    sender_type = Column(String(20), nullable=False)  # rider, driver
    sender_id = Column(String(50), nullable=True)
    message = Column(Text, nullable=False)
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

    # Seed promo codes (updated expiry dates)
    if db.query(PromoCode).count() == 0:
        promos = [
            PromoCode(code="FAMBA50", discount_percent=50, max_discount=5.00,
                     expires_at=datetime(2027, 6, 30, 23, 59, 59)),
            PromoCode(code="RIDE25", discount_percent=25, max_discount=3.00,
                     expires_at=datetime(2027, 6, 30, 23, 59, 59)),
            PromoCode(code="FIRST10", discount_percent=10, max_discount=2.00,
                     expires_at=datetime(2027, 6, 30, 23, 59, 59)),
            PromoCode(code="FOOD20", discount_percent=20, max_discount=4.00,
                     expires_at=datetime(2027, 6, 30, 23, 59, 59)),
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

    # Seed restaurants (Harare-based)
    if db.query(Restaurant).count() == 0:
        restaurants = [
            Restaurant(
                id="rest_01", name="Chicken Inn CBD", description="Zimbabwe's favourite fried chicken. Crispy, juicy, and always fresh.",
                address="First St & Jason Moyo Ave", area="CBD", lat=-17.8290, lng=31.0520,
                phone="0242700100", category="fast_food", cuisine="Fried Chicken, Fast Food",
                rating=4.3, delivery_fee=1.00, min_order=2.00, avg_prep_time_min=15,
                is_featured=True,
            ),
            Restaurant(
                id="rest_02", name="Nando's Avondale", description="Flame-grilled PERi-PERi chicken with that legendary Nando's flavour.",
                address="King George Rd, Avondale", area="Avondale", lat=-17.7925, lng=31.0418,
                phone="0242334455", category="restaurant", cuisine="PERi-PERi, Grills",
                rating=4.5, delivery_fee=1.50, min_order=3.00, avg_prep_time_min=20,
                is_featured=True,
            ),
            Restaurant(
                id="rest_03", name="Galito's Eastgate", description="Flame-grilled chicken at great prices. Meals, wraps, and sides.",
                address="Eastgate Mall, Robert Mugabe Rd", area="CBD", lat=-17.8312, lng=31.0548,
                phone="0242750300", category="fast_food", cuisine="Grilled Chicken, Fast Food",
                rating=4.2, delivery_fee=1.00, min_order=2.00, avg_prep_time_min=15,
            ),
            Restaurant(
                id="rest_04", name="Mambo's Grill", description="Authentic Zimbabwean braai and sadza. Home-cooked taste with generous portions.",
                address="Samora Machel Ave, CBD", area="CBD", lat=-17.8275, lng=31.0505,
                phone="0242780100", category="restaurant", cuisine="Zimbabwean, Braai, Traditional",
                rating=4.6, delivery_fee=1.00, min_order=2.50, avg_prep_time_min=25,
                is_featured=True,
            ),
            Restaurant(
                id="rest_05", name="Spur Borrowdale", description="Family restaurant with ribs, steaks, burgers, and great desserts.",
                address="Borrowdale Rd, Sam Levy's Village", area="Borrowdale", lat=-17.7852, lng=31.0648,
                phone="0242885500", category="restaurant", cuisine="Steaks, Burgers, Family",
                rating=4.4, delivery_fee=2.00, min_order=5.00, avg_prep_time_min=30,
            ),
            Restaurant(
                id="rest_06", name="Creamy Inn", description="Ice cream, milkshakes, and soft serve. Perfect treats for Harare's sunny days.",
                address="Joina City, CBD", area="CBD", lat=-17.8296, lng=31.0532,
                phone="0242700200", category="cafe", cuisine="Ice Cream, Desserts, Drinks",
                rating=4.1, delivery_fee=1.00, min_order=1.50, avg_prep_time_min=10,
            ),
            Restaurant(
                id="rest_07", name="Pizza Inn Sam Levy's", description="Fresh pizza made to order. Wide range of toppings and combos.",
                address="Sam Levy's Village, Borrowdale", area="Borrowdale", lat=-17.7848, lng=31.0652,
                phone="0242885600", category="fast_food", cuisine="Pizza, Italian, Fast Food",
                rating=4.3, delivery_fee=1.50, min_order=3.00, avg_prep_time_min=20,
                is_featured=True,
            ),
            Restaurant(
                id="rest_08", name="Mimi's Kitchen", description="Home-style Zimbabwean cooking. Sadza, stews, and fresh vegetables daily.",
                address="Mbare Musika area", area="Mbare", lat=-17.8605, lng=31.0355,
                phone="0772100200", category="restaurant", cuisine="Zimbabwean, Home Cooking, Traditional",
                rating=4.7, delivery_fee=0.75, min_order=1.50, avg_prep_time_min=20,
            ),
        ]
        db.add_all(restaurants)

    # Seed menu items
    if db.query(MenuItem).count() == 0:
        menu_items = [
            # Chicken Inn
            MenuItem(restaurant_id="rest_01", name="2 Piece Chicken & Chips", description="2 crispy fried chicken pieces with golden chips", price=3.50, category="main", is_popular=True),
            MenuItem(restaurant_id="rest_01", name="Chicken Burger Combo", description="Chicken burger, chips, and a drink", price=4.50, category="combo", is_popular=True),
            MenuItem(restaurant_id="rest_01", name="6 Piece Bucket", description="6 pieces of crispy fried chicken", price=8.00, category="main"),
            MenuItem(restaurant_id="rest_01", name="Chip Roll", description="Chips in a fresh roll with sauce", price=1.50, category="side"),
            MenuItem(restaurant_id="rest_01", name="Coleslaw", description="Fresh creamy coleslaw", price=1.00, category="side"),
            MenuItem(restaurant_id="rest_01", name="Coca-Cola 500ml", description="Ice cold Coca-Cola", price=1.00, category="drink"),
            # Nando's
            MenuItem(restaurant_id="rest_02", name="Quarter Chicken & 2 Sides", description="Quarter flame-grilled PERi-PERi chicken with 2 sides of your choice", price=6.00, category="main", is_popular=True),
            MenuItem(restaurant_id="rest_02", name="Full Chicken", description="Whole flame-grilled PERi-PERi chicken", price=12.00, category="main"),
            MenuItem(restaurant_id="rest_02", name="Chicken Wrap", description="PERi-PERi chicken wrap with fresh salad", price=5.00, category="main", is_popular=True),
            MenuItem(restaurant_id="rest_02", name="PERi Chips (Regular)", description="Crispy chips with PERi-PERi salt", price=2.50, category="side"),
            MenuItem(restaurant_id="rest_02", name="Bottomless Drink", description="Unlimited refills on soft drinks", price=2.00, category="drink"),
            # Galito's
            MenuItem(restaurant_id="rest_03", name="Quarter Chicken Meal", description="Quarter chicken with rice or chips", price=4.00, category="main", is_popular=True),
            MenuItem(restaurant_id="rest_03", name="Chicken Wrap", description="Flame-grilled chicken wrap", price=3.50, category="main"),
            MenuItem(restaurant_id="rest_03", name="Wings (6 pcs)", description="Flame-grilled chicken wings", price=4.00, category="main"),
            # Mambo's Grill
            MenuItem(restaurant_id="rest_04", name="Sadza & Beef Stew", description="Traditional sadza with rich beef stew and vegetables", price=3.00, category="main", is_popular=True),
            MenuItem(restaurant_id="rest_04", name="Sadza & Chicken", description="Sadza with grilled or stewed chicken", price=3.50, category="main", is_popular=True),
            MenuItem(restaurant_id="rest_04", name="T-Bone Steak", description="Braai-grilled T-bone steak with sadza and salad", price=7.00, category="main"),
            MenuItem(restaurant_id="rest_04", name="Madora & Sadza", description="Traditional mopane worms with sadza", price=4.00, category="main"),
            MenuItem(restaurant_id="rest_04", name="Mazoe Orange", description="Refreshing Mazoe orange crush", price=0.75, category="drink"),
            # Spur
            MenuItem(restaurant_id="rest_05", name="Spur Burger", description="Classic beef burger with all the trimmings", price=6.50, category="main", is_popular=True),
            MenuItem(restaurant_id="rest_05", name="Pork Ribs (Full)", description="Full rack of slow-basted BBQ pork ribs", price=12.00, category="main"),
            MenuItem(restaurant_id="rest_05", name="Cheese & Bacon Burger", description="Beef burger with melted cheese and crispy bacon", price=7.50, category="main"),
            MenuItem(restaurant_id="rest_05", name="Chocolate Brownie", description="Warm chocolate brownie with ice cream", price=3.50, category="dessert"),
            # Creamy Inn
            MenuItem(restaurant_id="rest_06", name="Soft Serve (Regular)", description="Creamy vanilla soft serve cone", price=1.00, category="dessert", is_popular=True),
            MenuItem(restaurant_id="rest_06", name="Chocolate Milkshake", description="Thick chocolate milkshake", price=2.50, category="drink", is_popular=True),
            MenuItem(restaurant_id="rest_06", name="Sundae", description="Soft serve sundae with your choice of topping", price=2.00, category="dessert"),
            # Pizza Inn
            MenuItem(restaurant_id="rest_07", name="Meat Feast Pizza (Medium)", description="Loaded with beef, pepperoni, ham, and sausage", price=7.00, category="main", is_popular=True),
            MenuItem(restaurant_id="rest_07", name="Margherita Pizza (Medium)", description="Classic tomato and mozzarella", price=5.00, category="main"),
            MenuItem(restaurant_id="rest_07", name="BBQ Chicken Pizza (Medium)", description="BBQ sauce base with grilled chicken", price=6.50, category="main"),
            MenuItem(restaurant_id="rest_07", name="Garlic Bread", description="Toasted garlic bread with herb butter", price=2.00, category="side"),
            # Mimi's Kitchen
            MenuItem(restaurant_id="rest_08", name="Sadza & Muriwo", description="Sadza with fresh green vegetables", price=2.00, category="main", is_popular=True),
            MenuItem(restaurant_id="rest_08", name="Sadza, Beef & Muriwo", description="Full plate: sadza, beef stew, and greens", price=3.50, category="main", is_popular=True),
            MenuItem(restaurant_id="rest_08", name="Rice & Chicken", description="Rice with stewed chicken", price=3.00, category="main"),
            MenuItem(restaurant_id="rest_08", name="Maputi (Large)", description="Large bag of roasted maize kernels", price=0.50, category="side"),
            MenuItem(restaurant_id="rest_08", name="Sweet Tea", description="Zimbabwean-style sweet tea", price=0.50, category="drink"),
        ]
        db.add_all(menu_items)

    db.commit()


# Counters for generating IDs
_job_counter = 1000
_order_counter = 5000


# ==================== USER DB Operations (for auth persistence) ====================

def db_create_user(user_id: str, phone: str, name: str, password_hash: str,
                   user_type: str = "rider") -> dict:
    """Create a new user in the database."""
    with get_db() as db:
        user = User(
            id=user_id, phone=phone, name=name,
            password_hash=password_hash, user_type=user_type,
        )
        db.add(user)
        db.commit()
        db.refresh(user)
        return _user_to_dict(user)


def db_get_user_by_id(user_id: str) -> Optional[dict]:
    """Get user by ID from the database."""
    with get_db() as db:
        user = db.query(User).filter(User.id == user_id).first()
        return _user_to_dict(user) if user else None


def db_get_user_by_phone(phone: str) -> Optional[dict]:
    """Get user by phone number from the database."""
    with get_db() as db:
        user = db.query(User).filter(User.phone == phone).first()
        return _user_to_dict(user) if user else None


def db_list_users(limit: int = 100) -> List[dict]:
    """List all users."""
    with get_db() as db:
        users = db.query(User).order_by(User.created_at.desc()).limit(limit).all()
        return [_user_to_dict(u) for u in users]


def db_update_user(user_id: str, **updates) -> Optional[dict]:
    """Update user fields."""
    with get_db() as db:
        user = db.query(User).filter(User.id == user_id).first()
        if not user:
            return None
        for key, value in updates.items():
            if hasattr(user, key):
                setattr(user, key, value)
        user.updated_at = datetime.utcnow()
        db.commit()
        db.refresh(user)
        return _user_to_dict(user)


def db_get_user_count() -> int:
    """Get total user count."""
    with get_db() as db:
        return db.query(User).count()


def _user_to_dict(user: User) -> dict:
    """Convert User model to dictionary."""
    return {
        "id": user.id,
        "phone": user.phone,
        "name": user.name,
        "email": user.email,
        "password_hash": user.password_hash,
        "user_type": user.user_type,
        "is_verified": user.is_verified,
        "is_active": user.is_active,
        "wallet_balance": user.wallet_balance,
        "referral_code": user.referral_code,
        "created_at": user.created_at.isoformat() if user.created_at else None,
    }


# ==================== JOB CRUD Operations ====================

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
            avg = db.query(func.avg(Rating.rating)).filter(
                Rating.driver_id == driver.id
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
            func.count(DriverEarning.id),
            func.sum(DriverEarning.amount),
            func.sum(DriverEarning.commission),
            func.sum(DriverEarning.net_amount),
            func.avg(DriverEarning.net_amount),
        ).filter(DriverEarning.driver_id == driver_id).first()

        today = datetime.utcnow().strftime("%Y-%m-%d")
        today_stats = db.query(
            func.count(DriverEarning.id),
            func.sum(DriverEarning.net_amount),
        ).filter(
            DriverEarning.driver_id == driver_id,
            func.date(DriverEarning.created_at) == today,
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
                func.count(DriverEarning.id),
                func.sum(DriverEarning.net_amount),
            ).filter(DriverEarning.driver_id == d.id).first()

            result.append({
                "id": d.id,
                "name": d.name,
                "rating": d.rating,
                "total_trips": stats[0] or 0,
                "net_earnings": round(stats[1] or 0, 2),
            })

        return sorted(result, key=lambda x: x["net_earnings"], reverse=True)


# ==================== RESTAURANT CRUD ====================

def list_restaurants(category: Optional[str] = None, area: Optional[str] = None,
                     featured_only: bool = False, limit: int = 50) -> List[dict]:
    """List restaurants with optional filters."""
    with get_db() as db:
        q = db.query(Restaurant).filter(Restaurant.is_active == True)
        if category:
            q = q.filter(Restaurant.category == category)
        if area:
            q = q.filter(Restaurant.area.ilike(f"%{area}%"))
        if featured_only:
            q = q.filter(Restaurant.is_featured == True)
        restaurants = q.order_by(Restaurant.rating.desc()).limit(limit).all()
        return [_restaurant_to_dict(r) for r in restaurants]


def get_restaurant(restaurant_id: str) -> Optional[dict]:
    """Get restaurant by ID."""
    with get_db() as db:
        r = db.query(Restaurant).filter(Restaurant.id == restaurant_id).first()
        return _restaurant_to_dict(r) if r else None


def search_restaurants(query: str, limit: int = 20) -> List[dict]:
    """Search restaurants by name, cuisine, or area."""
    with get_db() as db:
        restaurants = db.query(Restaurant).filter(
            Restaurant.is_active == True,
            (Restaurant.name.ilike(f"%{query}%")) |
            (Restaurant.cuisine.ilike(f"%{query}%")) |
            (Restaurant.area.ilike(f"%{query}%"))
        ).order_by(Restaurant.rating.desc()).limit(limit).all()
        return [_restaurant_to_dict(r) for r in restaurants]


def _restaurant_to_dict(r: Restaurant) -> dict:
    return {
        "id": r.id,
        "name": r.name,
        "description": r.description,
        "address": r.address,
        "area": r.area,
        "lat": r.lat,
        "lng": r.lng,
        "phone": r.phone,
        "image_url": r.image_url,
        "category": r.category,
        "cuisine": r.cuisine,
        "rating": r.rating,
        "total_orders": r.total_orders,
        "delivery_fee": r.delivery_fee,
        "min_order": r.min_order,
        "avg_prep_time_min": r.avg_prep_time_min,
        "opening_time": r.opening_time,
        "closing_time": r.closing_time,
        "is_open": r.is_open,
        "is_featured": r.is_featured,
    }


# ==================== MENU ITEM CRUD ====================

def get_menu(restaurant_id: str, category: Optional[str] = None) -> List[dict]:
    """Get menu items for a restaurant."""
    with get_db() as db:
        q = db.query(MenuItem).filter(
            MenuItem.restaurant_id == restaurant_id,
            MenuItem.is_available == True,
        )
        if category:
            q = q.filter(MenuItem.category == category)
        items = q.order_by(MenuItem.is_popular.desc(), MenuItem.name).all()
        return [_menu_item_to_dict(i) for i in items]


def get_menu_item(item_id: int) -> Optional[dict]:
    """Get a single menu item."""
    with get_db() as db:
        item = db.query(MenuItem).filter(MenuItem.id == item_id).first()
        return _menu_item_to_dict(item) if item else None


def _menu_item_to_dict(i: MenuItem) -> dict:
    return {
        "id": i.id,
        "restaurant_id": i.restaurant_id,
        "name": i.name,
        "description": i.description,
        "price": i.price,
        "image_url": i.image_url,
        "category": i.category,
        "is_available": i.is_available,
        "is_popular": i.is_popular,
    }


# ==================== FOOD ORDER CRUD ====================

def create_food_order(data: dict) -> dict:
    """Create a new food order."""
    global _order_counter
    _order_counter += 1
    order_id = f"FO{_order_counter}"

    with get_db() as db:
        order = FoodOrder(
            id=order_id,
            rider_id=data.get("rider_id"),
            restaurant_id=data["restaurant_id"],
            status="placed",
            items_json=json.dumps(data["items"]),
            subtotal=data["subtotal"],
            delivery_fee=data.get("delivery_fee", 1.00),
            discount=data.get("discount", 0.0),
            total=data["total"],
            delivery_address=data.get("delivery_address"),
            delivery_lat=data.get("delivery_lat"),
            delivery_lng=data.get("delivery_lng"),
            payment_method=data.get("payment_method", "cash"),
            rider_name=data.get("rider_name"),
            rider_phone=data.get("rider_phone"),
            special_instructions=data.get("special_instructions"),
            estimated_delivery_min=data.get("estimated_delivery_min"),
        )
        db.add(order)

        # Increment restaurant order count
        restaurant = db.query(Restaurant).filter(Restaurant.id == data["restaurant_id"]).first()
        if restaurant:
            restaurant.total_orders = (restaurant.total_orders or 0) + 1

        db.commit()
        db.refresh(order)
        return _food_order_to_dict(order)


def get_food_order(order_id: str) -> Optional[dict]:
    """Get food order by ID."""
    with get_db() as db:
        order = db.query(FoodOrder).filter(FoodOrder.id == order_id).first()
        return _food_order_to_dict(order) if order else None


def update_food_order(order_id: str, **updates) -> Optional[dict]:
    """Update a food order."""
    with get_db() as db:
        order = db.query(FoodOrder).filter(FoodOrder.id == order_id).first()
        if not order:
            return None

        if "driver" in updates:
            updates["driver_json"] = json.dumps(updates.pop("driver"))

        now = datetime.utcnow()
        new_status = updates.get("status")
        if new_status == "confirmed" and not order.confirmed_at:
            updates["confirmed_at"] = now
        elif new_status == "picked_up" and not order.picked_up_at:
            updates["picked_up_at"] = now
        elif new_status == "delivered" and not order.delivered_at:
            updates["delivered_at"] = now

        for key, value in updates.items():
            if hasattr(order, key):
                setattr(order, key, value)

        order.updated_at = now
        db.commit()
        db.refresh(order)
        return _food_order_to_dict(order)


def list_food_orders(rider_id: Optional[str] = None, restaurant_id: Optional[str] = None,
                     status: Optional[str] = None, limit: int = 50) -> List[dict]:
    """List food orders with optional filters."""
    with get_db() as db:
        q = db.query(FoodOrder)
        if rider_id:
            q = q.filter(FoodOrder.rider_id == rider_id)
        if restaurant_id:
            q = q.filter(FoodOrder.restaurant_id == restaurant_id)
        if status:
            q = q.filter(FoodOrder.status == status)
        orders = q.order_by(FoodOrder.created_at.desc()).limit(limit).all()
        return [_food_order_to_dict(o) for o in orders]


def _food_order_to_dict(o: FoodOrder) -> dict:
    result = {
        "id": o.id,
        "rider_id": o.rider_id,
        "restaurant_id": o.restaurant_id,
        "driver_id": o.driver_id,
        "status": o.status,
        "items": json.loads(o.items_json) if o.items_json else [],
        "subtotal": o.subtotal,
        "delivery_fee": o.delivery_fee,
        "discount": o.discount,
        "total": o.total,
        "delivery_address": o.delivery_address,
        "delivery_lat": o.delivery_lat,
        "delivery_lng": o.delivery_lng,
        "payment_method": o.payment_method,
        "payment_status": o.payment_status,
        "rider_name": o.rider_name,
        "rider_phone": o.rider_phone,
        "special_instructions": o.special_instructions,
        "estimated_delivery_min": o.estimated_delivery_min,
        "cancel_reason": o.cancel_reason,
        "created_at": o.created_at.isoformat() if o.created_at else None,
        "confirmed_at": o.confirmed_at.isoformat() if o.confirmed_at else None,
        "picked_up_at": o.picked_up_at.isoformat() if o.picked_up_at else None,
        "delivered_at": o.delivered_at.isoformat() if o.delivered_at else None,
    }
    if o.driver_json:
        result["driver"] = json.loads(o.driver_json)
    else:
        result["driver"] = None
    return result


# ==================== WALLET CRUD ====================

def get_wallet_balance(user_id: str) -> float:
    """Get user wallet balance."""
    with get_db() as db:
        user = db.query(User).filter(User.id == user_id).first()
        return user.wallet_balance if user else 0.0


def wallet_top_up(user_id: str, amount: float, description: str = "Wallet top-up") -> dict:
    """Add money to wallet."""
    with get_db() as db:
        user = db.query(User).filter(User.id == user_id).first()
        if not user:
            return {"ok": False, "message": "User not found"}

        user.wallet_balance = (user.wallet_balance or 0) + amount
        txn = WalletTransaction(
            user_id=user_id, type="top_up", amount=amount,
            balance_after=user.wallet_balance, description=description,
        )
        db.add(txn)
        db.commit()
        return {"ok": True, "balance": user.wallet_balance, "transaction_id": txn.id}


def wallet_deduct(user_id: str, amount: float, txn_type: str = "ride_payment",
                  reference_id: str = None, description: str = "Payment") -> dict:
    """Deduct money from wallet."""
    with get_db() as db:
        user = db.query(User).filter(User.id == user_id).first()
        if not user:
            return {"ok": False, "message": "User not found"}
        if (user.wallet_balance or 0) < amount:
            return {"ok": False, "message": "Insufficient balance"}

        user.wallet_balance -= amount
        txn = WalletTransaction(
            user_id=user_id, type=txn_type, amount=-amount,
            balance_after=user.wallet_balance, reference_id=reference_id,
            description=description,
        )
        db.add(txn)
        db.commit()
        return {"ok": True, "balance": user.wallet_balance, "transaction_id": txn.id}


def wallet_credit(user_id: str, amount: float, txn_type: str = "referral_credit",
                  reference_id: str = None, description: str = "Credit") -> dict:
    """Credit money to wallet (refunds, referral bonuses, etc.)."""
    with get_db() as db:
        user = db.query(User).filter(User.id == user_id).first()
        if not user:
            return {"ok": False, "message": "User not found"}

        user.wallet_balance = (user.wallet_balance or 0) + amount
        txn = WalletTransaction(
            user_id=user_id, type=txn_type, amount=amount,
            balance_after=user.wallet_balance, reference_id=reference_id,
            description=description,
        )
        db.add(txn)
        db.commit()
        return {"ok": True, "balance": user.wallet_balance, "transaction_id": txn.id}


def get_wallet_transactions(user_id: str, limit: int = 50) -> List[dict]:
    """Get wallet transaction history."""
    with get_db() as db:
        txns = db.query(WalletTransaction).filter(
            WalletTransaction.user_id == user_id
        ).order_by(WalletTransaction.created_at.desc()).limit(limit).all()
        return [{
            "id": t.id,
            "type": t.type,
            "amount": t.amount,
            "balance_after": t.balance_after,
            "reference_id": t.reference_id,
            "description": t.description,
            "created_at": t.created_at.isoformat() if t.created_at else None,
        } for t in txns]


# ==================== FOOD ORDER RATING CRUD ====================

def add_food_rating(data: dict) -> dict:
    """Add a food order rating."""
    with get_db() as db:
        rating = FoodOrderRating(
            order_id=data["order_id"],
            restaurant_id=data["restaurant_id"],
            rider_id=data.get("rider_id"),
            food_rating=data["food_rating"],
            delivery_rating=data.get("delivery_rating"),
            comment=data.get("comment"),
        )
        db.add(rating)

        # Update restaurant average rating
        restaurant = db.query(Restaurant).filter(
            Restaurant.id == data["restaurant_id"]
        ).first()
        if restaurant:
            avg = db.query(func.avg(FoodOrderRating.food_rating)).filter(
                FoodOrderRating.restaurant_id == restaurant.id
            ).scalar()
            if avg:
                restaurant.rating = round(avg, 2)

        db.commit()
        return {"ok": True, "id": rating.id, "restaurant_rating": restaurant.rating if restaurant else None}


def get_restaurant_ratings(restaurant_id: str, limit: int = 20) -> List[dict]:
    """Get ratings for a restaurant."""
    with get_db() as db:
        ratings = db.query(FoodOrderRating).filter(
            FoodOrderRating.restaurant_id == restaurant_id
        ).order_by(FoodOrderRating.created_at.desc()).limit(limit).all()
        return [{
            "id": r.id, "order_id": r.order_id,
            "food_rating": r.food_rating, "delivery_rating": r.delivery_rating,
            "comment": r.comment,
            "created_at": r.created_at.isoformat() if r.created_at else None,
        } for r in ratings]


# ==================== CHAT CRUD ====================

def save_chat_message(job_id: str = None, order_id: str = None,
                      sender_type: str = "rider", sender_id: str = None,
                      message: str = "") -> dict:
    """Save a chat message."""
    with get_db() as db:
        msg = ChatMessageModel(
            job_id=job_id, order_id=order_id,
            sender_type=sender_type, sender_id=sender_id,
            message=message,
        )
        db.add(msg)
        db.commit()
        db.refresh(msg)
        return {
            "id": msg.id, "job_id": msg.job_id, "order_id": msg.order_id,
            "sender_type": msg.sender_type, "message": msg.message,
            "created_at": msg.created_at.isoformat() if msg.created_at else None,
        }


def get_chat_history(job_id: str = None, order_id: str = None,
                     limit: int = 50) -> List[dict]:
    """Get chat messages for a job or order."""
    with get_db() as db:
        q = db.query(ChatMessageModel)
        if job_id:
            q = q.filter(ChatMessageModel.job_id == job_id)
        elif order_id:
            q = q.filter(ChatMessageModel.order_id == order_id)
        else:
            return []
        msgs = q.order_by(ChatMessageModel.created_at.asc()).limit(limit).all()
        return [{
            "id": m.id, "job_id": m.job_id, "order_id": m.order_id,
            "sender_type": m.sender_type, "message": m.message,
            "created_at": m.created_at.isoformat() if m.created_at else None,
        } for m in msgs]


# ==================== PROXIMITY DRIVER MATCHING ====================

import math


def _haversine_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Calculate distance between two lat/lng points in km."""
    R = 6371.0
    dlat = math.radians(lat2 - lat1)
    dlng = math.radians(lng2 - lng1)
    a = (math.sin(dlat / 2) ** 2 +
         math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) *
         math.sin(dlng / 2) ** 2)
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def pick_nearest_driver(pickup_lat: float = None, pickup_lng: float = None) -> dict:
    """Pick the nearest available driver to a pickup location."""
    if pickup_lat is None or pickup_lng is None:
        return pick_driver()

    with get_db() as db:
        drivers = db.query(Driver).filter(
            Driver.is_active == True,
            Driver.lat.isnot(None),
            Driver.lng.isnot(None),
        ).all()

        if not drivers:
            return pick_driver()

        best = None
        best_dist = float('inf')
        for d in drivers:
            dist = _haversine_km(pickup_lat, pickup_lng, d.lat, d.lng)
            if dist < best_dist:
                best_dist = dist
                best = d

        if best:
            return _driver_to_dict(best)
        return pick_driver()


def update_driver_location(driver_id: str, lat: float, lng: float) -> dict:
    """Update a driver's live location."""
    with get_db() as db:
        driver = db.query(Driver).filter(Driver.id == driver_id).first()
        if not driver:
            return {"ok": False, "message": "Driver not found"}
        driver.lat = lat
        driver.lng = lng
        driver.is_online = True
        db.commit()
        return {"ok": True, "driver_id": driver_id, "lat": lat, "lng": lng}


# ==================== UNIFIED ORDER HISTORY ====================

def get_user_history(user_name: str = None, limit: int = 50) -> List[dict]:
    """Get combined ride + food order history for a user."""
    results = []

    with get_db() as db:
        # Rides
        ride_q = db.query(Job)
        if user_name:
            ride_q = ride_q.filter(Job.rider_name.ilike(f"%{user_name}%"))
        rides = ride_q.order_by(Job.created_at.desc()).limit(limit).all()

        for j in rides:
            results.append({
                "type": "ride",
                "id": j.id,
                "status": j.status,
                "from": j.pickup_text,
                "to": j.drop_text,
                "amount": j.fare_usd,
                "payment_method": j.payment_method,
                "created_at": j.created_at.isoformat() if j.created_at else None,
                "driver": json.loads(j.driver_json) if j.driver_json else None,
            })

        # Food orders
        order_q = db.query(FoodOrder)
        if user_name:
            order_q = order_q.filter(FoodOrder.rider_name.ilike(f"%{user_name}%"))
        orders = order_q.order_by(FoodOrder.created_at.desc()).limit(limit).all()

        for o in orders:
            restaurant = db.query(Restaurant).filter(Restaurant.id == o.restaurant_id).first()
            results.append({
                "type": "food_order",
                "id": o.id,
                "status": o.status,
                "restaurant": restaurant.name if restaurant else o.restaurant_id,
                "items_count": len(json.loads(o.items_json)) if o.items_json else 0,
                "amount": o.total,
                "payment_method": o.payment_method,
                "delivery_address": o.delivery_address,
                "created_at": o.created_at.isoformat() if o.created_at else None,
                "driver": json.loads(o.driver_json) if o.driver_json else None,
            })

    # Sort by date, newest first
    results.sort(key=lambda x: x.get("created_at") or "", reverse=True)
    return results[:limit]


# ==================== DISPUTE CRUD ====================

def create_dispute(data: dict) -> dict:
    """Create a new dispute."""
    with get_db() as db:
        dispute = Dispute(
            user_id=data.get("user_id"),
            job_id=data.get("job_id"),
            order_id=data.get("order_id"),
            type=data["type"],
            description=data["description"],
        )
        db.add(dispute)
        db.commit()
        db.refresh(dispute)
        return _dispute_to_dict(dispute)


def get_dispute(dispute_id: int) -> Optional[dict]:
    with get_db() as db:
        d = db.query(Dispute).filter(Dispute.id == dispute_id).first()
        return _dispute_to_dict(d) if d else None


def list_disputes(status: str = None, limit: int = 50) -> List[dict]:
    with get_db() as db:
        q = db.query(Dispute)
        if status:
            q = q.filter(Dispute.status == status)
        disputes = q.order_by(Dispute.created_at.desc()).limit(limit).all()
        return [_dispute_to_dict(d) for d in disputes]


def resolve_dispute(dispute_id: int, resolution: str, refund_amount: float = 0,
                    status: str = "resolved") -> Optional[dict]:
    with get_db() as db:
        d = db.query(Dispute).filter(Dispute.id == dispute_id).first()
        if not d:
            return None
        d.status = status
        d.resolution = resolution
        d.refund_amount = refund_amount
        d.resolved_at = datetime.utcnow()
        db.commit()
        db.refresh(d)
        return _dispute_to_dict(d)


def _dispute_to_dict(d: Dispute) -> dict:
    return {
        "id": d.id, "user_id": d.user_id, "job_id": d.job_id,
        "order_id": d.order_id, "type": d.type,
        "description": d.description, "status": d.status,
        "resolution": d.resolution, "refund_amount": d.refund_amount,
        "created_at": d.created_at.isoformat() if d.created_at else None,
        "resolved_at": d.resolved_at.isoformat() if d.resolved_at else None,
    }


# ==================== DRIVER DOCUMENT CRUD ====================

def submit_driver_document(data: dict) -> dict:
    """Submit a driver document for verification."""
    with get_db() as db:
        doc = DriverDocument(
            driver_id=data["driver_id"],
            doc_type=data["doc_type"],
            doc_number=data.get("doc_number"),
            file_url=data.get("file_url"),
        )
        db.add(doc)
        db.commit()
        db.refresh(doc)
        return _doc_to_dict(doc)


def get_driver_documents(driver_id: str) -> List[dict]:
    with get_db() as db:
        docs = db.query(DriverDocument).filter(
            DriverDocument.driver_id == driver_id
        ).order_by(DriverDocument.submitted_at.desc()).all()
        return [_doc_to_dict(d) for d in docs]


def list_pending_documents(limit: int = 50) -> List[dict]:
    with get_db() as db:
        docs = db.query(DriverDocument).filter(
            DriverDocument.status == "pending"
        ).order_by(DriverDocument.submitted_at.asc()).limit(limit).all()
        return [_doc_to_dict(d) for d in docs]


def list_all_documents(status: str = None, limit: int = 100) -> List[dict]:
    with get_db() as db:
        q = db.query(DriverDocument)
        if status:
            q = q.filter(DriverDocument.status == status)
        docs = q.order_by(DriverDocument.submitted_at.desc()).limit(limit).all()
        return [_doc_to_dict(d) for d in docs]


def review_driver_document(doc_id: int, status: str, reviewed_by: str = None,
                           rejection_reason: str = None) -> Optional[dict]:
    with get_db() as db:
        doc = db.query(DriverDocument).filter(DriverDocument.id == doc_id).first()
        if not doc:
            return None
        doc.status = status
        doc.reviewed_at = datetime.utcnow()
        doc.reviewed_by = reviewed_by
        if rejection_reason:
            doc.rejection_reason = rejection_reason

        # Auto-verify driver if all required docs are approved
        if status == "approved":
            required = {"national_id", "drivers_license"}
            approved = set(
                d.doc_type for d in db.query(DriverDocument).filter(
                    DriverDocument.driver_id == doc.driver_id,
                    DriverDocument.status == "approved",
                ).all()
            )
            approved.add(doc.doc_type)
            if required.issubset(approved):
                driver = db.query(Driver).filter(Driver.id == doc.driver_id).first()
                if driver:
                    driver.is_verified = True
                    driver.documents_verified = True

        db.commit()
        db.refresh(doc)
        return _doc_to_dict(doc)


def _doc_to_dict(d: DriverDocument) -> dict:
    return {
        "id": d.id, "driver_id": d.driver_id,
        "doc_type": d.doc_type, "doc_number": d.doc_number,
        "file_url": d.file_url, "status": d.status,
        "rejection_reason": d.rejection_reason,
        "submitted_at": d.submitted_at.isoformat() if d.submitted_at else None,
        "reviewed_at": d.reviewed_at.isoformat() if d.reviewed_at else None,
        "reviewed_by": d.reviewed_by,
    }


# Initialize on import
init_db()
