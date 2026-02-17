from datetime import datetime

CORRIDORS = {
    "CBD": {"eta_bias_min": 2, "price_bias": 1.0},
    "Campus": {"eta_bias_min": 1, "price_bias": 0.9},
    "Retail": {"eta_bias_min": 3, "price_bias": 1.1},
}

# Surge pricing configuration
SURGE_CONFIG = {
    "peak_hours": [(7, 9), (12, 14), (17, 19)],  # morning, lunch, evening rush
    "weekend_multiplier": 1.05,
    "peak_multiplier": 1.3,
    "rain_multiplier": 1.5,  # toggled manually or via weather API
    "high_demand_multiplier": 1.4,
    "min_multiplier": 1.0,
    "max_multiplier": 2.0,
}

# Runtime surge state (can be toggled by admin)
_surge_overrides = {
    "rain_active": False,
    "high_demand_active": False,
    "manual_multiplier": None,
}


def get_surge_multiplier() -> dict:
    """Calculate current surge multiplier based on time/conditions."""
    now = datetime.now()
    hour = now.hour
    is_weekend = now.weekday() >= 5

    multiplier = 1.0
    reasons = []

    # Check peak hours
    for start, end in SURGE_CONFIG["peak_hours"]:
        if start <= hour < end:
            multiplier = max(multiplier, SURGE_CONFIG["peak_multiplier"])
            reasons.append(f"Peak hour ({start}:00-{end}:00)")
            break

    # Weekend boost
    if is_weekend:
        multiplier *= SURGE_CONFIG["weekend_multiplier"]
        reasons.append("Weekend")

    # Rain surge
    if _surge_overrides["rain_active"]:
        multiplier *= SURGE_CONFIG["rain_multiplier"]
        reasons.append("Rain/bad weather")

    # High demand
    if _surge_overrides["high_demand_active"]:
        multiplier *= SURGE_CONFIG["high_demand_multiplier"]
        reasons.append("High demand")

    # Manual override
    if _surge_overrides["manual_multiplier"] is not None:
        multiplier = _surge_overrides["manual_multiplier"]
        reasons = ["Manual override"]

    # Clamp
    multiplier = max(SURGE_CONFIG["min_multiplier"],
                     min(SURGE_CONFIG["max_multiplier"], multiplier))

    return {
        "multiplier": round(multiplier, 2),
        "is_surge": multiplier > 1.0,
        "reasons": reasons,
        "hour": hour,
        "is_weekend": is_weekend,
        "config": SURGE_CONFIG,
    }


def set_surge_override(rain: bool = None, high_demand: bool = None,
                       manual: float = None):
    """Admin controls for surge pricing."""
    if rain is not None:
        _surge_overrides["rain_active"] = rain
    if high_demand is not None:
        _surge_overrides["high_demand_active"] = high_demand
    _surge_overrides["manual_multiplier"] = manual
    return get_surge_multiplier()


def classify_corridor(pickup_txt: str, drop_txt: str) -> str:
    blob = (pickup_txt + " " + drop_txt).lower()
    keywords = ["uz", "university", "campus", "hit"]
    if any(k in blob for k in keywords):
        return "Campus"
    if any(k in blob for k in ["mall", "retail", "market"]):
        return "Retail"
    return "CBD"


def estimate_eta_minutes(distance_km: float, corridor: str) -> int:
    base = max(2, int(distance_km / 0.35))
    return base + CORRIDORS[corridor]["eta_bias_min"]


def estimate_price_usd(
    distance_km: float,
    corridor: str,
    peak: bool = False
) -> float:
    base = 0.70
    dist = 0.35 * distance_km
    price = (base + dist) * CORRIDORS[corridor]["price_bias"]

    # Apply surge pricing
    surge = get_surge_multiplier()
    if surge["is_surge"]:
        price *= surge["multiplier"]
    elif peak:
        price *= 1.15

    return round(price, 2), round(base, 2), round(dist, 2)
