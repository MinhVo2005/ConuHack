from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from typing import List
from database import get_db
from services.account_service import AccountService
from schemas.account import AccountResponse, AccountSummary

router = APIRouter(prefix="/api", tags=["accounts"])


@router.get("/user/{user_id}/accounts", response_model=List[AccountResponse])
def get_accounts(user_id: str, db: Session = Depends(get_db)):
    """Get all accounts for a user."""
    service = AccountService(db)
    accounts = service.get_accounts_by_user_id(user_id)
    return accounts


@router.get("/user/{user_id}/accounts/summary", response_model=AccountSummary)
def get_account_summary(user_id: str, db: Session = Depends(get_db)):
    """Get account summary with totals."""
    service = AccountService(db)
    summary = service.get_account_summary(user_id)
    return summary


@router.get("/user/{user_id}/accounts/{account_type}", response_model=AccountResponse)
def get_account_by_type(user_id: str, account_type: str, db: Session = Depends(get_db)):
    """Get account by type."""
    service = AccountService(db)
    account = service.get_account_by_type(user_id, account_type)
    return account


@router.get("/account/{account_id}", response_model=AccountResponse)
def get_account(account_id: int, db: Session = Depends(get_db)):
    """Get account details."""
    service = AccountService(db)
    account = service.get_account(account_id)
    return account


@router.get("/account/{account_id}/balance")
def get_balance(account_id: int, db: Session = Depends(get_db)):
    """Get account balance only."""
    service = AccountService(db)
    balance = service.get_balance(account_id)
    return {"balance": balance}
