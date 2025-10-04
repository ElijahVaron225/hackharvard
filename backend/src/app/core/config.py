from __future__ import annotations
from pydantic import BaseModel
from dotenv import load_dotenv
import os

load_dotenv()  # loads from .env if present

class Settings(BaseModel):
    APP_NAME: str = os.getenv("APP_NAME", "FastAPI Minimal")
    ENVIRONMENT: str = os.getenv("ENVIRONMENT", "development")
    API_V1_PREFIX: str = os.getenv("API_V1_PREFIX", "/api/v1")
    ELEVENLABS_API_KEY: str = os.getenv("ELEVENLABS_API_KEY")
    GEMINI_API_KEY: str = os.getenv("GEMINI_API_KEY")
    SUPABASE_URL: str = os.getenv("SUPABASE_URL")
    SUPABASE_KEY: str = os.getenv("SUPABASE_KEY")
    
    # Kiri Engine API configuration
    KIRI_API_KEY: str = os.getenv("KIRI_API_KEY")
    
    # Polling configuration
    POLLING_TIMEOUT_MINUTES: int = int(os.getenv("POLLING_TIMEOUT_MINUTES", "45"))
    POLLING_INITIAL_DELAY: float = float(os.getenv("POLLING_INITIAL_DELAY", "2.0"))
    POLLING_MAX_DELAY: float = float(os.getenv("POLLING_MAX_DELAY", "30.0"))
    
    # Job cleanup configuration
    JOB_CLEANUP_AGE_HOURS: int = int(os.getenv("JOB_CLEANUP_AGE_HOURS", "24"))

settings = Settings()
