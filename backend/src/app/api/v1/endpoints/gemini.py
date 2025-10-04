# import fastapi and gemini apis
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from app.utils.gemini import get_gemini_client

router = APIRouter()

class ChatRequest(BaseModel):
    user_message: str

@router.get("/gemini")
def get_gemini():
    return {"status": "ok"}

@router.post("/gemini/chat")
def chat_with_gemini(request: ChatRequest):
    try:
        client = get_gemini_client()
        response = client.models.generate_content(
            model="gemini-2.0-flash",
            contents=[request.user_message],
        )
        return {"response": response.text}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


