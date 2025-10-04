from __future__ import annotations

import httpx
from typing import Optional, Dict, Any
from .models import KiriCreateJobResponse, KiriStatusResponse, KiriModelZipResponse
from .core.config import settings
from .mock_config import mock_config
import logging

logger = logging.getLogger(__name__)


class KiriEngineClient:
    """Client for interacting with Kiri Engine API (mock or real)."""
    
    def __init__(self, api_key: str = None):
        self.api_key = api_key or mock_config.get_api_key()
        self.base_url = mock_config.get_api_url()
        self.headers = mock_config.get_headers()
        
        if mock_config.is_mock_mode():
            logger.info("🔧 Running in MOCK mode - no real API calls will be made")
        else:
            logger.info("🌐 Running in REAL mode - will make actual API calls")
    
    async def create_job(
        self, 
        video_url: str, 
        file_format: str = "usdz",
        model_quality: int = 0,  # 0=High, 1=Medium, 2=Low, 3=Ultra
        texture_quality: int = 0,  # 0=4K, 1=2K, 2=1K, 3=8K
        is_mask: int = 0,  # 0=Off, 1=On
        texture_smoothing: int = 0,  # 0=Off, 1=On
        additional_params: Optional[Dict[str, Any]] = None
    ) -> KiriCreateJobResponse:
        """
        Create a new video processing job with Kiri Engine.
        
        Args:
            video_url: URL of the video to process
            file_format: Output file format (default: usdz)
            model_quality: Model quality setting (0=High, 1=Medium, 2=Low, 3=Ultra)
            texture_quality: Texture quality setting (0=4K, 1=2K, 2=1K, 3=8K)
            is_mask: Auto Object Masking (0=Off, 1=On)
            texture_smoothing: Texture Smoothing (0=Off, 1=On)
            additional_params: Additional parameters to include
            
        Returns:
            KiriCreateJobResponse with job details
        """
        url = f"{self.base_url}/api/v1/open/photo/video"
        
        # Prepare form data
        form_data = {
            "fileFormat": file_format,
            "modelQuality": model_quality,
            "textureQuality": texture_quality,
            "isMask": is_mask,
            "textureSmoothing": texture_smoothing,
            "videoUrl": video_url
        }
        
        # Add additional parameters if provided
        if additional_params:
            form_data.update(additional_params)
        
        try:
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    url,
                    headers=self.headers,
                    data=form_data,
                    timeout=30.0
                )
                response.raise_for_status()
                
                result = response.json()
                logger.info(f"Successfully created Kiri job: {result}")
                
                return KiriCreateJobResponse(**result)
                
        except httpx.HTTPStatusError as e:
            logger.error(f"HTTP error creating Kiri job: {e.response.status_code} - {e.response.text}")
            raise Exception(f"Failed to create Kiri job: {e.response.status_code}")
        except httpx.RequestError as e:
            logger.error(f"Request error creating Kiri job: {e}")
            raise Exception(f"Failed to create Kiri job: {e}")
        except Exception as e:
            logger.error(f"Unexpected error creating Kiri job: {e}")
            raise
    
    async def get_job_status(self, serialize: str) -> KiriStatusResponse:
        """
        Get the status of a Kiri Engine job.
        
        Args:
            serialize: Job serialize parameter from create_job response
            
        Returns:
            KiriStatusResponse with current job status
        """
        url = f"{self.base_url}/api/v1/open/model/getStatus"
        params = {"serialize": serialize}
        
        try:
            async with httpx.AsyncClient() as client:
                response = await client.get(
                    url,
                    headers={"Authorization": f"Bearer {self.api_key}"},
                    params=params,
                    timeout=30.0
                )
                response.raise_for_status()
                
                result = response.json()
                logger.debug(f"Kiri job status response: {result}")
                
                return KiriStatusResponse(**result)
                
        except httpx.HTTPStatusError as e:
            logger.error(f"HTTP error getting Kiri job status: {e.response.status_code} - {e.response.text}")
            raise Exception(f"Failed to get Kiri job status: {e.response.status_code}")
        except httpx.RequestError as e:
            logger.error(f"Request error getting Kiri job status: {e}")
            raise Exception(f"Failed to get Kiri job status: {e}")
        except Exception as e:
            logger.error(f"Unexpected error getting Kiri job status: {e}")
            raise
    
    async def get_model_zip_url(self, serialize: str) -> KiriModelZipResponse:
        """
        Get the model zip download URL for a completed job.
        
        Args:
            serialize: Job serialize parameter from create_job response
            
        Returns:
            KiriModelZipResponse with model download URL
        """
        url = f"{self.base_url}/api/v1/open/model/getModelZip"
        params = {"serialize": serialize}
        
        try:
            async with httpx.AsyncClient() as client:
                response = await client.get(
                    url,
                    headers={"Authorization": f"Bearer {self.api_key}"},
                    params=params,
                    timeout=30.0
                )
                response.raise_for_status()
                
                result = response.json()
                logger.info(f"Successfully got model zip URL: {result}")
                
                return KiriModelZipResponse(**result)
                
        except httpx.HTTPStatusError as e:
            logger.error(f"HTTP error getting model zip URL: {e.response.status_code} - {e.response.text}")
            raise Exception(f"Failed to get model zip URL: {e.response.status_code}")
        except httpx.RequestError as e:
            logger.error(f"Request error getting model zip URL: {e}")
            raise Exception(f"Failed to get model zip URL: {e}")
        except Exception as e:
            logger.error(f"Unexpected error getting model zip URL: {e}")
            raise


# Global client instance
kiri_client = KiriEngineClient()
