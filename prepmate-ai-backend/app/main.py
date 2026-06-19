"""
PrepMate AI - Backend API
Senior Backend Architecture by PrepMate Team
"""

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.responses import JSONResponse
from contextlib import asynccontextmanager
import logging
import time

from app.routers import (
    auth,
    chatbot,
    pdf_processing,
    notes_generator,
    mcq_generator,
    study_planner,
    analytics,
)
from app.core.config import settings
from app.core.firebase import initialize_firebase
from app.middleware.rate_limiter import RateLimitMiddleware

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan - startup and shutdown events."""
    logger.info("🚀 PrepMate AI Backend starting up...")
    initialize_firebase()
    logger.info("✅ Firebase initialized")
    yield
    logger.info("🛑 PrepMate AI Backend shutting down...")


app = FastAPI(
    title="PrepMate AI API",
    description="""
## PrepMate AI - Your Intelligent Study Companion

A comprehensive AI-powered study platform backend built with:
- **FastAPI** - High-performance async API framework
- **Firebase** - Authentication & Firestore database
- **Gemini AI** - Google's multimodal AI for intelligent features
- **PyMuPDF + Tesseract** - PDF processing & OCR

### Features
- 🤖 AI Chatbot with conversation history
- 📄 PDF Upload & Text Extraction (with OCR)
- 📝 AI Notes Generator (Summaries, Flashcards, Questions)
- ❓ MCQ Generator (100+ questions with scoring)
- 📅 Daily Study Planner
- 📊 User Analytics & Progress Tracking
    """,
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url="/openapi.json",
    lifespan=lifespan,
)

# ─── Middleware ────────────────────────────────────────────────────────────────

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.add_middleware(GZipMiddleware, minimum_size=1000)
app.add_middleware(RateLimitMiddleware)


@app.middleware("http")
async def log_requests(request: Request, call_next):
    start_time = time.time()
    response = await call_next(request)
    duration = round((time.time() - start_time) * 1000, 2)
    logger.info(f"{request.method} {request.url.path} - {response.status_code} [{duration}ms]")
    return response


# ─── Routers ──────────────────────────────────────────────────────────────────

app.include_router(auth.router,            prefix="/api/v1/auth",      tags=["Authentication"])
app.include_router(chatbot.router,         prefix="/api/v1/chat",      tags=["AI Chatbot"])
app.include_router(pdf_processing.router,  prefix="/api/v1/pdf",       tags=["PDF Processing"])
app.include_router(notes_generator.router, prefix="/api/v1/notes",     tags=["Notes Generator"])
app.include_router(mcq_generator.router,   prefix="/api/v1/mcq",       tags=["MCQ Generator"])
app.include_router(study_planner.router,   prefix="/api/v1/planner",   tags=["Study Planner"])
app.include_router(analytics.router,       prefix="/api/v1/analytics", tags=["Analytics"])


# ─── Health & Root ────────────────────────────────────────────────────────────

@app.get("/", tags=["Health"])
async def root():
    return {
        "service": "PrepMate AI Backend",
        "version": "1.0.0",
        "status": "operational",
        "docs": "/docs",
    }


@app.get("/health", tags=["Health"])
async def health_check():
    return {
        "status": "healthy",
        "services": {
            "api": "up",
            "firebase": "connected",
            "gemini": "ready",
        },
    }


# ─── Global Exception Handler ────────────────────────────────────────────────

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logger.error(f"Unhandled exception: {exc}", exc_info=True)
    return JSONResponse(
        status_code=500,
        content={"detail": "Internal server error. Please try again later."},
    )
