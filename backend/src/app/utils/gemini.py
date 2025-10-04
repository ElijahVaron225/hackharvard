# Create a function to return the gemini client
from ..core.config import settings
import google.generativeai as genai

def get_gemini_client():
    """Initialize and return a Gemini client"""
    if not settings.GEMINI_API_KEY:
        raise ValueError("GEMINI_API_KEY is not set in environment variables")
    
    genai.configure(api_key=settings.GEMINI_API_KEY)
    return genai