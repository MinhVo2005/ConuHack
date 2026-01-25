import pytest
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from fastapi.testclient import TestClient
from sqlalchemy import create_engine, StaticPool
from sqlalchemy.orm import sessionmaker

from database import Base, get_db


# Use in-memory SQLite with StaticPool to share connection across threads
TEST_DATABASE_URL = "sqlite:///:memory:"
test_engine = create_engine(
    TEST_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool
)
TestSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=test_engine)


@pytest.fixture(scope="function")
def db_session():
    """Create tables and provide a session for each test."""
    # Import models to register them
    import models.user
    import models.account
    import models.transaction
    import models.environment

    Base.metadata.create_all(bind=test_engine)
    session = TestSessionLocal()
    yield session
    session.close()
    Base.metadata.drop_all(bind=test_engine)


@pytest.fixture(scope="function")
def client(db_session):
    """Create test client with database override."""
    from main import app

    def override_get_db():
        try:
            yield db_session
        finally:
            pass

    app.dependency_overrides[get_db] = override_get_db

    with TestClient(app) as test_client:
        yield test_client

    app.dependency_overrides.clear()


class TestUserController:
    """Tests for user endpoints."""

    def test_create_user(self, client):
        """Test creating a new user."""
        response = client.post(
            "/api/user",
            json={"id": "test_user", "name": "Test User"}
        )

        assert response.status_code == 201
        data = response.json()
        assert data["id"] == "test_user"
        assert data["name"] == "Test User"

    def test_get_user(self, client):
        """Test getting a user."""
        # Create user first
        client.post("/api/user", json={"id": "get_user", "name": "Get User"})

        response = client.get("/api/user/get_user")

        assert response.status_code == 200
        data = response.json()
        assert data["id"] == "get_user"
        assert len(data["accounts"]) == 4

    def test_get_user_not_found(self, client):
        """Test getting non-existent user."""
        response = client.get("/api/user/nonexistent")

        assert response.status_code == 404

    def test_get_or_create_user(self, client):
        """Test get or create endpoint."""
        # First call creates
        response = client.post(
            "/api/user/get-or-create",
            json={"id": "goc_user", "name": "GOC User"}
        )
        assert response.status_code == 200

        # Second call gets existing
        response = client.post(
            "/api/user/get-or-create",
            json={"id": "goc_user", "name": "Different Name"}
        )
        assert response.status_code == 200
        assert response.json()["name"] == "GOC User"  # Name unchanged

    def test_update_user(self, client):
        """Test updating user name."""
        client.post("/api/user", json={"id": "update_user", "name": "Old Name"})

        response = client.put(
            "/api/user/update_user",
            json={"name": "New Name"}
        )

        assert response.status_code == 200
        assert response.json()["name"] == "New Name"

    def test_delete_user(self, client):
        """Test deleting user."""
        client.post("/api/user", json={"id": "delete_user", "name": "Delete Me"})

        response = client.delete("/api/user/delete_user")
        assert response.status_code == 204

        # Verify deleted
        response = client.get("/api/user/delete_user")
        assert response.status_code == 404


class TestAccountController:
    """Tests for account endpoints."""

    def test_get_accounts(self, client):
        """Test getting all accounts for a user."""
        client.post("/api/user", json={"id": "acc_user", "name": "Account User"})

        response = client.get("/api/user/acc_user/accounts")

        assert response.status_code == 200
        data = response.json()
        assert len(data) == 4

    def test_get_account_summary(self, client):
        """Test getting account summary."""
        client.post("/api/user", json={"id": "sum_user", "name": "Summary User"})

        response = client.get("/api/user/sum_user/accounts/summary")

        assert response.status_code == 200
        data = response.json()
        assert data["total_cash"] == 1500
        assert data["gold_bars"] == 0

    def test_get_account_by_type(self, client):
        """Test getting account by type."""
        client.post("/api/user", json={"id": "type_user", "name": "Type User"})

        response = client.get("/api/user/type_user/accounts/checking")

        assert response.status_code == 200
        data = response.json()
        assert data["type"] == "checking"
        assert data["balance"] == 1000

    def test_get_balance(self, client):
        """Test getting account balance."""
        client.post("/api/user", json={"id": "bal_user", "name": "Balance User"})

        # Get checking account ID
        accounts = client.get("/api/user/bal_user/accounts").json()
        checking = next(a for a in accounts if a["type"] == "checking")

        response = client.get(f"/api/account/{checking['id']}/balance")

        assert response.status_code == 200
        assert response.json()["balance"] == 1000


class TestTransactionController:
    """Tests for transaction endpoints."""

    def test_transfer(self, client):
        """Test transfer between accounts."""
        client.post("/api/user", json={"id": "trans_user", "name": "Transfer User"})
        accounts = client.get("/api/user/trans_user/accounts").json()
        checking = next(a for a in accounts if a["type"] == "checking")
        savings = next(a for a in accounts if a["type"] == "savings")

        response = client.post("/api/transfer", json={
            "from_account_id": checking["id"],
            "to_account_id": savings["id"],
            "amount": 200
        })

        assert response.status_code == 201
        assert response.json()["amount"] == 200

    def test_deposit(self, client):
        """Test deposit."""
        client.post("/api/user", json={"id": "dep_user", "name": "Deposit User"})
        accounts = client.get("/api/user/dep_user/accounts").json()
        checking = next(a for a in accounts if a["type"] == "checking")

        response = client.post("/api/deposit", json={
            "account_id": checking["id"],
            "amount": 500
        })

        assert response.status_code == 201
        assert response.json()["amount"] == 500

    def test_withdraw(self, client):
        """Test withdrawal."""
        client.post("/api/user", json={"id": "with_user", "name": "Withdraw User"})
        accounts = client.get("/api/user/with_user/accounts").json()
        checking = next(a for a in accounts if a["type"] == "checking")

        response = client.post("/api/withdraw", json={
            "account_id": checking["id"],
            "amount": 300
        })

        assert response.status_code == 201
        assert response.json()["amount"] == 300

    def test_collect_gold(self, client):
        """Test collecting gold."""
        client.post("/api/user", json={"id": "gold_user", "name": "Gold User"})

        response = client.post("/api/collect-gold", json={
            "user_id": "gold_user"
        })

        assert response.status_code == 201
        assert response.json()["amount"] == 1

    def test_exchange_gold(self, client):
        """Test exchanging gold."""
        client.post("/api/user", json={"id": "exch_user", "name": "Exchange User"})

        # Collect some gold first
        for _ in range(3):
            client.post("/api/collect-gold", json={"user_id": "exch_user"})

        response = client.post("/api/exchange-gold", json={
            "user_id": "exch_user",
            "bars": 2,
            "to_account_type": "checking"
        })

        assert response.status_code == 201
        data = response.json()
        assert data["transaction"]["amount"] == 2
        assert data["exchangeRate"] == 7000

    def test_get_gold_rate(self, client):
        """Test getting gold rate."""
        response = client.get("/api/gold-rate")

        assert response.status_code == 200
        data = response.json()
        assert data["rate"] == 7000
        assert data["currency"] == "USD"

    def test_send_money(self, client):
        """Test sending money to another user."""
        client.post("/api/user", json={"id": "sender", "name": "Sender"})
        client.post("/api/user", json={"id": "receiver", "name": "Receiver"})

        response = client.post("/api/send", json={
            "from_user_id": "sender",
            "to_user_id": "receiver",
            "amount": 100
        })

        assert response.status_code == 201
        data = response.json()
        assert data["transaction"]["amount"] == 100

    def test_find_users(self, client):
        """Test finding users."""
        client.post("/api/user", json={"id": "alice", "name": "Alice Smith"})
        client.post("/api/user", json={"id": "bob", "name": "Bob Jones"})

        response = client.get("/api/users?search=alice")

        assert response.status_code == 200
        data = response.json()
        assert len(data) == 1
        assert data[0]["name"] == "Alice Smith"

    def test_get_transaction_history(self, client):
        """Test getting transaction history."""
        client.post("/api/user", json={"id": "hist_user", "name": "History User"})
        accounts = client.get("/api/user/hist_user/accounts").json()
        checking = next(a for a in accounts if a["type"] == "checking")

        # Create some transactions
        client.post("/api/deposit", json={"account_id": checking["id"], "amount": 100})
        client.post("/api/deposit", json={"account_id": checking["id"], "amount": 200})

        response = client.get("/api/user/hist_user/transactions")

        assert response.status_code == 200
        assert len(response.json()) == 2


class TestEnvironmentController:
    """Tests for environment endpoints."""

    def test_get_environment(self, client):
        """Test getting environment."""
        response = client.get("/api/environment")

        assert response.status_code == 200
        data = response.json()
        assert "temperature" in data
        assert "humidity" in data

    def test_update_environment(self, client):
        """Test updating environment."""
        response = client.put("/api/environment", json={
            "temperature": 30,
            "humidity": 70
        })

        assert response.status_code == 200
        data = response.json()
        assert data["temperature"] == 30
        assert data["humidity"] == 70

    def test_reset_environment(self, client):
        """Test resetting environment."""
        # Change some values
        client.put("/api/environment", json={"temperature": 40})

        response = client.post("/api/environment/reset")

        assert response.status_code == 200
        data = response.json()
        assert data["temperature"] == 20

    def test_get_adaptation_hints(self, client):
        """Test getting adaptation hints."""
        response = client.get("/api/environment/hints")

        assert response.status_code == 200
        data = response.json()
        assert "visual" in data
        assert "interaction" in data
