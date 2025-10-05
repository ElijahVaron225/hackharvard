# prompts.py
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from app.api.v1.endpoints.skybox import generate_skybox
from app.api.v1.endpoints.gemini import chat_with_gemini

router = APIRouter(prefix="/prompts", tags=["prompts"])



class WorkflowRequest(BaseModel):
    request: str = Field(..., description="The user's request/prompt")
    post_id: str | None = Field(None, description="Post ID to update with generated URLs")

from typing import Union
from fastapi import Body, HTTPException

@router.post("/workflow", tags=["workflow"])
async def workflow(request: Union[str, dict] = Body(...)):
    # 👇 Added: unpack the user's text from either a raw string or common keys
    if isinstance(request, str):
        user_text = request
        post_id = None
    else:
        user_text = (
            request.get("prompt")
            or request.get("text")
            or request.get("message")
            or request.get("input")
            or request.get("query")
            or request.get("content")
        )
        post_id = request.get("post_id")
        if not isinstance(user_text, str) or not user_text.strip():
            raise HTTPException(
                status_code=422,
                detail="Send a JSON string or an object with one of: 'prompt', 'text', 'message', 'input', 'query', 'content'."
            )

    try:
        # Create a ChatRequest object from the unpacked text
        from app.api.v1.endpoints.gemini import ChatRequest
        chat_request = ChatRequest(message=user_text)
        
        # Get the prompt from Gemini
        gemini_response = chat_with_gemini(chat_request)
        
        # Extract the message from Gemini response and create SendPromptRequest
        prompt_text = gemini_response.get("message", user_text)
        send_prompt_request = SendPromptRequest(prompt=prompt_text, post_id=post_id)
        
        # Send the prompt for skybox generation
        result = await send_prompt(send_prompt_request)
        
        # If we have a post_id, also process any uploaded images
        if post_id:
            await process_uploaded_images_for_post(post_id)
        
        return result
    except Exception as e:
        print(f"💥 Error in workflow: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

    

class SendPromptRequest(BaseModel):
    prompt: str = Field(..., min_length=1)
    post_id: str | None = Field(None, description="Post ID to update with generated URLs")
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
            from app.utils.supabase import add_url_to_generated_images_bucket, add_url_to_thumbnails_bucket, update_post_urls
            
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
            
            # Update the posts table with the URLs if post_id is provided
            if request.post_id:
                print(f"📝 Updating post {request.post_id} with generated URLs")
                post_update_result = await update_post_urls(
                    post_id=request.post_id,
                    image_url=file_url,
                    thumbnail_url=thumb_url
                )
                extracted_data["post_update"] = post_update_result
                print(f"✅ Post update result: {post_update_result}")
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


@router.post("/launch-experience/{post_id}", tags=["experience"])
async def launch_experience_from_post(post_id: str):
    """
    Launch experience for an existing post.
    If the post already has generated content, return it.
    If not, generate new content and update the post.
    """
    try:
        # First, check if the post already has generated content
        from app.utils.supabase import get_client
        client = get_client()
        
        # Get the post data
        post_response = client.from_("posts").select("*").eq("id", post_id).execute()
        
        if not post_response.data:
            raise HTTPException(status_code=404, detail=f"Post {post_id} not found")
        
        post_data = post_response.data[0]
        
        # Check if post already has generated content
        if post_data.get("generated_images") and post_data.get("thumbnail_url"):
            print(f"✅ Post {post_id} already has generated content")
            return {
                "status": "success",
                "post_id": post_id,
                "file_url": post_data.get("generated_images"),
                "thumb_url": post_data.get("thumbnail_url"),
                "generation_id": post_data.get("generation_id"),
                "already_generated": True
            }
        
        # If no generated content, we need to generate it
        # For now, we'll need a prompt - this could be stored in the post or generated
        prompt = post_data.get("content") or post_data.get("title") or "Generate a skybox experience"
        
        print(f"🚀 Generating content for post {post_id} with prompt: {prompt}")
        
        # Use the existing workflow to generate content
        workflow_request = {
            "prompt": prompt,
            "post_id": post_id
        }
        
        result = await workflow(workflow_request)
        return result
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"💥 Error in launch-experience: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

async def process_uploaded_images_for_post(post_id: str):
    """
    Process any uploaded images for a specific post.
    This function checks if the post has uploaded images and processes them.
    """
    print(f"🔍 [WORKFLOW] Checking for uploaded images for post {post_id}")
    try:
        from app.utils.supabase import get_client
        client = get_client()
        print(f"🔍 [WORKFLOW] Supabase client created")
        
        # Get the post data to check for uploaded images
        print(f"🔍 [WORKFLOW] Fetching post data for {post_id}...")
        post_response = client.from_("posts").select("*").eq("id", post_id).execute()
        print(f"🔍 [WORKFLOW] Post response: {post_response}")
        
        if not post_response.data:
            print(f"⚠️ [WORKFLOW] Post {post_id} not found")
            return
        
        post_data = post_response.data[0]
        print(f"🔍 [WORKFLOW] Post data: {post_data}")
        
        # Check if there are any uploaded images that need processing
        # Look for fields that might contain uploaded image URLs
        uploaded_image_url = None
        
        # Check common fields where users might upload images
        if post_data.get("uploaded_image_url"):
            uploaded_image_url = post_data.get("uploaded_image_url")
            print(f"🔍 [WORKFLOW] Found uploaded_image_url: {uploaded_image_url}")
        elif post_data.get("image_url"):
            uploaded_image_url = post_data.get("image_url")
            print(f"🔍 [WORKFLOW] Found image_url: {uploaded_image_url}")
        elif post_data.get("user_uploaded_image"):
            uploaded_image_url = post_data.get("user_uploaded_image")
            print(f"🔍 [WORKFLOW] Found user_uploaded_image: {uploaded_image_url}")
        
        if uploaded_image_url:
            print(f"🖼️ [WORKFLOW] Processing uploaded image for post {post_id}: {uploaded_image_url}")
            
            # Import the image processing function
            from app.utils.image_processing import remove_background_and_add_white_bg
            from app.utils.supabase import add_processed_image_to_bucket, update_post_user_scanned_item
            import uuid
            
            try:
                # Process the image
                print(f"🖼️ [WORKFLOW] Starting Remove.bg processing...")
                processed_image_data = await remove_background_and_add_white_bg(uploaded_image_url)
                print(f"✅ [WORKFLOW] Remove.bg processing completed")
                
                # Generate a unique filename for the processed image
                file_name = f"processed_heirloom_{post_id}_{uuid.uuid4()}.png"
                print(f"📝 [WORKFLOW] Generated filename: {file_name}")
                
                # Upload the processed image to Supabase
                print(f"📤 [WORKFLOW] Uploading to Supabase...")
                upload_result = await add_processed_image_to_bucket(processed_image_data, file_name)
                print(f"📤 [WORKFLOW] Upload result: {upload_result}")
                
                if upload_result["success"]:
                    processed_image_public_url = upload_result["public_url"]
                    print(f"🔗 [WORKFLOW] Processed image URL: {processed_image_public_url}")
                    
                    # Update the post with the processed image URL
                    print(f"💾 [WORKFLOW] Updating database...")
                    update_result = await update_post_user_scanned_item(post_id, processed_image_public_url)
                    print(f"💾 [WORKFLOW] Database update result: {update_result}")
                    
                    if update_result["success"]:
                        print(f"✅ [WORKFLOW] Successfully processed and uploaded image for post {post_id}")
                    else:
                        print(f"⚠️ [WORKFLOW] Failed to update post {post_id} with processed image URL: {update_result['error']}")
                else:
                    print(f"❌ [WORKFLOW] Failed to upload processed image: {upload_result['error']}")
                    
            except Exception as e:
                print(f"❌ [WORKFLOW] Error processing image for post {post_id}: {str(e)}")
        else:
            print(f"ℹ️ [WORKFLOW] No uploaded images found for post {post_id}")
            
    except Exception as e:
        print(f"❌ [WORKFLOW] Error in process_uploaded_images_for_post: {str(e)}")



