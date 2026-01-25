import pytest
from fastapi import HTTPException
from services.account_service import AccountService


class TestAccountService:
    """Tests for AccountService."""

    def test_get_account(self, db_session, sample_user):
        """Test getting an account by ID."""
        service = AccountService(db_session)
        checking = next(a for a in sample_user.accounts if a.type == "checking")

        account = service.get_account(checking.id)
        assert account.id == checking.id
        assert account.type == "checking"

    def test_get_account_not_found(self, db_session):
        """Test getting non-existent account."""
        service = AccountService(db_session)

        with pytest.raises(HTTPException) as exc_info:
            service.get_account(99999)

        assert exc_info.value.status_code == 404

    def test_get_accounts_by_user_id(self, db_session, sample_user):
        """Test getting all accounts for a user."""
        service = AccountService(db_session)
        accounts = service.get_accounts_by_user_id(sample_user.id)

        assert len(accounts) == 3
        types = {a.type for a in accounts}
        assert types == {"checking", "savings", "treasure_chest"}

    def test_get_account_by_type(self, db_session, sample_user):
        """Test getting account by type."""
        service = AccountService(db_session)

        checking = service.get_account_by_type(sample_user.id, "checking")
        assert checking.type == "checking"
        assert checking.balance == 1000

        savings = service.get_account_by_type(sample_user.id, "savings")
        assert savings.type == "savings"
        assert savings.balance == 500

    def test_get_account_by_type_not_found(self, db_session, sample_user):
        """Test getting non-existent account type."""
        service = AccountService(db_session)

        with pytest.raises(HTTPException) as exc_info:
            service.get_account_by_type(sample_user.id, "invalid_type")

        assert exc_info.value.status_code == 404

    def test_get_balance(self, db_session, sample_user):
        """Test getting account balance."""
        service = AccountService(db_session)
        checking = next(a for a in sample_user.accounts if a.type == "checking")

        balance = service.get_balance(checking.id)
        assert balance == 1000

    def test_get_balance_by_type(self, db_session, sample_user):
        """Test getting balance by account type."""
        service = AccountService(db_session)

        balance = service.get_balance_by_type(sample_user.id, "checking")
        assert balance == 1000

    def test_update_balance(self, db_session, sample_user):
        """Test updating account balance."""
        service = AccountService(db_session)
        checking = next(a for a in sample_user.accounts if a.type == "checking")

        updated = service.update_balance(checking.id, 2000)
        assert updated.balance == 2000

    def test_update_balance_negative_fails(self, db_session, sample_user):
        """Test that negative balance update fails."""
        service = AccountService(db_session)
        checking = next(a for a in sample_user.accounts if a.type == "checking")

        with pytest.raises(HTTPException) as exc_info:
            service.update_balance(checking.id, -100)

        assert exc_info.value.status_code == 400
        assert "negative" in exc_info.value.detail.lower()

    def test_add_to_balance(self, db_session, sample_user):
        """Test adding to account balance."""
        service = AccountService(db_session)
        checking = next(a for a in sample_user.accounts if a.type == "checking")

        updated = service.add_to_balance(checking.id, 500)
        assert updated.balance == 1500

    def test_add_to_balance_zero_fails(self, db_session, sample_user):
        """Test that adding zero/negative fails."""
        service = AccountService(db_session)
        checking = next(a for a in sample_user.accounts if a.type == "checking")

        with pytest.raises(HTTPException) as exc_info:
            service.add_to_balance(checking.id, 0)

        assert exc_info.value.status_code == 400

    def test_subtract_from_balance(self, db_session, sample_user):
        """Test subtracting from account balance."""
        service = AccountService(db_session)
        checking = next(a for a in sample_user.accounts if a.type == "checking")

        updated = service.subtract_from_balance(checking.id, 300)
        assert updated.balance == 700

    def test_subtract_from_balance_insufficient_funds(self, db_session, sample_user):
        """Test subtracting more than balance fails."""
        service = AccountService(db_session)
        checking = next(a for a in sample_user.accounts if a.type == "checking")

        with pytest.raises(HTTPException) as exc_info:
            service.subtract_from_balance(checking.id, 2000)

        assert exc_info.value.status_code == 400
        assert "insufficient" in exc_info.value.detail.lower()

    def test_get_account_summary(self, db_session, sample_user):
        """Test getting account summary."""
        service = AccountService(db_session)
        summary = service.get_account_summary(sample_user.id)

        assert len(summary["accounts"]) == 3
        assert summary["total_cash"] == 1500  # checking + savings
        assert summary["gold_bars"] == 0
