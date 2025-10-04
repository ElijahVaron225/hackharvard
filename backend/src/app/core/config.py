from __future__ import annotations
from pydantic import BaseModel
from dotenv import load_dotenv
import os

load_dotenv()  # loads from .env if present

class Settings(BaseModel):
    APP_NAME: str = os.getenv("APP_NAME", "FastAPI Minimal")
    ENVIRONMENT: str = os.getenv("ENVIRONMENT", "development")
    API_V1_PREFIX: str = os.getenv("API_V1_PREFIX", "/api/v1")

settings = Settings()
