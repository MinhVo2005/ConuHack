import pytest
from fastapi import HTTPException
from services.transaction_service import TransactionService, GOLD_BAR_VALUE
from services.account_service import AccountService


class TestTransactionService:
    """Tests for TransactionService."""

    def test_get_gold_bar_value(self, db_session):
        """Test getting gold bar value."""
        service = TransactionService(db_session)
        assert service.get_gold_bar_value() == 7000

    def test_transfer_between_accounts(self, db_session, sample_user):
        """Test transferring between user's accounts."""
        service = TransactionService(db_session)
        account_service = AccountService(db_session)

        checking = account_service.get_account_by_type(sample_user.id, "checking")
        savings = account_service.get_account_by_type(sample_user.id, "savings")

        transaction = service.transfer(checking.id, savings.id, 200)

        assert transaction.amount == 200
        assert transaction.type == "transfer"

        # Verify balances
        db_session.refresh(checking)
        db_session.refresh(savings)
        assert checking.balance == 800
        assert savings.balance == 700

    def test_transfer_insufficient_funds(self, db_session, sample_user):
        """Test transfer with insufficient funds fails."""
        service = TransactionService(db_session)
        account_service = AccountService(db_session)

        checking = account_service.get_account_by_type(sample_user.id, "checking")
        savings = account_service.get_account_by_type(sample_user.id, "savings")

        with pytest.raises(HTTPException) as exc_info:
            service.transfer(checking.id, savings.id, 5000)

        assert exc_info.value.status_code == 400
        assert "insufficient" in exc_info.value.detail.lower()

    def test_transfer_to_treasure_chest_fails(self, db_session, sample_user):
        """Test transfer to treasure chest fails."""
        service = TransactionService(db_session)
        account_service = AccountService(db_session)

        checking = account_service.get_account_by_type(sample_user.id, "checking")
        treasure = account_service.get_account_by_type(sample_user.id, "treasure_chest")

        with pytest.raises(HTTPException) as exc_info:
            service.transfer(checking.id, treasure.id, 100)

        assert exc_info.value.status_code == 400
        assert "treasure chest" in exc_info.value.detail.lower()

    def test_deposit(self, db_session, sample_user):
        """Test depositing funds."""
        service = TransactionService(db_session)
        account_service = AccountService(db_session)

        checking = account_service.get_account_by_type(sample_user.id, "checking")
        transaction = service.deposit(checking.id, 500)

        assert transaction.amount == 500
        assert transaction.type == "deposit"
        assert transaction.from_account_id is None

        db_session.refresh(checking)
        assert checking.balance == 1500

    def test_deposit_to_treasure_chest_fails(self, db_session, sample_user):
        """Test deposit to treasure chest fails."""
        service = TransactionService(db_session)
        account_service = AccountService(db_session)

        treasure = account_service.get_account_by_type(sample_user.id, "treasure_chest")

        with pytest.raises(HTTPException) as exc_info:
            service.deposit(treasure.id, 100)

        assert exc_info.value.status_code == 400

    def test_withdraw(self, db_session, sample_user):
        """Test withdrawing funds."""
        service = TransactionService(db_session)
        account_service = AccountService(db_session)

        checking = account_service.get_account_by_type(sample_user.id, "checking")
        transaction = service.withdraw(checking.id, 300)

        assert transaction.amount == 300
        assert transaction.type == "withdrawal"
        assert transaction.to_account_id is None

        db_session.refresh(checking)
        assert checking.balance == 700

    def test_withdraw_insufficient_funds(self, db_session, sample_user):
        """Test withdraw with insufficient funds fails."""
        service = TransactionService(db_session)
        account_service = AccountService(db_session)

        checking = account_service.get_account_by_type(sample_user.id, "checking")

        with pytest.raises(HTTPException) as exc_info:
            service.withdraw(checking.id, 5000)

        assert exc_info.value.status_code == 400

    def test_collect_gold_bar(self, db_session, sample_user):
        """Test collecting a gold bar."""
        service = TransactionService(db_session)
        account_service = AccountService(db_session)

        transaction = service.collect_gold_bar(sample_user.id)

        assert transaction.amount == 1
        assert transaction.type == "deposit"

        treasure = account_service.get_account_by_type(sample_user.id, "treasure_chest")
        assert treasure.balance == 1

    def test_exchange_gold(self, db_session, sample_user):
        """Test exchanging gold for cash."""
        service = TransactionService(db_session)
        account_service = AccountService(db_session)

        # First collect some gold
        for _ in range(5):
            service.collect_gold_bar(sample_user.id)

        # Exchange 3 bars
        transaction = service.exchange_gold(sample_user.id, 3, "checking")

        assert transaction.amount == 3
        assert transaction.type == "gold_exchange"

        # Verify balances
        treasure = account_service.get_account_by_type(sample_user.id, "treasure_chest")
        checking = account_service.get_account_by_type(sample_user.id, "checking")

        assert treasure.balance == 2  # 5 - 3
        assert checking.balance == 1000 + (3 * GOLD_BAR_VALUE)  # 1000 + 21000

    def test_exchange_gold_insufficient_bars(self, db_session, sample_user):
        """Test exchange with insufficient gold bars fails."""
        service = TransactionService(db_session)

        with pytest.raises(HTTPException) as exc_info:
            service.exchange_gold(sample_user.id, 10, "checking")

        assert exc_info.value.status_code == 400
        assert "insufficient" in exc_info.value.detail.lower()

    def test_exchange_gold_to_treasure_fails(self, db_session, sample_user):
        """Test exchange to treasure chest fails."""
        service = TransactionService(db_session)
        service.collect_gold_bar(sample_user.id)

        with pytest.raises(HTTPException) as exc_info:
            service.exchange_gold(sample_user.id, 1, "treasure_chest")

        assert exc_info.value.status_code == 400

    def test_send_money(self, db_session, sample_users):
        """Test sending money to another user."""
        service = TransactionService(db_session)
        account_service = AccountService(db_session)

        alice, bob = sample_users

        transaction = service.send_money(alice.id, bob.id, 100)

        assert transaction.amount == 100
        assert transaction.type == "transfer"

        # Verify balances
        alice_checking = account_service.get_account_by_type(alice.id, "checking")
        bob_checking = account_service.get_account_by_type(bob.id, "checking")

        assert alice_checking.balance == 900
        assert bob_checking.balance == 1100

    def test_send_money_to_self_fails(self, db_session, sample_user):
        """Test sending money to yourself fails."""
        service = TransactionService(db_session)

        with pytest.raises(HTTPException) as exc_info:
            service.send_money(sample_user.id, sample_user.id, 100)

        assert exc_info.value.status_code == 400
        assert "yourself" in exc_info.value.detail.lower()

    def test_send_money_from_treasure_fails(self, db_session, sample_users):
        """Test sending from treasure chest fails."""
        service = TransactionService(db_session)
        alice, bob = sample_users

        with pytest.raises(HTTPException) as exc_info:
            service.send_money(alice.id, bob.id, 100, "treasure_chest", "checking")

        assert exc_info.value.status_code == 400

    def test_get_transaction_history(self, db_session, sample_user):
        """Test getting transaction history."""
        service = TransactionService(db_session)
        account_service = AccountService(db_session)

        checking = account_service.get_account_by_type(sample_user.id, "checking")
        savings = account_service.get_account_by_type(sample_user.id, "savings")

        # Create some transactions
        service.transfer(checking.id, savings.id, 100)
        service.deposit(checking.id, 200)
        service.withdraw(savings.id, 50)

        history = service.get_transaction_history(sample_user.id)

        assert len(history) == 3

    def test_get_account_transactions(self, db_session, sample_user):
        """Test getting transactions for a specific account."""
        service = TransactionService(db_session)
        account_service = AccountService(db_session)

        checking = account_service.get_account_by_type(sample_user.id, "checking")
        savings = account_service.get_account_by_type(sample_user.id, "savings")

        # Create transactions
        service.transfer(checking.id, savings.id, 100)
        service.deposit(checking.id, 200)
        service.withdraw(savings.id, 50)

        checking_txns = service.get_account_transactions(checking.id)
        savings_txns = service.get_account_transactions(savings.id)

        assert len(checking_txns) == 2  # transfer + deposit
        assert len(savings_txns) == 2  # transfer + withdraw
