# Kiri Engine FastAPI Backend

A FastAPI backend service that integrates with the Kiri Engine API to process videos and generate USDZ 3D models. This service implements a complete video → KIRI (polling) → USDZ → Supabase workflow.

## Features

- **Video Processing**: Submit video URLs for 3D model generation using Kiri Engine
- **Background Polling**: Automatic status monitoring with exponential backoff
- **Job Management**: In-memory job tracking with status updates
- **File Processing**: Automatic ZIP extraction and USDZ file handling
- **RESTful API**: Clean endpoints for job creation, status checking, and result retrieval
- **Error Handling**: Comprehensive error handling and logging
- **Configurable**: Environment-based configuration for all settings

## Architecture

```
POST /scan → Kiri Engine API → Background Polling → ZIP Download → USDZ Extraction → Supabase Upload
```

### Components

- **FastAPI Routes**: RESTful endpoints for job management
- **Kiri Engine Client**: HTTP client for Kiri Engine API integration
- **Job Store**: In-memory storage for job tracking and status management
- **Background Service**: Polling service with exponential backoff and timeout handling
- **Utility Functions**: File handling, ZIP extraction, and retry logic

## Installation

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd backend
   ```

2. **Create a virtual environment**:
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

3. **Install dependencies**:
   ```bash
   pip install -r requirements.txt
   ```

4. **Set up environment variables**:
   Create a `.env` file in the backend directory:
   ```env
   # Required
   KIRI_API_KEY=your_kiri_api_key_here
   
   # Optional (with defaults)
   APP_NAME=Kiri Engine FastAPI
   ENVIRONMENT=development
   API_V1_PREFIX=/api/v1
   POLLING_TIMEOUT_MINUTES=45
   POLLING_INITIAL_DELAY=2.0
   POLLING_MAX_DELAY=30.0
   JOB_CLEANUP_AGE_HOURS=24
   ```

5. **Run the application**:
   ```bash
   uvicorn src.app.main:app --reload --host 0.0.0.0 --port 8000
   ```

The API will be available at `http://localhost:8000`

## API Documentation

Once the server is running, you can access:
- **Interactive API docs**: `http://localhost:8000/docs`
- **ReDoc documentation**: `http://localhost:8000/redoc`

## API Endpoints

### 1. Create Scan Job
```http
POST /api/v1/scan
Content-Type: application/json

{
  "videoUrl": "https://example.com/video.mp4",
  "fileFormat": "usdz",
  "modelQuality": 0,
  "textureQuality": 0,
  "isMask": 0,
  "textureSmoothing": 0,
  "additionalParams": {}
}
```

**Response** (201 Created):
```json
{
  "jobId": "123e4567-e89b-12d3-a456-426614174000",
  "status": "queued"
}
```

### 2. Get Job Status
```http
GET /api/v1/scan/{jobId}/status
```

**Response** (200 OK):
```json
{
  "jobId": "123e4567-e89b-12d3-a456-426614174000",
  "status": "processing",
  "error": null
}
```

### 3. Get Job Result
```http
GET /api/v1/scan/{jobId}/result
```

**Response** (200 OK) - When ready:
```json
{
  "jobId": "123e4567-e89b-12d3-a456-426614174000",
  "status": "success",
  "usdzUrl": "https://fake-supabase-url.com/usdz/123e4567-e89b-12d3-a456-426614174000.usdz"
}
```

**Response** (200 OK) - When still processing:
```json
{
  "jobId": "123e4567-e89b-12d3-a456-426614174000",
  "status": "processing",
  "usdzUrl": null
}
```

### 4. Get Job Statistics
```http
GET /api/v1/scan/stats
```

**Response** (200 OK):
```json
{
  "total_jobs": 15,
  "status_counts": {
    "queued": 2,
    "processing": 3,
    "success": 8,
    "failed": 2
  }
}
```

## Job Status Codes

| Status | Description | Kiri Engine Code |
|--------|-------------|------------------|
| `queued` | Job created and waiting to start | 3 |
| `uploading` | Video is being uploaded | -1 |
| `processing` | 3D model is being generated | 0 |
| `success` | Job completed successfully | 2 |
| `failed` | Job failed | 1 |
| `expired` | Job expired | 4 |

## Quality Parameters

### Model Quality (`modelQuality`)
| Value | Description |
|-------|-------------|
| `0` | High |
| `1` | Medium |
| `2` | Low |
| `3` | Ultra |

### Texture Quality (`textureQuality`)
| Value | Description |
|-------|-------------|
| `0` | 4K |
| `1` | 2K |
| `2` | 1K |
| `3` | 8K |

### Additional Parameters
| Parameter | Type | Description | Values |
|-----------|------|-------------|--------|
| `isMask` | int | Auto Object Masking | `0` = Off, `1` = On |
| `textureSmoothing` | int | Texture Smoothing | `0` = Off, `1` = On |

## Testing with cURL

### 1. Create a scan job:
```bash
curl -X POST "http://localhost:8000/api/v1/scan" \
  -H "Content-Type: application/json" \
  -d '{
    "videoUrl": "https://example.com/sample-video.mp4",
    "fileFormat": "usdz",
    "modelQuality": 0,
    "textureQuality": 0,
    "isMask": 0,
    "textureSmoothing": 0
  }'
```

### 2. Check job status:
```bash
curl -X GET "http://localhost:8000/api/v1/scan/{jobId}/status"
```

### 3. Get job result:
```bash
curl -X GET "http://localhost:8000/api/v1/scan/{jobId}/result"
```

### 4. Get statistics:
```bash
curl -X GET "http://localhost:8000/api/v1/scan/stats"
```

## Configuration

### Environment Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `KIRI_API_KEY` | Kiri Engine API key | - | Yes |
| `POLLING_TIMEOUT_MINUTES` | Maximum polling time | 45 | No |
| `POLLING_INITIAL_DELAY` | Initial delay between polls (seconds) | 2.0 | No |
| `POLLING_MAX_DELAY` | Maximum delay between polls (seconds) | 30.0 | No |
| `JOB_CLEANUP_AGE_HOURS` | Age threshold for job cleanup | 24 | No |

### Polling Behavior

The service uses exponential backoff for polling:
- **Initial delay**: 2 seconds
- **Maximum delay**: 30 seconds
- **Multiplier**: 1.5x
- **Jitter**: ±25% random variation
- **Timeout**: 45 minutes (configurable)

## Error Handling

The service includes comprehensive error handling:

- **Validation errors**: Invalid video URLs or malformed requests
- **API errors**: Kiri Engine API failures with retry logic
- **Timeout errors**: Jobs that exceed the polling timeout
- **File processing errors**: ZIP extraction and USDZ handling failures
- **Network errors**: Connection issues with automatic retries

## Logging

The service uses Python's built-in logging with different levels:
- **INFO**: Job creation, status updates, successful operations
- **WARNING**: Retry attempts, non-critical issues
- **ERROR**: Failed operations, API errors
- **DEBUG**: Detailed debugging information

## Development

### Project Structure
```
backend/
├── src/
│   └── app/
│       ├── api/v1/endpoints/
│       │   └── kiri.py          # FastAPI endpoints
│       ├── core/
│       │   └── config.py        # Configuration settings
│       ├── kiri_client.py       # Kiri Engine API client
│       ├── models.py            # Pydantic models
│       ├── service.py           # Background polling service
│       ├── store.py             # In-memory job store
│       ├── utils.py             # Utility functions
│       └── main.py              # FastAPI application
├── requirements.txt
└── README.md
```

### Adding New Features

1. **New endpoints**: Add to `src/app/api/v1/endpoints/kiri.py`
2. **New models**: Add to `src/app/models.py`
3. **New utilities**: Add to `src/app/utils.py`
4. **Configuration**: Update `src/app/core/config.py`

## Production Considerations

### TODO: Supabase Integration

The current implementation includes a placeholder for Supabase upload:
```python
def upload_usdz_placeholder(job_id: str, usdz_path: str) -> str:
    # TODO: Replace with actual Supabase upload implementation
    return f"https://fake-supabase-url.com/usdz/{job_id}.usdz"
```

**Your teammate should implement**:
1. Supabase client configuration
2. File upload to Supabase storage
3. URL generation for uploaded files
4. Error handling for upload failures

### Scaling Considerations

- **Job Store**: Currently in-memory, consider Redis for production
- **Background Tasks**: Consider Celery for distributed processing
- **File Storage**: Implement proper file cleanup and storage management
- **Monitoring**: Add metrics and health checks
- **Rate Limiting**: Implement API rate limiting

## Troubleshooting

### Common Issues

1. **"KIRI_API_KEY not set"**: Ensure the environment variable is properly set
2. **"Job not found"**: Job may have been cleaned up or never created
3. **"Invalid video URL"**: Check URL format and accessibility
4. **"Polling timeout"**: Job took longer than 45 minutes to complete

### Debug Mode

Enable debug logging by setting the log level:
```python
import logging
logging.basicConfig(level=logging.DEBUG)
```

## License

[Add your license information here]

## Support

For issues and questions:
1. Check the logs for error details
2. Verify environment variables are set correctly
3. Test with the provided cURL examples
4. Check Kiri Engine API documentation for service status