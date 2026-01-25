const EnvironmentService = require('../services/environmentService');

const EnvironmentController = {
  // GET /api/environment
  getEnvironment(req, res) {
    try {
      const environment = EnvironmentService.getEnvironment();
      res.json(environment);
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  },

  // PUT /api/environment
  updateEnvironment(req, res) {
    try {
      const { temperature, humidity, wind_speed, noise, brightness } = req.body;

      const environment = EnvironmentService.updateEnvironment({
        temperature,
        humidity,
        wind_speed,
        noise,
        brightness
      });
      res.json(environment);
    } catch (error) {
      if (error.message.includes('must be') || error.message.includes('Invalid')) {
        res.status(400).json({ error: error.message });
      } else {
        res.status(500).json({ error: error.message });
      }
    }
  },

  // POST /api/environment/reset
  resetEnvironment(req, res) {
    try {
      const environment = EnvironmentService.resetEnvironment();
      res.json(environment);
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  },

  // GET /api/environment/hints
  getAdaptationHints(req, res) {
    try {
      const hints = EnvironmentService.getAdaptationHints();
      res.json(hints);
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  }
};

module.exports = EnvironmentController;
