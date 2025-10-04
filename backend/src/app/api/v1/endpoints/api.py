# prompts.py
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from app.api.v1.endpoints.skybox import generate_skybox
from app.api.v1.endpoints.gemini import chat_with_gemini

router = APIRouter(prefix="/prompts", tags=["prompts"])



@router.post("/workflow", tags=["workflow"])
async def workflow(request):
    try:
        prompt = chat_with_gemini(request)
        send_prompt = await send_prompt(prompt)
        return send_prompt
    except Exception as e:
        print(f"💥 Error in workflow: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))
    

class SendPromptRequest(BaseModel):
    prompt: str = Field(..., min_length=1)
    metadata: dict | None = None

@router.post("/send-prompt", tags=["prompts"])
async def send_prompt(request: SendPromptRequest):
    try:    
        print(f"🚀 Starting send-prompt for: '{request.prompt}'")
        
        # Step 1: Generate skybox (returns immediately with pending status)
        response = await generate_skybox(request)
        print(f"📝 Initial generation response: {response}")
        
        # Extract pusher info for waiting
        generation_id = response.get("id")
        pusher_channel = response.get("pusher_channel")
        pusher_event = response.get("pusher_event", "status_update")
        
        if not pusher_channel:
            raise HTTPException(
                status_code=500,
                detail="No pusher channel received from skybox generation"
            )
        
        print(f"⏳ Waiting for completion via Pusher channel: {pusher_channel}")
        
        # Step 2: Wait for completion via Pusher webhook
        from app.api.v1.endpoints.skybox import wait_for_completion, PusherWaitRequest
        
        pusher_request = PusherWaitRequest(
            pusher_channel=pusher_channel,
            pusher_event=pusher_event
        )
        
        # Wait for the generation to complete
        completed_response = await wait_for_completion(pusher_request)
        print(f"✅ Generation completed! Response: {completed_response}")
        
        # Extract URLs from completed response
        file_url = completed_response.get("file_url")
        thumb_url = completed_response.get("thumb_url")
        
        extracted_data = {
            "status": "success",
            "prompt": request.prompt,
            "file_url": file_url,                      # Full size generated image URL
            "thumb_url": thumb_url,                    # Thumbnail image URL
            "generation_id": generation_id,            # Generation ID for tracking
            "generation_status": completed_response.get("status") # Should be "complete"
        }
        
        # Upload to Supabase now that we have the URLs
        if file_url and thumb_url and generation_id:
            # Import here to avoid circular imports
            from app.utils.supabase import add_url_to_generated_images_bucket, add_url_to_thumbnails_bucket
            
            print(f"📤 Uploading skybox {generation_id} to Supabase - file_url: {file_url}")
            
            # Upload full image to generated_images bucket
            generated_result = await add_url_to_generated_images_bucket(
                url=file_url, 
                file_name=f"skybox_{generation_id}.jpg"
            )
            extracted_data["supabase_generated"] = generated_result
            print(f"✅ Generated image upload result: {generated_result}")
            
            # Upload thumbnail to thumbnails bucket
            thumb_result = await add_url_to_thumbnails_bucket(
                url=thumb_url, 
                file_name=f"skybox_thumb_{generation_id}.jpg"
            )
            extracted_data["supabase_thumbnail"] = thumb_result
            print(f"✅ Thumbnail upload result: {thumb_result}")
        else:
            print(f"❌ Missing URLs after completion - file_url: {file_url}, thumb_url: {thumb_url}")
            raise HTTPException(
                status_code=500,
                detail="Generation completed but URLs are missing"
            )
        
        print(f"🎉 Send-prompt completed successfully!")
        return extracted_data
        
    except HTTPException:
        # Re-raise HTTPExceptions as-is
        raise
    except Exception as e:
        print(f"💥 Error in send-prompt: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))



