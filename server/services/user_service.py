from sqlalchemy.orm import Session
from fastapi import HTTPException
from models.user import User
from models.account import Account


# Default account balances
DEFAULT_CHECKING_BALANCE = 1000
DEFAULT_SAVINGS_BALANCE = 500
DEFAULT_TREASURE_BALANCE = 0


class UserService:
    def __init__(self, db: Session):
        self.db = db

    def create_user(self, user_id: str, name: str) -> User:
        """Create a new user with default accounts."""
        # Check if user already exists
        existing = self.db.query(User).filter(User.id == user_id).first()
        if existing:
            raise HTTPException(status_code=409, detail="User already exists")

        # Create user
        user = User(id=user_id, name=name)
        self.db.add(user)
        self.db.flush()

        # Create default accounts
        accounts = [
            Account(
                user_id=user_id,
                type="checking",
                name="Checking Account",
                balance=DEFAULT_CHECKING_BALANCE
            ),
            Account(
                user_id=user_id,
                type="savings",
                name="Savings Account",
                balance=DEFAULT_SAVINGS_BALANCE
            ),
            Account(
                user_id=user_id,
                type="treasure_chest",
                name="Treasure Chest",
                balance=DEFAULT_TREASURE_BALANCE
            )
        ]
        for account in accounts:
            self.db.add(account)

        self.db.commit()
        self.db.refresh(user)
        return user

    def get_user(self, user_id: str) -> User:
        """Get user by ID."""
        user = self.db.query(User).filter(User.id == user_id).first()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        return user

    def get_user_with_accounts(self, user_id: str) -> User:
        """Get user with all accounts."""
        user = self.get_user(user_id)
        # Eager load accounts
        _ = user.accounts
        return user

    def get_or_create_user(self, user_id: str, name: str) -> tuple[User, bool]:
        """Get existing user or create new one. Returns (user, created)."""
        user = self.db.query(User).filter(User.id == user_id).first()
        if user:
            return user, False
        return self.create_user(user_id, name), True

    def update_user_name(self, user_id: str, name: str) -> User:
        """Update user's name."""
        user = self.get_user(user_id)
        user.name = name
        self.db.commit()
        self.db.refresh(user)
        return user

    def delete_user(self, user_id: str) -> None:
        """Delete user and all associated accounts."""
        user = self.get_user(user_id)
        self.db.delete(user)
        self.db.commit()

    def user_exists(self, user_id: str) -> bool:
        """Check if user exists."""
        return self.db.query(User).filter(User.id == user_id).first() is not None

    def find_users(self, search_term: str) -> list[User]:
        """Search for users by name or ID."""
        return self.db.query(User).filter(
            (User.name.ilike(f"%{search_term}%")) |
            (User.id.ilike(f"%{search_term}%"))
        ).all()
