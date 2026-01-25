const { getDb, saveDb } = require('./index');

const User = {
  create(id, name) {
    const db = getDb();
    const stmt = db.prepare('INSERT INTO users (id, name) VALUES (?, ?)');
    stmt.run([id, name]);
    stmt.free();
    saveDb();
    return this.findById(id);
  },

  findById(id) {
    const db = getDb();
    const stmt = db.prepare('SELECT id, name, created_at FROM users WHERE id = ?');
    stmt.bind([id]);

    if (!stmt.step()) {
      stmt.free();
      return null;
    }

    const row = stmt.get();
    stmt.free();

    return {
      id: row[0],
      name: row[1],
      created_at: row[2]
    };
  },

  findAll() {
    const db = getDb();
    const stmt = db.prepare('SELECT id, name, created_at FROM users');
    const results = [];

    while (stmt.step()) {
      const row = stmt.get();
      results.push({
        id: row[0],
        name: row[1],
        created_at: row[2]
      });
    }
    stmt.free();
    return results;
  },

  update(id, name) {
    const db = getDb();
    const stmt = db.prepare('UPDATE users SET name = ? WHERE id = ?');
    stmt.run([name, id]);
    stmt.free();
    saveDb();
    return this.findById(id);
  },

  delete(id) {
    const db = getDb();
    const stmt = db.prepare('DELETE FROM users WHERE id = ?');
    stmt.run([id]);
    stmt.free();
    saveDb();
  },

  exists(id) {
    return this.findById(id) !== null;
  }
};

module.exports = User;
