from fastapi import APIRouter
from .endpoints import health, gemini, eleven

api_router = APIRouter()
api_router.include_router(health.router, tags=["health"])
api_router.include_router(gemini.router, tags=["gemini"])
api_router.include_router(eleven.router, tags=["elevenlabs"])
