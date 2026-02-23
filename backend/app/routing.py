"""OSRM routing client for real road-distance ETA and distance calculations."""
import httpx
from typing import Optional, Tuple
from .config import settings

OSRM_BASE = settings.osrm_base_url


async def get_route(
    pickup_lat: float, pickup_lng: float,
    drop_lat: float, drop_lng: float,
) -> Optional[dict]:
    """Get route from OSRM between two points.
    Returns distance_km, duration_min, and geometry."""
    url = (
        f"{OSRM_BASE}/route/v1/driving/"
        f"{pickup_lng},{pickup_lat};{drop_lng},{drop_lat}"
        f"?overview=simplified&geometries=geojson"
    )
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            resp = await client.get(url)
            data = resp.json()

        if data.get("code") != "Ok" or not data.get("routes"):
            return None

        route = data["routes"][0]
        return {
            "distance_km": round(route["distance"] / 1000, 2),
            "duration_min": round(route["duration"] / 60, 1),
            "geometry": route.get("geometry"),
        }
    except Exception:
        return None


def get_route_sync(
    pickup_lat: float, pickup_lng: float,
    drop_lat: float, drop_lng: float,
) -> Optional[dict]:
    """Synchronous version for use in non-async endpoints."""
    url = (
        f"{OSRM_BASE}/route/v1/driving/"
        f"{pickup_lng},{pickup_lat};{drop_lng},{drop_lat}"
        f"?overview=simplified&geometries=geojson"
    )
    try:
        with httpx.Client(timeout=5.0) as client:
            resp = client.get(url)
            data = resp.json()

        if data.get("code") != "Ok" or not data.get("routes"):
            return None

        route = data["routes"][0]
        return {
            "distance_km": round(route["distance"] / 1000, 2),
            "duration_min": round(route["duration"] / 60, 1),
            "geometry": route.get("geometry"),
        }
    except Exception:
        return None


def get_eta_and_distance(
    pickup_lat: float, pickup_lng: float,
    drop_lat: float, drop_lng: float,
) -> Tuple[float, float]:
    """Get (distance_km, eta_minutes) using OSRM. Falls back to straight-line estimate."""
    route = get_route_sync(pickup_lat, pickup_lng, drop_lat, drop_lng)
    if route:
        return route["distance_km"], route["duration_min"]

    # Fallback: haversine straight-line * 1.4 road factor
    import math
    R = 6371.0
    dlat = math.radians(drop_lat - pickup_lat)
    dlng = math.radians(drop_lng - pickup_lng)
    a = (math.sin(dlat / 2) ** 2 +
         math.cos(math.radians(pickup_lat)) * math.cos(math.radians(drop_lat)) *
         math.sin(dlng / 2) ** 2)
    straight_km = R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    road_km = round(straight_km * 1.4, 2)
    eta = round(road_km / 0.35, 1)  # ~21 km/h avg motorcycle speed
    return road_km, eta
