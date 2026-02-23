"""In-memory sliding-window rate limiter for FastAPI."""
import time
from collections import defaultdict
from typing import Optional

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import JSONResponse


class RateBucket:
    __slots__ = ("timestamps",)

    def __init__(self):
        self.timestamps: list = []

    def hit(self, now: float, window: float) -> int:
        cutoff = now - window
        self.timestamps = [t for t in self.timestamps if t > cutoff]
        self.timestamps.append(now)
        return len(self.timestamps)


_buckets: dict = defaultdict(RateBucket)

# Route-specific overrides: path_prefix -> (max_requests, window_seconds)
ROUTE_LIMITS = {
    "/auth/register": (5, 60),
    "/auth/login": (10, 60),
    "/otp/send": (3, 60),
    "/otp/verify": (10, 60),
}

DEFAULT_LIMIT = 120   # requests per window
DEFAULT_WINDOW = 60   # seconds


def _get_client_ip(request: Request) -> str:
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return request.client.host if request.client else "unknown"


class RateLimitMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        if request.method == "OPTIONS":
            return await call_next(request)

        ip = _get_client_ip(request)
        path = request.url.path
        now = time.time()

        # Find best matching route limit
        limit, window = DEFAULT_LIMIT, DEFAULT_WINDOW
        for prefix, (rl, rw) in ROUTE_LIMITS.items():
            if path.startswith(prefix):
                limit, window = rl, rw
                break

        key = f"{ip}:{path}" if path in ROUTE_LIMITS else f"{ip}:global"
        count = _buckets[key].hit(now, window)

        if count > limit:
            retry_after = int(window - (now - _buckets[key].timestamps[0]))
            return JSONResponse(
                status_code=429,
                content={
                    "detail": "Too many requests. Please slow down.",
                    "retry_after": max(1, retry_after),
                },
                headers={
                    "Retry-After": str(max(1, retry_after)),
                    "X-RateLimit-Limit": str(limit),
                    "X-RateLimit-Remaining": "0",
                },
            )

        response = await call_next(request)
        response.headers["X-RateLimit-Limit"] = str(limit)
        response.headers["X-RateLimit-Remaining"] = str(max(0, limit - count))
        return response
