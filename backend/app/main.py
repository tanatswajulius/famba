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
    get_surge_multiplier,
    set_surge_override,
)
from .routing import get_route, get_eta_and_distance
from .email_service import notify
from .schemas import (
    CreateJob, Quote, QuoteRequest,
    CreateFoodOrder, WalletTopUp, WalletPayment,
    FoodOrderRating, ChatMessage, DriverLocationUpdate,
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
    # Food ratings
    add_food_rating, get_restaurant_ratings,
    # Chat
    save_chat_message, get_chat_history,
    # Proximity matching
    pick_nearest_driver, update_driver_location,
    # Unified history
    get_user_history,
    # Disputes
    create_dispute, get_dispute, list_disputes, resolve_dispute,
    # Driver documents
    submit_driver_document, get_driver_documents,
    list_pending_documents, list_all_documents, review_driver_document,
    # Restaurant owner
    get_restaurant_stats, update_restaurant_info,
    update_menu_item, create_menu_item, delete_menu_item,
    update_food_order_status_restaurant,
    # OTP
    create_otp, verify_otp,
    # Favorites
    add_favorite_place, get_favorite_places, delete_favorite_place,
    add_favorite_restaurant, get_favorite_restaurants, remove_favorite_restaurant,
    # Driver withdrawals
    get_driver_balance, request_withdrawal, get_driver_withdrawals,
    process_withdrawal, list_pending_withdrawals,
    # Scheduled
    list_scheduled_jobs, schedule_food_order,
    # Geofencing
    is_within_service_area, validate_ride_geofence,
    # Admin roles
    check_permission, set_user_role, list_admin_users,
    ROLE_PERMISSIONS, db_update_user,
)

load_dotenv()

app = FastAPI(
    title=settings.api_title,
    version=settings.api_version,
    debug=settings.debug,
)

# CORS - restrict in production, allow all in dev
_cors_origins = settings.cors_origins.split(",")
app.add_middleware(
    CORSMiddleware,
    allow_origins=_cors_origins if settings.is_production else ["*"],
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type", "Accept"],
    max_age=600,
)


# Security headers middleware
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response


class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        response: Response = await call_next(request)
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["X-XSS-Protection"] = "1; mode=block"
        response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
        if settings.is_production:
            response.headers["Strict-Transport-Security"] = (
                "max-age=63072000; includeSubDomains"
            )
        return response


app.add_middleware(SecurityHeadersMiddleware)

from .rate_limit import RateLimitMiddleware
app.add_middleware(RateLimitMiddleware)

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
        notify(user.get("email"), "welcome", name=user.get("name", "there"))
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
        role=current_user.get("role", "user"),
        is_verified=current_user.get("is_verified", False),
        wallet_balance=current_user.get("wallet_balance", 0.0),
        created_at=current_user.get("created_at", ""),
    )


@app.put("/users/me")
def update_me(payload: dict, current_user: dict = Depends(get_current_user)):
    """Update current user profile."""
    user_id = current_user["id"]
    updates = {}
    if "name" in payload:
        updates["name"] = payload["name"]
    if "email" in payload:
        updates["email"] = payload["email"]
    if not updates:
        raise HTTPException(400, "Nothing to update")
    result = db_update_user(user_id, **updates)
    if not result:
        raise HTTPException(404, "User not found")
    return {"ok": True, "user_id": user_id}


# ==================== ROUTING ====================

@app.get("/route")
async def route_between(
    pickup_lat: float, pickup_lng: float,
    drop_lat: float, drop_lng: float,
):
    """Get road-distance route between two GPS points via OSRM."""
    route = await get_route(pickup_lat, pickup_lng, drop_lat, drop_lng)
    if not route:
        raise HTTPException(502, "Could not calculate route")
    corridor = "CBD"
    price, base, dist = estimate_price_usd(route["distance_km"], corridor)
    return {
        **route,
        "price_usd": price,
        "base_fare": base,
        "distance_fare": dist,
    }


# ==================== RIDE ROUTES ====================

@app.post("/quote", response_model=Quote)
def quote(q: QuoteRequest, _auth=Depends(require_auth)):
    road_km = q.distance_km
    # Use OSRM road distance when GPS coords are available
    if all(getattr(q, a, None) for a in ("pickup_lat", "pickup_lng", "drop_lat", "drop_lng")):
        road_km_calc, road_eta = get_eta_and_distance(
            q.pickup_lat, q.pickup_lng, q.drop_lat, q.drop_lng)
        road_km = road_km_calc or q.distance_km

    corridor = classify_corridor(q.pickup_text, q.drop_text)
    eta = estimate_eta_minutes(road_km, corridor)
    price, base, dist = estimate_price_usd(road_km, corridor, peak=q.peak)
    return Quote(
        corridor=corridor, eta_min=eta, price_usd=price,
        base_fare=base, distance_fare=dist, total_usd=price,
    )


@app.post("/jobs")
def create(j: CreateJob, _auth=Depends(require_auth)):
    job = create_job(j.model_dump())
    # Use proximity matching if coordinates available, else fallback to rotation
    drv = get_driver_by_id(j.driver_id) if j.driver_id else None
    if not drv:
        pickup_lat = job.get("pickup_lat")
        pickup_lng = job.get("pickup_lng")
        drv = pick_nearest_driver(pickup_lat, pickup_lng)
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

    # Auto-assign nearest driver for delivery
    drv = pick_nearest_driver(restaurant.get("lat") if isinstance(restaurant, dict) else restaurant.lat,
                               restaurant.get("lng") if isinstance(restaurant, dict) else restaurant.lng)
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


# ==================== FOOD RATINGS ====================

@app.post("/food-orders/{order_id}/rate")
def rate_food_order(order_id: str, rating: FoodOrderRating, _auth=Depends(require_auth)):
    """Rate a food order."""
    order = get_food_order(order_id)
    if not order:
        raise HTTPException(404, "Order not found")
    if order["status"] != "delivered":
        raise HTTPException(400, "Can only rate delivered orders")

    result = add_food_rating({
        "order_id": order_id,
        "restaurant_id": rating.restaurant_id,
        "rider_id": _auth.get("id"),
        "food_rating": rating.food_rating,
        "delivery_rating": rating.delivery_rating,
        "comment": rating.comment,
    })
    return result


@app.get("/restaurants/{restaurant_id}/ratings")
def restaurant_ratings(restaurant_id: str, limit: int = 20, _auth=Depends(require_auth)):
    """Get ratings for a restaurant."""
    return {"ratings": get_restaurant_ratings(restaurant_id, limit)}


# ==================== CHAT ====================

@app.post("/chat/send")
async def send_chat_message(msg: ChatMessage, _auth=Depends(require_auth)):
    """Send a chat message (persisted + broadcast via WS)."""
    saved = save_chat_message(
        job_id=msg.job_id, order_id=msg.order_id,
        sender_type=msg.sender_type,
        sender_id=_auth.get("id"),
        message=msg.message,
    )
    # Also broadcast via WebSocket if there's a job or order room
    room_id = msg.job_id or msg.order_id
    if room_id:
        await chat_room.broadcast(room_id, {"type": "chat", "message": saved})
    return saved


@app.get("/chat/history")
def chat_history(job_id: str = None, order_id: str = None,
                 limit: int = 50, _auth=Depends(require_auth)):
    """Get chat history for a job or order."""
    return {"messages": get_chat_history(job_id=job_id, order_id=order_id, limit=limit)}


# ==================== DRIVER LOCATION ====================

@app.post("/drivers/{driver_id}/location")
async def driver_location_update(driver_id: str, loc: DriverLocationUpdate,
                                 _auth=Depends(require_auth)):
    """Update driver's live GPS location."""
    result = update_driver_location(driver_id, loc.lat, loc.lng)
    if not result.get("ok"):
        raise HTTPException(404, result.get("message", "Driver not found"))

    # Broadcast location to any tracking subscribers
    await driver_tracker.broadcast_driver_location(driver_id, loc.lat, loc.lng)
    return result


# ==================== UNIFIED HISTORY ====================

@app.get("/history")
def order_history(limit: int = 50, _auth=Depends(require_auth)):
    """Get combined ride + food order history."""
    user_name = _auth.get("name")
    return {"history": get_user_history(user_name=user_name, limit=limit)}


# ==================== SURGE PRICING ====================

@app.get("/surge")
def surge_status(_auth=Depends(require_auth)):
    """Get current surge pricing status."""
    return get_surge_multiplier()


@app.post("/surge/override")
def surge_override(payload: dict, _auth=Depends(require_auth)):
    """Admin: override surge pricing."""
    return set_surge_override(
        rain=payload.get("rain"),
        high_demand=payload.get("high_demand"),
        manual=payload.get("manual_multiplier"),
    )


# ==================== DISPUTES ====================

@app.post("/disputes")
def create_dispute_route(payload: dict, _auth=Depends(require_auth)):
    """Create a dispute/complaint."""
    if not payload.get("type") or not payload.get("description"):
        raise HTTPException(400, "Type and description are required")
    data = {
        "user_id": _auth.get("id"),
        "job_id": payload.get("job_id"),
        "order_id": payload.get("order_id"),
        "type": payload["type"],
        "description": payload["description"],
    }
    return create_dispute(data)


@app.get("/disputes")
def list_disputes_route(status: str = None, limit: int = 50,
                        _auth=Depends(require_auth)):
    """List disputes (admin)."""
    return {"disputes": list_disputes(status=status, limit=limit)}


@app.get("/disputes/{dispute_id}")
def get_dispute_route(dispute_id: int, _auth=Depends(require_auth)):
    d = get_dispute(dispute_id)
    if not d:
        raise HTTPException(404, "Dispute not found")
    return d


@app.post("/disputes/{dispute_id}/resolve")
def resolve_dispute_route(dispute_id: int, payload: dict,
                          _auth=Depends(require_auth)):
    """Admin: resolve a dispute."""
    resolution = payload.get("resolution", "")
    refund = payload.get("refund_amount", 0)
    status = payload.get("status", "resolved")
    result = resolve_dispute(dispute_id, resolution, refund, status)
    if not result:
        raise HTTPException(404, "Dispute not found")

    if refund > 0 and result.get("user_id"):
        from .database import wallet_credit
        wallet_credit(result["user_id"], refund,
                      txn_type="refund",
                      reference_id=str(dispute_id),
                      description=f"Refund for dispute #{dispute_id}")

    notify(result.get("user_email"), "dispute_update",
           name=result.get("user_name", "Customer"), dispute=result)

    return result


# ==================== DRIVER DOCUMENTS ====================

@app.post("/drivers/{driver_id}/documents")
def submit_document(driver_id: str, payload: dict,
                    _auth=Depends(require_auth)):
    """Driver: submit a document for verification."""
    doc_type = payload.get("doc_type")
    if doc_type not in ("national_id", "drivers_license",
                        "vehicle_registration", "insurance"):
        raise HTTPException(400, "Invalid document type")
    data = {
        "driver_id": driver_id,
        "doc_type": doc_type,
        "doc_number": payload.get("doc_number"),
        "file_url": payload.get("file_url"),
    }
    return submit_driver_document(data)


@app.get("/drivers/{driver_id}/documents")
def get_documents(driver_id: str, _auth=Depends(require_auth)):
    """Get all documents for a driver."""
    return {"documents": get_driver_documents(driver_id)}


@app.get("/admin/documents/pending")
def pending_documents(_auth=Depends(require_auth)):
    """Admin: list pending document verifications."""
    return {"documents": list_pending_documents()}


@app.get("/admin/documents")
def all_documents(status: str = None, limit: int = 100,
                  _auth=Depends(require_auth)):
    """Admin: list all documents."""
    return {"documents": list_all_documents(status=status, limit=limit)}


@app.post("/admin/documents/{doc_id}/review")
def review_document(doc_id: int, payload: dict,
                    _auth=Depends(require_auth)):
    """Admin: approve or reject a document."""
    status = payload.get("status")
    if status not in ("approved", "rejected"):
        raise HTTPException(400, "Status must be 'approved' or 'rejected'")
    result = review_driver_document(
        doc_id, status,
        reviewed_by=_auth.get("id", "admin"),
        rejection_reason=payload.get("reason"),
    )
    if not result:
        raise HTTPException(404, "Document not found")

    if result.get("driver_verified"):
        notify(result.get("driver_email"), "driver_verified",
               name=result.get("driver_name", "Driver"))

    return result


@app.post("/admin/email/test")
def test_email(payload: dict, _auth=Depends(require_auth)):
    """Admin: send a test email to verify SMTP settings."""
    to = payload.get("to")
    if not to:
        raise HTTPException(400, "Missing 'to' address")
    from .email_service import send_email, _base_html
    html = _base_html("Test Email", "<h2>It works!</h2><p>Famba email is configured correctly.</p>")
    ok = send_email(to, "Famba test email", html)
    return {"sent": ok, "to": to}


# ==================== OTP / PHONE VERIFICATION ====================

@app.post("/otp/send")
def send_otp(payload: dict):
    """Send OTP code to a phone number."""
    phone = payload.get("phone", "").strip()
    purpose = payload.get("purpose", "verify")
    if not phone or len(phone) < 9:
        raise HTTPException(400, "Valid phone number required")
    result = create_otp(phone, purpose)
    # In production, send via SMS provider. In dev, return code for testing.
    if settings.is_development:
        return {**result, "message": "OTP sent (dev: code included)"}
    return {"phone": phone, "expires_in": 600,
            "message": "OTP sent to your phone."}


@app.post("/otp/verify")
def verify_otp_route(payload: dict):
    """Verify OTP code."""
    phone = payload.get("phone", "").strip()
    code = payload.get("code", "").strip()
    purpose = payload.get("purpose", "verify")
    if not phone or not code:
        raise HTTPException(400, "Phone and code required")
    result = verify_otp(phone, code, purpose)
    if not result["valid"]:
        raise HTTPException(400, result["message"])
    return result


# ==================== FAVORITES ====================

@app.get("/favorites/places")
def list_fav_places(_auth=Depends(require_auth)):
    """Get user's saved places."""
    return {"places": get_favorite_places(_auth["id"])}


@app.post("/favorites/places")
def save_fav_place(payload: dict, _auth=Depends(require_auth)):
    """Save a favorite place (home, work, etc.)."""
    if not payload.get("name"):
        raise HTTPException(400, "Place name required")
    return add_favorite_place(_auth["id"], payload)


@app.delete("/favorites/places/{place_id}")
def delete_fav_place(place_id: int, _auth=Depends(require_auth)):
    ok = delete_favorite_place(place_id, _auth["id"])
    if not ok:
        raise HTTPException(404, "Place not found")
    return {"ok": True}


@app.get("/favorites/restaurants")
def list_fav_restaurants(_auth=Depends(require_auth)):
    """Get user's favorite restaurants."""
    return {"restaurants": get_favorite_restaurants(_auth["id"])}


@app.post("/favorites/restaurants")
def save_fav_restaurant(payload: dict, _auth=Depends(require_auth)):
    """Save a restaurant as favorite."""
    rid = payload.get("restaurant_id")
    if not rid:
        raise HTTPException(400, "restaurant_id required")
    return add_favorite_restaurant(_auth["id"], rid)


@app.delete("/favorites/restaurants/{fav_id}")
def delete_fav_restaurant(fav_id: int, _auth=Depends(require_auth)):
    ok = remove_favorite_restaurant(fav_id, _auth["id"])
    if not ok:
        raise HTTPException(404, "Favorite not found")
    return {"ok": True}


# ==================== DRIVER WITHDRAWALS ====================

@app.get("/drivers/{driver_id}/balance")
def driver_balance(driver_id: str, _auth=Depends(require_auth)):
    """Get driver's available balance for withdrawal."""
    return get_driver_balance(driver_id)


@app.post("/drivers/{driver_id}/withdraw")
def driver_withdraw(driver_id: str, payload: dict,
                    _auth=Depends(require_auth)):
    """Driver: request a withdrawal."""
    amount = payload.get("amount", 0)
    method = payload.get("method", "ecocash")
    account = payload.get("account_number", "")
    if not account:
        raise HTTPException(400, "Account number required")
    if method not in ("ecocash", "innbucks", "bank_transfer"):
        raise HTTPException(400, "Method must be ecocash, innbucks, or bank_transfer")
    result = request_withdrawal(driver_id, amount, method, account)
    if not result.get("ok"):
        raise HTTPException(400, result.get("message", "Withdrawal failed"))
    return result


@app.get("/drivers/{driver_id}/withdrawals")
def driver_withdrawal_history(driver_id: str, _auth=Depends(require_auth)):
    """Get driver's withdrawal history."""
    return {"withdrawals": get_driver_withdrawals(driver_id)}


@app.get("/admin/withdrawals/pending")
def admin_pending_withdrawals(_auth=Depends(require_auth)):
    """Admin: list pending withdrawal requests."""
    return {"withdrawals": list_pending_withdrawals()}


@app.post("/admin/withdrawals/{withdrawal_id}/process")
def admin_process_withdrawal(withdrawal_id: int, payload: dict,
                             _auth=Depends(require_auth)):
    """Admin: approve/reject a withdrawal."""
    status = payload.get("status")
    if status not in ("processing", "completed", "failed"):
        raise HTTPException(400, "Status must be processing, completed, or failed")
    result = process_withdrawal(withdrawal_id, status,
                                reference=payload.get("reference"))
    if not result:
        raise HTTPException(404, "Withdrawal not found")
    return result


# ==================== GEOFENCING ====================

@app.get("/geofence/check")
def check_geofence(lat: float, lng: float, _auth=Depends(require_auth)):
    """Check if a point is within the Harare service area."""
    return is_within_service_area(lat, lng)


@app.post("/geofence/validate-ride")
def validate_geofence(payload: dict, _auth=Depends(require_auth)):
    """Validate both pickup and drop-off are within service area."""
    required = ["pickup_lat", "pickup_lng", "drop_lat", "drop_lng"]
    if not all(payload.get(k) for k in required):
        raise HTTPException(400, "All coordinates required")
    result = validate_ride_geofence(
        payload["pickup_lat"], payload["pickup_lng"],
        payload["drop_lat"], payload["drop_lng"])
    if not result["ok"]:
        raise HTTPException(400, result["message"])
    return result


@app.get("/geofence/service-area")
def service_area():
    """Get the current service area definition."""
    from .database import HARARE_SERVICE_AREA
    return HARARE_SERVICE_AREA


# ==================== SCHEDULED ORDERS ====================

@app.post("/food-orders/schedule")
def schedule_food_order_route(payload: dict, _auth=Depends(require_auth)):
    """Schedule a food order for later delivery."""
    order_id = payload.get("order_id")
    scheduled_time = payload.get("scheduled_time")
    if not order_id or not scheduled_time:
        raise HTTPException(400, "order_id and scheduled_time required")
    result = schedule_food_order(order_id, scheduled_time)
    if not result:
        raise HTTPException(404, "Order not found")
    return {"ok": True, "order_id": order_id,
            "scheduled_time": scheduled_time,
            "message": "Order scheduled successfully"}


@app.get("/jobs/scheduled")
def get_scheduled_jobs(_auth=Depends(require_auth)):
    """List all scheduled rides."""
    return {"jobs": list_scheduled_jobs()}


# ==================== ADMIN ROLES & PERMISSIONS ====================

@app.get("/admin/roles")
def get_roles(_auth=Depends(require_auth)):
    """List available roles and their permissions."""
    return {role: list(perms) for role, perms in ROLE_PERMISSIONS.items()}


@app.get("/admin/users")
def admin_list_users(limit: int = 100, _auth=Depends(require_auth)):
    """Admin: list all users."""
    return {"users": db_list_users(limit)}


@app.get("/admin/staff")
def admin_staff(_auth=Depends(require_auth)):
    """Admin: list admin/support staff."""
    return {"staff": list_admin_users()}


@app.post("/admin/users/{user_id}/role")
def admin_set_role(user_id: str, payload: dict, _auth=Depends(require_auth)):
    """Super admin: set a user's role."""
    role = payload.get("role", "")
    if role not in ROLE_PERMISSIONS:
        raise HTTPException(400, f"Invalid role. Must be one of: {list(ROLE_PERMISSIONS.keys())}")
    result = set_user_role(user_id, role)
    if not result:
        raise HTTPException(404, "User not found")
    return result


@app.post("/admin/users/{user_id}/deactivate")
def admin_deactivate_user(user_id: str, _auth=Depends(require_auth)):
    """Admin: deactivate a user account."""
    result = db_update_user(user_id, is_active=False)
    if not result:
        raise HTTPException(404, "User not found")
    return {"ok": True, "user_id": user_id, "is_active": False}


@app.post("/admin/users/{user_id}/activate")
def admin_activate_user(user_id: str, _auth=Depends(require_auth)):
    """Admin: reactivate a user account."""
    result = db_update_user(user_id, is_active=True)
    if not result:
        raise HTTPException(404, "User not found")
    return {"ok": True, "user_id": user_id, "is_active": True}


# ==================== APP VERSION / FORCE UPDATE ====================

APP_VERSIONS = {
    "rider_android": {"min": "1.0.0", "latest": "1.2.0", "force_update": False},
    "rider_ios": {"min": "1.0.0", "latest": "1.2.0", "force_update": False},
    "driver_android": {"min": "1.0.0", "latest": "1.1.0", "force_update": False},
    "driver_ios": {"min": "1.0.0", "latest": "1.1.0", "force_update": False},
}


@app.get("/app/version")
def check_app_version(platform: str = "rider_android", current: str = "1.0.0"):
    """Check if the app needs updating."""
    config = APP_VERSIONS.get(platform)
    if not config:
        return {"update_required": False, "force": False}

    def _parse(v):
        return tuple(int(x) for x in v.split("."))

    cur = _parse(current)
    min_v = _parse(config["min"])
    latest_v = _parse(config["latest"])

    force = cur < min_v
    update_available = cur < latest_v
    return {
        "update_required": force,
        "update_available": update_available,
        "force": force or config["force_update"],
        "current_version": current,
        "latest_version": config["latest"],
        "min_version": config["min"],
        "message": "Please update to continue using Famba." if force else (
            "A new version is available." if update_available else "You're up to date."
        ),
    }


@app.post("/admin/app/version")
def set_app_version(payload: dict, _auth=Depends(require_auth)):
    """Admin: update version requirements."""
    platform = payload.get("platform")
    if platform not in APP_VERSIONS:
        raise HTTPException(400, f"Invalid platform. Must be one of: {list(APP_VERSIONS.keys())}")
    if "min" in payload:
        APP_VERSIONS[platform]["min"] = payload["min"]
    if "latest" in payload:
        APP_VERSIONS[platform]["latest"] = payload["latest"]
    if "force_update" in payload:
        APP_VERSIONS[platform]["force_update"] = payload["force_update"]
    return APP_VERSIONS[platform]


# ==================== ANALYTICS EXPORT ====================

@app.get("/admin/export/rides")
def export_rides(_auth=Depends(require_auth)):
    """Export rides data as CSV."""
    from io import StringIO
    import csv
    jobs = list_jobs(limit=1000)
    output = StringIO()
    writer = csv.writer(output)
    writer.writerow(["id", "status", "pickup", "drop", "distance_km", "fare_usd",
                      "driver_id", "payment_method", "created_at"])
    for j in jobs:
        writer.writerow([j.get("id"), j.get("status"), j.get("pickup_text"),
                         j.get("drop_text"), j.get("distance_km"), j.get("fare_usd"),
                         j.get("driver_id"), j.get("payment_method"), j.get("created_at")])
    from starlette.responses import StreamingResponse
    output.seek(0)
    return StreamingResponse(
        iter([output.getvalue()]),
        media_type="text/csv",
        headers={"Content-Disposition": "attachment; filename=famba_rides.csv"},
    )


@app.get("/admin/export/food-orders")
def export_food_orders(_auth=Depends(require_auth)):
    """Export food orders as CSV."""
    from io import StringIO
    import csv
    orders = list_food_orders(limit=1000)
    output = StringIO()
    writer = csv.writer(output)
    writer.writerow(["id", "restaurant_id", "status", "subtotal", "delivery_fee",
                      "total", "delivery_address", "payment_method", "created_at"])
    for o in orders:
        writer.writerow([o.get("id"), o.get("restaurant_id"), o.get("status"),
                         o.get("subtotal"), o.get("delivery_fee"), o.get("total"),
                         o.get("delivery_address"), o.get("payment_method"), o.get("created_at")])
    from starlette.responses import StreamingResponse
    output.seek(0)
    return StreamingResponse(
        iter([output.getvalue()]),
        media_type="text/csv",
        headers={"Content-Disposition": "attachment; filename=famba_food_orders.csv"},
    )


@app.get("/admin/export/drivers")
def export_drivers(_auth=Depends(require_auth)):
    """Export drivers data as CSV."""
    from io import StringIO
    import csv
    drivers = get_all_drivers()
    output = StringIO()
    writer = csv.writer(output)
    writer.writerow(["id", "name", "phone", "rating", "total_trips",
                      "is_online", "is_verified", "created_at"])
    for d in drivers:
        writer.writerow([d.get("id"), d.get("name"), d.get("phone"),
                         d.get("rating"), d.get("total_trips"),
                         d.get("is_online"), d.get("is_verified"), d.get("created_at")])
    from starlette.responses import StreamingResponse
    output.seek(0)
    return StreamingResponse(
        iter([output.getvalue()]),
        media_type="text/csv",
        headers={"Content-Disposition": "attachment; filename=famba_drivers.csv"},
    )


@app.get("/admin/export/users")
def export_users(_auth=Depends(require_auth)):
    """Export users data as CSV."""
    from io import StringIO
    import csv
    users = db_list_users(1000)
    output = StringIO()
    writer = csv.writer(output)
    writer.writerow(["id", "phone", "name", "user_type", "role",
                      "is_verified", "wallet_balance", "created_at"])
    for u in users:
        writer.writerow([u.get("id"), u.get("phone"), u.get("name"),
                         u.get("user_type"), u.get("role"),
                         u.get("is_verified"), u.get("wallet_balance"), u.get("created_at")])
    from starlette.responses import StreamingResponse
    output.seek(0)
    return StreamingResponse(
        iter([output.getvalue()]),
        media_type="text/csv",
        headers={"Content-Disposition": "attachment; filename=famba_users.csv"},
    )


# ==================== RECEIPT GENERATION ====================

@app.get("/receipts/ride/{job_id}")
def ride_receipt(job_id: str, _auth=Depends(require_auth)):
    """Generate HTML receipt for a ride."""
    job = get_job(job_id)
    if not job:
        raise HTTPException(404, "Job not found")
    from .email_service import _base_html
    body = f"""
    <h2>Ride Receipt</h2>
    <div class="detail"><table>
      <tr><td class="label">Receipt #</td><td class="value">{job['id']}</td></tr>
      <tr><td class="label">From</td><td class="value">{job.get('pickup_text','')}</td></tr>
      <tr><td class="label">To</td><td class="value">{job.get('drop_text','')}</td></tr>
      <tr><td class="label">Distance</td><td class="value">{job.get('distance_km',0):.1f} km</td></tr>
      <tr><td class="label">Payment</td><td class="value">{job.get('payment_method','cash')}</td></tr>
      <tr><td class="label">Status</td><td class="value">{job.get('status','')}</td></tr>
      <tr><td class="label">Date</td><td class="value">{job.get('created_at','')}</td></tr>
    </table></div>
    <div style="text-align:center;margin-top:16px;padding:16px;background:#f9f9f9;border-radius:8px">
      <div style="font-size:14px;color:#888">Total Fare</div>
      <div style="font-size:36px;font-weight:700;color:#ff6600">${job.get('fare_usd',0):.2f}</div>
    </div>
    <p style="margin-top:16px;font-size:12px;color:#888;text-align:center">
      Thank you for riding with Famba!
    </p>
    """
    html = _base_html(f"Receipt #{job['id']}", body)
    from starlette.responses import HTMLResponse
    return HTMLResponse(content=html)


@app.get("/receipts/food/{order_id}")
def food_receipt(order_id: str, _auth=Depends(require_auth)):
    """Generate HTML receipt for a food order."""
    order = get_food_order(order_id)
    if not order:
        raise HTTPException(404, "Order not found")
    items = order.get("items", [])
    items_html = "".join(
        f"<tr><td>{it.get('name','')}</td><td style='text-align:center'>x{it.get('qty',1)}</td>"
        f"<td style='text-align:right'>${it.get('price',0):.2f}</td></tr>"
        for it in items
    )
    from .email_service import _base_html
    body = f"""
    <h2>Food Order Receipt</h2>
    <div class="detail"><table>
      <tr><td class="label">Order #</td><td class="value">{order['id']}</td></tr>
      <tr><td class="label">Restaurant</td><td class="value">{order.get('restaurant_id','')}</td></tr>
      <tr><td class="label">Delivery</td><td class="value">{order.get('delivery_address','')}</td></tr>
      <tr><td class="label">Payment</td><td class="value">{order.get('payment_method','cash')}</td></tr>
      <tr><td class="label">Date</td><td class="value">{order.get('created_at','')}</td></tr>
    </table></div>
    <table style="width:100%;margin:16px 0;border-collapse:collapse">
      <thead><tr style="border-bottom:2px solid #eee">
        <th style="text-align:left;padding:8px">Item</th>
        <th style="text-align:center;padding:8px">Qty</th>
        <th style="text-align:right;padding:8px">Price</th>
      </tr></thead>
      <tbody>{items_html}</tbody>
    </table>
    <div style="text-align:right;padding:8px;border-top:2px solid #eee">
      <div>Subtotal: <strong>${order.get('subtotal',0):.2f}</strong></div>
      <div>Delivery: <strong>${order.get('delivery_fee',0):.2f}</strong></div>
      <div style="font-size:20px;color:#ff6600;margin-top:4px">
        Total: <strong>${order.get('total',0):.2f}</strong>
      </div>
    </div>
    """
    html = _base_html(f"Order #{order['id']}", body)
    from starlette.responses import HTMLResponse
    return HTMLResponse(content=html)


# ==================== RESTAURANT OWNER PORTAL ====================

@app.get("/restaurant-portal/{restaurant_id}/dashboard")
def restaurant_dashboard(restaurant_id: str, _auth=Depends(require_auth)):
    """Restaurant owner dashboard stats."""
    stats = get_restaurant_stats(restaurant_id)
    if not stats:
        raise HTTPException(404, "Restaurant not found")
    return stats


@app.get("/restaurant-portal/{restaurant_id}/orders")
def restaurant_orders(restaurant_id: str, status: str = None,
                      limit: int = 50, _auth=Depends(require_auth)):
    """Restaurant owner: list their orders."""
    return {"orders": list_food_orders(restaurant_id=restaurant_id,
                                       status=status, limit=limit)}


@app.post("/restaurant-portal/{restaurant_id}/orders/{order_id}/status")
def restaurant_update_order(restaurant_id: str, order_id: str,
                            payload: dict, _auth=Depends(require_auth)):
    """Restaurant owner: update order status (confirm, prepare, ready, cancel)."""
    order = get_food_order(order_id)
    if not order or order.get("restaurant_id") != restaurant_id:
        raise HTTPException(404, "Order not found")
    result = update_food_order_status_restaurant(order_id, payload.get("status", ""))
    if not result:
        raise HTTPException(400, "Invalid status transition")
    return result


@app.put("/restaurant-portal/{restaurant_id}/info")
def restaurant_update_info(restaurant_id: str, payload: dict,
                           _auth=Depends(require_auth)):
    """Restaurant owner: update restaurant profile."""
    result = update_restaurant_info(restaurant_id, payload)
    if not result:
        raise HTTPException(404, "Restaurant not found")
    return result


@app.get("/restaurant-portal/{restaurant_id}/menu")
def restaurant_menu(restaurant_id: str, _auth=Depends(require_auth)):
    """Restaurant owner: get menu."""
    return {"menu": get_menu(restaurant_id)}


@app.post("/restaurant-portal/{restaurant_id}/menu")
def restaurant_add_item(restaurant_id: str, payload: dict,
                        _auth=Depends(require_auth)):
    """Restaurant owner: add menu item."""
    if not payload.get("name") or not payload.get("price"):
        raise HTTPException(400, "Name and price required")
    payload["restaurant_id"] = restaurant_id
    return create_menu_item(restaurant_id, payload)


@app.put("/restaurant-portal/{restaurant_id}/menu/{item_id}")
def restaurant_edit_item(restaurant_id: str, item_id: int,
                         payload: dict, _auth=Depends(require_auth)):
    """Restaurant owner: update menu item."""
    result = update_menu_item(item_id, payload)
    if not result:
        raise HTTPException(404, "Menu item not found")
    return result


@app.delete("/restaurant-portal/{restaurant_id}/menu/{item_id}")
def restaurant_delete_item(restaurant_id: str, item_id: int,
                           _auth=Depends(require_auth)):
    """Restaurant owner: delete menu item."""
    ok = delete_menu_item(item_id)
    if not ok:
        raise HTTPException(404, "Menu item not found")
    return {"ok": True}


@app.get("/restaurant-portal/{restaurant_id}/ratings")
def restaurant_ratings(restaurant_id: str, _auth=Depends(require_auth)):
    """Restaurant owner: view their ratings."""
    return {"ratings": get_restaurant_ratings(restaurant_id)}


# ==================== WEBSOCKET ====================

# Driver location tracker - riders subscribe to watch a driver
class DriverTracker:
    def __init__(self):
        self.subscribers: Dict[str, Set[WebSocket]] = {}  # driver_id -> watchers

    async def subscribe(self, ws: WebSocket, driver_id: str):
        await ws.accept()
        if driver_id not in self.subscribers:
            self.subscribers[driver_id] = set()
        self.subscribers[driver_id].add(ws)

    def unsubscribe(self, ws: WebSocket, driver_id: str):
        if driver_id in self.subscribers:
            self.subscribers[driver_id].discard(ws)
            if not self.subscribers[driver_id]:
                del self.subscribers[driver_id]

    async def broadcast_driver_location(self, driver_id: str, lat: float, lng: float):
        if driver_id not in self.subscribers:
            return
        dead = set()
        for ws in self.subscribers[driver_id]:
            try:
                await ws.send_json({
                    "type": "driver_location",
                    "driver_id": driver_id,
                    "lat": lat, "lng": lng,
                })
            except Exception:
                dead.add(ws)
        for ws in dead:
            self.subscribers[driver_id].discard(ws)


driver_tracker = DriverTracker()


# Chat WebSocket - riders and drivers join a room
class ChatRoom:
    def __init__(self):
        self.rooms: Dict[str, Set[WebSocket]] = {}

    async def join(self, ws: WebSocket, room_id: str):
        await ws.accept()
        if room_id not in self.rooms:
            self.rooms[room_id] = set()
        self.rooms[room_id].add(ws)

    def leave(self, ws: WebSocket, room_id: str):
        if room_id in self.rooms:
            self.rooms[room_id].discard(ws)
            if not self.rooms[room_id]:
                del self.rooms[room_id]

    async def broadcast(self, room_id: str, message: dict):
        if room_id not in self.rooms:
            return
        dead = set()
        for ws in self.rooms[room_id]:
            try:
                await ws.send_json(message)
            except Exception:
                dead.add(ws)
        for ws in dead:
            self.rooms[room_id].discard(ws)


chat_room = ChatRoom()


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


@app.websocket("/ws/driver/{driver_id}")
async def websocket_driver_tracking(websocket: WebSocket, driver_id: str):
    """WebSocket: rider subscribes to live driver location updates."""
    await driver_tracker.subscribe(websocket, driver_id)
    try:
        while True:
            try:
                data = await asyncio.wait_for(websocket.receive_text(), timeout=30.0)
                if data == "ping":
                    await websocket.send_text("pong")
            except asyncio.TimeoutError:
                await websocket.send_json({"type": "heartbeat"})
    except WebSocketDisconnect:
        pass
    finally:
        driver_tracker.unsubscribe(websocket, driver_id)


@app.websocket("/ws/chat/{room_id}")
async def websocket_chat(websocket: WebSocket, room_id: str):
    """WebSocket: real-time chat between rider and driver."""
    await chat_room.join(websocket, room_id)
    try:
        while True:
            data = await websocket.receive_json()
            msg_type = data.get("type", "message")
            if msg_type == "message":
                saved = save_chat_message(
                    job_id=data.get("job_id"), order_id=data.get("order_id"),
                    sender_type=data.get("sender_type", "rider"),
                    sender_id=data.get("sender_id"),
                    message=data.get("message", ""),
                )
                await chat_room.broadcast(room_id, {"type": "chat", "message": saved})
            elif msg_type == "ping":
                await websocket.send_text("pong")
    except WebSocketDisconnect:
        pass
    finally:
        chat_room.leave(websocket, room_id)


@app.websocket("/ws/driver")
async def websocket_driver_dispatch(websocket: WebSocket):
    """WebSocket: driver app connects for ride/delivery dispatch.
    Currently a stub that keeps the connection alive.
    Real dispatch would push new ride/delivery requests here.
    """
    await websocket.accept()
    try:
        while True:
            try:
                data = await asyncio.wait_for(websocket.receive_text(), timeout=30.0)
                if data == "ping":
                    await websocket.send_text("pong")
            except asyncio.TimeoutError:
                await websocket.send_json({"type": "heartbeat"})
    except WebSocketDisconnect:
        pass
