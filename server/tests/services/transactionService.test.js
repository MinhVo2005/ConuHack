const { initDb, closeDb, getDb } = require('../../models');
const UserService = require('../../services/userService');
const TransactionService = require('../../services/transactionService');
const AccountService = require('../../services/accountService');
const User = require('../../models/user');
const Account = require('../../models/account');
const Transaction = require('../../models/transaction');

describe('TransactionService', () => {
  let testUser;
  let checkingId;
  let savingsId;
  let treasureChestId;

  beforeAll(async () => {
    await initDb(true);
  });

  afterAll(() => {
    closeDb();
  });

  beforeEach(() => {
    const db = getDb();

    // Clean up transactions first
    db.run('DELETE FROM transactions');

    // Clean up accounts
    db.run('DELETE FROM accounts');

    // Clean up users
    db.run('DELETE FROM users');

    // Reset auto-increment counters
    db.run('DELETE FROM sqlite_sequence');

    // Create a test user
    testUser = UserService.createUser('testuser', 'Test User');
    checkingId = testUser.accounts.find(a => a.type === 'checking').id;
    savingsId = testUser.accounts.find(a => a.type === 'savings').id;
    treasureChestId = testUser.accounts.find(a => a.type === 'treasure_chest').id;
  });

  describe('transfer', () => {
    it('should transfer money between checking and savings', () => {
      const transaction = TransactionService.transfer(checkingId, savingsId, 200, 'Test transfer');

      expect(transaction.type).toBe('transfer');
      expect(transaction.amount).toBe(200);

      const checking = AccountService.getAccount(checkingId);
      const savings = AccountService.getAccount(savingsId);

      expect(checking.balance).toBe(800);
      expect(savings.balance).toBe(700);
    });

    it('should throw error for insufficient balance', () => {
      expect(() => {
        TransactionService.transfer(checkingId, savingsId, 2000);
      }).toThrow('Insufficient balance');
    });

    it('should throw error for non-positive amount', () => {
      expect(() => {
        TransactionService.transfer(checkingId, savingsId, 0);
      }).toThrow('Amount must be positive');
    });

    it('should throw error for transfer to/from treasure chest', () => {
      expect(() => {
        TransactionService.transfer(checkingId, treasureChestId, 100);
      }).toThrow('Cannot transfer to/from treasure chest');

      expect(() => {
        TransactionService.transfer(treasureChestId, checkingId, 1);
      }).toThrow('Cannot transfer to/from treasure chest');
    });

    it('should throw error for nonexistent accounts', () => {
      expect(() => {
        TransactionService.transfer(99999, savingsId, 100);
      }).toThrow('Source account not found: 99999');

      expect(() => {
        TransactionService.transfer(checkingId, 99999, 100);
      }).toThrow('Destination account not found: 99999');
    });
  });

  describe('deposit', () => {
    it('should deposit money to account', () => {
      const transaction = TransactionService.deposit(checkingId, 500, 'Paycheck');

      expect(transaction.type).toBe('deposit');
      expect(transaction.amount).toBe(500);
      expect(transaction.from_account_id).toBeNull();

      const checking = AccountService.getAccount(checkingId);
      expect(checking.balance).toBe(1500);
    });

    it('should throw error for non-positive amount', () => {
      expect(() => {
        TransactionService.deposit(checkingId, 0);
      }).toThrow('Amount must be positive');
    });

    it('should throw error for deposit to treasure chest', () => {
      expect(() => {
        TransactionService.deposit(treasureChestId, 100);
      }).toThrow('Cannot deposit money to treasure chest');
    });
  });

  describe('withdraw', () => {
    it('should withdraw money from account', () => {
      const transaction = TransactionService.withdraw(checkingId, 300, 'ATM withdrawal');

      expect(transaction.type).toBe('withdrawal');
      expect(transaction.amount).toBe(300);
      expect(transaction.to_account_id).toBeNull();

      const checking = AccountService.getAccount(checkingId);
      expect(checking.balance).toBe(700);
    });

    it('should throw error for insufficient balance', () => {
      expect(() => {
        TransactionService.withdraw(checkingId, 2000);
      }).toThrow('Insufficient balance');
    });

    it('should throw error for withdrawal from treasure chest', () => {
      expect(() => {
        TransactionService.withdraw(treasureChestId, 1);
      }).toThrow('Cannot withdraw from treasure chest');
    });
  });

  describe('collectGoldBar', () => {
    it('should add a gold bar to treasure chest', () => {
      const transaction = TransactionService.collectGoldBar('testuser');

      expect(transaction.type).toBe('deposit');
      expect(transaction.amount).toBe(1);

      const treasureChest = AccountService.getAccount(treasureChestId);
      expect(treasureChest.balance).toBe(1);
    });

    it('should accumulate gold bars', () => {
      TransactionService.collectGoldBar('testuser');
      TransactionService.collectGoldBar('testuser');
      TransactionService.collectGoldBar('testuser');

      const treasureChest = AccountService.getAccount(treasureChestId);
      expect(treasureChest.balance).toBe(3);
    });

    it('should throw error for nonexistent user', () => {
      expect(() => {
        TransactionService.collectGoldBar('nonexistent');
      }).toThrow('User not found: nonexistent');
    });
  });

  describe('exchangeGold', () => {
    beforeEach(() => {
      // Add some gold bars
      TransactionService.collectGoldBar('testuser');
      TransactionService.collectGoldBar('testuser');
      TransactionService.collectGoldBar('testuser');
    });

    it('should exchange gold bars for cash (default to checking)', () => {
      const transaction = TransactionService.exchangeGold('testuser', 2);

      expect(transaction.type).toBe('gold_exchange');
      expect(transaction.amount).toBe(14000); // 2 bars * $7000

      const treasureChest = AccountService.getAccount(treasureChestId);
      const checking = AccountService.getAccount(checkingId);

      expect(treasureChest.balance).toBe(1); // 3 - 2 = 1
      expect(checking.balance).toBe(15000); // 1000 + 14000
    });

    it('should exchange gold bars to savings', () => {
      TransactionService.exchangeGold('testuser', 1, 'savings');

      const treasureChest = AccountService.getAccount(treasureChestId);
      const savings = AccountService.getAccount(savingsId);

      expect(treasureChest.balance).toBe(2);
      expect(savings.balance).toBe(7500); // 500 + 7000
    });

    it('should throw error for insufficient gold bars', () => {
      expect(() => {
        TransactionService.exchangeGold('testuser', 10);
      }).toThrow('Insufficient gold bars');
    });

    it('should throw error for non-positive bars', () => {
      expect(() => {
        TransactionService.exchangeGold('testuser', 0);
      }).toThrow('Number of bars must be positive');
    });

    it('should throw error for non-integer bars', () => {
      expect(() => {
        TransactionService.exchangeGold('testuser', 1.5);
      }).toThrow('Number of bars must be a whole number');
    });

    it('should throw error for invalid target account', () => {
      expect(() => {
        TransactionService.exchangeGold('testuser', 1, 'treasure_chest');
      }).toThrow('Can only exchange gold to checking or savings account');
    });
  });

  describe('getTransactionHistory', () => {
    it('should return transaction history for user', () => {
      TransactionService.deposit(checkingId, 100);
      TransactionService.transfer(checkingId, savingsId, 50);
      TransactionService.withdraw(savingsId, 25);

      const history = TransactionService.getTransactionHistory('testuser');

      expect(history).toHaveLength(3);
      expect(history[0].type).toBe('withdrawal'); // Most recent first
    });

    it('should throw error for nonexistent user', () => {
      expect(() => {
        TransactionService.getTransactionHistory('nonexistent');
      }).toThrow('User not found: nonexistent');
    });
  });

  describe('getGoldBarValue', () => {
    it('should return the gold bar exchange rate', () => {
      expect(TransactionService.getGoldBarValue()).toBe(7000);
    });
  });
});
