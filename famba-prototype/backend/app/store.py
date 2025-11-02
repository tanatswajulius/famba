from typing import Dict, List
from datetime import datetime
import itertools

_jobs: Dict[str, dict] = {}
_drivers: Dict[str, dict] = {
    "d1": {"id": "d1", "name": "Tendai", "rating": 4.9, "lat": -17.829, "lng": 31.052},
    "d2": {"id": "d2", "name": "Rudo",   "rating": 4.8, "lat": -17.825, "lng": 31.048},
}
_job_id = itertools.count(1001)

def create_job(job: dict) -> dict:
    job_id = f"J{next(_job_id)}"
    job["id"] = job_id
    job["status"] = "searching"
    job["created_at"] = datetime.utcnow().isoformat()
    _jobs[job_id] = job
    return job

def get_job(job_id: str) -> dict | None:
    return _jobs.get(job_id)

def update_job(job_id: str, **updates):
    if job_id in _jobs:
        _jobs[job_id].update(updates)
    return _jobs.get(job_id)

def list_jobs() -> List[dict]:
    return list(_jobs.values())

def pick_driver() -> dict:
    return _drivers["d1"] if len(_jobs) % 2 else _drivers["d2"]
