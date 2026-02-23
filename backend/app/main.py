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
)

load_dotenv()

app = FastAPI(
    title=settings.api_title,
    version=settings.api_version,
    debug=settings.debug,
)

# CORS — restrict in production, allow all in dev
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

    # Process refund if any
    if refund > 0 and result.get("user_id"):
        from .database import wallet_credit
        wallet_credit(result["user_id"], refund,
                      txn_type="refund",
                      reference_id=str(dispute_id),
                      description=f"Refund for dispute #{dispute_id}")

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
    return result


# ==================== WEBSOCKET ====================

# Driver location tracker — riders subscribe to watch a driver
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


# Chat WebSocket — riders and drivers join a room
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
