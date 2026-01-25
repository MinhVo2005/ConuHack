from pydantic import BaseModel, Field
from typing import Optional, Literal
from datetime import datetime


class TransferRequest(BaseModel):
    from_account_id: int
    to_account_id: int
    amount: float = Field(gt=0)
    description: Optional[str] = None


class DepositRequest(BaseModel):
    account_id: int
    amount: float = Field(gt=0)
    description: Optional[str] = None


class WithdrawRequest(BaseModel):
    account_id: int
    amount: float = Field(gt=0)
    description: Optional[str] = None


class CollectGoldRequest(BaseModel):
    user_id: str


class ExchangeGoldRequest(BaseModel):
    user_id: str
    bars: int = Field(gt=0)
    to_account_type: Literal["checking", "savings"]


class SendMoneyRequest(BaseModel):
    from_user_id: str
    to_user_id: str
    amount: float = Field(gt=0)
    from_account_type: Literal["checking", "savings"] = "checking"
    to_account_type: Literal["checking", "savings"] = "checking"
    description: Optional[str] = None


class TransactionResponse(BaseModel):
    id: int
    from_account_id: Optional[int] = None
    to_account_id: Optional[int] = None
    amount: float
    type: str
    description: Optional[str] = None
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class GoldRateResponse(BaseModel):
    rate: int
    currency: str = "USD"
    unit: str = "per gold bar"
