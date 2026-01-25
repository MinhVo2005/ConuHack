from pydantic import BaseModel, Field
from typing import Optional, Literal, List
from datetime import datetime


class EnvironmentUpdate(BaseModel):
    temperature: Optional[int] = Field(None, ge=-30, le=50)
    humidity: Optional[int] = Field(None, ge=0, le=100)
    wind_speed: Optional[int] = Field(None, ge=0, le=60)
    noise: Optional[Literal["quiet", "low", "med", "high", "boomboom"]] = None
    brightness: Optional[int] = Field(None, ge=1, le=10)


class EnvironmentResponse(BaseModel):
    id: int
    temperature: int
    humidity: int
    wind_speed: int
    noise: str
    brightness: int
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class AdaptationHints(BaseModel):
    visual: List[str] = []
    interaction: List[str] = []
