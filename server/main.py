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
from models.transaction import Transaction
from models.user import User

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

VALID_NOISE_LEVELS = {"quiet", "low", "med", "high", "boomboom"}
DIRECT_DEPOSIT_AMOUNT = 50


def _coerce_number(value):
    if value is None or isinstance(value, bool):
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _coerce_int(value):
    number = _coerce_number(value)
    if number is None:
        return None
    return int(round(number))


def _normalize_brightness(value):
    number = _coerce_number(value)
    if number is None:
        return None
    if number <= 1.5:
        min_val = 0.2
        max_val = 1.5
        if max_val <= min_val:
            scaled = 0.0
        else:
            scaled = (number - min_val) / (max_val - min_val)
        scaled = max(0.0, min(1.0, scaled))
        number = 1 + round(scaled * 9)
    brightness = int(round(number))
    return max(1, min(10, brightness))


def _noise_from_level(level):
    number = _coerce_number(level)
    if number is None:
        return None
    if number <= 20:
        return "quiet"
    if number <= 40:
        return "low"
    if number <= 60:
        return "med"
    if number <= 80:
        return "high"
    return "boomboom"


def _normalize_noise(noise, sound_level):
    if isinstance(noise, str) and noise in VALID_NOISE_LEVELS:
        return noise
    from_level = _noise_from_level(sound_level)
    if from_level is not None:
        return from_level
    return _noise_from_level(noise)


def _extract_environment_payload(data):
    if isinstance(data, dict):
        env = data.get("environment")
        if isinstance(env, dict):
            return env
        return data
    return {}


def _normalize_environment_payload(env):
    wind_speed = env.get("wind_speed")
    if wind_speed is None:
        wind_speed = env.get("windSpeed")
    return {
        "temperature": _coerce_int(env.get("temperature")),
        "humidity": _coerce_int(env.get("humidity")),
        "wind_speed": _coerce_int(wind_speed),
        "noise": _normalize_noise(env.get("noise"), env.get("soundLevel")),
        "brightness": _normalize_brightness(env.get("brightness")),
    }


def get_db_session():
    """Get a database session for socket handlers."""
    return SessionLocal()


def _register_player_sid(player_id, sid):
    if not player_id or not sid:
        return
    connected_players.setdefault(player_id, set()).add(sid)


def _unregister_sid(sid):
    if not sid:
        return
    for player_id, sids in list(connected_players.items()):
        if sid in sids:
            sids.discard(sid)
            if not sids:
                del connected_players[player_id]


def _get_player_sids(player_id, fallback_sid=None):
    sids = connected_players.get(player_id)
    if sids:
        return set(sids)
    if fallback_sid:
        return {fallback_sid}
    return set()


def _resolve_deposit_user_id(db, player_id):
    if not player_id:
        return None
    player_id = str(player_id)
    if not player_id.startswith("player_"):
        return player_id
    user = (
        db.query(User)
        .filter(~User.id.like("player_%"))
        .order_by(User.created_at.desc())
        .first()
    )
    if user:
        return user.id
    return player_id


def _select_deposit_account(account_service, user_id):
    if not user_id:
        return None
    accounts = account_service.get_accounts_by_user_id(user_id)
    if not accounts:
        return None
    for account in accounts:
        if account.type == "checking":
            return account
    accounts.sort(key=lambda account: account.id)
    return accounts[0]


# Socket.IO event handlers
@sio.event
async def connect(sid, environ):
    print(f"Client connected: {sid}")


@sio.event
async def disconnect(sid):
    print(f"Client disconnected: {sid}")
    _unregister_sid(sid)


@sio.event
async def join(sid, player_id):
    """Player joins the game."""
    db = get_db_session()
    try:
        user_service = UserService(db)
        user, created = user_service.get_or_create_user(player_id, f"Player {player_id[:8]}")
        _register_player_sid(player_id, sid)

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
        env_payload = _normalize_environment_payload(_extract_environment_payload(data))
        env = environment_service.update_environment(
            temperature=env_payload["temperature"],
            humidity=env_payload["humidity"],
            wind_speed=env_payload["wind_speed"],
            noise=env_payload["noise"],
            brightness=env_payload["brightness"]
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
            for recipient_sid in connected_players[to_user_id]:
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
    player_id = data.get("playerId") if isinstance(data, dict) else None
    if not player_id:
        return

    db = get_db_session()
    try:
        user_service = UserService(db)
        account_service = AccountService(db)

        user_service.get_or_create_user(player_id, f"Player {player_id[:8]}")
        treasure = account_service.get_account_by_type(player_id, "treasure_chest")

        current_balance = int(treasure.balance or 0)
        if isinstance(data, dict) and data.get("newTotal") is not None:
            target_balance = _coerce_int(data.get("newTotal"))
        else:
            gold_change = _coerce_number(data.get("goldChange")) if isinstance(data, dict) else 0
            if gold_change is None:
                gold_change = 0
            target_balance = _coerce_int(current_balance + gold_change)

        if target_balance is None:
            target_balance = current_balance

        delta = target_balance - current_balance
        deposit_account = None
        deposit_user_id = None
        did_change = False

        if delta != 0:
            treasure.balance = target_balance
            transaction = Transaction(
                from_account_id=treasure.id if delta < 0 else None,
                to_account_id=treasure.id if delta > 0 else None,
                amount=abs(delta),
                type="deposit" if delta > 0 else "withdrawal",
                description="Gold collected from game" if delta > 0 else "Gold lost in game"
            )
            db.add(transaction)
            did_change = True

        if delta > 0:
            deposit_user_id = _resolve_deposit_user_id(db, player_id)
            deposit_account = _select_deposit_account(account_service, deposit_user_id)
            if deposit_account:
                deposit_account.balance += DIRECT_DEPOSIT_AMOUNT
                deposit_transaction = Transaction(
                    from_account_id=None,
                    to_account_id=deposit_account.id,
                    amount=DIRECT_DEPOSIT_AMOUNT,
                    type="deposit",
                    description="Direct deposit from game"
                )
                db.add(deposit_transaction)
                did_change = True

        if did_change:
            db.commit()
            db.refresh(treasure)
            if deposit_account:
                db.refresh(deposit_account)
        else:
            db.commit()

        payload = {
            "gold": int(target_balance),
            "change": delta,
            "userId": player_id
        }
        notify_sids = _get_player_sids(player_id, fallback_sid=sid)
        if deposit_user_id and deposit_user_id != player_id:
            notify_sids |= _get_player_sids(deposit_user_id)
        for target_sid in notify_sids:
            await sio.emit("goldUpdated", payload, room=target_sid)
    except Exception as e:
        await sio.emit("error", {"message": str(e)}, room=sid)
    finally:
        db.close()


@sio.event
async def environmentUpdate(sid, data):
    """Handle environment update from game and broadcast to all clients."""
    environment = _extract_environment_payload(data)

    db = get_db_session()
    try:
        environment_service = EnvironmentService(db)
        env_payload = _normalize_environment_payload(environment)
        env = environment_service.update_environment(
            temperature=env_payload["temperature"],
            humidity=env_payload["humidity"],
            wind_speed=env_payload["wind_speed"],
            noise=env_payload["noise"],
            brightness=env_payload["brightness"]
        )
        hints = environment_service.get_adaptation_hints()
        env_dict = env.to_dict()
        if isinstance(environment, dict) and environment.get("type"):
            env_dict["region"] = environment.get("type")

        # Broadcast to all connected clients (including Flutter app)
        await sio.emit("environmentUpdated", {
            "environment": env_dict,
            "hints": hints
        })
    except Exception as e:
        await sio.emit("error", {"message": str(e)}, room=sid)
    finally:
        db.close()


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
