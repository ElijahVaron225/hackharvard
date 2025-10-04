from __future__ import annotations

import asyncio
import random
import zipfile
import tempfile
import os
import shutil
from typing import Optional, Callable, Any
import httpx
import logging

logger = logging.getLogger(__name__)


class ExponentialBackoff:
    """Exponential backoff with jitter for retry operations."""
    
    def __init__(
        self, 
        initial_delay: float = 2.0, 
        max_delay: float = 30.0, 
        stable_delay: float = None,
        multiplier: float = 1.5,
        jitter: bool = True
    ):
        self.initial_delay = initial_delay
        self.max_delay = max_delay
        self.stable_delay = stable_delay
        self.multiplier = multiplier
        self.jitter = jitter
        self.current_delay = initial_delay
        self.has_reached_max = False
    
    def get_next_delay(self) -> float:
        """Get the next delay value."""
        # If we've reached max delay and have a stable delay, use that
        if self.has_reached_max and self.stable_delay is not None:
            delay = self.stable_delay
        else:
            delay = self.current_delay
        
        if self.jitter:
            # Add random jitter (±25% of the delay)
            jitter_range = delay * 0.25
            delay += random.uniform(-jitter_range, jitter_range)
        
        # Update for next call
        if not self.has_reached_max:
            self.current_delay = min(self.current_delay * self.multiplier, self.max_delay)
            if self.current_delay >= self.max_delay:
                self.has_reached_max = True
        
        return max(0, delay)
    
    def reset(self):
        """Reset the backoff to initial values."""
        self.current_delay = self.initial_delay
        self.has_reached_max = False


async def download_file(url: str, file_path: str, timeout: float = 300.0) -> bool:
    """
    Download a file from URL to local path.
    
    Args:
        url: URL to download from
        file_path: Local path to save the file
        timeout: Request timeout in seconds
        
    Returns:
        True if successful, False otherwise
    """
    try:
        async with httpx.AsyncClient() as client:
            async with client.stream('GET', url, timeout=timeout) as response:
                response.raise_for_status()
                
                with open(file_path, 'wb') as f:
                    async for chunk in response.aiter_bytes():
                        f.write(chunk)
                
                logger.info(f"Successfully downloaded file: {file_path}")
                return True
                
    except httpx.HTTPStatusError as e:
        logger.error(f"HTTP error downloading file: {e.response.status_code} - {e.response.text}")
        return False
    except httpx.RequestError as e:
        logger.error(f"Request error downloading file: {e}")
        return False
    except Exception as e:
        logger.error(f"Unexpected error downloading file: {e}")
        return False


def extract_usdz_from_zip(zip_path: str, output_dir: str) -> Optional[str]:
    """
    Extract USDZ file from a ZIP archive.
    
    Args:
        zip_path: Path to the ZIP file
        output_dir: Directory to extract to
        
    Returns:
        Path to the extracted USDZ file, or None if not found
    """
    try:
        with zipfile.ZipFile(zip_path, 'r') as zip_ref:
            # List all files in the ZIP
            file_list = zip_ref.namelist()
            logger.info(f"Files in ZIP: {file_list}")
            
            # Find USDZ file
            usdz_files = [f for f in file_list if f.lower().endswith('.usdz')]
            
            if not usdz_files:
                logger.error("No USDZ file found in ZIP archive")
                return None
            
            # Use the first USDZ file found
            usdz_file = usdz_files[0]
            logger.info(f"Found USDZ file: {usdz_file}")
            
            # Extract the USDZ file
            zip_ref.extract(usdz_file, output_dir)
            
            # Get the full path to the extracted file
            extracted_path = os.path.join(output_dir, usdz_file)
            
            # If the file was in a subdirectory, move it to the output directory
            if os.path.dirname(usdz_file):
                final_path = os.path.join(output_dir, os.path.basename(usdz_file))
                shutil.move(extracted_path, final_path)
                extracted_path = final_path
            
            logger.info(f"Successfully extracted USDZ file: {extracted_path}")
            return extracted_path
            
    except zipfile.BadZipFile:
        logger.error("Invalid ZIP file")
        return None
    except Exception as e:
        logger.error(f"Error extracting USDZ from ZIP: {e}")
        return None


def cleanup_temp_files(*file_paths: str) -> None:
    """
    Clean up temporary files.
    
    Args:
        *file_paths: Paths to files to remove
    """
    for file_path in file_paths:
        try:
            if os.path.exists(file_path):
                os.remove(file_path)
                logger.debug(f"Cleaned up temp file: {file_path}")
        except Exception as e:
            logger.warning(f"Failed to clean up temp file {file_path}: {e}")


def create_temp_directory() -> str:
    """
    Create a temporary directory for processing files.
    
    Returns:
        Path to the temporary directory
    """
    temp_dir = tempfile.mkdtemp(prefix="kiri_processing_")
    logger.debug(f"Created temp directory: {temp_dir}")
    return temp_dir


def cleanup_temp_directory(dir_path: str) -> None:
    """
    Clean up a temporary directory and all its contents.
    
    Args:
        dir_path: Path to the directory to remove
    """
    try:
        if os.path.exists(dir_path):
            shutil.rmtree(dir_path)
            logger.debug(f"Cleaned up temp directory: {dir_path}")
    except Exception as e:
        logger.warning(f"Failed to clean up temp directory {dir_path}: {e}")


async def retry_with_backoff(
    func: Callable[..., Any],
    *args,
    max_retries: int = 5,
    initial_delay: float = 2.0,
    max_delay: float = 30.0,
    **kwargs
) -> Any:
    """
    Retry a function with exponential backoff.
    
    Args:
        func: Function to retry
        *args: Positional arguments for the function
        max_retries: Maximum number of retries
        initial_delay: Initial delay between retries
        max_delay: Maximum delay between retries
        **kwargs: Keyword arguments for the function
        
    Returns:
        Result of the function call
        
    Raises:
        Exception: If all retries fail
    """
    backoff = ExponentialBackoff(initial_delay, max_delay)
    last_exception = None
    
    for attempt in range(max_retries + 1):
        try:
            if asyncio.iscoroutinefunction(func):
                return await func(*args, **kwargs)
            else:
                return func(*args, **kwargs)
        except Exception as e:
            last_exception = e
            logger.warning(f"Attempt {attempt + 1} failed: {e}")
            
            if attempt < max_retries:
                delay = backoff.get_next_delay()
                logger.info(f"Retrying in {delay:.2f} seconds...")
                await asyncio.sleep(delay)
            else:
                logger.error(f"All {max_retries + 1} attempts failed")
                break
    
    raise last_exception


def validate_video_url(url: str) -> bool:
    """
    Basic validation for video URLs.
    
    Args:
        url: URL to validate
        
    Returns:
        True if URL appears valid, False otherwise
    """
    if not url or not isinstance(url, str):
        return False
    
    # Check for basic URL structure
    if not (url.startswith('http://') or url.startswith('https://')):
        return False
    
    # Check for common video file extensions
    video_extensions = ['.mp4', '.mov', '.avi', '.mkv', '.webm', '.m4v']
    url_lower = url.lower()
    
    return any(url_lower.endswith(ext) for ext in video_extensions) or 'video' in url_lower
