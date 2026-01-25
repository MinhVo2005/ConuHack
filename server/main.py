import socketio
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
import uvicorn
import os

from database import SessionLocal, init_db
from controllers import user_router, account_router, transaction_router, environment_router
from services.user_service import UserService
from services.account_service import AccountService
from services.transaction_service import TransactionService
from services.environment_service import EnvironmentService

# Create FastAPI app
app = FastAPI(
    title="Game Server API",
    description="Backend API for the treasure hunt game",
    version="1.0.0"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(user_router)
app.include_router(account_router)
app.include_router(transaction_router)
app.include_router(environment_router)

# Mount static files for game
game_path = os.path.join(os.path.dirname(__file__), "..", "game")
if os.path.exists(game_path):
    app.mount("/game", StaticFiles(directory=game_path, html=True), name="game")

# Create Socket.IO server
sio = socketio.AsyncServer(
    async_mode="asgi",
    cors_allowed_origins="*"
)

# Create combined ASGI app
socket_app = socketio.ASGIApp(sio, other_asgi_app=app)

# Store connected players
connected_players = {}


def get_db_session():
    """Get a database session for socket handlers."""
    return SessionLocal()


# Socket.IO event handlers
@sio.event
async def connect(sid, environ):
    print(f"Client connected: {sid}")


@sio.event
async def disconnect(sid):
    print(f"Client disconnected: {sid}")
    # Remove from connected players
    for player_id, player_sid in list(connected_players.items()):
        if player_sid == sid:
            del connected_players[player_id]
            break


@sio.event
async def join(sid, player_id):
    """Player joins the game."""
    db = get_db_session()
    try:
        user_service = UserService(db)
        user, created = user_service.get_or_create_user(player_id, f"Player {player_id[:8]}")
        connected_players[player_id] = sid

        # Load accounts
        _ = user.accounts

        await sio.emit("playerData", {
            "id": user.id,
            "name": user.name,
            "gold": sum(a.balance for a in user.accounts if a.type == "treasure_chest"),
            "accounts": [a.to_dict() for a in user.accounts]
        }, room=sid)
    except Exception as e:
        await sio.emit("error", {"message": str(e)}, room=sid)
    finally:
        db.close()


@sio.event
async def getUser(sid, player_id):
    """Get user data."""
    db = get_db_session()
    try:
        user_service = UserService(db)
        user = user_service.get_user_with_accounts(player_id)
        await sio.emit("playerData", {
            "id": user.id,
            "name": user.name,
            "accounts": [a.to_dict() for a in user.accounts]
        }, room=sid)
    except Exception as e:
        await sio.emit("error", {"message": str(e)}, room=sid)
    finally:
        db.close()


@sio.event
async def collectGold(sid, player_id):
    """Collect gold bar from game."""
    db = get_db_session()
    try:
        transaction_service = TransactionService(db)
        account_service = AccountService(db)

        transaction = transaction_service.collect_gold_bar(player_id)
        treasure = account_service.get_account_by_type(player_id, "treasure_chest")

        await sio.emit("goldCollected", {
            "transaction": transaction.to_dict(),
            "goldBars": int(treasure.balance)
        }, room=sid)
    except Exception as e:
        await sio.emit("error", {"message": str(e)}, room=sid)
    finally:
        db.close()


@sio.event
async def exchangeGold(sid, data):
    """Exchange gold bars for cash."""
    db = get_db_session()
    try:
        player_id = data.get("playerId")
        bars = data.get("bars", 1)
        to_account_type = data.get("toAccountType", "checking")

        transaction_service = TransactionService(db)
        account_service = AccountService(db)

        transaction = transaction_service.exchange_gold(player_id, bars, to_account_type)
        summary = account_service.get_account_summary(player_id)

        await sio.emit("goldExchanged", {
            "transaction": transaction.to_dict(),
            "summary": summary,
            "exchangeRate": transaction_service.get_gold_bar_value()
        }, room=sid)
    except Exception as e:
        await sio.emit("error", {"message": str(e)}, room=sid)
    finally:
        db.close()


@sio.event
async def updateEnvironment(sid, data):
    """Update environment state."""
    db = get_db_session()
    try:
        environment_service = EnvironmentService(db)
        env = environment_service.update_environment(
            temperature=data.get("temperature"),
            humidity=data.get("humidity"),
            wind_speed=data.get("wind_speed") or data.get("windSpeed"),
            noise=data.get("noise"),
            brightness=data.get("brightness")
        )
        hints = environment_service.get_adaptation_hints()

        await sio.emit("environmentUpdated", {
            "environment": env.to_dict(),
            "hints": hints
        }, room=sid)
    except Exception as e:
        await sio.emit("error", {"message": str(e)}, room=sid)
    finally:
        db.close()


@sio.event
async def getEnvironment(sid):
    """Get environment state."""
    db = get_db_session()
    try:
        environment_service = EnvironmentService(db)
        env = environment_service.get_environment()
        hints = environment_service.get_adaptation_hints()

        await sio.emit("environmentData", {
            "environment": env.to_dict(),
            "hints": hints
        }, room=sid)
    except Exception as e:
        await sio.emit("error", {"message": str(e)}, room=sid)
    finally:
        db.close()


@sio.event
async def transfer(sid, data):
    """Transfer between accounts."""
    db = get_db_session()
    try:
        player_id = data.get("playerId")
        from_account_id = data.get("fromAccountId")
        to_account_id = data.get("toAccountId")
        amount = data.get("amount")
        description = data.get("description")

        transaction_service = TransactionService(db)
        account_service = AccountService(db)

        transaction = transaction_service.transfer(
            from_account_id, to_account_id, amount, description
        )
        summary = account_service.get_account_summary(player_id)

        await sio.emit("transferComplete", {
            "transaction": transaction.to_dict(),
            "summary": summary
        }, room=sid)
    except Exception as e:
        await sio.emit("error", {"message": str(e)}, room=sid)
    finally:
        db.close()


@sio.event
async def getAccountSummary(sid, player_id):
    """Get account summary."""
    db = get_db_session()
    try:
        account_service = AccountService(db)
        summary = account_service.get_account_summary(player_id)
        await sio.emit("accountSummary", summary, room=sid)
    except Exception as e:
        await sio.emit("error", {"message": str(e)}, room=sid)
    finally:
        db.close()


@sio.event
async def sendMoney(sid, data):
    """Send money to another user."""
    db = get_db_session()
    try:
        from_user_id = data.get("fromUserId")
        to_user_id = data.get("toUserId")
        amount = data.get("amount")
        from_account_type = data.get("fromAccountType", "checking")
        to_account_type = data.get("toAccountType", "checking")
        description = data.get("description")

        transaction_service = TransactionService(db)
        account_service = AccountService(db)
        user_service = UserService(db)

        transaction = transaction_service.send_money(
            from_user_id, to_user_id, amount,
            from_account_type, to_account_type, description
        )

        sender_summary = account_service.get_account_summary(from_user_id)
        recipient_summary = account_service.get_account_summary(to_user_id)
        sender = user_service.get_user(from_user_id)
        recipient = user_service.get_user(to_user_id)

        # Notify sender
        await sio.emit("moneySent", {
            "transaction": transaction.to_dict(),
            "summary": sender_summary,
            "recipient": recipient.to_dict()
        }, room=sid)

        # Notify recipient if connected
        if to_user_id in connected_players:
            recipient_sid = connected_players[to_user_id]
            await sio.emit("moneyReceived", {
                "transaction": transaction.to_dict(),
                "summary": recipient_summary,
                "sender": sender.to_dict()
            }, room=recipient_sid)
    except Exception as e:
        await sio.emit("error", {"message": str(e)}, room=sid)
    finally:
        db.close()


@sio.event
async def updateGold(sid, data):
    """Handle gold update from game (legacy support)."""
    # This event is for tracking purposes, actual gold is managed via collectGold
    player_id = data.get("playerId")
    gold_change = data.get("goldChange", 0)
    new_total = data.get("newTotal", 0)

    await sio.emit("goldUpdated", {
        "gold": new_total,
        "change": gold_change
    }, room=sid)


@sio.event
async def environmentUpdate(sid, data):
    """Handle environment update from game."""
    player_id = data.get("playerId")
    environment = data.get("environment", {})

    # Just acknowledge, environment is managed by the game client
    await sio.emit("environmentAck", {"received": True}, room=sid)


@app.on_event("startup")
async def startup_event():
    """Initialize database on startup."""
    init_db()
    print("Database initialized")


@app.get("/")
async def root():
    """Root endpoint."""
    return {
        "message": "Game Server API",
        "docs": "/docs",
        "game": "/game"
    }


if __name__ == "__main__":
    PORT = int(os.environ.get("PORT", 3000))
    print(f"Starting server on http://localhost:{PORT}")
    print(f"Game available at http://localhost:{PORT}/game")
    print(f"API docs at http://localhost:{PORT}/docs")
    uvicorn.run(socket_app, host="0.0.0.0", port=PORT)
