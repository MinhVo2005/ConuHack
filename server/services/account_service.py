from sqlalchemy.orm import Session
from fastapi import HTTPException
from models.account import Account


class AccountService:
    def __init__(self, db: Session):
        self.db = db

    def get_account(self, account_id: int) -> Account:
        """Get account by ID."""
        account = self.db.query(Account).filter(Account.id == account_id).first()
        if not account:
            raise HTTPException(status_code=404, detail="Account not found")
        return account

    def get_accounts_by_user_id(self, user_id: str) -> list[Account]:
        """Get all accounts for a user."""
        return self.db.query(Account).filter(Account.user_id == user_id).all()

    def get_account_by_type(self, user_id: str, account_type: str) -> Account:
        """Get account by user ID and type."""
        account = self.db.query(Account).filter(
            Account.user_id == user_id,
            Account.type == account_type
        ).first()
        if not account:
            raise HTTPException(
                status_code=404,
                detail=f"Account of type '{account_type}' not found for user"
            )
        return account

    def get_balance(self, account_id: int) -> float:
        """Get account balance."""
        account = self.get_account(account_id)
        return account.balance

    def get_balance_by_type(self, user_id: str, account_type: str) -> float:
        """Get account balance by type."""
        account = self.get_account_by_type(user_id, account_type)
        return account.balance

    def update_balance(self, account_id: int, new_balance: float) -> Account:
        """Set account balance (cannot be negative)."""
        if new_balance < 0:
            raise HTTPException(status_code=400, detail="Balance cannot be negative")
        account = self.get_account(account_id)
        account.balance = new_balance
        self.db.commit()
        self.db.refresh(account)
        return account

    def add_to_balance(self, account_id: int, amount: float) -> Account:
        """Add to account balance (amount must be positive)."""
        if amount <= 0:
            raise HTTPException(status_code=400, detail="Amount must be positive")
        account = self.get_account(account_id)
        account.balance += amount
        self.db.commit()
        self.db.refresh(account)
        return account

    def subtract_from_balance(self, account_id: int, amount: float) -> Account:
        """Subtract from account balance (validates sufficient funds)."""
        if amount <= 0:
            raise HTTPException(status_code=400, detail="Amount must be positive")
        account = self.get_account(account_id)
        if account.balance < amount:
            raise HTTPException(status_code=400, detail="Insufficient funds")
        account.balance -= amount
        self.db.commit()
        self.db.refresh(account)
        return account

    def get_account_summary(self, user_id: str) -> dict:
        """Get account summary with totals."""
        accounts = self.get_accounts_by_user_id(user_id)

        total_cash = 0
        gold_bars = 0

        for account in accounts:
            if account.type == "treasure_chest":
                gold_bars = int(account.balance)
            else:
                total_cash += account.balance

        return {
            "accounts": [account.to_dict() for account in accounts],
            "total_cash": total_cash,
            "gold_bars": gold_bars
        }
