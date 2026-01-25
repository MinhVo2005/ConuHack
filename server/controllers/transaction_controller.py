from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from typing import List, Optional
from database import get_db
from services.transaction_service import TransactionService
from services.user_service import UserService
from services.account_service import AccountService
from schemas.transaction import (
    TransferRequest, DepositRequest, WithdrawRequest,
    CollectGoldRequest, ExchangeGoldRequest, SendMoneyRequest,
    TransactionResponse, GoldRateResponse
)

router = APIRouter(prefix="/api", tags=["transactions"])


@router.post("/transfer", response_model=TransactionResponse, status_code=201)
def transfer(request: TransferRequest, db: Session = Depends(get_db)):
    """Transfer between accounts."""
    service = TransactionService(db)
    transaction = service.transfer(
        request.from_account_id,
        request.to_account_id,
        request.amount,
        request.description
    )
    return transaction


@router.post("/deposit", response_model=TransactionResponse, status_code=201)
def deposit(request: DepositRequest, db: Session = Depends(get_db)):
    """External deposit."""
    service = TransactionService(db)
    transaction = service.deposit(
        request.account_id,
        request.amount,
        request.description
    )
    return transaction


@router.post("/withdraw", response_model=TransactionResponse, status_code=201)
def withdraw(request: WithdrawRequest, db: Session = Depends(get_db)):
    """External withdrawal."""
    service = TransactionService(db)
    transaction = service.withdraw(
        request.account_id,
        request.amount,
        request.description
    )
    return transaction


@router.post("/collect-gold", response_model=TransactionResponse, status_code=201)
def collect_gold(request: CollectGoldRequest, db: Session = Depends(get_db)):
    """Collect gold bar from game."""
    service = TransactionService(db)
    transaction = service.collect_gold_bar(request.user_id)
    return transaction


@router.post("/exchange-gold", status_code=201)
def exchange_gold(request: ExchangeGoldRequest, db: Session = Depends(get_db)):
    """Exchange gold bars for cash."""
    transaction_service = TransactionService(db)
    account_service = AccountService(db)

    transaction = transaction_service.exchange_gold(
        request.user_id,
        request.bars,
        request.to_account_type
    )
    summary = account_service.get_account_summary(request.user_id)

    return {
        "transaction": transaction.to_dict(),
        "summary": summary,
        "exchangeRate": transaction_service.get_gold_bar_value()
    }


@router.post("/send", status_code=201)
def send_money(request: SendMoneyRequest, db: Session = Depends(get_db)):
    """Send money to another user."""
    transaction_service = TransactionService(db)
    account_service = AccountService(db)
    user_service = UserService(db)

    transaction = transaction_service.send_money(
        request.from_user_id,
        request.to_user_id,
        request.amount,
        request.from_account_type,
        request.to_account_type,
        request.description
    )

    sender_summary = account_service.get_account_summary(request.from_user_id)
    recipient = user_service.get_user(request.to_user_id)

    return {
        "transaction": transaction.to_dict(),
        "summary": sender_summary,
        "recipient": recipient.to_dict()
    }


@router.get("/users")
def find_users(search: Optional[str] = Query(None), db: Session = Depends(get_db)):
    """Search for users."""
    service = UserService(db)
    users = service.find_users(search or "")
    return [user.to_dict() for user in users]


@router.get("/user/{user_id}/transactions", response_model=List[TransactionResponse])
def get_transaction_history(
    user_id: str,
    limit: int = Query(50, ge=1, le=100),
    db: Session = Depends(get_db)
):
    """Get transaction history for a user."""
    service = TransactionService(db)
    transactions = service.get_transaction_history(user_id, limit)
    return transactions


@router.get("/account/{account_id}/transactions", response_model=List[TransactionResponse])
def get_account_transactions(
    account_id: int,
    limit: int = Query(50, ge=1, le=100),
    db: Session = Depends(get_db)
):
    """Get transactions for a specific account."""
    service = TransactionService(db)
    transactions = service.get_account_transactions(account_id, limit)
    return transactions


@router.get("/gold-rate", response_model=GoldRateResponse)
def get_gold_rate(db: Session = Depends(get_db)):
    """Get gold bar exchange rate."""
    service = TransactionService(db)
    return {
        "rate": service.get_gold_bar_value(),
        "currency": "USD",
        "unit": "per gold bar"
    }
