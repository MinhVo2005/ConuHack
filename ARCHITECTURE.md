# Architecture Overview

## System Diagram

```
┌─────────────────┐     Socket.IO      ┌──────────────────┐
│   Game (JS)     │◄──────────────────►│                  │
│   Browser       │                    │   FastAPI        │
└─────────────────┘                    │   Backend        │
                                       │   (port 3000)    │
┌─────────────────┐     REST + WS      │                  │
│   Flutter App   │◄──────────────────►│                  │
│   Mobile        │                    └────────┬─────────┘
└─────────────────┘                             │
                                                ▼
                                       ┌──────────────────┐
                                       │   SQLite DB      │
                                       │   (game.db)      │
                                       └──────────────────┘
```

## Communication Strategy

| Feature | Method | Why |
|---------|--------|-----|
| Login/Register | REST | One-time call |
| Get Accounts | REST | Simple fetch |
| Transactions | REST | CRUD operations |
| Transfers | REST | Request-response |
| **Environment Sync** | **Socket.IO** | **Real-time updates** |
| Gold Collection | Socket.IO | Game events |

## Data Flow

### Environment Sync (Real-time)
```
Game → collectGold/move → Backend → environmentUpdated → Flutter App
                              ↓
                         Updates DB
```

### Banking Operations
```
Flutter App → REST API → Backend → DB → Response → Flutter App
```

## Key Endpoints

### REST API (http://localhost:3000/api)

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/user/get-or-create` | POST | Login with name |
| `/user/{id}` | GET | Get user + accounts |
| `/user/{user_id}/accounts` | GET | List accounts |
| `/transfer` | POST | Between own accounts |
| `/send` | POST | To other users |
| `/environment` | GET | Current state |
| `/environment/hints` | GET | UI adaptation hints |

### Socket.IO Events

| Event | Direction | Purpose |
|-------|-----------|---------|
| `join` | Client→Server | Register player |
| `environmentUpdated` | Server→Client | Biome changes |
| `goldCollected` | Server→Client | Treasure found |
| `playerData` | Server→Client | Initial user data |

## Flutter App Structure

```
lib/
├── main.dart           # Entry point
├── models.dart         # Data classes
├── api.dart            # Mock API (legacy)
├── backend_service.dart # Real API + Socket.IO
└── view.dart           # UI components
```

## Environment Mapping

| Game Biome | Flutter Region | Backend Noise |
|------------|----------------|---------------|
| beach | dryBeach | quiet |
| cave | darkCave | quiet |
| jungle | loudJungle | high/boomboom |
| windy | windyPlains | med |
| rain | rainforest | med |
| arctic | arcticSnows | low |

## Config

```dart
// Flutter - lib/backend_service.dart
const String baseUrl = 'http://localhost:3000';
```

```javascript
// Game - game.js
const SOCKET_URL = 'http://localhost:3000';
```

## Integration Checklist

- [x] Add http + socket_io_client packages
- [x] Create BackendService class
- [x] Login screen with name entry
- [x] Connect accounts to backend
- [x] Socket.IO environment listener
- [x] Transaction history from backend
- [x] Transfer functionality
- [x] Gold exchange integration

## Integration Complete!
