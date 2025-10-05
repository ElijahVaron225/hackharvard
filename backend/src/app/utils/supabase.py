# Import the supabase creds from the config
import time
import uuid
import httpx
from app.core.config import settings
from app.models import Post
from supabase import create_client, Client
from typing import List, Dict, Any

# Create a function to return supabase client
def get_client() -> Client:
    print(f"DEBUG: SUPABASE_URL = {settings.SUPABASE_URL}")
    print(f"DEBUG: SUPABASE_KEY = {settings.SUPABASE_KEY}")
    
    if not settings.SUPABASE_URL:
        raise ValueError("SUPABASE_URL is not set in environment variables")
    if not settings.SUPABASE_KEY:
        raise ValueError("SUPABASE_KEY is not set in environment variables")
    
    supabase: Client = create_client(settings.SUPABASE_URL, settings.SUPABASE_KEY)
    return supabase

def list_buckets() -> List[Dict[str, Any]]:
    """List all storage buckets in Supabase"""
    try:
        client = get_client()
        response = client.storage.list_buckets()
        return response
    except Exception as e:
        print(f"Error listing buckets: {e}")
        return []

async def add_url_to_generated_images_bucket(url: str, file_name: str = None) -> Dict[str, Any]:
    """
    Add a URL to the generated_images bucket
    """
    try:
        client = get_client()
        
        # If no file_name provided, extract from URL or use timestamp
        if not file_name:
            # Try to extract filename from URL, fallback to timestamp
            url_parts = url.split('/')
            if url_parts and '.' in url_parts[-1]:
                file_name = url_parts[-1]
            else:
                file_name = f"image_{int(time.time())}.jpg"
        
        # Download the content from the URL
        async with httpx.AsyncClient() as http_client:
            response = await http_client.get(url)
            response.raise_for_status()
            file_content = response.content
        
        # Upload the file content to the bucket
        upload_response = client.storage.from_("generated_images").upload(
            path=file_name,
            file=file_content,
            file_options={"content-type": "image/jpeg"}
        )
        
        return {
            "success": True,
            "bucket": "generated_images",
            "file_name": file_name,
            "url": url,
            "response": upload_response
        }
    except Exception as e:
        return {
            "success": False,
            "error": str(e),
            "bucket": "generated_images"
        }

async def add_url_to_thumbnails_bucket(url: str, file_name: str = None) -> Dict[str, Any]:
    """
    Add a URL to the thumbnails bucket
    """
    try:
        client = get_client()
        
        # If no file_name provided, extract from URL or use timestamp
        if not file_name:
            # Try to extract filename from URL, fallback to timestamp
            url_parts = url.split('/')
            if url_parts and '.' in url_parts[-1]:
                file_name = url_parts[-1]
            else:
                file_name = f"image_{int(time.time())}.jpg"
        
        # Download the content from the URL
        async with httpx.AsyncClient() as http_client:
            response = await http_client.get(url)
            response.raise_for_status()
            file_content = response.content
        
        # Upload the file content to the bucket
        upload_response = client.storage.from_("thumbnails").upload(
            path=file_name,
            file=file_content,
            file_options={"content-type": "image/jpeg"}
        )
        
        return {
            "success": True,
            "bucket": "thumbnails",
            "file_name": file_name,
            "url": url,
            "response": upload_response
        }
    except Exception as e:
        return {
            "success": False,
            "error": str(e),
            "bucket": "thumbnails"
        }

def list_thumbnails() -> Dict[str, Any]:
    """
    List all files in the thumbnails bucket
    """
    try:
        client = get_client()
        
        # List all files in the thumbnails bucket
        files_response = client.storage.from_("thumbnails").list()
        
        # Get public URLs for each file
        thumbnails = []
        for file_info in files_response:
            if file_info.get('name'):  # Make sure it's a file, not a folder
                # Get the public URL for the file
                public_url = client.storage.from_("thumbnails").get_public_url(file_info['name'])
                
                thumbnails.append({
                    "file_name": file_info['name'],
                    "public_url": public_url,
                    "size": file_info.get('metadata', {}).get('size'),
                    "created_at": file_info.get('created_at'),
                    "updated_at": file_info.get('updated_at')
                })
        
        return {
            "success": True,
            "bucket": "thumbnails",
            "count": len(thumbnails),
            "thumbnails": thumbnails
        }
    except Exception as e:
        return {
            "success": False,
            "error": str(e),
            "bucket": "thumbnails"
        }


def list_generated_images() -> Dict[str, Any]:
    """
    List all files in the generated_images bucket
    """
    try:
        client = get_client()
        
        # List all files in the generated_images bucket
        files_response = client.storage.from_("generated_images").list()
        
        # Get public URLs for each file
        generated_images = []
        for file_info in files_response:
            if file_info.get('name'):  # Make sure it's a file, not a folder
                # Get the public URL for the file
                public_url = client.storage.from_("generated_images").get_public_url(file_info['name'])
                
                generated_images.append({
                    "file_name": file_info['name'],
                    "public_url": public_url,
                    "size": file_info.get('metadata', {}).get('size'),
                    "created_at": file_info.get('created_at'),
                    "updated_at": file_info.get('updated_at')
                })
        
        return {
            "success": True,
            "bucket": "generated_images",
            "count": len(generated_images),
            "generated_images": generated_images
        }
    except Exception as e:
        return {
            "success": False,
            "error": str(e),
            "bucket": "generated_images"
        }


def get_generated_image_url(file_name: str) -> Dict[str, Any]:
    """
    Get the public URL for a specific file in the generated_images bucket
    
    Args:
        file_name: Name of the file to get URL for
        
    Returns:
        Dictionary with success status and file information
    """
    try:
        client = get_client()
        
        # Check if file exists in the bucket
        files_response = client.storage.from_("generated_images").list()
        
        # Look for the specific file
        file_found = False
        file_info = None
        
        for file_data in files_response:
            if file_data.get('name') == file_name:
                file_found = True
                file_info = file_data
                break
        
        if not file_found:
            return {
                "success": False,
                "error": f"File '{file_name}' not found in generated_images bucket",
                "bucket": "generated_images"
            }
        
        # Get the public URL for the file
        public_url = client.storage.from_("generated_images").get_public_url(file_name)
        
        return {
            "success": True,
            "bucket": "generated_images",
            "file_name": file_name,
            "public_url": public_url,
            "size": file_info.get('metadata', {}).get('size'),
            "created_at": file_info.get('created_at'),
            "updated_at": file_info.get('updated_at')
        }
    except Exception as e:
        return {
            "success": False,
            "error": str(e),
            "bucket": "generated_images"
        }

async def create_post_empty(post: Post) -> Dict[str, Any]:
    """
    Create a post
    """
    try:
        print(f"DEBUG: Creating post: {post}")
        client = get_client()
        post_id = str(uuid.uuid4())
        response = client.from_("posts").insert({"id": post_id, "user_id": post.user_id}).execute()
        return {
            "success": True,
            "post_id": post_id,
            "response": response
        }
    except Exception as e:
        return {
            "success": False,
            "error": str(e),
            "bucket": "posts"
        }
        

async def get_posts() -> List[Dict[str, any]]:
    """Gets all posts"""
    try:
        client: Client = create_client(settings.SUPABASE_URL, settings.SUPABASE_KEY)
        response = client.table("posts").select("*").execute()

        return response.data
    except Exception as e:
        return []

async def update_post(post: Post) -> Dict[str, Any]:
    """
    Update a post
    """
    try:
        client = get_client()
        # Convert Post model to dict for update
        post_dict = post.model_dump(exclude_unset=True)
        response = client.from_("posts").update(post_dict).eq("id", post.id).execute()
        return {
            "success": True,
            "post_id": post.id,
            "response": response
        }
    except Exception as e:
        return {
            "success": False,
            "error": str(e),
            "post_id": post.id
        }


async def update_post_urls(post_id: str, image_url: str, thumbnail_url: str) -> Dict[str, Any]:
    """
    Update a post with generated image URLs
    """
    try:
        client = get_client()
        response = client.from_("posts").update({
            "generated_images": image_url,
            "thumbnail_url": thumbnail_url
        }).eq("id", post_id).execute()
        
        return {
            "success": True,
            "post_id": post_id,
            "generated_images": image_url,
            "thumbnail_url": thumbnail_url,
            "response": response
        }
    except Exception as e:
        return {
            "success": False,
            "error": str(e),
            "post_id": post_id
        }


async def add_usdz_to_bucket(usdz_file_path: str, file_name: str = None) -> Dict[str, Any]:
    """
    Upload a USDZ file to the user_scanned_items bucket
    
    Args:
        usdz_file_path: Local path to the USDZ file
        file_name: Optional custom filename for the USDZ file
        
    Returns:
        Dictionary with success status and file information
    """
    try:
        import os
        client = get_client()
        
        # If no file_name provided, use the filename from the path
        if not file_name:
            file_name = os.path.basename(usdz_file_path)
        
        # Read the USDZ file content
        with open(usdz_file_path, 'rb') as f:
            usdz_content = f.read()
        
        # Upload the USDZ file to the user_scanned_items bucket
        upload_response = client.storage.from_("user_scanned_items").upload(
            path=file_name,
            file=usdz_content,
            file_options={"content-type": "model/vnd.usdz+zip"}
        )
        
        # Get the public URL for the uploaded file
        public_url = client.storage.from_("user_scanned_items").get_public_url(file_name)
        
        return {
            "success": True,
            "bucket": "user_scanned_items",
            "file_name": file_name,
            "public_url": public_url,
            "response": upload_response
        }
    except Exception as e:
        return {
            "success": False,
            "error": str(e),
            "bucket": "user_scanned_items"
        }

async def add_processed_image_to_bucket(image_data: bytes, file_name: str) -> Dict[str, Any]:
    """
    Upload a processed image to the user_scanned_items bucket
    
    Args:
        image_data: Raw image data (bytes)
        file_name: Filename for the image
        
    Returns:
        Dictionary with success status and file information
    """
    print(f"📤 [SUPABASE] Uploading processed image to bucket: {file_name}")
    print(f"📤 [SUPABASE] Image data size: {len(image_data)} bytes")
    try:
        client = get_client()
        print(f"📤 [SUPABASE] Supabase client created successfully")
        
        # Upload the processed image to the user_scanned_items bucket
        print(f"📤 [SUPABASE] Starting upload to user_scanned_items bucket...")
        upload_response = client.storage.from_("user_scanned_items").upload(
            path=file_name,
            file=image_data,
            file_options={"content-type": "image/png"}
        )
        print(f"✅ [SUPABASE] Upload response: {upload_response}")
        
        # Get the public URL for the uploaded file
        public_url = client.storage.from_("user_scanned_items").get_public_url(file_name)
        print(f"🔗 [SUPABASE] Public URL generated: {public_url}")
        
        result = {
            "success": True,
            "bucket": "user_scanned_items",
            "file_name": file_name,
            "public_url": public_url,
            "response": upload_response
        }
        print(f"✅ [SUPABASE] Upload successful: {result}")
        return result
    except Exception as e:
        print(f"❌ [SUPABASE] Upload failed: {str(e)}")
        return {
            "success": False,
            "error": str(e),
            "bucket": "user_scanned_items"
        }

async def update_post_user_scanned_item(post_id: str, processed_image_url: str) -> Dict[str, Any]:
    """
    Update a post's user_scanned_item field with the processed image URL
    
    Args:
        post_id: ID of the post to update
        processed_image_url: URL of the processed image
        
    Returns:
        Dictionary with success status
    """
    print(f"💾 [DATABASE] Updating post {post_id} with processed image URL: {processed_image_url}")
    try:
        client = get_client()
        print(f"💾 [DATABASE] Supabase client created for database update")
        
        # First, let's check if the post exists
        print(f"💾 [DATABASE] Checking if post {post_id} exists...")
        check_response = client.from_("posts").select("id").eq("id", post_id).execute()
        print(f"💾 [DATABASE] Post check response: {check_response}")
        
        if not check_response.data:
            print(f"❌ [DATABASE] Post {post_id} not found in database")
            return {
                "success": False,
                "error": f"Post {post_id} not found",
                "post_id": post_id
            }
        
        print(f"✅ [DATABASE] Post {post_id} found, proceeding with update...")
        
        # Update the post
        response = client.from_("posts").update({
            "user_scanned_item": processed_image_url
        }).eq("id", post_id).execute()
        
        print(f"✅ [DATABASE] Update response: {response}")
        
        result = {
            "success": True,
            "post_id": post_id,
            "user_scanned_item": processed_image_url,
            "response": response
        }
        print(f"✅ [DATABASE] Database update successful: {result}")
        return result
    except Exception as e:
        print(f"❌ [DATABASE] Database update failed: {str(e)}")
        return {
            "success": False,
            "error": str(e),
            "post_id": post_id
        }
