// Game constants
const TILE_SIZE = 48;  // Larger tiles = more zoom
const MAP_WIDTH = 60;  // tiles
const MAP_HEIGHT = 60; // tiles
const CANVAS_WIDTH = 800;
const CANVAS_HEIGHT = 600;

// Player
const PLAYER_SIZE = 32;
const PLAYER_SPEED = 1;

// Environment types
const ENV_TYPES = {
  BEACH: 'beach',
  CAVE: 'cave',
  JUNGLE: 'jungle',
  WINDY: 'windy',
  RAIN: 'rain',
  ARCTIC: 'arctic'
};

// Biome adjacency rules (which biomes can be neighbors)
const BIOME_ADJACENCY = {
  [ENV_TYPES.ARCTIC]: [ENV_TYPES.RAIN, ENV_TYPES.WINDY, ENV_TYPES.ARCTIC],
  [ENV_TYPES.RAIN]: [ENV_TYPES.ARCTIC, ENV_TYPES.WINDY, ENV_TYPES.JUNGLE, ENV_TYPES.RAIN],
  [ENV_TYPES.WINDY]: [ENV_TYPES.ARCTIC, ENV_TYPES.RAIN, ENV_TYPES.JUNGLE, ENV_TYPES.BEACH, ENV_TYPES.WINDY],
  [ENV_TYPES.JUNGLE]: [ENV_TYPES.RAIN, ENV_TYPES.WINDY, ENV_TYPES.BEACH, ENV_TYPES.JUNGLE],
  [ENV_TYPES.BEACH]: [ENV_TYPES.WINDY, ENV_TYPES.JUNGLE, ENV_TYPES.BEACH],
  [ENV_TYPES.CAVE]: [ENV_TYPES.CAVE] // Caves are isolated with walls
};

// Environment colors (pixel art palettes)
const ENV_COLORS = {
  [ENV_TYPES.BEACH]: {
    ground: ['#f4d03f', '#f7dc6f', '#f9e79f'],
    accent: '#e59866',
    name: 'Bright Beach'
  },
  [ENV_TYPES.CAVE]: {
    ground: ['#2c2c54', '#474787', '#3d3d6b'],
    accent: '#706fd3',
    name: 'Dark Cave'
  },
  [ENV_TYPES.JUNGLE]: {
    ground: ['#27ae60', '#2ecc71', '#58d68d'],
    accent: '#1e8449',
    name: 'Loud Jungle'
  },
  [ENV_TYPES.WINDY]: {
    ground: ['#a9cce3', '#d4e6f1', '#85c1e9'],
    accent: '#5dade2',
    name: 'Windy Plain'
  },
  [ENV_TYPES.RAIN]: {
    ground: ['#2d5a27', '#3d6b37', '#4a7a42'],
    accent: '#1e4620',
    name: 'Rainy Zone'
  },
  [ENV_TYPES.ARCTIC]: {
    ground: ['#ffffff', '#f5f5f5', '#e8e8e8'],
    accent: '#d0d0d0',
    name: 'Arctic Snow'
  }
};

// Environment properties
const ENV_PROPERTIES = {
  [ENV_TYPES.BEACH]: {
    brightness: 1.5,
    temperature: 35,
    humidity: 60,
    windSpeed: 5,
    soundLevel: 30
  },
  [ENV_TYPES.CAVE]: {
    brightness: 0.2,
    temperature: 15,
    humidity: 80,
    windSpeed: 0,
    soundLevel: 10
  },
  [ENV_TYPES.JUNGLE]: {
    brightness: 0.8,
    temperature: 28,
    humidity: 90,
    windSpeed: 5,
    soundLevel: 85  // Loud!
  },
  [ENV_TYPES.WINDY]: {
    brightness: 1.0,
    temperature: 18,
    humidity: 40,
    windSpeed: 50,
    windDirection: { x: 1, y: 0 },  // Will be randomized per zone
    soundLevel: 45
  },
  [ENV_TYPES.RAIN]: {
    brightness: 0.6,
    temperature: 12,
    humidity: 95,
    windSpeed: 20,
    soundLevel: 50
  },
  [ENV_TYPES.ARCTIC]: {
    brightness: 1.1,
    temperature: -15,
    humidity: 30,
    windSpeed: 30,
    soundLevel: 20
  }
};

// Treasure and obstacles
const TREASURE_GOLD_MIN = 10;
const TREASURE_GOLD_MAX = 100;
const OBSTACLE_GOLD_PENALTY = 5;
