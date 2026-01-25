const AccountService = require('../services/accountService');

const AccountController = {
  // GET /api/user/:userId/accounts
  getAccounts(req, res) {
    try {
      const accounts = AccountService.getAccountsByUserId(req.params.userId);
      res.json(accounts);
    } catch (error) {
      if (error.message.includes('not found')) {
        res.status(404).json({ error: error.message });
      } else {
        res.status(500).json({ error: error.message });
      }
    }
  },

  // GET /api/user/:userId/accounts/summary
  getAccountSummary(req, res) {
    try {
      const summary = AccountService.getAccountSummary(req.params.userId);
      res.json(summary);
    } catch (error) {
      if (error.message.includes('not found')) {
        res.status(404).json({ error: error.message });
      } else {
        res.status(500).json({ error: error.message });
      }
    }
  },

  // GET /api/account/:id
  getAccount(req, res) {
    try {
      const account = AccountService.getAccount(parseInt(req.params.id));
      res.json(account);
    } catch (error) {
      if (error.message.includes('not found')) {
        res.status(404).json({ error: error.message });
      } else {
        res.status(500).json({ error: error.message });
      }
    }
  },

  // GET /api/user/:userId/accounts/:type
  getAccountByType(req, res) {
    try {
      const account = AccountService.getAccountByType(req.params.userId, req.params.type);
      res.json(account);
    } catch (error) {
      if (error.message.includes('not found')) {
        res.status(404).json({ error: error.message });
      } else {
        res.status(500).json({ error: error.message });
      }
    }
  },

  // GET /api/account/:id/balance
  getBalance(req, res) {
    try {
      const balance = AccountService.getBalance(parseInt(req.params.id));
      res.json({ balance });
    } catch (error) {
      if (error.message.includes('not found')) {
        res.status(404).json({ error: error.message });
      } else {
        res.status(500).json({ error: error.message });
      }
    }
  }
};

module.exports = AccountController;
