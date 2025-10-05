"""
Utility functions for image processing, specifically background removal and adding a white background.
Integrates with the Remove.bg API.
"""
import httpx
from PIL import Image
from io import BytesIO
from app.core.config import settings
from fastapi import HTTPException
import logging

logger = logging.getLogger(__name__)

async def _remove_background(image_url: str) -> bytes:
    """
    Removes the background from an image using the Remove.bg API.
    Returns the processed image data as bytes (PNG format with transparency).
    """
    if not settings.REMOVE_BG_KEY:
        raise ValueError("REMOVE_BG_KEY is not set in environment variables")

    headers = {
        "X-Api-Key": settings.REMOVE_BG_KEY,
    }
    data = {
        "image_url": image_url,
        "size": "auto",
        "format": "png",
        "bg_color": "white"  # Request white background directly from Remove.bg
    }

    async with httpx.AsyncClient() as client:
        response = await client.post(
            "https://api.remove.bg/v1.0/removebg",
            headers=headers,
            data=data,
            timeout=60.0
        )
        response.raise_for_status()  # Raise an exception for 4xx or 5xx status codes
        return response.content

async def remove_background_and_add_white_bg(image_url: str) -> bytes:
    """
    Removes the background from an image and ensures it has a solid white background.
    This function now primarily relies on Remove.bg's bg_color parameter.
    """
    print(f"🖼️ [IMAGE_PROCESSING] Starting background removal for: {image_url}")
    logger.info(f"Processing image for background removal and white background: {image_url}")
    try:
        processed_image_data = await _remove_background(image_url)
        print(f"✅ [IMAGE_PROCESSING] Background removal successful, data size: {len(processed_image_data)} bytes")
        logger.info("Background removed and white background applied by Remove.bg API.")
        return processed_image_data
    except httpx.HTTPStatusError as e:
        print(f"❌ [IMAGE_PROCESSING] HTTP error: {e.response.status_code} - {e.response.text}")
        logger.error(f"HTTP error during background removal: {e.response.status_code} - {e.response.text}")
        raise HTTPException(status_code=e.response.status_code, detail=f"Remove.bg API error: {e.response.text}")
    except Exception as e:
        print(f"❌ [IMAGE_PROCESSING] Error: {str(e)}")
        logger.error(f"Error during image processing: {e}")
        raise HTTPException(status_code=500, detail=f"Image processing failed: {str(e)}")

async def get_remaining_credits() -> int:
    """
    Fetches the remaining Remove.bg API credits.
    """
    if not settings.REMOVE_BG_KEY:
        return 0  # Or raise an error, depending on desired behavior

    headers = {
        "X-Api-Key": settings.REMOVE_BG_KEY,
    }

    async with httpx.AsyncClient() as client:
        response = await client.get(
            "https://api.remove.bg/v1.0/account",
            headers=headers,
            timeout=10.0
        )
        response.raise_for_status()
        data = response.json()
        return data.get("data", {}).get("attributes", {}).get("credits", 0)