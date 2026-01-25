const User = require('../models/user');
const Account = require('../models/account');

// Default starting balances
const DEFAULT_CHECKING_BALANCE = 1000;
const DEFAULT_SAVINGS_BALANCE = 500;
const DEFAULT_TREASURE_CHEST_BALANCE = 0;

const UserService = {
  createUser(id, name) {
    // Check if user already exists
    if (User.exists(id)) {
      throw new Error(`User already exists: ${id}`);
    }

    // Create user
    const user = User.create(id, name);

    // Create default accounts
    Account.create(user.id, 'checking', 'Checking Account', DEFAULT_CHECKING_BALANCE);
    Account.create(user.id, 'savings', 'Savings Account', DEFAULT_SAVINGS_BALANCE);
    Account.create(user.id, 'treasure_chest', 'Treasure Chest', DEFAULT_TREASURE_CHEST_BALANCE);

    return this.getUserWithAccounts(id);
  },

  getUser(id) {
    const user = User.findById(id);
    if (!user) {
      throw new Error(`User not found: ${id}`);
    }
    return user;
  },

  getUserWithAccounts(id) {
    const user = this.getUser(id);
    const accounts = Account.findByUserId(id);

    return {
      ...user,
      accounts
    };
  },

  getOrCreateUser(id, name = 'Explorer') {
    if (User.exists(id)) {
      return this.getUserWithAccounts(id);
    }
    return this.createUser(id, name);
  },

  updateUserName(id, name) {
    this.getUser(id); // Throws if not found
    return User.update(id, name);
  },

  deleteUser(id) {
    this.getUser(id); // Throws if not found

    // Delete all user's accounts first
    const accounts = Account.findByUserId(id);
    for (const account of accounts) {
      Account.delete(account.id);
    }

    // Delete user
    User.delete(id);
  }
};

module.exports = UserService;
