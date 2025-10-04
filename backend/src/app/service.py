from __future__ import annotations

import asyncio
import time
import tempfile
import os
from typing import Optional
from .kiri_client import kiri_client
from .store import job_store
from .models import JobStatus
from .utils import (
    ExponentialBackoff, 
    download_file, 
    extract_usdz_from_zip, 
    cleanup_temp_files, 
    create_temp_directory, 
    cleanup_temp_directory,
    retry_with_backoff
)
import logging

logger = logging.getLogger(__name__)


def upload_usdz_placeholder(job_id: str, usdz_path: str) -> str:
    """
    Placeholder function for uploading USDZ to Supabase.
    TODO: Replace with actual Supabase upload implementation.
    
    Args:
        job_id: Job identifier
        usdz_path: Local path to USDZ file
        
    Returns:
        Fake URL for the uploaded USDZ file
    """
    # This is a placeholder - your teammate will implement the actual Supabase upload
    fake_url = f"https://fake-supabase-url.com/usdz/{job_id}.usdz"
    logger.info(f"Placeholder upload: {usdz_path} -> {fake_url}")
    return fake_url


def map_kiri_status_to_job_status(kiri_status: int) -> JobStatus:
    """
    Map Kiri Engine status codes to our job status enum.
    
    Args:
        kiri_status: Kiri Engine status code
        
    Returns:
        Corresponding JobStatus
    """
    status_mapping = {
        -1: JobStatus.UPLOADING,
        0: JobStatus.PROCESSING,
        1: JobStatus.FAILED,
        2: JobStatus.SUCCESS,
        3: JobStatus.QUEUED,
        4: JobStatus.EXPIRED
    }
    
    return status_mapping.get(kiri_status, JobStatus.PROCESSING)


async def process_job_completion(job_id: str, kiri_serialize: str) -> None:
    """
    Process a completed job by downloading and extracting the USDZ file.
    
    Args:
        job_id: Job identifier
        kiri_serialize: Kiri Engine serialize parameter
    """
    logger.info(f"Processing completion for job {job_id}")
    
    try:
        # Get the model zip URL from Kiri Engine
        zip_response = await retry_with_backoff(
            kiri_client.get_model_zip_url,
            kiri_serialize,
            max_retries=3
        )
        
        if not zip_response.success or not zip_response.data.get('modelUrl'):
            error_msg = "Failed to get model zip URL from Kiri Engine"
            logger.error(error_msg)
            job_store.update_job_status(job_id, JobStatus.FAILED, error=error_msg)
            return
        
        model_url = zip_response.data['modelUrl']
        logger.info(f"Got model URL: {model_url}")
        
        # Create temporary directory for processing
        temp_dir = create_temp_directory()
        zip_path = os.path.join(temp_dir, f"{job_id}.zip")
        
        try:
            # Download the ZIP file
            success = await download_file(model_url, zip_path, timeout=300.0)
            if not success:
                error_msg = "Failed to download model ZIP file"
                logger.error(error_msg)
                job_store.update_job_status(job_id, JobStatus.FAILED, error=error_msg)
                return
            
            # Extract USDZ from ZIP
            usdz_path = extract_usdz_from_zip(zip_path, temp_dir)
            if not usdz_path:
                error_msg = "Failed to extract USDZ file from ZIP"
                logger.error(error_msg)
                job_store.update_job_status(job_id, JobStatus.FAILED, error=error_msg)
                return
            
            # Upload USDZ (placeholder implementation)
            usdz_url = upload_usdz_placeholder(job_id, usdz_path)
            
            # Update job status to ready
            job_store.update_job_status(job_id, JobStatus.SUCCESS, usdz_url=usdz_url)
            logger.info(f"Job {job_id} completed successfully with USDZ URL: {usdz_url}")
            
        finally:
            # Clean up temporary files
            cleanup_temp_files(zip_path, usdz_path if 'usdz_path' in locals() else None)
            cleanup_temp_directory(temp_dir)
            
    except Exception as e:
        error_msg = f"Error processing job completion: {str(e)}"
        logger.error(error_msg)
        job_store.update_job_status(job_id, JobStatus.FAILED, error=error_msg)


async def poll_job_status(job_id: str, kiri_serialize: str, timeout_minutes: int = 45) -> None:
    """
    Poll Kiri Engine for job status with exponential backoff.
    
    Args:
        job_id: Job identifier
        kiri_serialize: Kiri Engine serialize parameter
        timeout_minutes: Maximum time to poll in minutes
    """
    logger.info(f"Starting polling for job {job_id}")
    
    backoff = ExponentialBackoff(initial_delay=2.0, max_delay=30.0)
    start_time = time.time()
    timeout_seconds = timeout_minutes * 60
    
    while True:
        try:
            # Check if we've exceeded the timeout
            elapsed_time = time.time() - start_time
            if elapsed_time > timeout_seconds:
                error_msg = f"Job polling timed out after {timeout_minutes} minutes"
                logger.error(error_msg)
                job_store.update_job_status(job_id, JobStatus.FAILED, error=error_msg)
                return
            
            # Get job status from Kiri Engine
            status_response = await retry_with_backoff(
                kiri_client.get_job_status,
                kiri_serialize,
                max_retries=3
            )
            
            if not status_response.success:
                error_msg = "Failed to get job status from Kiri Engine"
                logger.error(error_msg)
                job_store.update_job_status(job_id, JobStatus.FAILED, error=error_msg)
                return
            
            # Extract status from response
            kiri_status = status_response.data.get('status')
            if kiri_status is None:
                error_msg = "Invalid status response from Kiri Engine"
                logger.error(error_msg)
                job_store.update_job_status(job_id, JobStatus.FAILED, error=error_msg)
                return
            
            # Map to our job status
            job_status = map_kiri_status_to_job_status(kiri_status)
            logger.info(f"Job {job_id} status: {job_status} (Kiri status: {kiri_status})")
            
            # Update job status in store
            job_store.update_job_status(job_id, job_status)
            
            # Check if job is complete
            if job_status == JobStatus.SUCCESS:
                logger.info(f"Job {job_id} completed successfully, processing result...")
                await process_job_completion(job_id, kiri_serialize)
                return
            elif job_status in [JobStatus.FAILED, JobStatus.EXPIRED]:
                error_msg = f"Job failed with status: {job_status}"
                logger.error(error_msg)
                job_store.update_job_status(job_id, job_status, error=error_msg)
                return
            
            # Job is still in progress, wait before next poll
            delay = backoff.get_next_delay()
            logger.debug(f"Job {job_id} still processing, waiting {delay:.2f} seconds...")
            await asyncio.sleep(delay)
            
        except Exception as e:
            error_msg = f"Error polling job status: {str(e)}"
            logger.error(error_msg)
            job_store.update_job_status(job_id, JobStatus.FAILED, error=error_msg)
            return


async def start_job_polling(job_id: str, kiri_serialize: str) -> None:
    """
    Start background polling for a job.
    
    Args:
        job_id: Job identifier
        kiri_serialize: Kiri Engine serialize parameter
    """
    logger.info(f"Starting background polling for job {job_id}")
    
    # Start polling in a background task
    asyncio.create_task(poll_job_status(job_id, kiri_serialize))


async def cleanup_old_jobs() -> None:
    """
    Clean up old completed jobs from the store.
    This should be called periodically.
    """
    try:
        removed_count = job_store.cleanup_old_jobs(max_age_hours=24)
        if removed_count > 0:
            logger.info(f"Cleaned up {removed_count} old jobs")
    except Exception as e:
        logger.error(f"Error cleaning up old jobs: {e}")


async def get_job_statistics() -> dict:
    """
    Get statistics about jobs in the store.
    
    Returns:
        Dictionary with job statistics
    """
    try:
        all_jobs = job_store.get_all_jobs()
        total_jobs = len(all_jobs)
        
        status_counts = {}
        for job in all_jobs.values():
            status = job.status.value
            status_counts[status] = status_counts.get(status, 0) + 1
        
        return {
            "total_jobs": total_jobs,
            "status_counts": status_counts
        }
    except Exception as e:
        logger.error(f"Error getting job statistics: {e}")
        return {"error": str(e)}
