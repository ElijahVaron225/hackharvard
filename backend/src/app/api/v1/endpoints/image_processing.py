"""
Image processing endpoints for background removal and white background replacement.
"""
from fastapi import APIRouter, HTTPException, UploadFile, File, Form
from pydantic import BaseModel, Field
from app.utils.image_processing import remove_background_and_add_white_bg, get_remaining_credits
from app.utils.supabase import add_processed_image_to_bucket, update_post_user_scanned_item
from typing import Optional
import os
import uuid
import httpx

router = APIRouter(prefix="/image-processing", tags=["image-processing"])

class ProcessImageRequest(BaseModel):
    image_url: str = Field(..., description="URL of the image to process")
    post_id: Optional[str] = Field(None, description="Post ID to update with processed image URL")

class ProcessImageResponse(BaseModel):
    success: bool
    processed_image_url: Optional[str] = None
    error: Optional[str] = None
    post_id: str

@router.post("/process-heirloom")
async def process_heirloom_image(request: ProcessImageRequest):
    """
    Processes an heirloom image by removing its background and replacing it with white.
    Optionally updates a post's user_scanned_item field with the processed image URL.
    """
    try:
        # Process the image
        processed_image_data = await remove_background_and_add_white_bg(request.image_url)
        
        # Generate a unique filename for the processed image
        file_extension = "png"  # Remove.bg returns PNG
        file_name = f"processed_heirloom_{uuid.uuid4()}.{file_extension}"
        
        # Upload the processed image to Supabase
        upload_result = await add_processed_image_to_bucket(processed_image_data, file_name)
        
        if not upload_result["success"]:
            raise HTTPException(status_code=500, detail=f"Failed to upload processed image to Supabase: {upload_result['error']}")
        
        processed_image_public_url = upload_result["public_url"]
        
        # If post_id is provided, update the post
        if request.post_id:
            update_result = await update_post_user_scanned_item(request.post_id, processed_image_public_url)
            if not update_result["success"]:
                # Log error but don't fail the entire request if image was uploaded
                print(f"⚠️ Failed to update post {request.post_id} with processed image URL: {update_result['error']}")
        
        return ProcessImageResponse(
            success=True,
            processed_image_url=processed_image_public_url,
            post_id=request.post_id or "unknown"
        )
    except HTTPException:
        raise  # Re-raise HTTPExceptions
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

@router.post("/process-uploaded-image")
async def process_uploaded_image(
    file: UploadFile = File(...),
    post_id: Optional[str] = Form(None)
):
    """
    Process an uploaded image file by removing background and adding white background.
    This endpoint accepts direct file uploads.
    """
    try:
        # Validate file type
        if not file.content_type or not file.content_type.startswith('image/'):
            raise HTTPException(status_code=400, detail="File must be an image")
        
        # Read the uploaded file
        file_content = await file.read()
        
        # Upload the original image to a temporary location first
        temp_filename = f"temp_upload_{uuid.uuid4()}.{file.filename.split('.')[-1]}"
        temp_upload_result = await add_processed_image_to_bucket(file_content, temp_filename)
        
        if not temp_upload_result["success"]:
            raise HTTPException(status_code=500, detail=f"Failed to upload original image: {temp_upload_result['error']}")
        
        temp_image_url = temp_upload_result["public_url"]
        
        # Process the image through Remove.bg
        processed_image_data = await remove_background_and_add_white_bg(temp_image_url)
        
        # Generate final filename for processed image
        processed_filename = f"processed_heirloom_{uuid.uuid4()}.png"
        
        # Upload the processed image
        final_upload_result = await add_processed_image_to_bucket(processed_image_data, processed_filename)
        
        if not final_upload_result["success"]:
            raise HTTPException(status_code=500, detail=f"Failed to upload processed image: {final_upload_result['error']}")
        
        processed_image_public_url = final_upload_result["public_url"]
        
        # Update post if post_id provided
        if post_id:
            update_result = await update_post_user_scanned_item(post_id, processed_image_public_url)
            if not update_result["success"]:
                print(f"⚠️ Failed to update post {post_id} with processed image URL: {update_result['error']}")
        
        return ProcessImageResponse(
            success=True,
            processed_image_url=processed_image_public_url,
            post_id=post_id or "unknown"
        )
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

@router.post("/process-for-post/{post_id}")
async def process_image_for_post(
    post_id: str,
    image_url: str = Form(...)
):
    """
    Process an image for a specific post by removing background and adding white background.
    This endpoint is specifically designed to work with post IDs.
    """
    print(f"🚀 [API] Starting image processing for post {post_id}")
    print(f"🚀 [API] Image URL: {image_url}")
    try:
        # Process the image
        print(f"🖼️ [API] Calling Remove.bg API...")
        processed_image_data = await remove_background_and_add_white_bg(image_url)
        print(f"✅ [API] Remove.bg processing completed")
        
        # Generate a unique filename for the processed image
        file_name = f"processed_heirloom_{post_id}_{uuid.uuid4()}.png"
        print(f"📝 [API] Generated filename: {file_name}")
        
        # Upload the processed image to Supabase
        print(f"📤 [API] Uploading to Supabase...")
        upload_result = await add_processed_image_to_bucket(processed_image_data, file_name)
        print(f"📤 [API] Upload result: {upload_result}")
        
        if not upload_result["success"]:
            print(f"❌ [API] Upload failed: {upload_result['error']}")
            raise HTTPException(status_code=500, detail=f"Failed to upload processed image: {upload_result['error']}")
        
        processed_image_public_url = upload_result["public_url"]
        print(f"🔗 [API] Processed image URL: {processed_image_public_url}")
        
        # Update the post with the processed image URL
        print(f"💾 [API] Updating database...")
        update_result = await update_post_user_scanned_item(post_id, processed_image_public_url)
        print(f"💾 [API] Database update result: {update_result}")
        
        if not update_result["success"]:
            # Log error but don't fail the entire request if image was uploaded
            print(f"⚠️ [API] Failed to update post {post_id} with processed image URL: {update_result['error']}")
        else:
            print(f"✅ [API] Database update successful!")
        
        result = ProcessImageResponse(
            success=True,
            processed_image_url=processed_image_public_url,
            post_id=post_id
        )
        print(f"🎉 [API] Complete pipeline successful: {result}")
        return result
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ [API] Pipeline failed: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

@router.get("/verify-post/{post_id}")
async def verify_post_processed_image(post_id: str):
    """
    Verify that a post has been updated with a processed image URL.
    """
    try:
        from app.utils.supabase import get_client
        client = get_client()
        
        print(f"🔍 [VERIFY] Checking post {post_id} for processed image...")
        
        # Get the post data
        post_response = client.from_("posts").select("*").eq("id", post_id).execute()
        
        if not post_response.data:
            print(f"❌ [VERIFY] Post {post_id} not found")
            return {"success": False, "error": f"Post {post_id} not found"}
        
        post_data = post_response.data[0]
        print(f"🔍 [VERIFY] Post data: {post_data}")
        
        user_scanned_item = post_data.get("user_scanned_item")
        
        if user_scanned_item:
            print(f"✅ [VERIFY] Post {post_id} has processed image: {user_scanned_item}")
            return {
                "success": True,
                "post_id": post_id,
                "user_scanned_item": user_scanned_item,
                "has_processed_image": True
            }
        else:
            print(f"⚠️ [VERIFY] Post {post_id} has no processed image")
            return {
                "success": True,
                "post_id": post_id,
                "user_scanned_item": None,
                "has_processed_image": False
            }
            
    except Exception as e:
        print(f"❌ [VERIFY] Error verifying post: {str(e)}")
        return {"success": False, "error": str(e)}

@router.get("/credits")
async def get_credits():
    """
    Returns the remaining Remove.bg API credits.
    """
    try:
        credits = await get_remaining_credits()
        return {"status": "success", "remaining_credits": credits}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to retrieve credits: {str(e)}")