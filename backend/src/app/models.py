from __future__ import annotations

from enum import Enum
from typing import Optional
from pydantic import BaseModel, Field


class JobStatus(str, Enum):
    """Job status enumeration matching Kiri Engine API status codes."""
    UPLOADING = "uploading"      # -1
    PROCESSING = "processing"    # 0
    FAILED = "failed"           # 1
    SUCCESS = "success"         # 2
    QUEUED = "queued"           # 3
    EXPIRED = "expired"         # 4


class ModelQuality(int, Enum):
    """Model quality enumeration matching Kiri Engine API values."""
    HIGH = 0
    MEDIUM = 1
    LOW = 2
    ULTRA = 3


class TextureQuality(int, Enum):
    """Texture quality enumeration matching Kiri Engine API values."""
    FOUR_K = 0
    TWO_K = 1
    ONE_K = 2
    EIGHT_K = 3


class ScanRequest(BaseModel):
    """Request model for creating a new scan job."""
    videoUrl: str = Field(..., description="URL of the video to process")
    fileFormat: str = Field(default="usdz", description="Output file format")
    modelQuality: ModelQuality = Field(default=ModelQuality.HIGH, description="Model quality setting (0=High, 1=Medium, 2=Low, 3=Ultra)")
    textureQuality: TextureQuality = Field(default=TextureQuality.FOUR_K, description="Texture quality setting (0=4K, 1=2K, 2=1K, 3=8K)")
    isMask: Optional[int] = Field(default=0, description="Auto Object Masking (0=Off, 1=On)")
    textureSmoothing: Optional[int] = Field(default=0, description="Texture Smoothing (0=Off, 1=On)")
    additionalParams: Optional[dict] = Field(default_factory=dict, description="Additional parameters")


class ScanResponse(BaseModel):
    """Response model for scan job creation."""
    jobId: str = Field(..., description="Unique job identifier")
    status: JobStatus = Field(..., description="Current job status")


class JobStatusResponse(BaseModel):
    """Response model for job status queries."""
    jobId: str = Field(..., description="Unique job identifier")
    status: JobStatus = Field(..., description="Current job status")
    error: Optional[str] = Field(None, description="Error message if job failed")


class JobResultResponse(BaseModel):
    """Response model for job results."""
    jobId: str = Field(..., description="Unique job identifier")
    status: JobStatus = Field(..., description="Current job status")
    usdzUrl: Optional[str] = Field(None, description="URL to download the USDZ file")


class KiriJobData(BaseModel):
    """Internal model for storing job data in memory."""
    jobId: str
    status: JobStatus
    error: Optional[str] = None
    usdzUrl: Optional[str] = None
    kiriSerialize: Optional[str] = None  # Kiri Engine serialize parameter
    created_at: float  # Unix timestamp


class KiriCreateJobResponse(BaseModel):
    """Response model from Kiri Engine create job API."""
    data: dict
    message: str
    success: bool


class KiriStatusResponse(BaseModel):
    """Response model from Kiri Engine status API."""
    data: dict
    message: str
    success: bool


class KiriModelZipResponse(BaseModel):
    """Response model from Kiri Engine model zip API."""
    data: dict
    message: str
    success: bool


class Post(BaseModel):
    """Post model for storing user posts."""
    id: Optional[str] = Field(None, description="Unique post identifier")
    user_id: str = Field(..., description="ID of the user who created the post")
    title: Optional[str] = Field(None, description="Post title")
    content: Optional[str] = Field(None, description="Post content")
    image_url: Optional[str] = Field(None, description="URL of the post image")
    thumbnail_url: Optional[str] = Field(None, description="URL of the post thumbnail")
    created_at: Optional[str] = Field(None, description="Post creation timestamp")
    updated_at: Optional[str] = Field(None, description="Post last update timestamp")
