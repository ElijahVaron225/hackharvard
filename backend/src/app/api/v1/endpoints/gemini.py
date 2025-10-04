# import fastapi and gemini apis
from fastapi import APIRouter, HTTPException
from app.utils.gemini import get_gemini_client

router = APIRouter()

@router.get("/gemini")
def get_gemini():
    return {"status": "ok"}

@router.post("/gemini/chat")
def chat_with_gemini(user_message: str):
    try:
        client = get_gemini_client()
        response = client.models.generate_content(
            model="gemini-2.0-flash",
            contents=[user_message],
        )
        return response.text
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


