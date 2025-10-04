from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from app.utils.gemini import get_gemini_client, load_prompt_file
import os

router = APIRouter()

class ChatRequest(BaseModel):
    message: str

@router.get("/")
def get_gemini():
    return {"status": "ok"}

@router.post("/chat")
def chat_with_gemini(request: ChatRequest):
    try:
        # Get the path to the prompt file
        current_dir = os.path.dirname(os.path.abspath(__file__))
        prompt_file_path = os.path.join(current_dir, "..", "..", "..", "utils", "prompts", "generate_prompt.txt")
        
        # Load the system prompt from file
        system_prompt = load_prompt_file(prompt_file_path)
        
        # Combine system prompt with user message
        full_prompt = f"{system_prompt}\n\n{request.message}"
        
        # Check if API key is available
        if not os.getenv("GEMINI_API_KEY"):
            # Return mock response for testing
            return {
                "message": "Prompt (4 phrases): indoors ground view living room with fireplace, bookshelf, front 0° fireplace, left bookshelf right couch back 180° wall, sunlit afternoon no people, asymmetric layout limited duplicates\nNegative (4 phrases): outdoors, focal at 180° or multiple centers reflections tiling swapped left right, >3 identical objects overlap clipping blurry unreadable text, laptops neon guessed brands",
                "user_message": request.message,
                "system_prompt_used": system_prompt[:100] + "..." if len(system_prompt) > 100 else system_prompt,
                "note": "Mock response - GEMINI_API_KEY not set"
            }
        
        # Get Gemini client and generate response
        try:
            gemini_client = get_gemini_client()
            print(f"🤖 Sending prompt to Gemini: {full_prompt[:200]}...")
            response = gemini_client.generate_content(full_prompt)
            print(f"✅ Gemini response: {response.text}")
            
            return {
                "message": response.text,
                "user_message": request.message,
                "system_prompt_used": system_prompt[:100] + "..." if len(system_prompt) > 100 else system_prompt
            }
        except Exception as gemini_error:
            print(f"❌ Gemini error: {str(gemini_error)}")
            # If Gemini fails, return mock response
            return {
                "message": "Prompt (4 phrases): indoors ground view living room with fireplace, bookshelf, front 0° fireplace, left bookshelf right couch back 180° wall, sunlit afternoon no people, asymmetric layout limited duplicates\nNegative (4 phrases): outdoors, focal at 180° or multiple centers reflections tiling swapped left right, >3 identical objects overlap clipping blurry unreadable text, laptops neon guessed brands",
                "user_message": request.message,
                "system_prompt_used": system_prompt[:100] + "..." if len(system_prompt) > 100 else system_prompt,
                "note": f"Mock response - Gemini error: {str(gemini_error)}"
            }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


