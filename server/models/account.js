const { getDb, saveDb } = require('./index');

const ACCOUNT_TYPES = ['checking', 'savings', 'treasure_chest'];

const Account = {
  create(userId, type, name, balance = 0) {
    if (!ACCOUNT_TYPES.includes(type)) {
      throw new Error(`Invalid account type: ${type}`);
    }

    const db = getDb();
    const stmt = db.prepare('INSERT INTO accounts (user_id, type, name, balance) VALUES (?, ?, ?, ?)');
    stmt.run([userId, type, name, balance]);
    stmt.free();

    // Get the last inserted ID BEFORE saveDb (saveDb resets last_insert_rowid)
    const idStmt = db.prepare('SELECT last_insert_rowid()');
    idStmt.step();
    const id = idStmt.get()[0];
    idStmt.free();

    saveDb();
    return this.findById(id);
  },

  findById(id) {
    const db = getDb();
    const stmt = db.prepare('SELECT id, user_id, type, name, balance, created_at, updated_at FROM accounts WHERE id = ?');
    stmt.bind([id]);

    if (!stmt.step()) {
      stmt.free();
      return null;
    }

    const row = stmt.get();
    stmt.free();

    return {
      id: row[0],
      user_id: row[1],
      type: row[2],
      name: row[3],
      balance: row[4],
      created_at: row[5],
      updated_at: row[6]
    };
  },

  findByUserId(userId) {
    const db = getDb();
    const stmt = db.prepare('SELECT id, user_id, type, name, balance, created_at, updated_at FROM accounts WHERE user_id = ?');
    stmt.bind([userId]);
    const results = [];

    while (stmt.step()) {
      const row = stmt.get();
      results.push({
        id: row[0],
        user_id: row[1],
        type: row[2],
        name: row[3],
        balance: row[4],
        created_at: row[5],
        updated_at: row[6]
      });
    }
    stmt.free();
    return results;
  },

  findByUserIdAndType(userId, type) {
    const db = getDb();
    const stmt = db.prepare('SELECT id, user_id, type, name, balance, created_at, updated_at FROM accounts WHERE user_id = ? AND type = ?');
    stmt.bind([userId, type]);

    if (!stmt.step()) {
      stmt.free();
      return null;
    }

    const row = stmt.get();
    stmt.free();

    return {
      id: row[0],
      user_id: row[1],
      type: row[2],
      name: row[3],
      balance: row[4],
      created_at: row[5],
      updated_at: row[6]
    };
  },

  updateBalance(id, balance) {
    const db = getDb();
    const stmt = db.prepare('UPDATE accounts SET balance = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?');
    stmt.run([balance, id]);
    stmt.free();
    saveDb();
    return this.findById(id);
  },

  addToBalance(id, amount) {
    const account = this.findById(id);
    if (!account) {
      throw new Error(`Account not found: ${id}`);
    }
    return this.updateBalance(id, account.balance + amount);
  },

  subtractFromBalance(id, amount) {
    const account = this.findById(id);
    if (!account) {
      throw new Error(`Account not found: ${id}`);
    }
    if (account.balance < amount) {
      throw new Error('Insufficient balance');
    }
    return this.updateBalance(id, account.balance - amount);
  },

  delete(id) {
    const db = getDb();
    const stmt = db.prepare('DELETE FROM accounts WHERE id = ?');
    stmt.run([id]);
    stmt.free();
    saveDb();
  }
};

module.exports = Account;
