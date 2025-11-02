CORRIDORS = {
    "CBD":     {"eta_bias_min": 2, "price_bias": 1.0},
    "Campus":  {"eta_bias_min": 1, "price_bias": 0.9},
    "Retail":  {"eta_bias_min": 3, "price_bias": 1.1},
}


def classify_corridor(pickup_txt: str, drop_txt: str) -> str:
    blob = (pickup_txt + " " + drop_txt).lower()
    keywords = ["uz", "university", "campus", "hit"]
    if any(k in blob for k in keywords):
        return "Campus"
    if any(k in blob for k in ["mall", "retail", "market"]):
        return "Retail"
    return "CBD"


def estimate_eta_minutes(distance_km: float, corridor: str) -> int:
    # ~0.35 km/min baseline on moto
    base = max(2, int(distance_km / 0.35))
    return base + CORRIDORS[corridor]["eta_bias_min"]


def estimate_price_usd(
    distance_km: float,
    corridor: str,
    peak: bool = False
) -> float:
    # seed around ~$1.50 fares in pilot
    base = 0.70 + 0.35 * distance_km
    price = base * CORRIDORS[corridor]["price_bias"]
    if peak:
        price *= 1.15
    return round(price, 2)
