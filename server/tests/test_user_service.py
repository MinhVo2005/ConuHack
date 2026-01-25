import pytest
from fastapi import HTTPException
from services.user_service import UserService


class TestUserService:
    """Tests for UserService."""

    def test_create_user(self, db_session):
        """Test creating a new user."""
        service = UserService(db_session)
        user = service.create_user("new_user", "New User")

        assert user.id == "new_user"
        assert user.name == "New User"
        assert len(user.accounts) == 3

    def test_create_user_with_default_accounts(self, db_session):
        """Test that user is created with correct default accounts."""
        service = UserService(db_session)
        user = service.create_user("user_with_accounts", "Account User")

        account_types = {a.type: a for a in user.accounts}

        assert "checking" in account_types
        assert "savings" in account_types
        assert "treasure_chest" in account_types

        assert account_types["checking"].balance == 1000
        assert account_types["savings"].balance == 500
        assert account_types["treasure_chest"].balance == 0

    def test_create_user_duplicate(self, db_session, sample_user):
        """Test creating duplicate user raises error."""
        service = UserService(db_session)

        with pytest.raises(HTTPException) as exc_info:
            service.create_user(sample_user.id, "Duplicate")

        assert exc_info.value.status_code == 409
        assert "already exists" in exc_info.value.detail

    def test_get_user(self, db_session, sample_user):
        """Test getting an existing user."""
        service = UserService(db_session)
        user = service.get_user(sample_user.id)

        assert user.id == sample_user.id
        assert user.name == sample_user.name

    def test_get_user_not_found(self, db_session):
        """Test getting non-existent user raises error."""
        service = UserService(db_session)

        with pytest.raises(HTTPException) as exc_info:
            service.get_user("nonexistent_user")

        assert exc_info.value.status_code == 404

    def test_get_user_with_accounts(self, db_session, sample_user):
        """Test getting user with accounts loaded."""
        service = UserService(db_session)
        user = service.get_user_with_accounts(sample_user.id)

        assert user.id == sample_user.id
        assert len(user.accounts) == 3

    def test_get_or_create_user_existing(self, db_session, sample_user):
        """Test get_or_create with existing user."""
        service = UserService(db_session)
        user, created = service.get_or_create_user(sample_user.id, "Different Name")

        assert created is False
        assert user.id == sample_user.id
        assert user.name == sample_user.name  # Name not changed

    def test_get_or_create_user_new(self, db_session):
        """Test get_or_create with new user."""
        service = UserService(db_session)
        user, created = service.get_or_create_user("brand_new_user", "Brand New")

        assert created is True
        assert user.id == "brand_new_user"
        assert user.name == "Brand New"
        assert len(user.accounts) == 3

    def test_update_user_name(self, db_session, sample_user):
        """Test updating user name."""
        service = UserService(db_session)
        updated = service.update_user_name(sample_user.id, "Updated Name")

        assert updated.name == "Updated Name"

    def test_delete_user(self, db_session, sample_user):
        """Test deleting user."""
        service = UserService(db_session)
        service.delete_user(sample_user.id)

        assert service.user_exists(sample_user.id) is False

    def test_user_exists(self, db_session, sample_user):
        """Test checking if user exists."""
        service = UserService(db_session)

        assert service.user_exists(sample_user.id) is True
        assert service.user_exists("nonexistent") is False

    def test_find_users(self, db_session, sample_users):
        """Test searching for users."""
        service = UserService(db_session)

        results = service.find_users("Alice")
        assert len(results) == 1
        assert results[0].name == "Alice"

        results = service.find_users("user")
        assert len(results) == 2
