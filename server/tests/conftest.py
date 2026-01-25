import pytest
import sys
import os

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from database import Base
from models import User, Account, Transaction, Environment


# Use in-memory SQLite for tests
TEST_DATABASE_URL = "sqlite:///:memory:"


@pytest.fixture(scope="function")
def db_engine():
    """Create a test database engine."""
    engine = create_engine(
        TEST_DATABASE_URL,
        connect_args={"check_same_thread": False}
    )
    Base.metadata.create_all(bind=engine)
    yield engine
    Base.metadata.drop_all(bind=engine)


@pytest.fixture(scope="function")
def db_session(db_engine):
    """Create a test database session."""
    SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=db_engine)
    session = SessionLocal()
    yield session
    session.rollback()
    session.close()


@pytest.fixture
def sample_user(db_session):
    """Create a sample user with accounts."""
    from services.user_service import UserService
    service = UserService(db_session)
    user = service.create_user("test_user_1", "Test User")
    return user


@pytest.fixture
def sample_users(db_session):
    """Create multiple sample users."""
    from services.user_service import UserService
    service = UserService(db_session)
    user1 = service.create_user("user_1", "Alice")
    user2 = service.create_user("user_2", "Bob")
    return [user1, user2]
