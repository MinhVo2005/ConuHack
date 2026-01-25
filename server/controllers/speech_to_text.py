import os
from dotenv import load_dotenv
from fastapi import APIRouter, UploadFile, File, HTTPException
from fastapi.responses import StreamingResponse, Response
from pydantic import BaseModel
from elevenlabs.client import AsyncElevenLabs
from typing import Optional
import io

load_dotenv()

# Initialize the Router
router = APIRouter(
    prefix="/api",
    tags=["ElevenLabs Operations"]
)

client = AsyncElevenLabs(api_key=os.getenv("ELEVENLABS_API_KEY"))

# Available voices - using ElevenLabs preset voices
# You can also use custom voice IDs
VOICES = {
    "default": "21m00Tcm4TlvDq8ikWAM",  # Rachel - calm, professional
    "friendly": "EXAVITQu4vr4xnSDxMaL",  # Bella - warm, friendly
    "professional": "ErXwobaYiN019PkySvjV",  # Antoni - clear, professional
}


class TTSRequest(BaseModel):
    text: str
    voice: Optional[str] = "default"  # Voice preset name or voice_id

@router.post("/transcribe")
async def transcribe_audio(file: UploadFile = File(...)):
    """
    Controller to convert uploaded audio files into text using ElevenLabs Speech-to-Text.
    """
    try:
        # Read the uploaded file into memory
        audio_data = await file.read()

        # Call ElevenLabs Speech-to-Text
        # Try with the available model - "scribe_v1" or just default
        try:
            transcription = await client.speech_to_text.convert(
                file=audio_data,
                model_id="scribe_v1",  # Use v1 as fallback
                language_code="eng",
            )
        except Exception:
            # Try without model_id if scribe_v1 doesn't work
            transcription = await client.speech_to_text.convert(
                file=audio_data,
                language_code="eng",
            )

        return {
            "filename": file.filename,
            "transcript": getattr(transcription, 'text', str(transcription)),
            "language": getattr(transcription, 'language_code', 'eng'),
            "words": getattr(transcription, 'words', [])
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Transcription failed: {str(e)}")
    finally:
        await file.close()


@router.post("/text-to-speech")
async def text_to_speech(request: TTSRequest):
    """
    Convert text to speech using ElevenLabs TTS.
    Returns audio as MP3 stream.
    """
    try:
        if not request.text or not request.text.strip():
            raise HTTPException(status_code=400, detail="Text is required")

        # Get voice ID
        voice_id = VOICES.get(request.voice, request.voice)
        if not voice_id:
            voice_id = VOICES["default"]

        # Generate speech using text_to_speech.convert
        # Using eleven_turbo_v2_5 (available on free tier, fast and good quality)
        # Note: This returns an async generator, not a coroutine
        audio_generator = client.text_to_speech.convert(
            voice_id=voice_id,
            text=request.text,
            model_id="eleven_turbo_v2_5",
        )

        # Collect audio chunks
        audio_chunks = []
        async for chunk in audio_generator:
            audio_chunks.append(chunk)
        audio_data = b"".join(audio_chunks)

        # Return as audio response
        return Response(
            content=audio_data,
            media_type="audio/mpeg",
            headers={
                "Content-Disposition": "inline; filename=response.mp3"
            }
        )

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"TTS failed: {str(e)}")