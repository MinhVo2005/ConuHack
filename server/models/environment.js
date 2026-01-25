const { getDb, saveDb } = require('./index');

const NOISE_LEVELS = ['quiet', 'low', 'med', 'high', 'boomboom'];

const Environment = {
  get() {
    const db = getDb();
    const stmt = db.prepare('SELECT temperature, humidity, wind_speed, noise, brightness, updated_at FROM environment WHERE id = 1');

    if (!stmt.step()) {
      stmt.free();
      return null;
    }

    const row = stmt.get();
    stmt.free();

    return {
      temperature: row[0],
      humidity: row[1],
      wind_speed: row[2],
      noise: row[3],
      brightness: row[4],
      updated_at: row[5]
    };
  },

  update(data) {
    const db = getDb();
    const current = this.get();

    const temperature = data.temperature !== undefined ? data.temperature : current.temperature;
    const humidity = data.humidity !== undefined ? data.humidity : current.humidity;
    const wind_speed = data.wind_speed !== undefined ? data.wind_speed : current.wind_speed;
    const noise = data.noise !== undefined ? data.noise : current.noise;
    const brightness = data.brightness !== undefined ? data.brightness : current.brightness;

    // Validate noise level
    if (!NOISE_LEVELS.includes(noise)) {
      throw new Error(`Invalid noise level: ${noise}`);
    }

    // Validate brightness
    if (brightness < 1 || brightness > 10) {
      throw new Error(`Brightness must be between 1 and 10`);
    }

    const stmt = db.prepare(
      `UPDATE environment
       SET temperature = ?, humidity = ?, wind_speed = ?, noise = ?, brightness = ?, updated_at = CURRENT_TIMESTAMP
       WHERE id = 1`
    );
    stmt.run([temperature, humidity, wind_speed, noise, brightness]);
    stmt.free();
    saveDb();

    return this.get();
  },

  reset() {
    const db = getDb();
    db.run(
      `UPDATE environment
       SET temperature = 20, humidity = 50, wind_speed = 0, noise = 'quiet', brightness = 5, updated_at = CURRENT_TIMESTAMP
       WHERE id = 1`
    );
    saveDb();
    return this.get();
  }
};

module.exports = Environment;
