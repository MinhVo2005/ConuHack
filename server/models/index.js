const initSqlJs = require('sql.js');
const fs = require('fs');
const path = require('path');

const DB_PATH = path.join(__dirname, '..', 'game.db');

let db = null;

async function initDb(inMemory = false) {
  const SQL = await initSqlJs();

  if (inMemory) {
    db = new SQL.Database();
  } else {
    try {
      if (fs.existsSync(DB_PATH)) {
        const buffer = fs.readFileSync(DB_PATH);
        db = new SQL.Database(buffer);
      } else {
        db = new SQL.Database();
      }
    } catch (e) {
      db = new SQL.Database();
    }
  }

  createTables();
  if (!inMemory) saveDb();

  return db;
}

function createTables() {
  // Users table
  db.run(`
    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP
    )
  `);

  // Accounts table
  db.run(`
    CREATE TABLE IF NOT EXISTS accounts (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id TEXT NOT NULL,
      type TEXT NOT NULL CHECK (type IN ('checking', 'savings', 'treasure_chest')),
      name TEXT NOT NULL,
      balance REAL DEFAULT 0,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (user_id) REFERENCES users(id)
    )
  `);

  // Transactions table
  db.run(`
    CREATE TABLE IF NOT EXISTS transactions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      from_account_id INTEGER,
      to_account_id INTEGER,
      amount REAL NOT NULL,
      type TEXT NOT NULL CHECK (type IN ('transfer', 'deposit', 'withdrawal', 'gold_exchange')),
      description TEXT,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (from_account_id) REFERENCES accounts(id),
      FOREIGN KEY (to_account_id) REFERENCES accounts(id)
    )
  `);

  // Environment table (single row)
  db.run(`
    CREATE TABLE IF NOT EXISTS environment (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      temperature INTEGER DEFAULT 20,
      humidity INTEGER DEFAULT 50,
      wind_speed INTEGER DEFAULT 0,
      noise TEXT DEFAULT 'quiet' CHECK (noise IN ('quiet', 'low', 'med', 'high', 'boomboom')),
      brightness INTEGER DEFAULT 5 CHECK (brightness >= 1 AND brightness <= 10),
      updated_at TEXT DEFAULT CURRENT_TIMESTAMP
    )
  `);

  // Insert default environment row if not exists
  const envExists = db.exec('SELECT COUNT(*) FROM environment');
  if (envExists[0].values[0][0] === 0) {
    db.run(`INSERT INTO environment (id) VALUES (1)`);
  }
}

function saveDb() {
  if (db && !db._inMemory) {
    const data = db.export();
    const buffer = Buffer.from(data);
    fs.writeFileSync(DB_PATH, buffer);
  }
}

function getDb() {
  return db;
}

function closeDb() {
  if (db) {
    db.close();
    db = null;
  }
}

module.exports = {
  initDb,
  getDb,
  saveDb,
  closeDb
};
