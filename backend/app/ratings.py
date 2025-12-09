from typing import List, Dict
from datetime import datetime

_ratings: List[Dict] = []


def add_rating(data: Dict) -> Dict:
    entry = {
        "job_id": data.get("job_id"),
        "driver_id": data.get("driver_id"),
        "rating": float(data.get("rating", 0)),
        "comment": data.get("comment"),
        "created_at": datetime.utcnow().isoformat(),
    }
    _ratings.append(entry)
    return entry


def list_ratings() -> List[Dict]:
    return list(_ratings)

