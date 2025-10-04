# Import the supabase creds from the config
import time
import httpx
from app.core.config import settings
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
                file_name = f"thumbnail_{int(time.time())}.jpg"
        
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




