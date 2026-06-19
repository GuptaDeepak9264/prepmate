"""
In-memory rate limiter middleware using sliding window algorithm.
For production, replace with Redis-backed limiter.
"""

from fastapi import Request
from fastapi.responses import JSONResponse
from starlette.middleware.base import BaseHTTPMiddleware
from collections import defaultdict, deque
from app.core.config import settings
import time
import logging

logger = logging.getLogger(__name__)

# Exempt paths from rate limiting
EXEMPT_PATHS = {"/", "/health", "/docs", "/redoc", "/openapi.json"}


class RateLimitMiddleware(BaseHTTPMiddleware):
    def __init__(self, app):
        super().__init__(app)
        self._requests: dict[str, deque] = defaultdict(deque)
        self.limit = settings.RATE_LIMIT_REQUESTS
        self.window = settings.RATE_LIMIT_WINDOW_SECONDS

    def _get_client_id(self, request: Request) -> str:
        # Use real IP (handles proxies / Render / Railway)
        forwarded = request.headers.get("X-Forwarded-For")
        if forwarded:
            return forwarded.split(",")[0].strip()
        return request.client.host if request.client else "unknown"

    async def dispatch(self, request: Request, call_next):
        if request.url.path in EXEMPT_PATHS:
            return await call_next(request)

        client_id = self._get_client_id(request)
        now = time.time()
        window_start = now - self.window

        # Slide the window
        q = self._requests[client_id]
        while q and q[0] < window_start:
            q.popleft()

        if len(q) >= self.limit:
            logger.warning(f"Rate limit exceeded for {client_id}")
            return JSONResponse(
                status_code=429,
                content={
                    "detail": f"Rate limit exceeded. Max {self.limit} requests per {self.window}s."
                },
                headers={"Retry-After": str(self.window)},
            )

        q.append(now)
        response = await call_next(request)
        response.headers["X-RateLimit-Limit"] = str(self.limit)
        response.headers["X-RateLimit-Remaining"] = str(self.limit - len(q))
        return response
