const { getDb, saveDb } = require('./index');

const TRANSACTION_TYPES = ['transfer', 'deposit', 'withdrawal', 'gold_exchange'];

const Transaction = {
  create(fromAccountId, toAccountId, amount, type, description = '') {
    if (!TRANSACTION_TYPES.includes(type)) {
      throw new Error(`Invalid transaction type: ${type}`);
    }

    const db = getDb();
    const stmt = db.prepare('INSERT INTO transactions (from_account_id, to_account_id, amount, type, description) VALUES (?, ?, ?, ?, ?)');
    stmt.run([fromAccountId, toAccountId, amount, type, description]);
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
    const stmt = db.prepare('SELECT id, from_account_id, to_account_id, amount, type, description, created_at FROM transactions WHERE id = ?');
    stmt.bind([id]);

    if (!stmt.step()) {
      stmt.free();
      return null;
    }

    const row = stmt.get();
    stmt.free();

    return {
      id: row[0],
      from_account_id: row[1],
      to_account_id: row[2],
      amount: row[3],
      type: row[4],
      description: row[5],
      created_at: row[6]
    };
  },

  findByAccountId(accountId, limit = 50) {
    const db = getDb();
    const stmt = db.prepare(
      `SELECT id, from_account_id, to_account_id, amount, type, description, created_at
       FROM transactions
       WHERE from_account_id = ? OR to_account_id = ?
       ORDER BY created_at DESC, id DESC
       LIMIT ?`
    );
    stmt.bind([accountId, accountId, limit]);
    const results = [];

    while (stmt.step()) {
      const row = stmt.get();
      results.push({
        id: row[0],
        from_account_id: row[1],
        to_account_id: row[2],
        amount: row[3],
        type: row[4],
        description: row[5],
        created_at: row[6]
      });
    }
    stmt.free();
    return results;
  },

  findByUserId(userId, limit = 50) {
    const db = getDb();
    const stmt = db.prepare(
      `SELECT t.id, t.from_account_id, t.to_account_id, t.amount, t.type, t.description, t.created_at
       FROM transactions t
       LEFT JOIN accounts a1 ON t.from_account_id = a1.id
       LEFT JOIN accounts a2 ON t.to_account_id = a2.id
       WHERE a1.user_id = ? OR a2.user_id = ?
       ORDER BY t.created_at DESC, t.id DESC
       LIMIT ?`
    );
    stmt.bind([userId, userId, limit]);
    const results = [];

    while (stmt.step()) {
      const row = stmt.get();
      results.push({
        id: row[0],
        from_account_id: row[1],
        to_account_id: row[2],
        amount: row[3],
        type: row[4],
        description: row[5],
        created_at: row[6]
      });
    }
    stmt.free();
    return results;
  },

  findAll(limit = 100) {
    const db = getDb();
    const stmt = db.prepare(
      `SELECT id, from_account_id, to_account_id, amount, type, description, created_at
       FROM transactions
       ORDER BY created_at DESC, id DESC
       LIMIT ?`
    );
    stmt.bind([limit]);
    const results = [];

    while (stmt.step()) {
      const row = stmt.get();
      results.push({
        id: row[0],
        from_account_id: row[1],
        to_account_id: row[2],
        amount: row[3],
        type: row[4],
        description: row[5],
        created_at: row[6]
      });
    }
    stmt.free();
    return results;
  }
};

module.exports = Transaction;
