from fastapi import APIRouter
from app.api.v1.endpoints.eleven import router as eleven_router
from app.api.v1.endpoints.gemini import router as gemini_router
from app.api.v1.endpoints.health import router as health_router
from app.api.v1.endpoints.skybox import router as skybox_router
from app.api.v1.endpoints.supabase import router as supabase_router
from app.api.v1.endpoints.api import router as api_router

router = APIRouter()
router.include_router(health_router, prefix="/health", tags=["health"])
router.include_router(eleven_router, prefix="/eleven", tags=["eleven"])
router.include_router(gemini_router, prefix="/gemini", tags=["gemini"])
router.include_router(skybox_router, prefix="/skybox", tags=["skybox"])
router.include_router(supabase_router, prefix="/supabase", tags=["supabase"])
router.include_router(api_router, prefix="/api", tags=["api"])



