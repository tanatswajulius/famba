from typing import Dict, List
from datetime import datetime
import itertools

_jobs: Dict[str, dict] = {}
_drivers: Dict[str, dict] = {
    "d1": {
        "id": "d1",
        "name": "Tendai",
        "rating": 4.9,
        "lat": -17.829,
        "lng": 31.052,
        "vehicle": "Bajaj Boxer",
        "color": "Green",
        "plate": "MBK-2489",
    },
    "d2": {
        "id": "d2",
        "name": "Rudo",
        "rating": 4.8,
        "lat": -17.825,
        "lng": 31.048,
        "vehicle": "TVS HLX",
        "color": "Red",
        "plate": "MBK-3671",
    },
}
_driver_order = ["d1", "d2"]
_driver_idx = itertools.cycle(range(len(_driver_order)))
_current_driver_idx = next(_driver_idx)
PICKUP = {"lat": -17.8292, "lng": 31.0522}
DROP = {"lat": -17.8200, "lng": 31.0490}
_job_id = itertools.count(1001)

def create_job(job: dict) -> dict:
    job_id = f"J{next(_job_id)}"
    job["id"] = job_id
    job["status"] = "searching"
    job["created_at"] = datetime.utcnow().isoformat()
    job["pickup_lat"] = PICKUP["lat"]
    job["pickup_lng"] = PICKUP["lng"]
    job["drop_lat"] = DROP["lat"]
    job["drop_lng"] = DROP["lng"]
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


def _advance_driver_pointer():
    global _current_driver_idx
    _current_driver_idx = next(_driver_idx)


def pick_driver() -> dict:
    drv = _drivers[_driver_order[_current_driver_idx]]
    _advance_driver_pointer()
    return drv


def get_next_driver() -> dict:
    return _drivers[_driver_order[_current_driver_idx]]


def get_driver_by_id(driver_id: str | None) -> dict | None:
    if driver_id and driver_id in _drivers:
        return _drivers[driver_id]
    return None
