from __future__ import annotations

from fastapi import APIRouter, HTTPException, status
from typing import Optional
from ....models import ScanRequest, ScanResponse, JobStatusResponse, JobResultResponse, JobStatus
from ....kiri_client import kiri_client
from ....store import job_store
from ....service import start_job_polling
from ....utils import validate_video_url
import logging

logger = logging.getLogger(__name__)

router = APIRouter()


@router.post("/scan", response_model=ScanResponse, status_code=status.HTTP_201_CREATED)
async def create_scan_job(request: ScanRequest) -> ScanResponse:
    """
    Create a new video scan job with Kiri Engine.
    
    Args:
        request: Scan request containing video URL and parameters
        
    Returns:
        ScanResponse with job ID and initial status
        
    Raises:
        HTTPException: If request validation fails or job creation fails
    """
    try:
        # Validate video URL
        if not validate_video_url(request.videoUrl):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid video URL format"
            )
        
        # Create job with Kiri Engine
        logger.info(f"Creating Kiri job for video: {request.videoUrl}")
        
        kiri_response = await kiri_client.create_job(
            video_url=request.videoUrl,
            file_format=request.fileFormat,
            model_quality=request.modelQuality.value,  # Convert enum to int
            texture_quality=request.textureQuality.value,  # Convert enum to int
            is_mask=request.isMask,
            texture_smoothing=request.textureSmoothing,
            additional_params=request.additionalParams
        )
        
        if not kiri_response.success:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Failed to create Kiri job: {kiri_response.message}"
            )
        
        # Extract serialize parameter from response
        kiri_serialize = kiri_response.data.get('serialize')
        if not kiri_serialize:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Invalid response from Kiri Engine: missing serialize parameter"
            )
        
        # Create job in our store
        job_id = job_store.create_job(kiri_serialize)
        
        # Start background polling
        await start_job_polling(job_id, kiri_serialize)
        
        logger.info(f"Successfully created scan job: {job_id}")
        
        return ScanResponse(
            jobId=job_id,
            status=JobStatus.QUEUED
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Unexpected error creating scan job: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error while creating scan job"
        )


@router.get("/scan/{job_id}/status", response_model=JobStatusResponse)
async def get_job_status(job_id: str) -> JobStatusResponse:
    """
    Get the current status of a scan job.
    
    Args:
        job_id: Job identifier
        
    Returns:
        JobStatusResponse with current status and optional error
        
    Raises:
        HTTPException: If job not found
    """
    try:
        job = job_store.get_job(job_id)
        if not job:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Job not found"
            )
        
        return JobStatusResponse(
            jobId=job_id,
            status=job.status,
            error=job.error
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Unexpected error getting job status: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error while getting job status"
        )


@router.get("/scan/{job_id}/result", response_model=JobResultResponse)
async def get_job_result(job_id: str) -> JobResultResponse:
    """
    Get the result of a completed scan job.
    
    Args:
        job_id: Job identifier
        
    Returns:
        JobResultResponse with status and USDZ URL if ready
        
    Raises:
        HTTPException: If job not found or not ready
    """
    try:
        job = job_store.get_job(job_id)
        if not job:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Job not found"
            )
        
        # If job is ready, return the result
        if job.status == JobStatus.SUCCESS:
            if not job.usdzUrl:
                raise HTTPException(
                    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                    detail="Job completed but USDZ URL not available"
                )
            
            return JobResultResponse(
                jobId=job_id,
                status=JobStatus.SUCCESS,
                usdzUrl=job.usdzUrl
            )
        
        # If job failed, return error status
        if job.status in [JobStatus.FAILED, JobStatus.EXPIRED]:
            return JobResultResponse(
                jobId=job_id,
                status=job.status,
                usdzUrl=None
            )
        
        # Job is still processing, return current status
        return JobResultResponse(
            jobId=job_id,
            status=job.status,
            usdzUrl=None
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Unexpected error getting job result: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error while getting job result"
        )


@router.get("/scan/{job_id}/info")
async def get_job_info(job_id: str) -> dict:
    """
    Get detailed information about a job (for debugging/monitoring).
    
    Args:
        job_id: Job identifier
        
    Returns:
        Detailed job information
        
    Raises:
        HTTPException: If job not found
    """
    try:
        job = job_store.get_job(job_id)
        if not job:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Job not found"
            )
        
        return {
            "jobId": job.jobId,
            "status": job.status,
            "error": job.error,
            "usdzUrl": job.usdzUrl,
            "kiriSerialize": job.kiriSerialize,
            "created_at": job.created_at
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Unexpected error getting job info: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error while getting job info"
        )


@router.get("/stats")
async def get_job_statistics() -> dict:
    """
    Get statistics about all jobs in the system.
    
    Returns:
        Job statistics
    """
    try:
        from ....service import get_job_statistics
        return await get_job_statistics()
    except Exception as e:
        logger.error(f"Unexpected error getting job statistics: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error while getting job statistics"
        )
