# Create a function to return the gemini client
from ..core.config import settings
from google import genai

def get_gemini_client() -> genai.Client:
    return genai.Client(api_key=settings.GEMINI_API_KEY)