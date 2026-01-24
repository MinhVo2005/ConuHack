const initSqlJs = require('sql.js');
const fs = require('fs');
const path = require('path');

const DB_PATH = path.join(__dirname, 'game.db');

let db = null;

// Initialize database
async function initDb() {
  const SQL = await initSqlJs();

  // Load existing database or create new one
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

  // Create tables
  db.run(`
    CREATE TABLE IF NOT EXISTS players (
      id TEXT PRIMARY KEY,
      gold INTEGER DEFAULT 0,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      updated_at TEXT DEFAULT CURRENT_TIMESTAMP
    )
  `);

  saveDb();
  return db;
}

function saveDb() {
  if (db) {
    const data = db.export();
    const buffer = Buffer.from(data);
    fs.writeFileSync(DB_PATH, buffer);
  }
}

function getOrCreatePlayer(playerId) {
  const result = db.exec(`SELECT * FROM players WHERE id = '${playerId}'`);

  if (result.length === 0 || result[0].values.length === 0) {
    db.run(`INSERT INTO players (id, gold) VALUES ('${playerId}', 0)`);
    saveDb();
    return { id: playerId, gold: 0 };
  }

  const row = result[0].values[0];
  return {
    id: row[0],
    gold: row[1],
    created_at: row[2],
    updated_at: row[3]
  };
}

function updatePlayerGold(playerId, gold) {
  db.run(`UPDATE players SET gold = ${gold}, updated_at = CURRENT_TIMESTAMP WHERE id = '${playerId}'`);
  saveDb();
  return getOrCreatePlayer(playerId);
}

function getPlayerGold(playerId) {
  const player = getOrCreatePlayer(playerId);
  return player.gold;
}

module.exports = {
  initDb,
  getOrCreatePlayer,
  updatePlayerGold,
  getPlayerGold
};
