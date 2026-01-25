const TransactionService = require('../services/transactionService');

const TransactionController = {
  // POST /api/transfer
  transfer(req, res) {
    try {
      const { fromAccountId, toAccountId, amount, description } = req.body;

      if (!fromAccountId || !toAccountId || amount === undefined) {
        return res.status(400).json({ error: 'fromAccountId, toAccountId, and amount are required' });
      }

      const transaction = TransactionService.transfer(
        parseInt(fromAccountId),
        parseInt(toAccountId),
        parseFloat(amount),
        description || 'Transfer'
      );
      res.status(201).json(transaction);
    } catch (error) {
      if (error.message.includes('not found')) {
        res.status(404).json({ error: error.message });
      } else if (error.message.includes('Insufficient') || error.message.includes('Cannot transfer')) {
        res.status(400).json({ error: error.message });
      } else {
        res.status(500).json({ error: error.message });
      }
    }
  },

  // POST /api/deposit
  deposit(req, res) {
    try {
      const { accountId, amount, description } = req.body;

      if (!accountId || amount === undefined) {
        return res.status(400).json({ error: 'accountId and amount are required' });
      }

      const transaction = TransactionService.deposit(
        parseInt(accountId),
        parseFloat(amount),
        description || 'Deposit'
      );
      res.status(201).json(transaction);
    } catch (error) {
      if (error.message.includes('not found')) {
        res.status(404).json({ error: error.message });
      } else if (error.message.includes('Cannot deposit')) {
        res.status(400).json({ error: error.message });
      } else {
        res.status(500).json({ error: error.message });
      }
    }
  },

  // POST /api/withdraw
  withdraw(req, res) {
    try {
      const { accountId, amount, description } = req.body;

      if (!accountId || amount === undefined) {
        return res.status(400).json({ error: 'accountId and amount are required' });
      }

      const transaction = TransactionService.withdraw(
        parseInt(accountId),
        parseFloat(amount),
        description || 'Withdrawal'
      );
      res.status(201).json(transaction);
    } catch (error) {
      if (error.message.includes('not found')) {
        res.status(404).json({ error: error.message });
      } else if (error.message.includes('Insufficient') || error.message.includes('Cannot withdraw')) {
        res.status(400).json({ error: error.message });
      } else {
        res.status(500).json({ error: error.message });
      }
    }
  },

  // POST /api/collect-gold
  collectGold(req, res) {
    try {
      const { userId } = req.body;

      if (!userId) {
        return res.status(400).json({ error: 'userId is required' });
      }

      const transaction = TransactionService.collectGoldBar(userId);
      res.status(201).json(transaction);
    } catch (error) {
      if (error.message.includes('not found')) {
        res.status(404).json({ error: error.message });
      } else {
        res.status(500).json({ error: error.message });
      }
    }
  },

  // POST /api/exchange-gold
  exchangeGold(req, res) {
    try {
      const { userId, bars, toAccountType } = req.body;

      if (!userId || bars === undefined) {
        return res.status(400).json({ error: 'userId and bars are required' });
      }

      const transaction = TransactionService.exchangeGold(
        userId,
        parseInt(bars),
        toAccountType || 'checking'
      );
      res.status(201).json({
        transaction,
        exchangeRate: TransactionService.getGoldBarValue(),
        totalCash: parseInt(bars) * TransactionService.getGoldBarValue()
      });
    } catch (error) {
      if (error.message.includes('not found')) {
        res.status(404).json({ error: error.message });
      } else if (error.message.includes('Insufficient') || error.message.includes('must be')) {
        res.status(400).json({ error: error.message });
      } else {
        res.status(500).json({ error: error.message });
      }
    }
  },

  // GET /api/user/:userId/transactions
  getTransactionHistory(req, res) {
    try {
      const limit = parseInt(req.query.limit) || 50;
      const transactions = TransactionService.getTransactionHistory(req.params.userId, limit);
      res.json(transactions);
    } catch (error) {
      if (error.message.includes('not found')) {
        res.status(404).json({ error: error.message });
      } else {
        res.status(500).json({ error: error.message });
      }
    }
  },

  // GET /api/account/:accountId/transactions
  getAccountTransactions(req, res) {
    try {
      const limit = parseInt(req.query.limit) || 50;
      const transactions = TransactionService.getAccountTransactions(
        parseInt(req.params.accountId),
        limit
      );
      res.json(transactions);
    } catch (error) {
      if (error.message.includes('not found')) {
        res.status(404).json({ error: error.message });
      } else {
        res.status(500).json({ error: error.message });
      }
    }
  },

  // GET /api/gold-rate
  getGoldRate(req, res) {
    res.json({
      rate: TransactionService.getGoldBarValue(),
      currency: 'USD',
      description: '1 gold bar = $' + TransactionService.getGoldBarValue()
    });
  }
};

module.exports = TransactionController;
