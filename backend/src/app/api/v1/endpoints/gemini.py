# import fastapi and gemini apis
from fastapi import APIRouter
from app.utils.gemini import get_gemini_client

router = APIRouter()

@router.get("/gemini")
def get_gemini():
    return {"status": "ok"}

