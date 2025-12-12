import os
import secrets
import asyncio
import json
from typing import Dict, Set

from dotenv import load_dotenv
from fastapi import Depends, FastAPI, HTTPException, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware

from .config import settings
from .auth import (
    Token, UserCreate, UserLogin, UserResponse,
    get_current_user, get_current_active_user, require_admin, require_driver,
    create_user, authenticate_user, create_tokens, refresh_access_token, revoke_refresh_token,
    get_user_by_phone,
)
from .recommend import (
    classify_corridor,
    estimate_eta_minutes,
    estimate_price_usd,
)
from .schemas import CreateJob, Quote, QuoteRequest
from .simulator import simulate
from .database import (
    create_job,
    get_job,
    get_next_driver,
    get_driver_by_id,
    list_jobs,
    pick_driver,
    update_job,
    add_rating,
    list_ratings,
    validate_promo as db_validate_promo,
    search_locations,
    get_popular_locations,
    # Referrals
    create_referral,
    get_referral,
    apply_referral,
    get_referral_stats,
    # Driver earnings
    record_driver_earning,
    get_driver_earnings,
    get_all_drivers_earnings,
)

load_dotenv()

app = FastAPI(
    title=settings.api_title,
    version=settings.api_version,
    debug=settings.debug,
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins.split(","),
    allow_methods=["*"],
    allow_headers=["*"],
)

# Legacy auth constants (for backward compatibility)
EXPECTED_USER = settings.basic_user
EXPECTED_PASS = settings.basic_pass


# Use the new auth system
require_auth = get_current_active_user


@app.get("/health")
def health():
    return {"ok": True, "environment": settings.environment}


# ==================== AUTH ROUTES ====================

@app.post("/auth/register", response_model=Token)
def register(user_data: UserCreate):
    """Register a new user."""
    # Check if phone already exists
    if get_user_by_phone(user_data.phone):
        raise HTTPException(400, "Phone number already registered")
    
    try:
        user = create_user(user_data)
        return create_tokens(user["id"], user["user_type"])
    except ValueError as e:
        raise HTTPException(400, str(e))


@app.post("/auth/login", response_model=Token)
def login(credentials: UserLogin):
    """Login with phone and password."""
    user = authenticate_user(credentials.phone, credentials.password)
    if not user:
        raise HTTPException(401, "Invalid phone or password")
    return create_tokens(user["id"], user.get("user_type", "rider"))


@app.post("/auth/refresh", response_model=Token)
def refresh_token(payload: dict):
    """Refresh access token using refresh token."""
    refresh = payload.get("refresh_token")
    if not refresh:
        raise HTTPException(400, "Refresh token required")
    
    tokens = refresh_access_token(refresh)
    if not tokens:
        raise HTTPException(401, "Invalid or expired refresh token")
    return tokens


@app.post("/auth/logout")
def logout(payload: dict, _user=Depends(get_current_user)):
    """Logout and revoke refresh token."""
    refresh = payload.get("refresh_token")
    if refresh:
        revoke_refresh_token(refresh)
    return {"ok": True}


@app.get("/auth/me", response_model=UserResponse)
def get_me(current_user: dict = Depends(get_current_user)):
    """Get current user profile."""
    return UserResponse(
        id=current_user["id"],
        phone=current_user["phone"],
        name=current_user["name"],
        user_type=current_user.get("user_type", "rider"),
        is_verified=current_user.get("is_verified", False),
        created_at=current_user.get("created_at", ""),
    )


# ==================== RIDE ROUTES ====================

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
    return get_job(job["id"])


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


@app.post("/promo/validate")
def validate_promo(payload: dict, _auth=Depends(require_auth)):
    code = payload.get("code", "").upper()
    return db_validate_promo(code)


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
    # Create a scheduled job
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


# Location search endpoints
@app.get("/locations/search")
def locations_search(q: str = "", limit: int = 10, _auth=Depends(require_auth)):
    """Search locations by name, address, or area."""
    if not q or len(q) < 2:
        return {"locations": get_popular_locations(limit)}
    return {"locations": search_locations(q, limit)}


@app.get("/locations/popular")
def locations_popular(limit: int = 10, _auth=Depends(require_auth)):
    """Get popular locations."""
    return {"locations": get_popular_locations(limit)}


# Quick fare estimate endpoint
@app.post("/estimate")
def quick_estimate(payload: dict, _auth=Depends(require_auth)):
    """Quick fare estimate without full quote details."""
    distance_km = payload.get("distance_km", 5.0)
    corridor = classify_corridor(
        payload.get("pickup_text", ""),
        payload.get("drop_text", ""),
    )
    price, base, dist = estimate_price_usd(distance_km, corridor, peak=False)
    eta = estimate_eta_minutes(distance_km, corridor)
    
    return {
        "estimate_usd": round(price, 2),
        "eta_min": eta,
        "distance_km": distance_km,
        "corridor": corridor,
    }


# Referral endpoints
@app.post("/referrals/create")
def create_referral_code(payload: dict, _auth=Depends(require_auth)):
    """Create a referral code for a user."""
    name = payload.get("name", "User")
    phone = payload.get("phone")
    return create_referral(name, phone)


@app.get("/referrals/{code}")
def get_referral_info(code: str, _auth=Depends(require_auth)):
    """Get referral info by code."""
    referral = get_referral(code)
    if not referral:
        raise HTTPException(404, "Referral code not found")
    return referral


@app.post("/referrals/apply")
def apply_referral_code(payload: dict, _auth=Depends(require_auth)):
    """Apply a referral code for a new signup."""
    code = payload.get("code", "")
    referee_name = payload.get("name", "New User")
    referee_phone = payload.get("phone")
    return apply_referral(code, referee_name, referee_phone)


@app.get("/referrals/{code}/stats")
def referral_stats(code: str, _auth=Depends(require_auth)):
    """Get referral statistics."""
    stats = get_referral_stats(code)
    if not stats.get("ok"):
        raise HTTPException(404, stats.get("message", "Not found"))
    return stats


# Driver earnings endpoints
@app.get("/drivers/{driver_id}/earnings")
def driver_earnings(driver_id: str, _auth=Depends(require_auth)):
    """Get driver earnings summary and history."""
    return get_driver_earnings(driver_id)


@app.get("/drivers/earnings/leaderboard")
def earnings_leaderboard(_auth=Depends(require_auth)):
    """Get earnings leaderboard for all drivers."""
    return {"drivers": get_all_drivers_earnings()}


@app.post("/drivers/{driver_id}/earnings/record")
def record_earning(driver_id: str, payload: dict, _auth=Depends(require_auth)):
    """Record a driver earning (usually called after job completion)."""
    job_id = payload.get("job_id")
    amount = payload.get("amount", 0)
    commission_rate = payload.get("commission_rate", 0.15)
    return record_driver_earning(driver_id, job_id, amount, commission_rate)


# Multi-stop rides - Update job creation to support waypoints
@app.post("/jobs/multi-stop")
def create_multistop_job(payload: dict, _auth=Depends(require_auth)):
    """Create a multi-stop ride with waypoints."""
    # Base fare calculation with waypoints
    waypoints = payload.get("waypoints", [])
    total_distance = payload.get("total_distance_km", 5.0)
    
    corridor = classify_corridor(
        payload.get("pickup_text", ""),
        payload.get("drop_text", ""),
    )
    price, base, dist = estimate_price_usd(total_distance, corridor, peak=False)
    # Add stop fee for each waypoint
    stop_fee = 0.50 * len(waypoints)
    total_fare = price + stop_fee
    
    # Create job with waypoints stored as JSON string
    import json
    job_data = {
        "pickup_text": payload.get("pickup_text"),
        "drop_text": payload.get("drop_text"),
        "distance_km": total_distance,
        "rider_name": payload.get("rider_name"),
        "fare_usd": total_fare,
        "payment_method": payload.get("payment_method", "cash"),
        "pickup_lat": payload.get("pickup_lat"),
        "pickup_lng": payload.get("pickup_lng"),
        "drop_lat": payload.get("drop_lat"),
        "drop_lng": payload.get("drop_lng"),
    }
    
    job = create_job(job_data)
    drv = get_driver_by_id(payload.get("driver_id")) or pick_driver()
    update_job(
        job["id"],
        status="driver_assigned",
        driver_id=drv["id"],
        driver=drv,
    )
    
    simulate(job["id"])
    
    result = get_job(job["id"])
    result["waypoints"] = waypoints
    result["stop_fee"] = stop_fee
    return result


# WebSocket connection manager for live tracking
class ConnectionManager:
    def __init__(self):
        self.active_connections: Dict[str, Set[WebSocket]] = {}

    async def connect(self, websocket: WebSocket, job_id: str):
        await websocket.accept()
        if job_id not in self.active_connections:
            self.active_connections[job_id] = set()
        self.active_connections[job_id].add(websocket)

    def disconnect(self, websocket: WebSocket, job_id: str):
        if job_id in self.active_connections:
            self.active_connections[job_id].discard(websocket)
            if not self.active_connections[job_id]:
                del self.active_connections[job_id]

    async def broadcast_to_job(self, job_id: str, message: dict):
        if job_id in self.active_connections:
            dead_connections = set()
            for connection in self.active_connections[job_id]:
                try:
                    await connection.send_json(message)
                except Exception:
                    dead_connections.add(connection)
            # Clean up dead connections
            for conn in dead_connections:
                self.active_connections[job_id].discard(conn)


manager = ConnectionManager()


@app.websocket("/ws/track/{job_id}")
async def websocket_track(websocket: WebSocket, job_id: str):
    """WebSocket endpoint for real-time job tracking."""
    # Basic auth via query param for WebSocket
    token = websocket.query_params.get("token", "")
    expected_token = f"{EXPECTED_USER}:{EXPECTED_PASS}"
    if token != expected_token:
        await websocket.close(code=4001)
        return

    await manager.connect(websocket, job_id)
    try:
        # Send initial job state
        job = get_job(job_id)
        if job:
            await websocket.send_json({
                "type": "job_update",
                "job": job,
            })

        # Keep connection alive and send updates
        while True:
            try:
                # Wait for messages or just keep alive
                data = await asyncio.wait_for(
                    websocket.receive_text(),
                    timeout=2.0
                )
                # Handle ping/pong
                if data == "ping":
                    await websocket.send_text("pong")
            except asyncio.TimeoutError:
                # Send job update every 2 seconds
                job = get_job(job_id)
                if job:
                    await websocket.send_json({
                        "type": "job_update",
                        "job": job,
                    })
                    # Check if job is complete
                    if job.get("status") == "complete":
                        await websocket.send_json({
                            "type": "ride_complete",
                            "job": job,
                        })
                        break
    except WebSocketDisconnect:
        pass
    finally:
        manager.disconnect(websocket, job_id)


# Endpoint to manually push updates (for testing)
@app.post("/ws/push/{job_id}")
async def push_update(job_id: str, payload: dict, _auth=Depends(require_auth)):
    """Push an update to all WebSocket clients watching a job."""
    job = get_job(job_id)
    if not job:
        raise HTTPException(404, "Job not found")
    
    await manager.broadcast_to_job(job_id, {
        "type": payload.get("type", "job_update"),
        "job": job,
        "data": payload.get("data"),
    })
    return {"ok": True, "connections": len(manager.active_connections.get(job_id, set()))}
