"""
Standalone test for Gemini API
Run: python test_gemini.py
"""
import os
from dotenv import load_dotenv

load_dotenv()

def test_gemini():
    print("Testing Gemini API...")
    print(f"API Key present: {bool(os.getenv('GEMINI_API_KEY'))}")

    try:
        import google.generativeai as genai

        genai.configure(api_key=os.getenv("GEMINI_API_KEY"))

        # List available models first
        print("\nAvailable models:")
        for m in genai.list_models():
            if 'generateContent' in m.supported_generation_methods:
                print(f"  - {m.name}")

        # Try different model names
        model_names = [
            "gemini-1.5-flash",
            "gemini-1.5-pro",
            "gemini-pro",
            "gemini-2.0-flash-exp",
        ]

        working_model = None
        for model_name in model_names:
            try:
                print(f"\nTrying model: {model_name}")
                model = genai.GenerativeModel(model_name)
                response = model.generate_content("Say 'hello' in JSON format: {\"greeting\": \"hello\"}")
                print(f"  Success! Response: {response.text[:100]}...")
                working_model = model_name
                break
            except Exception as e:
                print(f"  Failed: {e}")

        if working_model:
            print(f"\n✓ Working model: {working_model}")
            return working_model
        else:
            print("\n✗ No working model found")
            return None

    except ImportError:
        print("✗ google-generativeai not installed. Run: pip install google-generativeai")
        return None
    except Exception as e:
        print(f"✗ Error: {e}")
        return None

if __name__ == "__main__":
    test_gemini()
