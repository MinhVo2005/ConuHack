from sqlalchemy.orm import Session
from fastapi import HTTPException
from models.transaction import Transaction
from models.account import Account
from models.user import User
from .account_service import AccountService


# Gold exchange rate: 1 gold bar = $7000
GOLD_BAR_VALUE = 7000


class TransactionService:
    def __init__(self, db: Session):
        self.db = db
        self.account_service = AccountService(db)

    def get_gold_bar_value(self) -> int:
        """Get the value of one gold bar."""
        return GOLD_BAR_VALUE

    def transfer(
        self,
        from_account_id: int,
        to_account_id: int,
        amount: float,
        description: str = None
    ) -> Transaction:
        """Transfer between accounts (not treasure chest)."""
        from_account = self.account_service.get_account(from_account_id)
        to_account = self.account_service.get_account(to_account_id)

        # Validate not treasure chest
        if from_account.type == "treasure_chest" or to_account.type == "treasure_chest":
            raise HTTPException(
                status_code=400,
                detail="Cannot transfer to/from treasure chest. Use gold exchange instead."
            )

        # Validate same user
        if from_account.user_id != to_account.user_id:
            raise HTTPException(
                status_code=400,
                detail="Cannot transfer between different users. Use send money instead."
            )

        if from_account.is_loan:
            raise HTTPException(
                status_code=400,
                detail="Cannot transfer from credit card accounts."
            )

        # Validate sufficient funds
        if from_account.balance < amount:
            raise HTTPException(status_code=400, detail="Insufficient funds")

        # Perform transfer
        from_account.balance -= amount
        if to_account.is_loan:
            to_account.balance = max(to_account.balance - amount, 0)
        else:
            to_account.balance += amount

        # Record transaction
        transaction = Transaction(
            from_account_id=from_account_id,
            to_account_id=to_account_id,
            amount=amount,
            type="transfer",
            description=description or f"Transfer from {from_account.name} to {to_account.name}"
        )
        self.db.add(transaction)
        self.db.commit()
        self.db.refresh(transaction)
        return transaction

    def deposit(
        self,
        account_id: int,
        amount: float,
        description: str = None
    ) -> Transaction:
        """Deposit funds into account (not treasure chest)."""
        account = self.account_service.get_account(account_id)

        if account.type == "treasure_chest":
            raise HTTPException(
                status_code=400,
                detail="Cannot deposit to treasure chest. Use collect gold instead."
            )

        if account.is_loan:
            account.balance = max(account.balance - amount, 0)
        else:
            account.balance += amount

        transaction = Transaction(
            from_account_id=None,
            to_account_id=account_id,
            amount=amount,
            type="deposit",
            description=description or "External deposit"
        )
        self.db.add(transaction)
        self.db.commit()
        self.db.refresh(transaction)
        return transaction

    def withdraw(
        self,
        account_id: int,
        amount: float,
        description: str = None
    ) -> Transaction:
        """Withdraw funds from account (not treasure chest)."""
        account = self.account_service.get_account(account_id)

        if account.type == "treasure_chest":
            raise HTTPException(
                status_code=400,
                detail="Cannot withdraw from treasure chest. Use gold exchange instead."
            )

        if account.is_loan:
            account.balance += amount
        else:
            if account.balance < amount:
                raise HTTPException(status_code=400, detail="Insufficient funds")
            account.balance -= amount

        transaction = Transaction(
            from_account_id=account_id,
            to_account_id=None,
            amount=amount,
            type="withdrawal",
            description=description or "External withdrawal"
        )
        self.db.add(transaction)
        self.db.commit()
        self.db.refresh(transaction)
        return transaction

    def collect_gold_bar(self, user_id: str) -> Transaction:
        """Add one gold bar to user's treasure chest."""
        treasure_chest = self.account_service.get_account_by_type(user_id, "treasure_chest")

        treasure_chest.balance += 1

        transaction = Transaction(
            from_account_id=None,
            to_account_id=treasure_chest.id,
            amount=1,
            type="deposit",
            description="Gold bar collected from game"
        )
        self.db.add(transaction)
        self.db.commit()
        self.db.refresh(transaction)
        return transaction

    def exchange_gold(
        self,
        user_id: str,
        bars: int,
        to_account_type: str
    ) -> Transaction:
        """Exchange gold bars for cash."""
        if to_account_type not in ["checking", "savings"]:
            raise HTTPException(
                status_code=400,
                detail="Can only exchange gold to checking or savings account"
            )

        treasure_chest = self.account_service.get_account_by_type(user_id, "treasure_chest")
        to_account = self.account_service.get_account_by_type(user_id, to_account_type)

        if treasure_chest.balance < bars:
            raise HTTPException(
                status_code=400,
                detail=f"Insufficient gold bars. Have {int(treasure_chest.balance)}, need {bars}"
            )

        cash_amount = bars * GOLD_BAR_VALUE

        treasure_chest.balance -= bars
        to_account.balance += cash_amount

        transaction = Transaction(
            from_account_id=treasure_chest.id,
            to_account_id=to_account.id,
            amount=bars,
            type="gold_exchange",
            description=f"Exchanged {bars} gold bars for ${cash_amount}"
        )
        self.db.add(transaction)
        self.db.commit()
        self.db.refresh(transaction)
        return transaction

    def send_money(
        self,
        from_user_id: str,
        to_user_id: str,
        amount: float,
        from_account_type: str = "checking",
        to_account_type: str = "checking",
        description: str = None
    ) -> Transaction:
        """Send money to another user."""
        if from_user_id == to_user_id:
            raise HTTPException(
                status_code=400,
                detail="Cannot send money to yourself. Use transfer instead."
            )

        if from_account_type == "treasure_chest" or to_account_type == "treasure_chest":
            raise HTTPException(
                status_code=400,
                detail="Cannot send/receive gold bars. Use checking or savings."
            )

        # Validate users exist
        from_user = self.db.query(User).filter(User.id == from_user_id).first()
        to_user = self.db.query(User).filter(User.id == to_user_id).first()

        if not from_user:
            raise HTTPException(status_code=404, detail="Sender not found")
        if not to_user:
            raise HTTPException(status_code=404, detail="Recipient not found")

        from_account = self.account_service.get_account_by_type(from_user_id, from_account_type)
        to_account = self.account_service.get_account_by_type(to_user_id, to_account_type)

        if from_account.balance < amount:
            raise HTTPException(status_code=400, detail="Insufficient funds")

        from_account.balance -= amount
        to_account.balance += amount

        transaction = Transaction(
            from_account_id=from_account.id,
            to_account_id=to_account.id,
            amount=amount,
            type="transfer",
            description=description or f"Transfer from {from_user.name} to {to_user.name}"
        )
        self.db.add(transaction)
        self.db.commit()
        self.db.refresh(transaction)
        return transaction

    def get_transaction_history(self, user_id: str, limit: int = 50) -> list[Transaction]:
        """Get transaction history for a user."""
        accounts = self.db.query(Account).filter(Account.user_id == user_id).all()
        account_ids = [a.id for a in accounts]

        if not account_ids:
            return []

        transactions = self.db.query(Transaction).filter(
            (Transaction.from_account_id.in_(account_ids)) |
            (Transaction.to_account_id.in_(account_ids))
        ).order_by(Transaction.created_at.desc()).limit(limit).all()

        return transactions

    def get_account_transactions(self, account_id: int, limit: int = 50) -> list[Transaction]:
        """Get transactions for a specific account."""
        transactions = self.db.query(Transaction).filter(
            (Transaction.from_account_id == account_id) |
            (Transaction.to_account_id == account_id)
        ).order_by(Transaction.created_at.desc()).limit(limit).all()

        return transactions
