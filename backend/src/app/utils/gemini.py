import google.generativeai as genai
from app.core.config import settings
import os

def get_gemini_client():
    """Initialize and return Gemini client"""
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        raise ValueError("GEMINI_API_KEY environment variable not set")
    
    genai.configure(api_key=api_key)
    return genai.GenerativeModel('gemini-pro-latest')

def load_prompt_file(prompt_file_path: str) -> str:
    """Load prompt from file"""
    try:
        with open(prompt_file_path, 'r', encoding='utf-8') as file:
            return file.read().strip()
    except FileNotFoundError:
        raise FileNotFoundError(f"Prompt file not found: {prompt_file_path}")
    except Exception as e:
        raise Exception(f"Error reading prompt file: {str(e)}")
