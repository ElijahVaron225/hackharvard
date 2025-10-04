from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from app.utils.supabase import list_buckets, add_url_to_generated_images_bucket, add_url_to_thumbnails_bucket
from app.core.config import settings

router = APIRouter()

class URLRequest(BaseModel):
    url: str
    file_name: str = None

@router.get("/debug")
def debug_settings():
    """Debug Supabase settings"""
    return {
        "SUPABASE_URL": settings.SUPABASE_URL,
        "SUPABASE_KEY": settings.SUPABASE_KEY,
        "URL_SET": bool(settings.SUPABASE_URL),
        "KEY_SET": bool(settings.SUPABASE_KEY)
    }

@router.get("/buckets")
def get_buckets():
    """List all Supabase storage buckets"""
    try:
        buckets = list_buckets()
        return {"buckets": buckets}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/generated-images")
async def add_to_generated_images(request: URLRequest):
    """Add a URL to the generated_images bucket"""
    try:
        result = await add_url_to_generated_images_bucket(request.url, request.file_name)
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/thumbnails")
async def add_to_thumbnails(request: URLRequest):
    """Add a URL to the thumbnails bucket"""
    try:
        result = await add_url_to_thumbnails_bucket(request.url, request.file_name)
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
