const Account = require('../models/account');
const Transaction = require('../models/transaction');
const User = require('../models/user');

// Exchange rate: 1 gold bar = $7000
const GOLD_BAR_VALUE = 7000;

const TransactionService = {
  // Transfer money between checking and savings accounts
  transfer(fromAccountId, toAccountId, amount, description = 'Transfer') {
    if (amount <= 0) {
      throw new Error('Amount must be positive');
    }

    const fromAccount = Account.findById(fromAccountId);
    const toAccount = Account.findById(toAccountId);

    if (!fromAccount) {
      throw new Error(`Source account not found: ${fromAccountId}`);
    }
    if (!toAccount) {
      throw new Error(`Destination account not found: ${toAccountId}`);
    }

    // Cannot transfer to/from treasure chest (it's gold bars only)
    if (fromAccount.type === 'treasure_chest' || toAccount.type === 'treasure_chest') {
      throw new Error('Cannot transfer to/from treasure chest. Use exchangeGold instead.');
    }

    // Check sufficient balance
    if (fromAccount.balance < amount) {
      throw new Error('Insufficient balance');
    }

    // Perform transfer
    Account.subtractFromBalance(fromAccountId, amount);
    Account.addToBalance(toAccountId, amount);

    // Record transaction
    return Transaction.create(fromAccountId, toAccountId, amount, 'transfer', description);
  },

  // Receive external payment (deposit)
  deposit(toAccountId, amount, description = 'Deposit') {
    if (amount <= 0) {
      throw new Error('Amount must be positive');
    }

    const toAccount = Account.findById(toAccountId);
    if (!toAccount) {
      throw new Error(`Account not found: ${toAccountId}`);
    }

    // Cannot deposit to treasure chest directly
    if (toAccount.type === 'treasure_chest') {
      throw new Error('Cannot deposit money to treasure chest');
    }

    // Add to balance
    Account.addToBalance(toAccountId, amount);

    // Record transaction (null from_account means external)
    return Transaction.create(null, toAccountId, amount, 'deposit', description);
  },

  // Make external payment (withdrawal)
  withdraw(fromAccountId, amount, description = 'Payment') {
    if (amount <= 0) {
      throw new Error('Amount must be positive');
    }

    const fromAccount = Account.findById(fromAccountId);
    if (!fromAccount) {
      throw new Error(`Account not found: ${fromAccountId}`);
    }

    // Cannot withdraw from treasure chest directly
    if (fromAccount.type === 'treasure_chest') {
      throw new Error('Cannot withdraw from treasure chest. Use exchangeGold first.');
    }

    // Check sufficient balance
    if (fromAccount.balance < amount) {
      throw new Error('Insufficient balance');
    }

    // Subtract from balance
    Account.subtractFromBalance(fromAccountId, amount);

    // Record transaction (null to_account means external)
    return Transaction.create(fromAccountId, null, amount, 'withdrawal', description);
  },

  // Collect a gold bar (from treasure chest in game)
  collectGoldBar(userId) {
    if (!User.exists(userId)) {
      throw new Error(`User not found: ${userId}`);
    }

    const treasureChest = Account.findByUserIdAndType(userId, 'treasure_chest');
    if (!treasureChest) {
      throw new Error('Treasure chest account not found');
    }

    // Add 1 gold bar
    Account.addToBalance(treasureChest.id, 1);

    // Record transaction
    return Transaction.create(null, treasureChest.id, 1, 'deposit', 'Gold bar collected from treasure chest');
  },

  // Exchange gold bars for cash
  exchangeGold(userId, bars, toAccountType = 'checking') {
    if (bars <= 0) {
      throw new Error('Number of bars must be positive');
    }

    if (!Number.isInteger(bars)) {
      throw new Error('Number of bars must be a whole number');
    }

    if (toAccountType !== 'checking' && toAccountType !== 'savings') {
      throw new Error('Can only exchange gold to checking or savings account');
    }

    if (!User.exists(userId)) {
      throw new Error(`User not found: ${userId}`);
    }

    const treasureChest = Account.findByUserIdAndType(userId, 'treasure_chest');
    const targetAccount = Account.findByUserIdAndType(userId, toAccountType);

    if (!treasureChest) {
      throw new Error('Treasure chest account not found');
    }
    if (!targetAccount) {
      throw new Error(`${toAccountType} account not found`);
    }

    // Check sufficient gold bars
    if (treasureChest.balance < bars) {
      throw new Error(`Insufficient gold bars. Have: ${treasureChest.balance}, need: ${bars}`);
    }

    const cashAmount = bars * GOLD_BAR_VALUE;

    // Remove gold bars from treasure chest
    Account.subtractFromBalance(treasureChest.id, bars);

    // Add cash to target account
    Account.addToBalance(targetAccount.id, cashAmount);

    // Record transaction
    return Transaction.create(
      treasureChest.id,
      targetAccount.id,
      cashAmount,
      'gold_exchange',
      `Exchanged ${bars} gold bar(s) for $${cashAmount}`
    );
  },

  // Get transaction history for a user
  getTransactionHistory(userId, limit = 50) {
    if (!User.exists(userId)) {
      throw new Error(`User not found: ${userId}`);
    }
    return Transaction.findByUserId(userId, limit);
  },

  // Get transaction history for a specific account
  getAccountTransactions(accountId, limit = 50) {
    const account = Account.findById(accountId);
    if (!account) {
      throw new Error(`Account not found: ${accountId}`);
    }
    return Transaction.findByAccountId(accountId, limit);
  },

  // Get the gold bar exchange rate
  getGoldBarValue() {
    return GOLD_BAR_VALUE;
  },

  // Send money from one user to another
  sendMoney(fromUserId, toUserId, amount, fromAccountType = 'checking', toAccountType = 'checking', description = '') {
    if (amount <= 0) {
      throw new Error('Amount must be positive');
    }

    if (fromUserId === toUserId) {
      throw new Error('Cannot send money to yourself. Use transfer instead.');
    }

    if (!User.exists(fromUserId)) {
      throw new Error(`Sender not found: ${fromUserId}`);
    }
    if (!User.exists(toUserId)) {
      throw new Error(`Recipient not found: ${toUserId}`);
    }

    const fromAccount = Account.findByUserIdAndType(fromUserId, fromAccountType);
    const toAccount = Account.findByUserIdAndType(toUserId, toAccountType);

    if (!fromAccount) {
      throw new Error(`Sender's ${fromAccountType} account not found`);
    }
    if (!toAccount) {
      throw new Error(`Recipient's ${toAccountType} account not found`);
    }

    if (fromAccountType === 'treasure_chest' || toAccountType === 'treasure_chest') {
      throw new Error('Cannot send money to/from treasure chest');
    }

    if (fromAccount.balance < amount) {
      throw new Error('Insufficient balance');
    }

    // Perform transfer
    Account.subtractFromBalance(fromAccount.id, amount);
    Account.addToBalance(toAccount.id, amount);

    // Record transaction
    const desc = description || `Payment to ${toUserId}`;
    return Transaction.create(fromAccount.id, toAccount.id, amount, 'transfer', desc);
  },

  // Find users (for recipient lookup)
  findUsers(searchTerm) {
    const allUsers = User.findAll();
    if (!searchTerm) {
      return allUsers;
    }
    const term = searchTerm.toLowerCase();
    return allUsers.filter(u =>
      u.id.toLowerCase().includes(term) ||
      u.name.toLowerCase().includes(term)
    );
  }
};

module.exports = TransactionService;
