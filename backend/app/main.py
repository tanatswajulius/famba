import os
import secrets

from dotenv import load_dotenv
from fastapi import Depends, FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBasic, HTTPBasicCredentials

from .recommend import (
    classify_corridor,
    estimate_eta_minutes,
    estimate_price_usd,
)
from .schemas import CreateJob, Quote, QuoteRequest
from .simulator import simulate
from .store import (
    create_job,
    get_job,
    get_next_driver,
    get_driver_by_id,
    list_jobs,
    pick_driver,
    update_job,
)
from .ratings import add_rating, list_ratings

load_dotenv()

app = FastAPI(title="Famba Rider API (Prototype)")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

security = HTTPBasic()
EXPECTED_USER = os.getenv("BASIC_USER", "demo")
EXPECTED_PASS = os.getenv("BASIC_PASS", "demo123")


def require_auth(credentials: HTTPBasicCredentials = Depends(security)):
    user_ok = secrets.compare_digest(credentials.username, EXPECTED_USER)
    pass_ok = secrets.compare_digest(credentials.password, EXPECTED_PASS)
    if not (user_ok and pass_ok):
        raise HTTPException(status_code=401, detail="Unauthorized")
    return True


@app.get("/health")
def health():
    return {"ok": True}


@app.post("/quote", response_model=Quote)
def quote(q: QuoteRequest, _auth=Depends(require_auth)):
    corridor = classify_corridor(q.pickup_text, q.drop_text)
    eta = estimate_eta_minutes(q.distance_km, corridor)
    price, base, dist = estimate_price_usd(
        q.distance_km,
        corridor,
        peak=q.peak,
    )
    return Quote(
        corridor=corridor,
        eta_min=eta,
        price_usd=price,
        base_fare=base,
        distance_fare=dist,
        total_usd=price,
    )


@app.post("/jobs")
def create(j: CreateJob, _auth=Depends(require_auth)):
    job = create_job(j.model_dump())
    drv = get_driver_by_id(j.driver_id) or pick_driver()
    update_job(
        job["id"],
        status="driver_assigned",
        driver_id=drv["id"],
        driver=drv,
        fare_usd=j.fare_usd if hasattr(j, "fare_usd") else None,
    )
    simulate(job["id"])
    return job


@app.get("/jobs/{job_id}")
def get(job_id: str, _auth=Depends(require_auth)):
    job = get_job(job_id)
    if not job:
        raise HTTPException(404, "Job not found")
    return job


@app.get("/jobs")
def all_jobs(_auth=Depends(require_auth)):
    return list_jobs()


@app.post("/issues")
def report_issue(payload: dict, _auth=Depends(require_auth)):
    # Demo echo endpoint for Trust & Safety reporting
    return {"ok": True}


@app.post("/recommend")
def recommend_drivers(payload: dict, _auth=Depends(require_auth)):
    # Returns ranked list of candidate drivers based on corridor
    corridor = payload.get("corridor", "CBD")
    primary = get_next_driver()
    # Keep list stable while using the same primary driver the job will use
    drivers = [
        {
            "id": primary["id"],
            "name": primary["name"],
            "rating": primary["rating"],
            "eta_min": 2,
        },
        {"id": "alt1", "name": "Kuda M.", "rating": 4.7, "eta_min": 4},
        {"id": "alt2", "name": "Nyasha P.", "rating": 4.6, "eta_min": 6},
    ]
    return {"corridor": corridor, "drivers": drivers}


@app.post("/ratings")
def submit_rating(payload: dict, _auth=Depends(require_auth)):
    return add_rating(payload)


@app.get("/ratings")
def ratings(_auth=Depends(require_auth)):
    return list_ratings()


# Promo codes (mock validation)
PROMO_CODES = {
    "FAMBA50": {"discount": 50, "max_discount": 5.00, "valid": True},
    "RIDE25": {"discount": 25, "max_discount": 3.00, "valid": True},
    "FIRST10": {"discount": 10, "max_discount": 2.00, "valid": True},
}


@app.post("/promo/validate")
def validate_promo(payload: dict, _auth=Depends(require_auth)):
    code = payload.get("code", "").upper()
    if code in PROMO_CODES:
        promo = PROMO_CODES[code]
        return {
            "valid": True,
            "code": code,
            "discount": promo["discount"],
            "max_discount": promo["max_discount"],
            "message": f"{promo['discount']}% off applied!",
        }
    return {
        "valid": False,
        "code": code,
        "message": "Invalid or expired promo code",
    }


@app.post("/jobs/{job_id}/cancel")
def cancel_job(job_id: str, payload: dict, _auth=Depends(require_auth)):
    job = get_job(job_id)
    if not job:
        raise HTTPException(404, "Job not found")
    
    reason = payload.get("reason", "unknown")
    update_job(job_id, status="cancelled", cancel_reason=reason)
    return {"ok": True, "job_id": job_id, "reason": reason}


@app.post("/jobs/schedule")
def schedule_job(payload: dict, _auth=Depends(require_auth)):
    # Create a scheduled job (mock implementation)
    job = create_job(payload)
    update_job(
        job["id"],
        status="scheduled",
        scheduled_time=payload.get("scheduled_time"),
    )
    return {
        "ok": True,
        "job_id": job["id"],
        "scheduled_time": payload.get("scheduled_time"),
        "message": "Ride scheduled successfully",
    }
