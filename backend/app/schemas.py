from pydantic import BaseModel
from typing import Optional, List, Literal


# ==================== Ride schemas ====================

class QuoteRequest(BaseModel):
    pickup_text: str
    drop_text: str
    distance_km: float
    peak: bool = False


class Quote(BaseModel):
    corridor: str
    eta_min: int
    price_usd: float
    base_fare: float
    distance_fare: float
    total_usd: float


class CreateJob(BaseModel):
    pickup_text: str
    drop_text: str
    distance_km: float
    rider_name: str
    driver_id: Optional[str] = None
    fare_usd: Optional[float] = None


class Job(BaseModel):
    id: str
    status: Literal[
        "searching", "driver_assigned", "enroute",
        "arrived", "riding", "complete", "cancelled",
    ]
    driver_id: Optional[str] = None


# ==================== Food delivery schemas ====================

class OrderItem(BaseModel):
    menu_item_id: int
    name: str
    qty: int = 1
    price: float


class CreateFoodOrder(BaseModel):
    restaurant_id: str
    items: List[OrderItem]
    delivery_address: str
    delivery_lat: Optional[float] = None
    delivery_lng: Optional[float] = None
    payment_method: str = "cash"
    rider_name: Optional[str] = None
    rider_phone: Optional[str] = None
    special_instructions: Optional[str] = None
    promo_code: Optional[str] = None


# ==================== Wallet schemas ====================

class WalletTopUp(BaseModel):
    amount: float
    method: str = "ecocash"  # ecocash, innbucks, bank_transfer


class WalletPayment(BaseModel):
    amount: float
    reference_id: str
    type: str = "ride_payment"  # ride_payment, food_payment
    description: Optional[str] = None
