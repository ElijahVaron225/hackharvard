from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from app.utils.gemini import get_gemini_client

router = APIRouter()

class ChatRequest(BaseModel):
    message: str

@router.get("/")
def get_gemini():
    return {"status": "ok"}

@router.post("/chat")
def chat_with_gemini(request: ChatRequest):
    try:
        # TODO: Implement Gemini chat functionality
        return {"message": "Gemini chat not implemented yet", "user_message": request.message}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


