const UserService = require('../services/userService');

const UserController = {
  // GET /api/user/:id
  getUser(req, res) {
    try {
      const user = UserService.getUserWithAccounts(req.params.id);
      res.json(user);
    } catch (error) {
      if (error.message.includes('not found')) {
        res.status(404).json({ error: error.message });
      } else {
        res.status(500).json({ error: error.message });
      }
    }
  },

  // POST /api/user
  createUser(req, res) {
    try {
      const { id, name } = req.body;

      if (!id) {
        return res.status(400).json({ error: 'User ID is required' });
      }

      const user = UserService.createUser(id, name || 'Explorer');
      res.status(201).json(user);
    } catch (error) {
      if (error.message.includes('already exists')) {
        res.status(409).json({ error: error.message });
      } else {
        res.status(500).json({ error: error.message });
      }
    }
  },

  // POST /api/user/get-or-create
  getOrCreateUser(req, res) {
    try {
      const { id, name } = req.body;

      if (!id) {
        return res.status(400).json({ error: 'User ID is required' });
      }

      const user = UserService.getOrCreateUser(id, name || 'Explorer');
      res.json(user);
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  },

  // PUT /api/user/:id
  updateUser(req, res) {
    try {
      const { name } = req.body;

      if (!name) {
        return res.status(400).json({ error: 'Name is required' });
      }

      const user = UserService.updateUserName(req.params.id, name);
      res.json(user);
    } catch (error) {
      if (error.message.includes('not found')) {
        res.status(404).json({ error: error.message });
      } else {
        res.status(500).json({ error: error.message });
      }
    }
  },

  // DELETE /api/user/:id
  deleteUser(req, res) {
    try {
      UserService.deleteUser(req.params.id);
      res.status(204).send();
    } catch (error) {
      if (error.message.includes('not found')) {
        res.status(404).json({ error: error.message });
      } else {
        res.status(500).json({ error: error.message });
      }
    }
  }
};

module.exports = UserController;
