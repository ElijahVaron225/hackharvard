# Create a function to return the elevenlabs client
from src.app.core.config import settings
from elevenlabs import ElevenLabs

def get_elevenlabs_client() -> ElevenLabs:
    return ElevenLabs(api_key=settings.ELEVENLABS_API_KEY)