import os
from dotenv import load_dotenv
from fastapi import APIRouter,FastAPI, UploadFile, File
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from elevenlabs.client import AsyncElevenLabs

load_dotenv()

# Initialize the Router
router = APIRouter(
    prefix="/api",
    tags=["ElevenLabs Operations"]
)

client = AsyncElevenLabs(api_key=os.getenv("ELEVENLABS_API_KEY"))

@router.post("/transcribe")
async def transcribe_audio(file: UploadFile = File(...)):
    """
    Controller to convert uploaded audio files into text using ElevenLabs Scribe v2.
    """
    try:
        # Read the uploaded file into memory
        audio_data = await file.read()
        
        # Call ElevenLabs Speech-to-Text
        # scribe_v2 is the flagship model for 2026
        transcription = await client.speech_to_text.convert(
            file=audio_data,
            model_id="scribe_v2",
            tag_audio_events=True,  # Captures [laughter], [applause], etc.
            language_code="eng",    # Set to None for auto-detection
            diarize=True            # Identifies different speakers
        )

        return {
            "filename": file.filename,
            "transcript": transcription.text,
            "language": transcription.language_code,
            "words": transcription.words # Detailed timestamps if needed
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Transcription failed: {str(e)}")
    finally:
        await file.close()