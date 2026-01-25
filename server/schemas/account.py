from pydantic import BaseModel
from typing import Optional, Literal
from datetime import datetime


class AccountCreate(BaseModel):
    user_id: str
    type: Literal["checking", "savings", "treasure_chest"]
    name: str
    balance: float = 0


class AccountResponse(BaseModel):
    id: int
    user_id: str
    type: str
    name: str
    balance: float
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class AccountSummary(BaseModel):
    accounts: list
    total_cash: float
    gold_bars: int
