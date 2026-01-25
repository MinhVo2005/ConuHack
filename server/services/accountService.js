const Account = require('../models/account');
const User = require('../models/user');

const AccountService = {
  getAccount(id) {
    const account = Account.findById(id);
    if (!account) {
      throw new Error(`Account not found: ${id}`);
    }
    return account;
  },

  getAccountsByUserId(userId) {
    if (!User.exists(userId)) {
      throw new Error(`User not found: ${userId}`);
    }
    return Account.findByUserId(userId);
  },

  getAccountByType(userId, type) {
    if (!User.exists(userId)) {
      throw new Error(`User not found: ${userId}`);
    }
    const account = Account.findByUserIdAndType(userId, type);
    if (!account) {
      throw new Error(`Account of type ${type} not found for user ${userId}`);
    }
    return account;
  },

  getBalance(accountId) {
    const account = this.getAccount(accountId);
    return account.balance;
  },

  getBalanceByType(userId, type) {
    const account = this.getAccountByType(userId, type);
    return account.balance;
  },

  updateBalance(accountId, newBalance) {
    this.getAccount(accountId); // Throws if not found

    if (newBalance < 0) {
      throw new Error('Balance cannot be negative');
    }

    return Account.updateBalance(accountId, newBalance);
  },

  addToBalance(accountId, amount) {
    if (amount <= 0) {
      throw new Error('Amount must be positive');
    }
    return Account.addToBalance(accountId, amount);
  },

  subtractFromBalance(accountId, amount) {
    if (amount <= 0) {
      throw new Error('Amount must be positive');
    }

    const account = this.getAccount(accountId);
    if (account.balance < amount) {
      throw new Error('Insufficient balance');
    }

    return Account.subtractFromBalance(accountId, amount);
  },

  // Get summary of all accounts for a user
  getAccountSummary(userId) {
    const accounts = this.getAccountsByUserId(userId);

    const summary = {
      checking: null,
      savings: null,
      treasure_chest: null,
      total_cash: 0,
      gold_bars: 0
    };

    for (const account of accounts) {
      summary[account.type] = account;

      if (account.type === 'checking' || account.type === 'savings') {
        summary.total_cash += account.balance;
      } else if (account.type === 'treasure_chest') {
        summary.gold_bars = account.balance;
      }
    }

    return summary;
  }
};

module.exports = AccountService;
