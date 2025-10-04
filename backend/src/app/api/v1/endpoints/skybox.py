import os
import httpx
import asyncio
import json
import threading
import time
from fastapi import APIRouter, HTTPException
from dotenv import load_dotenv
from pydantic import BaseModel
import pysher

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
    print(f"🌅 Starting skybox generation for prompt: '{request.prompt}'")
    
    # Validate input
    if not request.prompt or not request.prompt.strip():
        print("❌ Error: Empty prompt provided")
        raise HTTPException(
            status_code=400,
            detail="Prompt cannot be empty"
        )
    
    if len(request.prompt) > 600:  # Reasonable limit for API
        print(f"❌ Error: Prompt too long ({len(request.prompt)} characters)")
        raise HTTPException(
            status_code=400,
            detail="Prompt too long (max 1000 characters)"
        )
    
    if not BLOCKADE_API_KEY:
        print("❌ Error: Blockade API key not configured")
        raise HTTPException(
            status_code=500, 
            detail="Blockade API key not configured"
        )
    
    print("✅ Input validation passed")
    
    url = "https://backend.blockadelabs.com/api/v1/skybox"
    headers = {
        "x-api-key": BLOCKADE_API_KEY,
        "Content-Type": "application/json"
    }
    payload = {
        "prompt": request.prompt.strip()
    }
    
    print(f"🚀 Sending request to Blockade Labs API...")
    print(f"   URL: {url}")
    print(f"   Payload: {payload}")
    
    try:
        async with httpx.AsyncClient(timeout=600.0) as client:
            response = await client.post(url, json=payload, headers=headers)
            print(f"📡 Received response: {response.status_code}")
            
            response.raise_for_status()
            result = response.json()
            print(f"✅ Success! Response: {result}")
            return result
            
    except httpx.TimeoutException:
        print("⏰ Timeout: Blockade API took too long to respond")
        raise HTTPException(
            status_code=504,
            detail="Request timeout - Blockade API took too long to respond"
        )
    except httpx.ConnectError:
        print("🔌 Connection Error: Unable to connect to Blockade API")
        raise HTTPException(
            status_code=503,
            detail="Unable to connect to Blockade API - service may be down"
        )
    except httpx.HTTPStatusError as e:
        print(f"🚨 HTTP Error {e.response.status_code}: {e.response.text}")
        # Handle specific HTTP status codes
        if e.response.status_code == 401:
            raise HTTPException(
                status_code=401,
                detail="Invalid API key for Blockade Labs"
            )
        elif e.response.status_code == 429:
            raise HTTPException(
                status_code=429,
                detail="Rate limit exceeded - too many requests to Blockade API"
            )
        elif e.response.status_code == 400:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid request to Blockade API: {e.response.text}"
            )
        else:
            raise HTTPException(
                status_code=e.response.status_code,
                detail=f"Blockade API error: {e.response.text}"
            )
    except httpx.RequestError as e:
        print(f"🌐 Network Error: {str(e)}")
        raise HTTPException(
            status_code=502,
            detail=f"Network error calling Blockade API: {str(e)}"
        )
    except ValueError as e:
        print(f"📄 JSON Parse Error: {str(e)}")
        raise HTTPException(
            status_code=502,
            detail=f"Invalid response from Blockade API: {str(e)}"
        )
    except Exception as e:
        print(f"💥 Unexpected Error: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Unexpected error calling Blockade API: {str(e)}"
        )

class PusherWaitRequest(BaseModel):
    pusher_channel: str
    pusher_event: str = "status_update"

@router.post("/wait-for-completion")
async def wait_for_completion(request: PusherWaitRequest):
    """
    Wait for skybox generation to complete via Pusher webhook
    """
    print(f"🔔 Waiting for completion on channel: {request.pusher_channel}")
    print(f"📡 Listening for event: {request.pusher_event}")
    
    try:
        # Create a future to hold the result
        result_future = asyncio.Future()
        
        def on_connect(data=None):
            print("✅ Connected to Pusher")
            channel = pusher.subscribe(request.pusher_channel)
            channel.bind(request.pusher_event, on_status_update)
            print(f"📡 Subscribed to channel: {request.pusher_channel}")
        
        def on_error(error):
            print(f"❌ Pusher connection error: {error}")
            result_future.set_exception(Exception(f"Pusher error: {error}"))
        
        def on_status_update(data):
            print(f"📨 Received status update: {data}")
            try:
                # Parse the data (it might be a string)
                if isinstance(data, str):
                    data = json.loads(data)
                
                status = data.get('status', '')
                print(f"🔄 Status: {status}")
                
                if status == 'complete':
                    print("✅ Generation complete! URLs should be populated.")
                    result_future.set_result(data)
                elif status == 'error':
                    error_msg = data.get('error_message', 'Unknown error')
                    print(f"❌ Generation failed: {error_msg}")
                    result_future.set_exception(Exception(f"Generation failed: {error_msg}"))
                else:
                    print(f"⏳ Still processing... Status: {status}")
                    
            except Exception as e:
                print(f"💥 Error processing status update: {str(e)}")
                result_future.set_exception(e)
        
        # Initialize Pusher with Blockade Labs credentials
        # Note: pysher only takes key and cluster, not app_id
        pusher = pysher.Pusher(
            key="a6a7b7662238ce4494d5",
            cluster="mt1"
        )
        print("🔑 Using Blockade Labs Pusher credentials")
        
        # Set up event handlers
        pusher.connection.bind('pusher:connection_established', on_connect)
        pusher.connection.bind('pusher:error', on_error)
        
        # Connect to Pusher
        print("🔌 Connecting to Pusher...")
        pusher.connect()
        
        # Give Pusher a moment to connect
        await asyncio.sleep(1)
        
        # Wait for completion with timeout (5 minutes)
        try:
            result = await asyncio.wait_for(result_future, timeout=300.0)
            print(f"🎉 Generation completed successfully!")
            return result
        except asyncio.TimeoutError:
            print("⏰ Timeout waiting for generation to complete")
            raise HTTPException(
                status_code=408,
                detail="Timeout waiting for generation to complete"
            )
        finally:
            # Disconnect from Pusher
            try:
                pusher.disconnect()
                print("🔌 Disconnected from Pusher")
            except:
                pass
        
    except Exception as e:
        print(f"💥 Error waiting for completion: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Error waiting for completion: {str(e)}"
        )




