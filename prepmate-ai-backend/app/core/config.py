"""
Configuration management using Pydantic Settings.
All secrets are loaded from environment variables.
"""

from pydantic_settings import BaseSettings
from pydantic import validator
from typing import List
import os


class Settings(BaseSettings):
    # ── App ───────────────────────────────────────────────────────────────────
    APP_NAME: str = "PrepMate AI"
    APP_VERSION: str = "1.0.0"
    ENVIRONMENT: str = "development"  # development | staging | production
    DEBUG: bool = False
    SECRET_KEY: str = "change-me-in-production"

    # ── Firebase ──────────────────────────────────────────────────────────────
    FIREBASE_PROJECT_ID: str = ""
    FIREBASE_CREDENTIALS_PATH: str = ""         # Path to service account JSON
    FIREBASE_CREDENTIALS_JSON: str = ""         # Or inline JSON (for Render/Railway)

    # ── Gemini AI ─────────────────────────────────────────────────────────────
    GEMINI_API_KEY: str = ""
    GEMINI_MODEL: str = "gemini-1.5-flash"
    GEMINI_PRO_MODEL: str = "gemini-1.5-pro"
    GEMINI_MAX_TOKENS: int = 8192
    GEMINI_TEMPERATURE: float = 0.7

    # ── Storage ───────────────────────────────────────────────────────────────
    UPLOAD_DIR: str = "/tmp/prepmate_uploads"
    MAX_UPLOAD_SIZE_MB: int = 50
    FIREBASE_STORAGE_BUCKET: str = ""

    # ── Rate Limiting ─────────────────────────────────────────────────────────
    RATE_LIMIT_REQUESTS: int = 100
    RATE_LIMIT_WINDOW_SECONDS: int = 60

    # ── CORS ──────────────────────────────────────────────────────────────────
    ALLOWED_ORIGINS: List[str] = [
        "http://localhost:3000",
        "http://localhost:5173",
        "https://prepmate.vercel.app",
        "https://prepmate-ai.web.app",
    ]

    # ── MCQ ───────────────────────────────────────────────────────────────────
    MCQ_DEFAULT_COUNT: int = 10
    MCQ_MAX_COUNT: int = 100

    # ── Study Planner ─────────────────────────────────────────────────────────
    PLANNER_DEFAULT_HOURS_PER_DAY: int = 4

    @validator("ALLOWED_ORIGINS", pre=True)
    def parse_origins(cls, v):
        if isinstance(v, str):
            return [o.strip() for o in v.split(",")]
        return v

    @validator("UPLOAD_DIR", pre=True, always=True)
    def create_upload_dir(cls, v):
        os.makedirs(v, exist_ok=True)
        return v

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        case_sensitive = True


settings = Settings()
