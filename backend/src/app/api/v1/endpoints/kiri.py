import os
import httpx
import asyncio
import json
import threading
import time
from fastapi import APIRouter, HTTPException
from dotenv import load_dotenv
from pydantic import BaseModel
from typing import Optional
import logging

# Load .env file
load_dotenv()

router = APIRouter()
logger = logging.getLogger(__name__)

KIRI_ENGINE_KEY = os.getenv("KIRI_ENGINE_KEY")

class KiriEngineRequest(BaseModel):
    url: str

class KiriEngineResponse(BaseModel):
    code: int
    msg: str
    data: dict
    ok: bool

class KiriScanResponse(BaseModel):
    serialize: str
    calculateType: int
    status: str = "queued"

class KiriStatusResponse(BaseModel):
    serialize: str
    status: int
    message: str

class KiriPollingRequest(BaseModel):
    serialize: str

class KiriDownloadRequest(BaseModel):
    serialize: str
    postId: str = None  # Optional post ID for tagging

class KiriDownloadResponse(BaseModel):
    usdzUrl: str

@router.post("/scan", response_model=KiriScanResponse)
async def scan_user_object(request: KiriEngineRequest):
    """
    Upload a video to Kiri Engine for featureless object scanning.
    """
    try:
        # Validate API key
        if not KIRI_ENGINE_KEY:
            raise HTTPException(
                status_code=500, 
                detail="KIRI_ENGINE_KEY not configured"
            )
        # Download video from Supabase URL
        logger.info(f"Downloading video from: {request.url}")
        
        async with httpx.AsyncClient() as client:
            # Download the video file
            video_response = await client.get(request.url)
            video_response.raise_for_status()
            video_content = video_response.content
            
            # Prepare form data for Kiri Engine API
            files = {
                'videoFile': ('video.mp4', video_content, 'video/mp4')
            }
            
            data = {
                'fileFormat': 'usdz'
            }
            
            # Make request to Kiri Engine API
            kiri_url = "https://api.kiriengine.app/api/v1/open/featureless/video"
            headers = {
                'Authorization': f'Bearer {KIRI_ENGINE_KEY}'
            }
            
            logger.info(f"Submitting video to Kiri Engine: {kiri_url}")
            
            kiri_response = await client.post(
                kiri_url,
                headers=headers,
                files=files,
                data=data,
                timeout=60.0
            )
            
            kiri_response.raise_for_status()
            response_data = kiri_response.json()
            
            logger.info(f"Kiri Engine response: {response_data}")
            
            # Validate response
            if not response_data.get('ok'):
                raise HTTPException(
                    status_code=400,
                    detail=f"Kiri Engine error: {response_data.get('msg', 'Unknown error')}"
                )
            
            # Extract serialize and calculateType from response
            data_obj = response_data.get('data', {})
            serialize = data_obj.get('serialize')
            calculate_type = data_obj.get('calculateType')
            
            if not serialize:
                raise HTTPException(
                    status_code=500,
                    detail="No serialize ID returned from Kiri Engine"
                )
            
            logger.info(f"Successfully submitted scan job. Serialize: {serialize}")
            
            return KiriScanResponse(
                serialize=serialize,
                calculateType=calculate_type or 2,  # Default to 2 for featureless
                status="queued"
            )
            
    except httpx.HTTPStatusError as e:
        logger.error(f"HTTP error calling Kiri Engine: {e.response.status_code} - {e.response.text}")
        raise HTTPException(
            status_code=e.response.status_code,
            detail=f"Kiri Engine API error: {e.response.text}"
        )
    except httpx.RequestError as e:
        logger.error(f"Request error calling Kiri Engine: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to connect to Kiri Engine: {str(e)}"
        )
    except Exception as e:
        logger.error(f"Unexpected error in scan_user_object: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Internal server error: {str(e)}"
        )

@router.get("/status/{serialize}", response_model=KiriStatusResponse)
async def get_kiri_status(serialize: str):
    """
    Get current status of a Kiri Engine job.
    
    Status codes:
    -1: Uploading
    0: Processing  
    1: Failed
    2: Successful
    3: Queuing
    4: Expired
    """
    try:
        # Validate API key
        if not KIRI_ENGINE_KEY:
            raise HTTPException(
                status_code=500, 
                detail="KIRI_ENGINE_KEY not configured"
            )
        
        logger.info(f"Checking status for serialize: {serialize}")
        
        async with httpx.AsyncClient() as client:
            # Make GET request to check status
            status_url = f"https://api.kiriengine.app/api/v1/open/model/getStatus?serialize={serialize}"
            headers = {
                'Authorization': f'Bearer {KIRI_ENGINE_KEY}'
            }
            
            status_response = await client.get(
                status_url,
                headers=headers,
                timeout=30.0
            )
            
            status_response.raise_for_status()
            response_data = status_response.json()
            
            logger.info(f"Status response: {response_data}")
            
            # Validate response
            if not response_data.get('ok'):
                raise HTTPException(
                    status_code=400,
                    detail=f"Kiri Engine error: {response_data.get('msg', 'Unknown error')}"
                )
            
            # Extract status from response
            data_obj = response_data.get('data', {})
            status = data_obj.get('status')
            returned_serialize = data_obj.get('serialize')
            
            if status is None:
                raise HTTPException(
                    status_code=500,
                    detail="No status returned from Kiri Engine"
                )
            
            # Map status to message
            status_messages = {
                -1: "Uploading",
                0: "Processing",
                1: "Failed",
                2: "Successful", 
                3: "Queuing",
                4: "Expired"
            }
            
            message = status_messages.get(status, f"Unknown status: {status}")
            
            logger.info(f"Status for {returned_serialize}: {message} (status: {status})")
            
            return KiriStatusResponse(
                serialize=returned_serialize or serialize,
                status=status,
                message=message
            )
            
    except httpx.HTTPStatusError as e:
        logger.error(f"HTTP error checking status: {e.response.status_code} - {e.response.text}")
        raise HTTPException(
            status_code=e.response.status_code,
            detail=f"Kiri Engine API error: {e.response.text}"
        )
    except httpx.RequestError as e:
        logger.error(f"Request error checking status: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to connect to Kiri Engine: {str(e)}"
        )
    except Exception as e:
        logger.error(f"Unexpected error in get_kiri_status: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Internal server error: {str(e)}"
        )

@router.post("/download", response_model=KiriDownloadResponse)
async def download_and_save_usdz(request: KiriDownloadRequest):
    """
    Download the zipped 3D model, extract USDZ, and save to Supabase.
    """
    try:
        # Validate API key
        if not KIRI_ENGINE_KEY:
            raise HTTPException(
                status_code=500, 
                detail="KIRI_ENGINE_KEY not configured"
            )
        
        logger.info(f"Downloading model for serialize: {request.serialize}")
        
        async with httpx.AsyncClient() as client:
            # Get download URL from Kiri Engine
            download_url = f"https://api.kiriengine.app/api/v1/open/model/getModelZip?serialize={request.serialize}"
            headers = {
                'Authorization': f'Bearer {KIRI_ENGINE_KEY}'
            }
            
            # Get the download link
            response = await client.get(download_url, headers=headers, timeout=30.0)
            response.raise_for_status()
            response_data = response.json()
            
            logger.info(f"Download response: {response_data}")
            
            # Validate response
            if not response_data.get('ok'):
                raise HTTPException(
                    status_code=400,
                    detail=f"Kiri Engine error: {response_data.get('msg', 'Unknown error')}"
                )
            
            # Extract model URL
            data_obj = response_data.get('data', {})
            model_url = data_obj.get('modelUrl')
            
            if not model_url:
                raise HTTPException(
                    status_code=500,
                    detail="No model URL returned from Kiri Engine"
                )
            
            logger.info(f"Downloading model from: {model_url}")
            
            # Download the zipped model
            model_response = await client.get(model_url, timeout=300.0)
            model_response.raise_for_status()
            zip_content = model_response.content
            
            # Create temporary directory for processing
            import tempfile
            import zipfile
            import os
            
            with tempfile.TemporaryDirectory() as temp_dir:
                # Save zip file
                zip_path = os.path.join(temp_dir, f"{request.serialize}.zip")
                with open(zip_path, 'wb') as f:
                    f.write(zip_content)
                
                # Extract USDZ from zip
                usdz_file = None
                with zipfile.ZipFile(zip_path, 'r') as zip_ref:
                    for file_name in zip_ref.namelist():
                        if file_name.lower().endswith('.usdz'):
                            usdz_file = file_name
                            zip_ref.extract(file_name, temp_dir)
                            break
                
                if not usdz_file:
                    raise HTTPException(
                        status_code=500,
                        detail="No USDZ file found in the downloaded zip"
                    )
                
                usdz_path = os.path.join(temp_dir, usdz_file)
                
                # Upload to Supabase
                from app.utils.supabase import add_usdz_to_bucket
                
                # Generate filename
                if request.postId:
                    filename = f"{request.postId}_{request.serialize}.usdz"
                else:
                    filename = f"{request.serialize}.usdz"
                
                # Upload to user_scanned_items bucket
                upload_result = await add_usdz_to_bucket(usdz_path, filename)
                
                if not upload_result["success"]:
                    raise HTTPException(
                        status_code=500,
                        detail=f"Failed to upload to Supabase: {upload_result['error']}"
                    )
                
                usdz_url = upload_result["public_url"]
                
                logger.info(f"Successfully saved USDZ: {usdz_url}")
                
                return KiriDownloadResponse(
                    usdzUrl=usdz_url
                )
            
    except httpx.HTTPStatusError as e:
        logger.error(f"HTTP error downloading model: {e.response.status_code} - {e.response.text}")
        raise HTTPException(
            status_code=e.response.status_code,
            detail=f"Kiri Engine API error: {e.response.text}"
        )
    except httpx.RequestError as e:
        logger.error(f"Request error downloading model: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to connect to Kiri Engine: {str(e)}"
        )
    except Exception as e:
        logger.error(f"Unexpected error in download_and_save_usdz: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Internal server error: {str(e)}"
        )
