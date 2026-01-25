from .user_controller import router as user_router
from .account_controller import router as account_router
from .transaction_controller import router as transaction_router
from .environment_controller import router as environment_router
from .speech_to_text import router as speech_to_text_router
from .voice_command import router as voice_command_router

__all__ = ["user_router", "account_router", "transaction_router", "environment_router", "speech_to_text_router", "voice_command_router"]
