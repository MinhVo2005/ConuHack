from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from database import get_db
from services.user_service import UserService
from schemas.user import UserCreate, UserUpdate, UserResponse, UserWithAccounts

router = APIRouter(prefix="/api", tags=["users"])


@router.get("/user/{user_id}", response_model=UserWithAccounts)
def get_user(user_id: str, db: Session = Depends(get_db)):
    """Get user with accounts."""
    service = UserService(db)
    user = service.get_user_with_accounts(user_id)
    return user


@router.post("/user", response_model=UserResponse, status_code=201)
def create_user(user_data: UserCreate, db: Session = Depends(get_db)):
    """Create a new user."""
    service = UserService(db)
    user = service.create_user(user_data.id, user_data.name)
    return user


@router.post("/user/get-or-create", response_model=UserWithAccounts)
def get_or_create_user(user_data: UserCreate, db: Session = Depends(get_db)):
    """Get existing user or create new one."""
    service = UserService(db)
    user, created = service.get_or_create_user(user_data.id, user_data.name)
    # Load accounts
    _ = user.accounts
    return user


@router.put("/user/{user_id}", response_model=UserResponse)
def update_user(user_id: str, user_data: UserUpdate, db: Session = Depends(get_db)):
    """Update user's name."""
    service = UserService(db)
    user = service.update_user_name(user_id, user_data.name)
    return user


@router.delete("/user/{user_id}", status_code=204)
def delete_user(user_id: str, db: Session = Depends(get_db)):
    """Delete user and all accounts."""
    service = UserService(db)
    service.delete_user(user_id)
    return None
