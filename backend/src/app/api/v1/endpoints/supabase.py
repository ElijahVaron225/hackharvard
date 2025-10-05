from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from app.utils.supabase import list_buckets, add_url_to_generated_images_bucket, add_url_to_thumbnails_bucket, get_generated_image_url, list_generated_images, list_thumbnails, create_post_empty, get_posts, update_post as update_post_util
from app.core.config import settings
from app.models import Post

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

@router.get("/get_thumbnails")
def get_thumbnails():
    """Get all thumbnail photos from the thumbnails bucket"""
    try:
        result = list_thumbnails()
        if not result["success"]:
            raise HTTPException(status_code=500, detail=result["error"])
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/generated-images/{file_name}")
def get_generated_image(file_name: str):
    """Get the public URL for a specific file in the generated_images bucket"""
    try:
        result = get_generated_image_url(file_name)
        if not result["success"]:
            if "not found" in result["error"]:
                raise HTTPException(status_code=404, detail=result["error"])
            else:
                raise HTTPException(status_code=500, detail=result["error"])
        return result
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    
@router.get("/get-posts")
async def get_all_posts():
    """Gets all the posts - returns 3 real hardcoded posts for demo"""
    print("📱 [BACKEND] get-posts endpoint called")
    try:
        # Return 3 real hardcoded posts from your data
        hardcoded_posts = [
            {
                "idx": 8,
                "id": "136f2b79-0565-4f7d-96fa-e0887f2b8722",
                "user_id": "b6e81940-0567-4967-8789-447a6cb8aa5c",
                "thumbnail_url": "https://ygrolpbmsuhcslizztvy.supabase.co/storage/v1/object/public/generated_images/M3_Cinematic_Realism_equirectangular-png_Make_a_photoreal_PBR_351798456_14400545.png",
                "user_scanned_item": "https://ygrolpbmsuhcslizztvy.supabase.co/storage/v1/object/public/user_scanned_items/testImage2.png",
                "generated_images": "https://ygrolpbmsuhcslizztvy.supabase.co/storage/v1/object/public/generated_images/M3_Cinematic_Realism_equirectangular-png_Make_a_photoreal_PBR_351798456_14400545.png",
                "created_at": "2025-10-05 08:08:08.392334+00",
                "caption": "india necklace",
                "likes": 0
            },
            {
                "idx": 9,
                "id": "4a132889-ce10-4bef-b9cf-22f6cba7f7ca",
                "user_id": "b6e81940-0567-4967-8789-447a6cb8aa5c",
                "thumbnail_url": "https://ygrolpbmsuhcslizztvy.supabase.co/storage/v1/object/public/generated_images/M3_Cinematic_Realism_equirectangular-jpg_Photoreal_PBR_3D_scene_1261325315_14400622.jpg",
                "user_scanned_item": "https://ygrolpbmsuhcslizztvy.supabase.co/storage/v1/object/public/user_scanned_items/testImage.jpg",
                "generated_images": "https://ygrolpbmsuhcslizztvy.supabase.co/storage/v1/object/public/generated_images/M3_Cinematic_Realism_equirectangular-jpg_Photoreal_PBR_3D_scene_1261325315_14400622.jpg",
                "created_at": "2025-10-05 07:59:58.59562+00",
                "caption": "Hack Harvard",
                "likes": 0
            },
            {
                "idx": 10,
                "id": "964c81e9-c998-467d-9e28-f5a1b6eeae2c",
                "user_id": "b6e81940-0567-4967-8789-447a6cb8aa5c",
                "thumbnail_url": "https://ygrolpbmsuhcslizztvy.supabase.co/storage/v1/object/public/generated_images/M3_Cinematic_Realism_equirectangular-jpg_Photoreal_PBR_3D_scene_1706171275_14400628.jpg",
                "user_scanned_item": "https://ygrolpbmsuhcslizztvy.supabase.co/storage/v1/object/public/user_scanned_items/testImage3.png",
                "generated_images": "https://ygrolpbmsuhcslizztvy.supabase.co/storage/v1/object/public/generated_images/M3_Cinematic_Realism_equirectangular-jpg_Photoreal_PBR_3D_scene_1706171275_14400628.jpg",
                "created_at": "2025-10-05 07:52:23.422968+00",
                "caption": "Watch",
                "likes": 0
            }
        ]
        
        print(f"📱 [BACKEND] Returning {len(hardcoded_posts)} real hardcoded posts")
        return hardcoded_posts
    except Exception as e:
        print(f"❌ [BACKEND] Error getting posts: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))
        

@router.post("/create-post")
async def create_post(request: Post):
    """Create a post"""
    try:
        result = await create_post_empty(request)
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.put("/update-post")
async def update_post(request: Post):
    """Update a post"""
    try:
        result = await update_post_util(request)
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
