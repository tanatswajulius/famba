import asyncio
from typing import Dict, Set

from dotenv import load_dotenv
from fastapi import (
    Depends, FastAPI, HTTPException,
    WebSocket, WebSocketDisconnect,
)
from fastapi.middleware.cors import CORSMiddleware

from .config import settings
from .auth import (
    Token, UserCreate, UserLogin, UserResponse,
    get_current_user, get_current_active_user,
    create_user, authenticate_user, create_tokens,
    refresh_access_token, revoke_refresh_token,
    get_user_by_phone,
)
from .recommend import (
    classify_corridor,
    estimate_eta_minutes,
    estimate_price_usd,
)
from .schemas import (
    CreateJob, Quote, QuoteRequest,
    CreateFoodOrder, WalletTopUp, WalletPayment,
)
from .simulator import simulate
from .database import (
    # Users
    db_list_users, db_get_user_count,
    # Jobs
    create_job, get_job, get_next_driver, get_driver_by_id, list_jobs,
    pick_driver, update_job,
    # Ratings
    add_rating, list_ratings,
    # Promos
    validate_promo as db_validate_promo,
    # Locations
    search_locations, get_popular_locations,
    # Referrals
    create_referral, get_referral, apply_referral, get_referral_stats,
    # Driver earnings
    record_driver_earning, get_driver_earnings, get_all_drivers_earnings,
    # Restaurants & food orders
    list_restaurants, get_restaurant, search_restaurants,
    get_menu,
    create_food_order, get_food_order,
    update_food_order, list_food_orders,
    # Wallet
    get_wallet_balance, wallet_top_up, wallet_deduct,
    get_wallet_transactions,
    # Drivers list
    get_all_drivers,
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
        wallet_balance=current_user.get("wallet_balance", 0.0),
        created_at=current_user.get("created_at", ""),
    )


# ==================== RIDE ROUTES ====================

@app.post("/quote", response_model=Quote)
def quote(q: QuoteRequest, _auth=Depends(require_auth)):
    corridor = classify_corridor(q.pickup_text, q.drop_text)
    eta = estimate_eta_minutes(q.distance_km, corridor)
    price, base, dist = estimate_price_usd(q.distance_km, corridor, peak=q.peak)
    return Quote(
        corridor=corridor, eta_min=eta, price_usd=price,
        base_fare=base, distance_fare=dist, total_usd=price,
    )


@app.post("/jobs")
def create(j: CreateJob, _auth=Depends(require_auth)):
    job = create_job(j.model_dump())
    drv = get_driver_by_id(j.driver_id) or pick_driver()
    update_job(
        job["id"], status="driver_assigned",
        driver_id=drv["id"], driver=drv,
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
    return {"ok": True}


@app.post("/recommend")
def recommend_drivers(payload: dict, _auth=Depends(require_auth)):
    corridor = payload.get("corridor", "CBD")
    primary = get_next_driver()
    drivers = [
        {"id": primary["id"], "name": primary["name"], "rating": primary["rating"], "eta_min": 2},
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
    job = create_job(payload)
    update_job(job["id"], status="scheduled", scheduled_time=payload.get("scheduled_time"))
    return {
        "ok": True, "job_id": job["id"],
        "scheduled_time": payload.get("scheduled_time"),
        "message": "Ride scheduled successfully",
    }


@app.get("/locations/search")
def locations_search(q: str = "", limit: int = 10, _auth=Depends(require_auth)):
    if not q or len(q) < 2:
        return {"locations": get_popular_locations(limit)}
    return {"locations": search_locations(q, limit)}


@app.get("/locations/popular")
def locations_popular(limit: int = 10, _auth=Depends(require_auth)):
    return {"locations": get_popular_locations(limit)}


@app.post("/estimate")
def quick_estimate(payload: dict, _auth=Depends(require_auth)):
    distance_km = payload.get("distance_km", 5.0)
    corridor = classify_corridor(payload.get("pickup_text", ""), payload.get("drop_text", ""))
    price, base, dist = estimate_price_usd(distance_km, corridor, peak=False)
    eta = estimate_eta_minutes(distance_km, corridor)
    return {"estimate_usd": round(price, 2), "eta_min": eta, "distance_km": distance_km, "corridor": corridor}


# ==================== REFERRAL ROUTES ====================

@app.post("/referrals/create")
def create_referral_code(payload: dict, _auth=Depends(require_auth)):
    name = payload.get("name", "User")
    phone = payload.get("phone")
    return create_referral(name, phone)


@app.get("/referrals/{code}")
def get_referral_info(code: str, _auth=Depends(require_auth)):
    referral = get_referral(code)
    if not referral:
        raise HTTPException(404, "Referral code not found")
    return referral


@app.post("/referrals/apply")
def apply_referral_code(payload: dict, _auth=Depends(require_auth)):
    code = payload.get("code", "")
    referee_name = payload.get("name", "New User")
    referee_phone = payload.get("phone")
    return apply_referral(code, referee_name, referee_phone)


@app.get("/referrals/{code}/stats")
def referral_stats(code: str, _auth=Depends(require_auth)):
    stats = get_referral_stats(code)
    if not stats.get("ok"):
        raise HTTPException(404, stats.get("message", "Not found"))
    return stats


# ==================== DRIVER ROUTES ====================

@app.get("/drivers")
def drivers_list(_auth=Depends(require_auth)):
    """List all active drivers."""
    return {"drivers": get_all_drivers()}


@app.get("/drivers/{driver_id}/earnings")
def driver_earnings(driver_id: str, _auth=Depends(require_auth)):
    return get_driver_earnings(driver_id)


@app.get("/drivers/earnings/leaderboard")
def earnings_leaderboard(_auth=Depends(require_auth)):
    return {"drivers": get_all_drivers_earnings()}


@app.post("/drivers/{driver_id}/earnings/record")
def record_earning(driver_id: str, payload: dict, _auth=Depends(require_auth)):
    job_id = payload.get("job_id")
    amount = payload.get("amount", 0)
    commission_rate = payload.get("commission_rate", 0.15)
    return record_driver_earning(driver_id, job_id, amount, commission_rate)


# ==================== MULTI-STOP RIDES ====================

@app.post("/jobs/multi-stop")
def create_multistop_job(payload: dict, _auth=Depends(require_auth)):
    waypoints = payload.get("waypoints", [])
    total_distance = payload.get("total_distance_km", 5.0)
    corridor = classify_corridor(payload.get("pickup_text", ""), payload.get("drop_text", ""))
    price, base, dist = estimate_price_usd(total_distance, corridor, peak=False)
    stop_fee = 0.50 * len(waypoints)
    total_fare = price + stop_fee

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
    update_job(job["id"], status="driver_assigned", driver_id=drv["id"], driver=drv)
    simulate(job["id"])

    result = get_job(job["id"])
    result["waypoints"] = waypoints
    result["stop_fee"] = stop_fee
    return result


# ==================== FOOD DELIVERY ROUTES ====================

@app.get("/restaurants")
def restaurants(category: str = None, area: str = None,
                featured: bool = False, limit: int = 50,
                _auth=Depends(require_auth)):
    """List restaurants with optional filters."""
    return {"restaurants": list_restaurants(category=category, area=area, featured_only=featured, limit=limit)}


@app.get("/restaurants/search")
def restaurants_search(q: str = "", limit: int = 20, _auth=Depends(require_auth)):
    """Search restaurants by name, cuisine, or area."""
    if not q or len(q) < 2:
        return {"restaurants": list_restaurants(limit=limit)}
    return {"restaurants": search_restaurants(q, limit)}


@app.get("/restaurants/{restaurant_id}")
def restaurant_detail(restaurant_id: str, _auth=Depends(require_auth)):
    """Get restaurant details with full menu."""
    restaurant = get_restaurant(restaurant_id)
    if not restaurant:
        raise HTTPException(404, "Restaurant not found")
    menu = get_menu(restaurant_id)
    restaurant["menu"] = menu
    return restaurant


@app.get("/restaurants/{restaurant_id}/menu")
def restaurant_menu(restaurant_id: str, category: str = None, _auth=Depends(require_auth)):
    """Get menu for a restaurant."""
    restaurant = get_restaurant(restaurant_id)
    if not restaurant:
        raise HTTPException(404, "Restaurant not found")
    return {"restaurant_id": restaurant_id, "items": get_menu(restaurant_id, category=category)}


@app.post("/food-orders")
def create_order(order: CreateFoodOrder, _auth=Depends(require_auth)):
    """Place a new food order."""
    restaurant = get_restaurant(order.restaurant_id)
    if not restaurant:
        raise HTTPException(404, "Restaurant not found")
    if not restaurant["is_open"]:
        raise HTTPException(400, "Restaurant is currently closed")

    subtotal = sum(item.price * item.qty for item in order.items)
    if subtotal < restaurant["min_order"]:
        raise HTTPException(400, f"Minimum order is ${restaurant['min_order']:.2f}")

    delivery_fee = restaurant["delivery_fee"]
    discount = 0.0

    # Validate promo code if provided
    if order.promo_code:
        promo_result = db_validate_promo(order.promo_code.upper())
        if promo_result.get("valid"):
            pct = promo_result["discount"] / 100
            discount = min(subtotal * pct, promo_result.get("max_discount", subtotal))

    total = subtotal + delivery_fee - discount

    order_data = {
        "restaurant_id": order.restaurant_id,
        "items": [item.model_dump() for item in order.items],
        "subtotal": round(subtotal, 2),
        "delivery_fee": delivery_fee,
        "discount": round(discount, 2),
        "total": round(total, 2),
        "delivery_address": order.delivery_address,
        "delivery_lat": order.delivery_lat,
        "delivery_lng": order.delivery_lng,
        "payment_method": order.payment_method,
        "rider_name": order.rider_name,
        "rider_phone": order.rider_phone,
        "special_instructions": order.special_instructions,
        "estimated_delivery_min": restaurant["avg_prep_time_min"] + 15,
    }

    food_order = create_food_order(order_data)

    # Auto-assign a driver for delivery
    drv = pick_driver()
    update_food_order(food_order["id"], status="confirmed", driver_id=drv["id"], driver=drv)

    return get_food_order(food_order["id"])


@app.get("/food-orders/{order_id}")
def get_order(order_id: str, _auth=Depends(require_auth)):
    """Get food order by ID."""
    order = get_food_order(order_id)
    if not order:
        raise HTTPException(404, "Order not found")
    return order


@app.get("/food-orders")
def orders_list(status: str = None, limit: int = 50, _auth=Depends(require_auth)):
    """List food orders."""
    return {"orders": list_food_orders(status=status, limit=limit)}


@app.post("/food-orders/{order_id}/status")
def update_order_status(order_id: str, payload: dict, _auth=Depends(require_auth)):
    """Update food order status."""
    order = get_food_order(order_id)
    if not order:
        raise HTTPException(404, "Order not found")

    new_status = payload.get("status")
    valid_statuses = ["confirmed", "preparing", "ready", "picked_up", "delivering", "delivered", "cancelled"]
    if new_status not in valid_statuses:
        raise HTTPException(400, f"Invalid status. Must be one of: {', '.join(valid_statuses)}")

    updates = {"status": new_status}
    if new_status == "cancelled":
        updates["cancel_reason"] = payload.get("reason", "")

    updated = update_food_order(order_id, **updates)
    return updated


@app.post("/food-orders/{order_id}/cancel")
def cancel_order(order_id: str, payload: dict, _auth=Depends(require_auth)):
    """Cancel a food order."""
    order = get_food_order(order_id)
    if not order:
        raise HTTPException(404, "Order not found")
    if order["status"] in ["delivered", "cancelled"]:
        raise HTTPException(400, "Cannot cancel this order")

    reason = payload.get("reason", "Customer cancelled")
    update_food_order(order_id, status="cancelled", cancel_reason=reason)
    return {"ok": True, "order_id": order_id, "reason": reason}


# ==================== WALLET ROUTES ====================

@app.get("/wallet/balance")
def wallet_balance_route(_auth=Depends(require_auth)):
    """Get current user's wallet balance."""
    user_id = _auth.get("id", "basic_auth_user")
    balance = get_wallet_balance(user_id)
    return {"user_id": user_id, "balance": balance}


@app.post("/wallet/top-up")
def wallet_topup_route(data: WalletTopUp, _auth=Depends(require_auth)):
    """Add money to wallet."""
    user_id = _auth.get("id", "basic_auth_user")
    if data.amount <= 0:
        raise HTTPException(400, "Amount must be positive")
    result = wallet_top_up(user_id, data.amount, description=f"Top-up via {data.method}")
    if not result.get("ok"):
        raise HTTPException(400, result.get("message", "Top-up failed"))
    return result


@app.post("/wallet/pay")
def wallet_pay_route(data: WalletPayment, _auth=Depends(require_auth)):
    """Pay from wallet."""
    user_id = _auth.get("id", "basic_auth_user")
    if data.amount <= 0:
        raise HTTPException(400, "Amount must be positive")
    result = wallet_deduct(
        user_id, data.amount, txn_type=data.type,
        reference_id=data.reference_id, description=data.description or "Payment",
    )
    if not result.get("ok"):
        raise HTTPException(400, result.get("message", "Payment failed"))
    return result


@app.get("/wallet/transactions")
def wallet_transactions_route(limit: int = 50, _auth=Depends(require_auth)):
    """Get wallet transaction history."""
    user_id = _auth.get("id", "basic_auth_user")
    return {"user_id": user_id, "transactions": get_wallet_transactions(user_id, limit)}


# ==================== ADMIN STATS ====================

@app.get("/admin/stats")
def admin_stats(_auth=Depends(require_auth)):
    """Get admin dashboard statistics."""
    jobs = list_jobs(limit=9999)
    food_orders = list_food_orders(limit=9999)
    drivers = get_all_drivers()
    user_count = db_get_user_count()

    ride_revenue = sum(j.get("fare_usd") or 0 for j in jobs)
    food_revenue = sum(o.get("total") or 0 for o in food_orders)

    return {
        "total_rides": len(jobs),
        "total_food_orders": len(food_orders),
        "total_drivers": len(drivers),
        "total_riders": user_count,
        "ride_revenue": round(ride_revenue, 2),
        "food_revenue": round(food_revenue, 2),
        "total_revenue": round(ride_revenue + food_revenue, 2),
        "recent_rides": jobs[:10],
        "recent_food_orders": food_orders[:10],
    }


@app.get("/admin/users")
def admin_users(limit: int = 100, _auth=Depends(require_auth)):
    """List all registered users."""
    users = db_list_users(limit)
    safe_users = [{k: v for k, v in u.items() if k != "password_hash"} for u in users]
    return {"users": safe_users}


# ==================== WEBSOCKET ====================

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
            for conn in dead_connections:
                self.active_connections[job_id].discard(conn)


manager = ConnectionManager()


@app.websocket("/ws/track/{job_id}")
async def websocket_track(websocket: WebSocket, job_id: str):
    """WebSocket endpoint for real-time job tracking."""
    token = websocket.query_params.get("token", "")
    expected_token = f"{EXPECTED_USER}:{EXPECTED_PASS}"
    if token != expected_token:
        await websocket.close(code=4001)
        return

    await manager.connect(websocket, job_id)
    try:
        job = get_job(job_id)
        if job:
            await websocket.send_json({"type": "job_update", "job": job})

        while True:
            try:
                data = await asyncio.wait_for(websocket.receive_text(), timeout=2.0)
                if data == "ping":
                    await websocket.send_text("pong")
            except asyncio.TimeoutError:
                job = get_job(job_id)
                if job:
                    await websocket.send_json({"type": "job_update", "job": job})
                    if job.get("status") == "complete":
                        await websocket.send_json({"type": "ride_complete", "job": job})
                        break
    except WebSocketDisconnect:
        pass
    finally:
        manager.disconnect(websocket, job_id)


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
