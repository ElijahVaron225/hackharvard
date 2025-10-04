from __future__ import annotations

import time
import uuid
from typing import Dict, Optional
from threading import Lock
from .models import JobStatus, KiriJobData
import logging

logger = logging.getLogger(__name__)


class JobStore:
    """In-memory store for tracking Kiri Engine jobs."""
    
    def __init__(self):
        self._jobs: Dict[str, KiriJobData] = {}
        self._lock = Lock()
    
    def create_job(self, kiri_serialize: str) -> str:
        """
        Create a new job entry in the store.
        
        Args:
            kiri_serialize: Kiri Engine serialize parameter
            
        Returns:
            Unique job ID
        """
        job_id = str(uuid.uuid4())
        
        with self._lock:
            self._jobs[job_id] = KiriJobData(
                jobId=job_id,
                status=JobStatus.QUEUED,
                kiriSerialize=kiri_serialize,
                created_at=time.time()
            )
        
        logger.info(f"Created new job: {job_id}")
        return job_id
    
    def get_job(self, job_id: str) -> Optional[KiriJobData]:
        """
        Get job data by ID.
        
        Args:
            job_id: Job identifier
            
        Returns:
            Job data or None if not found
        """
        with self._lock:
            return self._jobs.get(job_id)
    
    def update_job_status(
        self, 
        job_id: str, 
        status: JobStatus, 
        error: Optional[str] = None,
        usdz_url: Optional[str] = None
    ) -> bool:
        """
        Update job status and related fields.
        
        Args:
            job_id: Job identifier
            status: New status
            error: Error message if applicable
            usdz_url: USDZ file URL if ready
            
        Returns:
            True if job was updated, False if not found
        """
        with self._lock:
            if job_id not in self._jobs:
                logger.warning(f"Job not found for status update: {job_id}")
                return False
            
            job = self._jobs[job_id]
            job.status = status
            
            if error is not None:
                job.error = error
            
            if usdz_url is not None:
                job.usdzUrl = usdz_url
            
            logger.info(f"Updated job {job_id} status to {status}")
            return True
    
    def get_job_status(self, job_id: str) -> Optional[JobStatus]:
        """
        Get current job status.
        
        Args:
            job_id: Job identifier
            
        Returns:
            Job status or None if not found
        """
        job = self.get_job(job_id)
        return job.status if job else None
    
    def is_job_ready(self, job_id: str) -> bool:
        """
        Check if job is ready (status is SUCCESS).
        
        Args:
            job_id: Job identifier
            
        Returns:
            True if job is ready, False otherwise
        """
        status = self.get_job_status(job_id)
        return status == JobStatus.SUCCESS
    
    def is_job_failed(self, job_id: str) -> bool:
        """
        Check if job has failed.
        
        Args:
            job_id: Job identifier
            
        Returns:
            True if job failed, False otherwise
        """
        status = self.get_job_status(job_id)
        return status in [JobStatus.FAILED, JobStatus.EXPIRED]
    
    def get_job_result(self, job_id: str) -> Optional[KiriJobData]:
        """
        Get job result if ready.
        
        Args:
            job_id: Job identifier
            
        Returns:
            Job data if ready, None otherwise
        """
        job = self.get_job(job_id)
        if job and job.status == JobStatus.SUCCESS:
            return job
        return None
    
    def cleanup_old_jobs(self, max_age_hours: int = 24) -> int:
        """
        Remove old completed jobs from the store.
        
        Args:
            max_age_hours: Maximum age in hours for completed jobs
            
        Returns:
            Number of jobs removed
        """
        current_time = time.time()
        max_age_seconds = max_age_hours * 3600
        removed_count = 0
        
        with self._lock:
            jobs_to_remove = []
            
            for job_id, job in self._jobs.items():
                if (job.status in [JobStatus.SUCCESS, JobStatus.FAILED, JobStatus.EXPIRED] and
                    current_time - job.created_at > max_age_seconds):
                    jobs_to_remove.append(job_id)
            
            for job_id in jobs_to_remove:
                del self._jobs[job_id]
                removed_count += 1
        
        if removed_count > 0:
            logger.info(f"Cleaned up {removed_count} old jobs")
        
        return removed_count
    
    def get_all_jobs(self) -> Dict[str, KiriJobData]:
        """
        Get all jobs (for debugging/monitoring).
        
        Returns:
            Dictionary of all jobs
        """
        with self._lock:
            return self._jobs.copy()
    
    def get_job_count(self) -> int:
        """
        Get total number of jobs in store.
        
        Returns:
            Number of jobs
        """
        with self._lock:
            return len(self._jobs)


# Global store instance
job_store = JobStore()
