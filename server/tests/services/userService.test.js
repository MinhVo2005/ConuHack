const { initDb, closeDb } = require('../../models');
const UserService = require('../../services/userService');
const User = require('../../models/user');
const Account = require('../../models/account');

describe('UserService', () => {
  beforeAll(async () => {
    await initDb(true); // Use in-memory database for tests
  });

  afterAll(() => {
    closeDb();
  });

  beforeEach(() => {
    // Clean up users and accounts before each test
    const users = User.findAll();
    for (const user of users) {
      const accounts = Account.findByUserId(user.id);
      for (const account of accounts) {
        Account.delete(account.id);
      }
      User.delete(user.id);
    }
  });

  describe('createUser', () => {
    it('should create a user with default accounts', () => {
      const result = UserService.createUser('user1', 'Test User');

      expect(result.id).toBe('user1');
      expect(result.name).toBe('Test User');
      expect(result.accounts).toHaveLength(3);

      const checking = result.accounts.find(a => a.type === 'checking');
      const savings = result.accounts.find(a => a.type === 'savings');
      const treasureChest = result.accounts.find(a => a.type === 'treasure_chest');

      expect(checking.balance).toBe(1000);
      expect(savings.balance).toBe(500);
      expect(treasureChest.balance).toBe(0);
    });

    it('should throw error if user already exists', () => {
      UserService.createUser('user2', 'Test User');

      expect(() => {
        UserService.createUser('user2', 'Another Name');
      }).toThrow('User already exists: user2');
    });
  });

  describe('getUser', () => {
    it('should return user by id', () => {
      UserService.createUser('user3', 'Test User');
      const user = UserService.getUser('user3');

      expect(user.id).toBe('user3');
      expect(user.name).toBe('Test User');
    });

    it('should throw error if user not found', () => {
      expect(() => {
        UserService.getUser('nonexistent');
      }).toThrow('User not found: nonexistent');
    });
  });

  describe('getUserWithAccounts', () => {
    it('should return user with all accounts', () => {
      UserService.createUser('user4', 'Test User');
      const result = UserService.getUserWithAccounts('user4');

      expect(result.id).toBe('user4');
      expect(result.accounts).toHaveLength(3);
    });
  });

  describe('getOrCreateUser', () => {
    it('should create user if not exists', () => {
      const result = UserService.getOrCreateUser('user5', 'New User');

      expect(result.id).toBe('user5');
      expect(result.name).toBe('New User');
      expect(result.accounts).toHaveLength(3);
    });

    it('should return existing user if exists', () => {
      UserService.createUser('user6', 'Original Name');
      const result = UserService.getOrCreateUser('user6', 'Different Name');

      expect(result.id).toBe('user6');
      expect(result.name).toBe('Original Name'); // Should keep original name
    });
  });

  describe('updateUserName', () => {
    it('should update user name', () => {
      UserService.createUser('user7', 'Old Name');
      const result = UserService.updateUserName('user7', 'New Name');

      expect(result.name).toBe('New Name');
    });

    it('should throw error if user not found', () => {
      expect(() => {
        UserService.updateUserName('nonexistent', 'New Name');
      }).toThrow('User not found: nonexistent');
    });
  });

  describe('deleteUser', () => {
    it('should delete user and their accounts', () => {
      UserService.createUser('user8', 'Test User');
      UserService.deleteUser('user8');

      expect(User.exists('user8')).toBe(false);
      expect(Account.findByUserId('user8')).toHaveLength(0);
    });

    it('should throw error if user not found', () => {
      expect(() => {
        UserService.deleteUser('nonexistent');
      }).toThrow('User not found: nonexistent');
    });
  });
});
