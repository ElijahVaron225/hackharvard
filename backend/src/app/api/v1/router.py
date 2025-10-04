from fastapi import APIRouter
from .endpoints import health
from .endpoints import skybox

api_router = APIRouter()
api_router.include_router(health.router, tags=["health"])
api_router.include_router(skybox.router, tags=["skybox"])

