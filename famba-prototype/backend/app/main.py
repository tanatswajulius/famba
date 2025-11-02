from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from .schemas import QuoteRequest, Quote, CreateJob
from .recommend import classify_corridor, estimate_eta_minutes, estimate_price_usd
from .store import create_job, get_job, pick_driver, update_job, list_jobs
from .simulator import simulate

app = FastAPI(title="Famba Rider API (Prototype)")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

@app.get("/health")
def health():
    return {"ok": True}

@app.post("/quote", response_model=Quote)
def quote(q: QuoteRequest):
    corridor = classify_corridor(q.pickup_text, q.drop_text)
    eta = estimate_eta_minutes(q.distance_km, corridor)
    price = estimate_price_usd(q.distance_km, corridor, peak=q.peak)
    return Quote(corridor=corridor, eta_min=eta, price_usd=price)

@app.post("/jobs")
def create(j: CreateJob):
    job = create_job(j.model_dump())
    drv = pick_driver()
    update_job(job["id"], status="driver_assigned", driver_id=drv["id"], driver=drv)
    simulate(job["id"])
    return job

@app.get("/jobs/{job_id}")
def get(job_id: str):
    job = get_job(job_id)
    if not job: raise HTTPException(404, "Job not found")
    return job

@app.get("/jobs")
def all_jobs():
    return list_jobs()


@app.post("/issues")
def report_issue(payload: dict):
    # Demo echo endpoint for Trust & Safety reporting
    return {"ok": True}


@app.post("/recommend")
def recommend_drivers(payload: dict):
    # Returns ranked list of candidate drivers based on corridor
    corridor = payload.get("corridor", "CBD")
    # Mock driver recommendations
    drivers = [
        {"id": "D001", "name": "John M.", "rating": 4.9, "eta_min": 2},
        {"id": "D002", "name": "Sarah K.", "rating": 4.8, "eta_min": 3},
        {"id": "D003", "name": "David T.", "rating": 4.7, "eta_min": 5},
    ]
    return {"corridor": corridor, "drivers": drivers}
