"""
Test all imports to find what's broken
Run: python test_imports.py
"""
import sys

def test_import(name, import_fn):
    try:
        import_fn()
        print(f"[OK] {name}")
        return True
    except Exception as e:
        print(f"[FAIL] {name}: {e}")
        return False

print("Testing imports...\n")

# Core dependencies
test_import("fastapi", lambda: __import__('fastapi'))
test_import("uvicorn", lambda: __import__('uvicorn'))
test_import("pydantic", lambda: __import__('pydantic'))
test_import("sqlalchemy", lambda: __import__('sqlalchemy'))
test_import("python-socketio", lambda: __import__('socketio'))
test_import("dotenv", lambda: __import__('dotenv'))

print()

# API SDKs
test_import("elevenlabs", lambda: __import__('elevenlabs'))
test_import("google.generativeai", lambda: __import__('google.generativeai'))

print()

# Local modules
test_import("database", lambda: __import__('database'))
test_import("models.user", lambda: __import__('models.user'))
test_import("models.account", lambda: __import__('models.account'))
test_import("models.transaction", lambda: __import__('models.transaction'))
test_import("models.environment", lambda: __import__('models.environment'))

print()

test_import("services.user_service", lambda: __import__('services.user_service'))
test_import("services.account_service", lambda: __import__('services.account_service'))
test_import("services.transaction_service", lambda: __import__('services.transaction_service'))
test_import("services.environment_service", lambda: __import__('services.environment_service'))

print()

test_import("controllers.user_controller", lambda: __import__('controllers.user_controller'))
test_import("controllers.account_controller", lambda: __import__('controllers.account_controller'))
test_import("controllers.transaction_controller", lambda: __import__('controllers.transaction_controller'))
test_import("controllers.environment_controller", lambda: __import__('controllers.environment_controller'))
test_import("controllers.speech_to_text", lambda: __import__('controllers.speech_to_text'))
test_import("controllers.voice_command", lambda: __import__('controllers.voice_command'))

print()

# Try importing main
test_import("main (full app)", lambda: __import__('main'))

print("\nDone!")
