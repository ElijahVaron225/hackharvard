import os
import httpx
from fastapi import APIRouter, HTTPException
from dotenv import load_dotenv
from pydantic import BaseModel

# Load .env file
load_dotenv()

router = APIRouter()

# Load Blockade API key
BLOCKADE_API_KEY = os.getenv("BLOCKADE_API_KEY")

class SkyboxRequest(BaseModel):
    prompt: str

@router.get("/")
def get_skybox():
    return {"status": "ok"}

@router.post("/generate")
async def generate_skybox(request: SkyboxRequest):
    if not BLOCKADE_API_KEY:
        raise HTTPException(
            status_code=500, 
            detail="Blockade API key not configured"
        )
    
    url = "https://backend.blockadelabs.com/api/v1/skybox"

    headers = {
        "x-api-key": BLOCKADE_API_KEY,
        "Content-Type": "application/json"
    }
    
    payload = {
        "prompt": request.prompt
    }
    
    try:
        async with httpx.AsyncClient() as client:
            response = await client.post(url, json=payload, headers=headers)
            response.raise_for_status()
            return response.json()
    except httpx.HTTPStatusError as e:
        raise HTTPException(
            status_code=e.response.status_code,
            detail=f"Blockade API error: {e.response.text}"
        )
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Error calling Blockade API: {str(e)}"
        )




