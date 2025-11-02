from pydantic import BaseModel
from typing import Optional, Literal


class QuoteRequest(BaseModel):
    pickup_text: str
    drop_text: str
    distance_km: float
    peak: bool = False


class Quote(BaseModel):
    corridor: str
    eta_min: int
    price_usd: float


class CreateJob(BaseModel):
    pickup_text: str
    drop_text: str
    distance_km: float
    rider_name: str


class Job(BaseModel):
    id: str
    status: Literal[
        "searching",
        "driver_assigned",
        "enroute",
        "arrived",
        "riding",
        "complete"
    ]
    driver_id: Optional[str] = None
