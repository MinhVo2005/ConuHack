from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime


class UserCreate(BaseModel):
    id: str
    name: str


class UserUpdate(BaseModel):
    name: str


class UserResponse(BaseModel):
    id: str
    name: str
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class AccountInUser(BaseModel):
    id: int
    type: str
    name: str
    balance: float

    class Config:
        from_attributes = True


class UserWithAccounts(BaseModel):
    id: str
    name: str
    created_at: Optional[datetime] = None
    accounts: List[AccountInUser] = []

    class Config:
        from_attributes = True
