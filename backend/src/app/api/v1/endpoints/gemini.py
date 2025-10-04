# import fastapi and gemini apis
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from app.utils.gemini import get_gemini_client

router = APIRouter()

class ChatRequest(BaseModel):
    message: str

@router.get("/gemini")
def get_gemini():
    return {"status": "ok"}

@router.post("/gemini/chat")
def chat_with_gemini(request: ChatRequest):
    try:
        client = get_gemini_client()
        model = client.GenerativeModel('gemini-pro')
        
        response = model.generate_content(request.message)
        return {"response": response.text, "user_message": request.message}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


