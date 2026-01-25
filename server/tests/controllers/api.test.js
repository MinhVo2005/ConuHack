const request = require('supertest');
const express = require('express');
const { initDb, closeDb, getDb } = require('../../models');

// Import controllers
const UserController = require('../../controllers/userController');
const AccountController = require('../../controllers/accountController');
const TransactionController = require('../../controllers/transactionController');
const EnvironmentController = require('../../controllers/environmentController');

// Create test app
const app = express();
app.use(express.json());

// User routes
app.get('/api/user/:id', UserController.getUser);
app.post('/api/user', UserController.createUser);
app.post('/api/user/get-or-create', UserController.getOrCreateUser);
app.put('/api/user/:id', UserController.updateUser);
app.delete('/api/user/:id', UserController.deleteUser);

// Account routes
app.get('/api/user/:userId/accounts', AccountController.getAccounts);
app.get('/api/user/:userId/accounts/summary', AccountController.getAccountSummary);
app.get('/api/user/:userId/accounts/:type', AccountController.getAccountByType);
app.get('/api/account/:id', AccountController.getAccount);
app.get('/api/account/:id/balance', AccountController.getBalance);

// Transaction routes
app.post('/api/transfer', TransactionController.transfer);
app.post('/api/deposit', TransactionController.deposit);
app.post('/api/withdraw', TransactionController.withdraw);
app.post('/api/collect-gold', TransactionController.collectGold);
app.post('/api/exchange-gold', TransactionController.exchangeGold);
app.get('/api/user/:userId/transactions', TransactionController.getTransactionHistory);
app.get('/api/account/:accountId/transactions', TransactionController.getAccountTransactions);
app.get('/api/gold-rate', TransactionController.getGoldRate);
app.post('/api/send', TransactionController.sendMoney);
app.get('/api/users', TransactionController.findUsers);

// Environment routes
app.get('/api/environment', EnvironmentController.getEnvironment);
app.put('/api/environment', EnvironmentController.updateEnvironment);
app.post('/api/environment/reset', EnvironmentController.resetEnvironment);
app.get('/api/environment/hints', EnvironmentController.getAdaptationHints);

describe('API Controllers', () => {
  beforeAll(async () => {
    await initDb(true);
  });

  afterAll(() => {
    closeDb();
  });

  beforeEach(() => {
    const db = getDb();
    db.run('DELETE FROM transactions');
    db.run('DELETE FROM accounts');
    db.run('DELETE FROM users');
  });

  describe('User Controller', () => {
    it('POST /api/user - should create a user', async () => {
      const res = await request(app)
        .post('/api/user')
        .send({ id: 'user1', name: 'Test User' });

      expect(res.status).toBe(201);
      expect(res.body.id).toBe('user1');
      expect(res.body.name).toBe('Test User');
      expect(res.body.accounts).toHaveLength(3);
    });

    it('POST /api/user - should return 400 if id missing', async () => {
      const res = await request(app)
        .post('/api/user')
        .send({ name: 'Test User' });

      expect(res.status).toBe(400);
    });

    it('GET /api/user/:id - should get user with accounts', async () => {
      await request(app).post('/api/user').send({ id: 'user1', name: 'Test' });

      const res = await request(app).get('/api/user/user1');

      expect(res.status).toBe(200);
      expect(res.body.id).toBe('user1');
      expect(res.body.accounts).toHaveLength(3);
    });

    it('GET /api/user/:id - should return 404 for nonexistent user', async () => {
      const res = await request(app).get('/api/user/nonexistent');

      expect(res.status).toBe(404);
    });
  });

  describe('Account Controller', () => {
    beforeEach(async () => {
      await request(app).post('/api/user').send({ id: 'user1', name: 'Test' });
    });

    it('GET /api/user/:userId/accounts - should get all accounts', async () => {
      const res = await request(app).get('/api/user/user1/accounts');

      expect(res.status).toBe(200);
      expect(res.body).toHaveLength(3);
    });

    it('GET /api/user/:userId/accounts/summary - should get summary', async () => {
      const res = await request(app).get('/api/user/user1/accounts/summary');

      expect(res.status).toBe(200);
      expect(res.body.total_cash).toBe(1500);
      expect(res.body.gold_bars).toBe(0);
    });

    it('GET /api/user/:userId/accounts/:type - should get account by type', async () => {
      const res = await request(app).get('/api/user/user1/accounts/checking');

      expect(res.status).toBe(200);
      expect(res.body.type).toBe('checking');
      expect(res.body.balance).toBe(1000);
    });
  });

  describe('Transaction Controller', () => {
    let checkingId, savingsId, treasureChestId;

    beforeEach(async () => {
      const userRes = await request(app).post('/api/user').send({ id: 'user1', name: 'Test' });
      checkingId = userRes.body.accounts.find(a => a.type === 'checking').id;
      savingsId = userRes.body.accounts.find(a => a.type === 'savings').id;
      treasureChestId = userRes.body.accounts.find(a => a.type === 'treasure_chest').id;
    });

    it('POST /api/transfer - should transfer between accounts', async () => {
      const res = await request(app)
        .post('/api/transfer')
        .send({ fromAccountId: checkingId, toAccountId: savingsId, amount: 100 });

      expect(res.status).toBe(201);
      expect(res.body.amount).toBe(100);
      expect(res.body.type).toBe('transfer');
    });

    it('POST /api/deposit - should deposit to account', async () => {
      const res = await request(app)
        .post('/api/deposit')
        .send({ accountId: checkingId, amount: 500, description: 'Paycheck' });

      expect(res.status).toBe(201);
      expect(res.body.amount).toBe(500);
      expect(res.body.type).toBe('deposit');
    });

    it('POST /api/withdraw - should withdraw from account', async () => {
      const res = await request(app)
        .post('/api/withdraw')
        .send({ accountId: checkingId, amount: 200 });

      expect(res.status).toBe(201);
      expect(res.body.amount).toBe(200);
      expect(res.body.type).toBe('withdrawal');
    });

    it('POST /api/collect-gold - should collect gold bar', async () => {
      const res = await request(app)
        .post('/api/collect-gold')
        .send({ userId: 'user1' });

      expect(res.status).toBe(201);
      expect(res.body.amount).toBe(1);
    });

    it('POST /api/exchange-gold - should exchange gold for cash', async () => {
      // Collect 2 gold bars first
      await request(app).post('/api/collect-gold').send({ userId: 'user1' });
      await request(app).post('/api/collect-gold').send({ userId: 'user1' });

      const res = await request(app)
        .post('/api/exchange-gold')
        .send({ userId: 'user1', bars: 1 });

      expect(res.status).toBe(201);
      expect(res.body.exchangeRate).toBe(7000);
      expect(res.body.totalCash).toBe(7000);
    });

    it('GET /api/gold-rate - should return gold rate', async () => {
      const res = await request(app).get('/api/gold-rate');

      expect(res.status).toBe(200);
      expect(res.body.rate).toBe(7000);
    });

    it('GET /api/user/:userId/transactions - should get transaction history', async () => {
      await request(app).post('/api/deposit').send({ accountId: checkingId, amount: 100 });
      await request(app).post('/api/transfer').send({ fromAccountId: checkingId, toAccountId: savingsId, amount: 50 });

      const res = await request(app).get('/api/user/user1/transactions');

      expect(res.status).toBe(200);
      expect(res.body).toHaveLength(2);
    });

    it('POST /api/send - should send money between users', async () => {
      // Create second user
      await request(app).post('/api/user').send({ id: 'user2', name: 'User Two' });

      const res = await request(app)
        .post('/api/send')
        .send({ fromUserId: 'user1', toUserId: 'user2', amount: 250 });

      expect(res.status).toBe(201);
      expect(res.body.transaction.amount).toBe(250);
      expect(res.body.message).toContain('user1');
      expect(res.body.message).toContain('user2');

      // Verify balances
      const user1Summary = await request(app).get('/api/user/user1/accounts/summary');
      const user2Summary = await request(app).get('/api/user/user2/accounts/summary');

      expect(user1Summary.body.checking.balance).toBe(750); // 1000 - 250
      expect(user2Summary.body.checking.balance).toBe(1250); // 1000 + 250
    });

    it('POST /api/send - should return 400 for same user', async () => {
      const res = await request(app)
        .post('/api/send')
        .send({ fromUserId: 'user1', toUserId: 'user1', amount: 100 });

      expect(res.status).toBe(400);
      expect(res.body.error).toContain('yourself');
    });

    it('GET /api/users - should list all users', async () => {
      await request(app).post('/api/user').send({ id: 'alice', name: 'Alice' });
      await request(app).post('/api/user').send({ id: 'bob', name: 'Bob' });

      const res = await request(app).get('/api/users');

      expect(res.status).toBe(200);
      expect(res.body.length).toBeGreaterThanOrEqual(3); // user1, alice, bob
    });

    it('GET /api/users?search= - should filter users', async () => {
      await request(app).post('/api/user').send({ id: 'alice', name: 'Alice' });
      await request(app).post('/api/user').send({ id: 'bob', name: 'Bob' });

      const res = await request(app).get('/api/users?search=alice');

      expect(res.status).toBe(200);
      expect(res.body.length).toBe(1);
      expect(res.body[0].id).toBe('alice');
    });
  });

  describe('Environment Controller', () => {
    beforeEach(async () => {
      await request(app).post('/api/environment/reset');
    });

    it('GET /api/environment - should get current environment', async () => {
      const res = await request(app).get('/api/environment');

      expect(res.status).toBe(200);
      expect(res.body.temperature).toBe(20);
      expect(res.body.brightness).toBe(5);
      expect(res.body.noise).toBe('quiet');
    });

    it('PUT /api/environment - should update environment', async () => {
      const res = await request(app)
        .put('/api/environment')
        .send({ temperature: 35, noise: 'high' });

      expect(res.status).toBe(200);
      expect(res.body.temperature).toBe(35);
      expect(res.body.noise).toBe('high');
    });

    it('PUT /api/environment - should return 400 for invalid data', async () => {
      const res = await request(app)
        .put('/api/environment')
        .send({ brightness: 15 });

      expect(res.status).toBe(400);
    });

    it('POST /api/environment/reset - should reset environment', async () => {
      await request(app).put('/api/environment').send({ temperature: 100 });

      const res = await request(app).post('/api/environment/reset');

      expect(res.status).toBe(200);
      expect(res.body.temperature).toBe(20);
    });

    it('GET /api/environment/hints - should get adaptation hints', async () => {
      await request(app).put('/api/environment').send({ brightness: 2, noise: 'boomboom' });

      const res = await request(app).get('/api/environment/hints');

      expect(res.status).toBe(200);
      expect(res.body.adaptations.length).toBeGreaterThan(0);
    });
  });
});
