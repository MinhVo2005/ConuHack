const express = require('express');
const { createServer } = require('http');
const { Server } = require('socket.io');
const cors = require('cors');
const path = require('path');

// Import database
const { initDb } = require('./models');

// Import controllers
const UserController = require('./controllers/userController');
const AccountController = require('./controllers/accountController');
const TransactionController = require('./controllers/transactionController');
const EnvironmentController = require('./controllers/environmentController');

// Import services for socket handlers
const EnvironmentService = require('./services/environmentService');
const TransactionService = require('./services/transactionService');
const UserService = require('./services/userService');
const AccountService = require('./services/accountService');

const app = express();
const httpServer = createServer(app);
const io = new Server(httpServer, {
  cors: {
    origin: "*",
    methods: ["GET", "POST", "PUT", "DELETE"]
  }
});

app.use(cors());
app.use(express.json());

// Serve game static files
app.use('/game', express.static(path.join(__dirname, '../game')));

// ==================== REST API Routes ====================

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

// Environment routes
app.get('/api/environment', EnvironmentController.getEnvironment);
app.put('/api/environment', EnvironmentController.updateEnvironment);
app.post('/api/environment/reset', EnvironmentController.resetEnvironment);
app.get('/api/environment/hints', EnvironmentController.getAdaptationHints);

// ==================== Socket.io Real-time ====================

io.on('connection', (socket) => {
  console.log('Client connected:', socket.id);

  // Player joins with their ID
  socket.on('join', (playerId) => {
    socket.playerId = playerId;
    socket.join(playerId);

    try {
      const user = UserService.getOrCreateUser(playerId);
      socket.emit('userData', user);
      console.log(`Player ${playerId} joined`);
    } catch (error) {
      socket.emit('error', { message: error.message });
    }
  });

  // Get user data
  socket.on('getUser', (playerId) => {
    try {
      const user = UserService.getUserWithAccounts(playerId);
      socket.emit('userData', user);
    } catch (error) {
      socket.emit('error', { message: error.message });
    }
  });

  // Collect gold bar (from game)
  socket.on('collectGold', (playerId) => {
    try {
      const transaction = TransactionService.collectGoldBar(playerId);
      const summary = AccountService.getAccountSummary(playerId);

      // Broadcast to all clients in this player's room
      io.to(playerId).emit('goldCollected', {
        transaction,
        goldBars: summary.gold_bars
      });

      console.log(`Player ${playerId} collected a gold bar. Total: ${summary.gold_bars}`);
    } catch (error) {
      socket.emit('error', { message: error.message });
    }
  });

  // Exchange gold bars for cash
  socket.on('exchangeGold', (data) => {
    const { playerId, bars, toAccountType } = data;

    try {
      const transaction = TransactionService.exchangeGold(playerId, bars, toAccountType || 'checking');
      const summary = AccountService.getAccountSummary(playerId);

      io.to(playerId).emit('goldExchanged', {
        transaction,
        summary,
        exchangeRate: TransactionService.getGoldBarValue()
      });

      console.log(`Player ${playerId} exchanged ${bars} gold bars for $${bars * TransactionService.getGoldBarValue()}`);
    } catch (error) {
      socket.emit('error', { message: error.message });
    }
  });

  // Update environment (from game)
  socket.on('updateEnvironment', (data) => {
    try {
      const environment = EnvironmentService.updateEnvironment(data);
      const hints = EnvironmentService.getAdaptationHints();

      // Broadcast to all connected clients
      io.emit('environmentUpdated', {
        environment,
        hints
      });

      console.log('Environment updated:', environment);
    } catch (error) {
      socket.emit('error', { message: error.message });
    }
  });

  // Get current environment
  socket.on('getEnvironment', () => {
    try {
      const environment = EnvironmentService.getEnvironment();
      const hints = EnvironmentService.getAdaptationHints();
      socket.emit('environmentData', { environment, hints });
    } catch (error) {
      socket.emit('error', { message: error.message });
    }
  });

  // Transfer between accounts
  socket.on('transfer', (data) => {
    const { playerId, fromAccountId, toAccountId, amount, description } = data;

    try {
      const transaction = TransactionService.transfer(fromAccountId, toAccountId, amount, description);
      const summary = AccountService.getAccountSummary(playerId);

      io.to(playerId).emit('transferComplete', {
        transaction,
        summary
      });
    } catch (error) {
      socket.emit('error', { message: error.message });
    }
  });

  // Get account summary
  socket.on('getAccountSummary', (playerId) => {
    try {
      const summary = AccountService.getAccountSummary(playerId);
      socket.emit('accountSummary', summary);
    } catch (error) {
      socket.emit('error', { message: error.message });
    }
  });

  socket.on('disconnect', () => {
    console.log('Client disconnected:', socket.id);
  });
});

// ==================== Start Server ====================

const PORT = process.env.PORT || 3000;

async function start() {
  await initDb();
  console.log('Database initialized');

  httpServer.listen(PORT, () => {
    console.log(`Server running on http://localhost:${PORT}`);
    console.log(`Game available at http://localhost:${PORT}/game`);
    console.log('\nAPI Endpoints:');
    console.log('  User:');
    console.log('    GET    /api/user/:id');
    console.log('    POST   /api/user');
    console.log('    POST   /api/user/get-or-create');
    console.log('  Accounts:');
    console.log('    GET    /api/user/:userId/accounts');
    console.log('    GET    /api/user/:userId/accounts/summary');
    console.log('  Transactions:');
    console.log('    POST   /api/transfer');
    console.log('    POST   /api/deposit');
    console.log('    POST   /api/withdraw');
    console.log('    POST   /api/collect-gold');
    console.log('    POST   /api/exchange-gold');
    console.log('    GET    /api/gold-rate');
    console.log('  Environment:');
    console.log('    GET    /api/environment');
    console.log('    PUT    /api/environment');
    console.log('    GET    /api/environment/hints');
  });
}

start().catch(err => {
  console.error('Failed to start server:', err);
  process.exit(1);
});
