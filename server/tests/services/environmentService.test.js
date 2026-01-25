const { initDb, closeDb } = require('../../models');
const EnvironmentService = require('../../services/environmentService');
const Environment = require('../../models/environment');

describe('EnvironmentService', () => {
  beforeAll(async () => {
    await initDb(true);
  });

  afterAll(() => {
    closeDb();
  });

  beforeEach(() => {
    // Reset environment to defaults before each test
    Environment.reset();
  });

  describe('getEnvironment', () => {
    it('should return current environment', () => {
      const env = EnvironmentService.getEnvironment();

      expect(env.temperature).toBe(20);
      expect(env.humidity).toBe(50);
      expect(env.wind_speed).toBe(0);
      expect(env.noise).toBe('quiet');
      expect(env.brightness).toBe(5);
    });
  });

  describe('updateEnvironment', () => {
    it('should update environment with partial data', () => {
      const env = EnvironmentService.updateEnvironment({
        temperature: 30,
        noise: 'high'
      });

      expect(env.temperature).toBe(30);
      expect(env.noise).toBe('high');
      expect(env.humidity).toBe(50); // Unchanged
    });

    it('should update all environment properties', () => {
      const env = EnvironmentService.updateEnvironment({
        temperature: 35,
        humidity: 80,
        wind_speed: 25,
        noise: 'boomboom',
        brightness: 2
      });

      expect(env.temperature).toBe(35);
      expect(env.humidity).toBe(80);
      expect(env.wind_speed).toBe(25);
      expect(env.noise).toBe('boomboom');
      expect(env.brightness).toBe(2);
    });

    it('should throw error for invalid temperature type', () => {
      expect(() => {
        EnvironmentService.updateEnvironment({ temperature: 'hot' });
      }).toThrow('Temperature must be a number');
    });

    it('should throw error for invalid humidity type', () => {
      expect(() => {
        EnvironmentService.updateEnvironment({ humidity: 'wet' });
      }).toThrow('Humidity must be a number');
    });

    it('should throw error for invalid wind_speed type', () => {
      expect(() => {
        EnvironmentService.updateEnvironment({ wind_speed: 'fast' });
      }).toThrow('Wind speed must be a number');
    });

    it('should throw error for invalid brightness', () => {
      expect(() => {
        EnvironmentService.updateEnvironment({ brightness: 0 });
      }).toThrow('Brightness must be a number between 1 and 10');

      expect(() => {
        EnvironmentService.updateEnvironment({ brightness: 11 });
      }).toThrow('Brightness must be a number between 1 and 10');
    });

    it('should throw error for invalid noise level', () => {
      expect(() => {
        EnvironmentService.updateEnvironment({ noise: 'invalid' });
      }).toThrow('Invalid noise level');
    });
  });

  describe('convenience update methods', () => {
    it('should update temperature', () => {
      const env = EnvironmentService.updateTemperature(40);
      expect(env.temperature).toBe(40);
    });

    it('should update humidity', () => {
      const env = EnvironmentService.updateHumidity(90);
      expect(env.humidity).toBe(90);
    });

    it('should update wind speed', () => {
      const env = EnvironmentService.updateWindSpeed(30);
      expect(env.wind_speed).toBe(30);
    });

    it('should update noise', () => {
      const env = EnvironmentService.updateNoise('med');
      expect(env.noise).toBe('med');
    });

    it('should update brightness', () => {
      const env = EnvironmentService.updateBrightness(10);
      expect(env.brightness).toBe(10);
    });
  });

  describe('resetEnvironment', () => {
    it('should reset environment to defaults', () => {
      EnvironmentService.updateEnvironment({
        temperature: 100,
        humidity: 100,
        wind_speed: 100,
        noise: 'boomboom',
        brightness: 1
      });

      const env = EnvironmentService.resetEnvironment();

      expect(env.temperature).toBe(20);
      expect(env.humidity).toBe(50);
      expect(env.wind_speed).toBe(0);
      expect(env.noise).toBe('quiet');
      expect(env.brightness).toBe(5);
    });
  });

  describe('getAdaptationHints', () => {
    it('should return high contrast hint for low brightness', () => {
      EnvironmentService.updateBrightness(2);
      const hints = EnvironmentService.getAdaptationHints();

      expect(hints.adaptations).toContainEqual({
        type: 'visual',
        action: 'high_contrast',
        reason: 'Low brightness detected'
      });
    });

    it('should return reduce brightness hint for high brightness', () => {
      EnvironmentService.updateBrightness(9);
      const hints = EnvironmentService.getAdaptationHints();

      expect(hints.adaptations).toContainEqual({
        type: 'visual',
        action: 'reduce_brightness',
        reason: 'High brightness detected'
      });
    });

    it('should return haptic hint for high noise', () => {
      EnvironmentService.updateNoise('high');
      const hints = EnvironmentService.getAdaptationHints();

      expect(hints.adaptations).toContainEqual({
        type: 'interaction',
        action: 'enable_haptic',
        reason: 'High noise level detected'
      });
    });

    it('should return gesture mode hint for boomboom noise', () => {
      EnvironmentService.updateNoise('boomboom');
      const hints = EnvironmentService.getAdaptationHints();

      expect(hints.adaptations).toContainEqual({
        type: 'interaction',
        action: 'gesture_mode',
        reason: 'Extreme noise level detected'
      });
    });

    it('should return larger touch targets for high wind', () => {
      EnvironmentService.updateWindSpeed(25);
      const hints = EnvironmentService.getAdaptationHints();

      expect(hints.adaptations).toContainEqual({
        type: 'visual',
        action: 'larger_touch_targets',
        reason: 'High wind speed - potential instability'
      });
    });

    it('should return empty adaptations for normal environment', () => {
      const hints = EnvironmentService.getAdaptationHints();

      expect(hints.adaptations).toHaveLength(0);
    });
  });
});
