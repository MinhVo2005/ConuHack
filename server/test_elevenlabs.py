"""
Standalone test for ElevenLabs API
Run: python test_elevenlabs.py
"""
import os
import asyncio
from dotenv import load_dotenv

load_dotenv()

async def test_elevenlabs():
    print("Testing ElevenLabs API...")
    print(f"API Key present: {bool(os.getenv('ELEVENLABS_API_KEY'))}")

    try:
        from elevenlabs.client import ElevenLabs, AsyncElevenLabs

        api_key = os.getenv("ELEVENLABS_API_KEY")

        # Test with sync client first (easier to debug)
        print("\n--- Testing Sync Client ---")
        sync_client = ElevenLabs(api_key=api_key)

        # List available voices
        print("\nAvailable voices:")
        try:
            voices = sync_client.voices.get_all()
            for v in voices.voices[:5]:
                print(f"  - {v.name} (ID: {v.voice_id})")
        except Exception as e:
            print(f"  Failed to list voices: {e}")

        # Test TTS
        print("\n--- Testing Text-to-Speech ---")
        try:
            # Try the simple generate method
            audio = sync_client.generate(
                text="Hello, this is a test.",
                voice="Rachel",
                model="eleven_monolingual_v1"
            )
            # Convert generator to bytes
            audio_bytes = b"".join(audio)
            print(f"  [OK] TTS Success! Generated {len(audio_bytes)} bytes of audio")

            # Save to file for verification
            with open("test_output.mp3", "wb") as f:
                f.write(audio_bytes)
            print("  [OK] Saved to test_output.mp3")
        except Exception as e:
            print(f"  [FAIL] TTS Failed: {e}")

            # Try alternative method with newer models
            print("\n  Trying with newer models...")
            models_to_try = ["eleven_turbo_v2_5", "eleven_turbo_v2", "eleven_flash_v2_5", "eleven_flash_v2"]
            for model_name in models_to_try:
                try:
                    print(f"    Trying model: {model_name}")
                    audio = sync_client.text_to_speech.convert(
                        voice_id="21m00Tcm4TlvDq8ikWAM",  # Rachel
                        text="Hello, this is a test.",
                        model_id=model_name,
                    )
                    audio_bytes = b"".join(audio)
                    print(f"    [OK] Success with {model_name}! Generated {len(audio_bytes)} bytes")
                    break
                except Exception as e2:
                    print(f"    [FAIL] {model_name}: {e2}")

        # Test STT (Speech-to-Text)
        print("\n--- Testing Speech-to-Text ---")
        try:
            # Check if speech_to_text exists
            if hasattr(sync_client, 'speech_to_text'):
                print("  [OK] speech_to_text attribute exists")
                # We'd need an audio file to test this properly
                print("  (Skipping actual STT test - need audio file)")
            else:
                print("  [FAIL] speech_to_text attribute not found on client")
                print("  Available attributes:", [a for a in dir(sync_client) if not a.startswith('_')])
        except Exception as e:
            print(f"  [FAIL] STT check failed: {e}")

        # Test Async Client
        print("\n--- Testing Async Client ---")
        async_client = AsyncElevenLabs(api_key=api_key)
        try:
            audio_gen = await async_client.text_to_speech.convert(
                voice_id="21m00Tcm4TlvDq8ikWAM",
                text="Async test.",
                model_id="eleven_turbo_v2_5",
            )
            # Handle different response types
            if hasattr(audio_gen, '__aiter__'):
                chunks = []
                async for chunk in audio_gen:
                    chunks.append(chunk)
                audio_bytes = b''.join(chunks)
            else:
                audio_bytes = b''.join(audio_gen) if not isinstance(audio_gen, bytes) else audio_gen
            print(f"  [OK] Async TTS Success! Generated {len(audio_bytes)} bytes")
        except Exception as e:
            print(f"  [FAIL] Async TTS Failed: {e}")

        print("\n[OK] ElevenLabs tests complete")

    except ImportError as e:
        print(f"[FAIL] elevenlabs not installed. Run: pip install elevenlabs")
        print(f"  Import error: {e}")
    except Exception as e:
        print(f"[FAIL] Error: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    asyncio.run(test_elevenlabs())
