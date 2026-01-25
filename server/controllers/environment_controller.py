from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from database import get_db
from services.environment_service import EnvironmentService
from schemas.environment import EnvironmentUpdate, EnvironmentResponse, AdaptationHints

router = APIRouter(prefix="/api", tags=["environment"])


@router.get("/environment", response_model=EnvironmentResponse)
def get_environment(db: Session = Depends(get_db)):
    """Get current environment state."""
    service = EnvironmentService(db)
    env = service.get_environment()
    return env


@router.put("/environment", response_model=EnvironmentResponse)
def update_environment(request: EnvironmentUpdate, db: Session = Depends(get_db)):
    """Update environment state."""
    service = EnvironmentService(db)
    env = service.update_environment(
        temperature=request.temperature,
        humidity=request.humidity,
        wind_speed=request.wind_speed,
        noise=request.noise,
        brightness=request.brightness
    )
    return env


@router.post("/environment/reset", response_model=EnvironmentResponse)
def reset_environment(db: Session = Depends(get_db)):
    """Reset environment to defaults."""
    service = EnvironmentService(db)
    env = service.reset_environment()
    return env


@router.get("/environment/hints", response_model=AdaptationHints)
def get_adaptation_hints(db: Session = Depends(get_db)):
    """Get UI adaptation hints based on environment."""
    service = EnvironmentService(db)
    hints = service.get_adaptation_hints()
    return hints
