from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker, declarative_base
import os

# Database file path
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DATABASE_PATH = os.path.join(BASE_DIR, "game.db")
# Normalize path for Windows
DATABASE_PATH = os.path.normpath(DATABASE_PATH)
DATABASE_URL = f"sqlite:///{DATABASE_PATH}"

engine = create_engine(
    DATABASE_URL,
    connect_args={"check_same_thread": False},
    echo=False
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()


def get_db():
    """Dependency for getting database session."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def init_db():
    """Initialize database tables."""
    # Import models to register them with Base
    import models.user
    import models.account
    import models.transaction
    import models.environment
    # Create tables (will not recreate if they exist)
    Base.metadata.create_all(bind=engine)
    _ensure_credit_card_account_type()


def _ensure_credit_card_account_type():
    with engine.begin() as connection:
        row = connection.execute(
            text("SELECT sql FROM sqlite_master WHERE type='table' AND name='accounts'")
        ).fetchone()
        if not row or not row[0] or "credit_card" in row[0]:
            return

        connection.execute(text("PRAGMA foreign_keys=OFF"))
        connection.execute(
            text(
                """
                CREATE TABLE accounts_new (
                    id INTEGER NOT NULL,
                    user_id VARCHAR NOT NULL,
                    type VARCHAR NOT NULL,
                    name VARCHAR NOT NULL,
                    balance FLOAT,
                    created_at DATETIME,
                    updated_at DATETIME,
                    PRIMARY KEY (id),
                    CONSTRAINT valid_account_type CHECK (type IN ('checking', 'savings', 'treasure_chest', 'credit_card')),
                    FOREIGN KEY(user_id) REFERENCES users (id)
                )
                """
            )
        )
        connection.execute(
            text(
                """
                INSERT INTO accounts_new (id, user_id, type, name, balance, created_at, updated_at)
                SELECT id, user_id, type, name, balance, created_at, updated_at FROM accounts
                """
            )
        )
        connection.execute(text("DROP TABLE accounts"))
        connection.execute(text("ALTER TABLE accounts_new RENAME TO accounts"))
        connection.execute(text("PRAGMA foreign_keys=ON"))
