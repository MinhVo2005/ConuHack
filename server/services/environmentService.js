const Environment = require('../models/environment');

const EnvironmentService = {
  getEnvironment() {
    const env = Environment.get();
    if (!env) {
      throw new Error('Environment not initialized');
    }
    return env;
  },

  updateEnvironment(data) {
    // Validate input
    if (data.temperature !== undefined && typeof data.temperature !== 'number') {
      throw new Error('Temperature must be a number');
    }
    if (data.humidity !== undefined && typeof data.humidity !== 'number') {
      throw new Error('Humidity must be a number');
    }
    if (data.wind_speed !== undefined && typeof data.wind_speed !== 'number') {
      throw new Error('Wind speed must be a number');
    }
    if (data.brightness !== undefined) {
      if (typeof data.brightness !== 'number' || data.brightness < 1 || data.brightness > 10) {
        throw new Error('Brightness must be a number between 1 and 10');
      }
    }
    if (data.noise !== undefined) {
      const validNoise = ['quiet', 'low', 'med', 'high', 'boomboom'];
      if (!validNoise.includes(data.noise)) {
        throw new Error(`Invalid noise level. Must be one of: ${validNoise.join(', ')}`);
      }
    }

    return Environment.update(data);
  },

  // Convenience methods for updating individual properties
  updateTemperature(temperature) {
    return this.updateEnvironment({ temperature });
  },

  updateHumidity(humidity) {
    return this.updateEnvironment({ humidity });
  },

  updateWindSpeed(wind_speed) {
    return this.updateEnvironment({ wind_speed });
  },

  updateNoise(noise) {
    return this.updateEnvironment({ noise });
  },

  updateBrightness(brightness) {
    return this.updateEnvironment({ brightness });
  },

  resetEnvironment() {
    return Environment.reset();
  },

  // Get environment state for UI adaptation hints
  getAdaptationHints() {
    const env = this.getEnvironment();

    const hints = {
      environment: env,
      adaptations: []
    };

    // Brightness adaptations
    if (env.brightness <= 3) {
      hints.adaptations.push({
        type: 'visual',
        action: 'high_contrast',
        reason: 'Low brightness detected'
      });
    } else if (env.brightness >= 8) {
      hints.adaptations.push({
        type: 'visual',
        action: 'reduce_brightness',
        reason: 'High brightness detected'
      });
    }

    // Noise adaptations
    if (env.noise === 'high' || env.noise === 'boomboom') {
      hints.adaptations.push({
        type: 'interaction',
        action: 'enable_haptic',
        reason: 'High noise level detected'
      });
      hints.adaptations.push({
        type: 'interaction',
        action: 'larger_buttons',
        reason: 'High noise level detected'
      });
    }

    if (env.noise === 'boomboom') {
      hints.adaptations.push({
        type: 'interaction',
        action: 'gesture_mode',
        reason: 'Extreme noise level detected'
      });
    }

    // Wind speed adaptations (shaky hands simulation)
    if (env.wind_speed > 20) {
      hints.adaptations.push({
        type: 'visual',
        action: 'larger_touch_targets',
        reason: 'High wind speed - potential instability'
      });
    }

    return hints;
  }
};

module.exports = EnvironmentService;
