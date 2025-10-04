import fastapi
from fastapi.responses import StreamingResponse
from app.utils.elevenlabs import get_elevenlabs_client
from pydantic import BaseModel, Field
import io

router = fastapi.APIRouter()

class TextToSpeechRequest(BaseModel):
    text: str = Field(..., min_length=1, description="Text to convert to speech")
    voice_id: str = "JBFqnCBsd6RMkjVDRZzb"  # Default voice ID
    output_format: str = "mp3_44100_128"  # Default output format

@router.post("/eleven/text-to-speech")
def text_to_speech(request: TextToSpeechRequest):
    """
    Convert text to speech using ElevenLabs API
    """
    client = get_elevenlabs_client()
    
    try:
        # Use the correct ElevenLabs API method for v2.16.0
        audio_generator = client.text_to_speech.convert(
            text=request.text,
            voice_id=request.voice_id,
            model_id="eleven_multilingual_v2"
        )
        
        # Convert generator to bytes
        audio_bytes = b"".join(audio_generator)
        
        # Return the audio as a streaming response
        audio_stream = io.BytesIO(audio_bytes)
        return StreamingResponse(
            audio_stream,
            media_type="audio/mpeg",
            headers={"Content-Disposition": "attachment; filename=speech.mp3"}
        )
    except Exception as e:
        raise fastapi.HTTPException(status_code=500, detail=str(e))
