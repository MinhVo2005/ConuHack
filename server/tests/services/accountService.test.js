const { initDb, closeDb } = require('../../models');
const UserService = require('../../services/userService');
const AccountService = require('../../services/accountService');
const User = require('../../models/user');
const Account = require('../../models/account');

describe('AccountService', () => {
  let testUser;

  beforeAll(async () => {
    await initDb(true);
  });

  afterAll(() => {
    closeDb();
  });

  beforeEach(() => {
    // Clean up
    const users = User.findAll();
    for (const user of users) {
      const accounts = Account.findByUserId(user.id);
      for (const account of accounts) {
        Account.delete(account.id);
      }
      User.delete(user.id);
    }

    // Create a test user
    testUser = UserService.createUser('testuser', 'Test User');
  });

  describe('getAccount', () => {
    it('should return account by id', () => {
      const checkingId = testUser.accounts.find(a => a.type === 'checking').id;
      const account = AccountService.getAccount(checkingId);

      expect(account.id).toBe(checkingId);
      expect(account.type).toBe('checking');
    });

    it('should throw error if account not found', () => {
      expect(() => {
        AccountService.getAccount(99999);
      }).toThrow('Account not found: 99999');
    });
  });

  describe('getAccountsByUserId', () => {
    it('should return all accounts for a user', () => {
      const accounts = AccountService.getAccountsByUserId('testuser');

      expect(accounts).toHaveLength(3);
      expect(accounts.map(a => a.type).sort()).toEqual(['checking', 'savings', 'treasure_chest']);
    });

    it('should throw error if user not found', () => {
      expect(() => {
        AccountService.getAccountsByUserId('nonexistent');
      }).toThrow('User not found: nonexistent');
    });
  });

  describe('getAccountByType', () => {
    it('should return account by type', () => {
      const checking = AccountService.getAccountByType('testuser', 'checking');

      expect(checking.type).toBe('checking');
      expect(checking.balance).toBe(1000);
    });

    it('should throw error if account type not found', () => {
      // This shouldn't happen normally, but test the error handling
      expect(() => {
        AccountService.getAccountByType('nonexistent', 'checking');
      }).toThrow('User not found: nonexistent');
    });
  });

  describe('getBalance', () => {
    it('should return balance for account', () => {
      const checkingId = testUser.accounts.find(a => a.type === 'checking').id;
      const balance = AccountService.getBalance(checkingId);

      expect(balance).toBe(1000);
    });
  });

  describe('getBalanceByType', () => {
    it('should return balance by account type', () => {
      const balance = AccountService.getBalanceByType('testuser', 'savings');

      expect(balance).toBe(500);
    });
  });

  describe('updateBalance', () => {
    it('should update account balance', () => {
      const checkingId = testUser.accounts.find(a => a.type === 'checking').id;
      const result = AccountService.updateBalance(checkingId, 2000);

      expect(result.balance).toBe(2000);
    });

    it('should throw error for negative balance', () => {
      const checkingId = testUser.accounts.find(a => a.type === 'checking').id;

      expect(() => {
        AccountService.updateBalance(checkingId, -100);
      }).toThrow('Balance cannot be negative');
    });
  });

  describe('addToBalance', () => {
    it('should add to account balance', () => {
      const checkingId = testUser.accounts.find(a => a.type === 'checking').id;
      const result = AccountService.addToBalance(checkingId, 500);

      expect(result.balance).toBe(1500);
    });

    it('should throw error for non-positive amount', () => {
      const checkingId = testUser.accounts.find(a => a.type === 'checking').id;

      expect(() => {
        AccountService.addToBalance(checkingId, 0);
      }).toThrow('Amount must be positive');

      expect(() => {
        AccountService.addToBalance(checkingId, -100);
      }).toThrow('Amount must be positive');
    });
  });

  describe('subtractFromBalance', () => {
    it('should subtract from account balance', () => {
      const checkingId = testUser.accounts.find(a => a.type === 'checking').id;
      const result = AccountService.subtractFromBalance(checkingId, 300);

      expect(result.balance).toBe(700);
    });

    it('should throw error for insufficient balance', () => {
      const checkingId = testUser.accounts.find(a => a.type === 'checking').id;

      expect(() => {
        AccountService.subtractFromBalance(checkingId, 2000);
      }).toThrow('Insufficient balance');
    });

    it('should throw error for non-positive amount', () => {
      const checkingId = testUser.accounts.find(a => a.type === 'checking').id;

      expect(() => {
        AccountService.subtractFromBalance(checkingId, 0);
      }).toThrow('Amount must be positive');
    });
  });

  describe('getAccountSummary', () => {
    it('should return account summary', () => {
      const summary = AccountService.getAccountSummary('testuser');

      expect(summary.checking.balance).toBe(1000);
      expect(summary.savings.balance).toBe(500);
      expect(summary.treasure_chest.balance).toBe(0);
      expect(summary.total_cash).toBe(1500);
      expect(summary.gold_bars).toBe(0);
    });
  });
});
