// Map generation and management
class GameMap {
  constructor() {
    this.tiles = [];
    this.zones = [];
    this.treasures = [];
    this.obstacles = [];
    this.caveWalls = []; // Rock walls around caves
    this.generate();
  }

  generate() {
    // Initialize empty map
    for (let y = 0; y < MAP_HEIGHT; y++) {
      this.tiles[y] = [];
      for (let x = 0; x < MAP_WIDTH; x++) {
        this.tiles[y][x] = { type: null, variant: 0 };
      }
    }

    // Generate zones with adjacency rules
    this.generateZonesWithAdjacency();

    // Add cave walls
    this.generateCaveWalls();

    // Place treasures and obstacles
    this.placeTreasures();
    this.placeObstacles();
  }

  generateZonesWithAdjacency() {
    // Start with non-cave biomes for initial placement
    const normalBiomes = [ENV_TYPES.BEACH, ENV_TYPES.JUNGLE, ENV_TYPES.WINDY, ENV_TYPES.RAIN, ENV_TYPES.ARCTIC];

    // Create zone centers using a grid-based approach for better distribution
    const gridSize = 12; // Size of each zone roughly
    const numZonesX = Math.ceil(MAP_WIDTH / gridSize);
    const numZonesY = Math.ceil(MAP_HEIGHT / gridSize);

    // First pass: place zone centers
    for (let gy = 0; gy < numZonesY; gy++) {
      for (let gx = 0; gx < numZonesX; gx++) {
        const x = gx * gridSize + Math.floor(Math.random() * gridSize * 0.6) + gridSize * 0.2;
        const y = gy * gridSize + Math.floor(Math.random() * gridSize * 0.6) + gridSize * 0.2;

        this.zones.push({
          x: Math.min(MAP_WIDTH - 1, Math.floor(x)),
          y: Math.min(MAP_HEIGHT - 1, Math.floor(y)),
          type: null, // Will be assigned based on neighbors
          windDirection: {
            x: Math.random() * 2 - 1,
            y: Math.random() * 2 - 1
          }
        });
      }
    }

    // Normalize wind directions
    for (const zone of this.zones) {
      const len = Math.sqrt(zone.windDirection.x ** 2 + zone.windDirection.y ** 2);
      zone.windDirection.x /= len;
      zone.windDirection.y /= len;
    }

    // Second pass: assign biomes respecting adjacency
    // Start with a random biome for the first zone
    this.zones[0].type = normalBiomes[Math.floor(Math.random() * normalBiomes.length)];

    // Assign remaining zones based on neighbors
    for (let i = 1; i < this.zones.length; i++) {
      const zone = this.zones[i];
      const neighbors = this.getNeighborZones(zone, i);

      if (neighbors.length > 0) {
        // Find valid biomes based on all neighbors
        let validBiomes = [...normalBiomes];
        for (const neighbor of neighbors) {
          if (neighbor.type) {
            const allowed = BIOME_ADJACENCY[neighbor.type] || normalBiomes;
            validBiomes = validBiomes.filter(b => allowed.includes(b) && b !== ENV_TYPES.CAVE);
          }
        }

        if (validBiomes.length === 0) {
          validBiomes = [ENV_TYPES.WINDY, ENV_TYPES.RAIN]; // Fallback to temperate
        }

        zone.type = validBiomes[Math.floor(Math.random() * validBiomes.length)];
      } else {
        zone.type = normalBiomes[Math.floor(Math.random() * normalBiomes.length)];
      }
    }

    // Add some caves (they'll be isolated with walls)
    const numCaves = 3 + Math.floor(Math.random() * 3);
    for (let i = 0; i < numCaves; i++) {
      const caveZone = {
        x: 5 + Math.floor(Math.random() * (MAP_WIDTH - 10)),
        y: 5 + Math.floor(Math.random() * (MAP_HEIGHT - 10)),
        type: ENV_TYPES.CAVE,
        radius: 4 + Math.floor(Math.random() * 3), // Cave size
        entrances: [] // Will store entrance positions
      };

      // Determine 1-2 entrance directions
      const numEntrances = 1 + Math.floor(Math.random() * 2);
      const directions = ['north', 'south', 'east', 'west'];
      for (let e = 0; e < numEntrances; e++) {
        const dir = directions.splice(Math.floor(Math.random() * directions.length), 1)[0];
        caveZone.entrances.push(dir);
      }

      this.zones.push(caveZone);
    }

    // Assign each tile to nearest zone (with special handling for caves)
    for (let y = 0; y < MAP_HEIGHT; y++) {
      for (let x = 0; x < MAP_WIDTH; x++) {
        let minDist = Infinity;
        let nearestZone = this.zones[0];
        let inCave = false;

        // First check if inside any cave
        for (const zone of this.zones) {
          if (zone.type === ENV_TYPES.CAVE && zone.radius) {
            const dist = Math.sqrt((x - zone.x) ** 2 + (y - zone.y) ** 2);
            if (dist < zone.radius) {
              nearestZone = zone;
              inCave = true;
              break;
            }
          }
        }

        // If not in cave, find nearest normal zone
        if (!inCave) {
          for (const zone of this.zones) {
            if (zone.type === ENV_TYPES.CAVE) continue;

            // Use wrapping distance
            const dx = Math.min(Math.abs(x - zone.x), MAP_WIDTH - Math.abs(x - zone.x));
            const dy = Math.min(Math.abs(y - zone.y), MAP_HEIGHT - Math.abs(y - zone.y));
            const dist = Math.sqrt(dx * dx + dy * dy);

            if (dist < minDist) {
              minDist = dist;
              nearestZone = zone;
            }
          }
        }

        this.tiles[y][x] = {
          type: nearestZone.type,
          variant: Math.floor(Math.random() * 3),
          zone: nearestZone
        };
      }
    }
  }

  getNeighborZones(zone, currentIndex) {
    const neighbors = [];
    const maxDist = 15; // Maximum distance to consider a neighbor

    for (let i = 0; i < currentIndex; i++) {
      const other = this.zones[i];
      if (other.type === ENV_TYPES.CAVE) continue;

      const dist = Math.sqrt((zone.x - other.x) ** 2 + (zone.y - other.y) ** 2);
      if (dist < maxDist) {
        neighbors.push(other);
      }
    }

    return neighbors;
  }

  generateCaveWalls() {
    for (const zone of this.zones) {
      if (zone.type !== ENV_TYPES.CAVE || !zone.radius) continue;

      const radius = zone.radius;

      // Create walls around the cave perimeter
      for (let angle = 0; angle < Math.PI * 2; angle += 0.15) {
        const wallX = Math.floor(zone.x + Math.cos(angle) * radius);
        const wallY = Math.floor(zone.y + Math.sin(angle) * radius);

        if (wallX < 0 || wallX >= MAP_WIDTH || wallY < 0 || wallY >= MAP_HEIGHT) continue;

        // Check if this is an entrance
        let isEntrance = false;
        for (const entrance of zone.entrances) {
          const entranceAngle = {
            'north': -Math.PI / 2,
            'south': Math.PI / 2,
            'east': 0,
            'west': Math.PI
          }[entrance];

          const angleDiff = Math.abs(angle - entranceAngle);
          if (angleDiff < 0.4 || angleDiff > Math.PI * 2 - 0.4) {
            isEntrance = true;
            break;
          }
        }

        if (!isEntrance) {
          this.caveWalls.push({
            x: wallX * TILE_SIZE,
            y: wallY * TILE_SIZE,
            tileX: wallX,
            tileY: wallY,
            width: TILE_SIZE,
            height: TILE_SIZE
          });
        }
      }
    }
  }

  placeTreasures() {
    const numTreasures = 40 + Math.floor(Math.random() * 20);

    for (let i = 0; i < numTreasures; i++) {
      let x, y;
      let attempts = 0;

      do {
        x = Math.floor(Math.random() * MAP_WIDTH);
        y = Math.floor(Math.random() * MAP_HEIGHT);
        attempts++;
      } while (this.isOccupied(x, y) && attempts < 100);

      if (attempts < 100) {
        const gold = TREASURE_GOLD_MIN + Math.floor(Math.random() * (TREASURE_GOLD_MAX - TREASURE_GOLD_MIN));
        this.treasures.push({
          x: x * TILE_SIZE + TILE_SIZE / 2,
          y: y * TILE_SIZE + TILE_SIZE / 2,
          tileX: x,
          tileY: y,
          gold: gold,
          collected: false
        });
      }
    }
  }

  placeObstacles() {
    const numObstacles = 60 + Math.floor(Math.random() * 30);

    for (let i = 0; i < numObstacles; i++) {
      let x, y;
      let attempts = 0;

      do {
        x = Math.floor(Math.random() * MAP_WIDTH);
        y = Math.floor(Math.random() * MAP_HEIGHT);
        attempts++;
      } while (this.isOccupied(x, y) && attempts < 100);

      if (attempts < 100) {
        this.obstacles.push({
          x: x * TILE_SIZE,
          y: y * TILE_SIZE,
          tileX: x,
          tileY: y,
          width: TILE_SIZE,
          height: TILE_SIZE,
          type: this.tiles[y][x].type,
          destroyed: false
        });
      }
    }
  }

  isOccupied(x, y) {
    const centerX = Math.floor(MAP_WIDTH / 2);
    const centerY = Math.floor(MAP_HEIGHT / 2);

    if (Math.abs(x - centerX) < 3 && Math.abs(y - centerY) < 3) {
      return true;
    }

    // Check cave walls
    for (const wall of this.caveWalls) {
      if (wall.tileX === x && wall.tileY === y) return true;
    }

    for (const t of this.treasures) {
      if (t.tileX === x && t.tileY === y) return true;
    }

    for (const o of this.obstacles) {
      if (o.tileX === x && o.tileY === y) return true;
    }

    return false;
  }

  // Wrap coordinates for infinite map
  wrapCoordinates(x, y) {
    const maxX = MAP_WIDTH * TILE_SIZE;
    const maxY = MAP_HEIGHT * TILE_SIZE;

    let newX = x;
    let newY = y;

    if (newX < 0) newX += maxX;
    if (newX >= maxX) newX -= maxX;
    if (newY < 0) newY += maxY;
    if (newY >= maxY) newY -= maxY;

    return { x: newX, y: newY };
  }

  getTileAt(worldX, worldY) {
    const wrapped = this.wrapCoordinates(worldX, worldY);
    const tileX = Math.floor(wrapped.x / TILE_SIZE);
    const tileY = Math.floor(wrapped.y / TILE_SIZE);

    if (tileX < 0 || tileX >= MAP_WIDTH || tileY < 0 || tileY >= MAP_HEIGHT) {
      return null;
    }

    return this.tiles[tileY][tileX];
  }

  getEnvironmentAt(worldX, worldY) {
    const tile = this.getTileAt(worldX, worldY);
    if (!tile) return null;

    const envProps = { ...ENV_PROPERTIES[tile.type] };

    // Add wind direction for any zone with wind speed > 0
    if (tile.zone && tile.zone.windDirection && envProps.windSpeed > 0) {
      envProps.windDirection = tile.zone.windDirection;
    }

    return {
      type: tile.type,
      name: ENV_COLORS[tile.type].name,
      ...envProps
    };
  }

  draw(ctx, cameraX, cameraY) {
    const startTileX = Math.floor(cameraX / TILE_SIZE) - 1;
    const startTileY = Math.floor(cameraY / TILE_SIZE) - 1;
    const tilesX = Math.ceil(CANVAS_WIDTH / TILE_SIZE) + 3;
    const tilesY = Math.ceil(CANVAS_HEIGHT / TILE_SIZE) + 3;

    for (let y = startTileY; y < startTileY + tilesY; y++) {
      for (let x = startTileX; x < startTileX + tilesX; x++) {
        // Wrap tile coordinates
        const wrappedX = ((x % MAP_WIDTH) + MAP_WIDTH) % MAP_WIDTH;
        const wrappedY = ((y % MAP_HEIGHT) + MAP_HEIGHT) % MAP_HEIGHT;

        const tile = this.tiles[wrappedY][wrappedX];
        const colors = ENV_COLORS[tile.type].ground;
        const color = colors[tile.variant];

        const screenX = x * TILE_SIZE - cameraX;
        const screenY = y * TILE_SIZE - cameraY;

        // Draw tile
        ctx.fillStyle = color;
        ctx.fillRect(screenX, screenY, TILE_SIZE, TILE_SIZE);

        // Add pixel art detail
        ctx.fillStyle = colors[(tile.variant + 1) % 3];
        if ((wrappedX + wrappedY) % 3 === 0) {
          ctx.fillRect(screenX + 6, screenY + 6, 6, 6);
        }
        if ((wrappedX + wrappedY) % 5 === 0) {
          ctx.fillRect(screenX + 30, screenY + 30, 6, 6);
        }
      }
    }

    // Draw cave walls
    this.drawCaveWalls(ctx, cameraX, cameraY);

    // Draw obstacles
    this.drawObstacles(ctx, cameraX, cameraY);

    // Draw treasures
    this.drawTreasures(ctx, cameraX, cameraY);
  }

  drawCaveWalls(ctx, cameraX, cameraY) {
    for (const wall of this.caveWalls) {
      const screenX = wall.x - cameraX;
      const screenY = wall.y - cameraY;

      // Handle wrapping for drawing
      const offsets = [[0, 0]];
      if (wall.x < CANVAS_WIDTH) offsets.push([MAP_WIDTH * TILE_SIZE, 0]);
      if (wall.x > (MAP_WIDTH - 1) * TILE_SIZE - CANVAS_WIDTH) offsets.push([-MAP_WIDTH * TILE_SIZE, 0]);
      if (wall.y < CANVAS_HEIGHT) offsets.push([0, MAP_HEIGHT * TILE_SIZE]);
      if (wall.y > (MAP_HEIGHT - 1) * TILE_SIZE - CANVAS_HEIGHT) offsets.push([0, -MAP_HEIGHT * TILE_SIZE]);

      for (const [ox, oy] of offsets) {
        const drawX = screenX + ox;
        const drawY = screenY + oy;

        if (drawX < -TILE_SIZE || drawX > CANVAS_WIDTH ||
            drawY < -TILE_SIZE || drawY > CANVAS_HEIGHT) continue;

        // Draw rock wall (pixel art style)
        ctx.fillStyle = '#4a4a4a';
        ctx.fillRect(drawX, drawY, TILE_SIZE, TILE_SIZE);

        ctx.fillStyle = '#5a5a5a';
        ctx.fillRect(drawX + 4, drawY + 4, TILE_SIZE - 8, TILE_SIZE - 12);

        ctx.fillStyle = '#3a3a3a';
        ctx.fillRect(drawX, drawY + TILE_SIZE - 8, TILE_SIZE, 8);

        // Rock texture
        ctx.fillStyle = '#6a6a6a';
        ctx.fillRect(drawX + 8, drawY + 8, 8, 8);
        ctx.fillRect(drawX + 28, drawY + 20, 8, 8);
      }
    }
  }

  drawObstacles(ctx, cameraX, cameraY) {
    for (const obs of this.obstacles) {
      if (obs.destroyed) continue;

      const screenX = obs.x - cameraX;
      const screenY = obs.y - cameraY;

      if (screenX < -TILE_SIZE || screenX > CANVAS_WIDTH ||
          screenY < -TILE_SIZE || screenY > CANVAS_HEIGHT) continue;

      // Draw rock obstacle
      const baseColor = '#5d5d5d';
      const highlightColor = '#7d7d7d';
      const shadowColor = '#3d3d3d';

      ctx.fillStyle = baseColor;
      ctx.fillRect(screenX + 6, screenY + 12, TILE_SIZE - 12, TILE_SIZE - 16);

      ctx.fillStyle = highlightColor;
      ctx.fillRect(screenX + 12, screenY + 12, 12, 12);

      ctx.fillStyle = shadowColor;
      ctx.fillRect(screenX + 6, screenY + TILE_SIZE - 8, TILE_SIZE - 12, 6);
    }
  }

  drawTreasures(ctx, cameraX, cameraY) {
    for (const treasure of this.treasures) {
      if (treasure.collected) continue;

      const screenX = treasure.x - TILE_SIZE / 2 - cameraX;
      const screenY = treasure.y - TILE_SIZE / 2 - cameraY;

      if (screenX < -TILE_SIZE || screenX > CANVAS_WIDTH ||
          screenY < -TILE_SIZE || screenY > CANVAS_HEIGHT) continue;

      // Draw treasure chest
      ctx.fillStyle = '#8B4513';
      ctx.fillRect(screenX + 6, screenY + 16, TILE_SIZE - 12, TILE_SIZE - 20);

      ctx.fillStyle = '#A0522D';
      ctx.fillRect(screenX + 4, screenY + 12, TILE_SIZE - 8, 10);

      ctx.fillStyle = '#FFD700';
      ctx.fillRect(screenX + TILE_SIZE/2 - 6, screenY + 14, 12, 6);
      ctx.fillRect(screenX + TILE_SIZE/2 - 4, screenY + 22, 8, 12);

      ctx.fillStyle = '#DAA520';
      ctx.fillRect(screenX + TILE_SIZE/2 - 5, screenY + 26, 10, 8);
    }
  }

  checkTreasureCollision(playerX, playerY, playerSize) {
    const wrapped = this.wrapCoordinates(playerX, playerY);

    for (const treasure of this.treasures) {
      if (treasure.collected) continue;

      const dx = wrapped.x - treasure.x;
      const dy = wrapped.y - treasure.y;
      const dist = Math.sqrt(dx * dx + dy * dy);

      if (dist < playerSize / 2 + 16) {
        treasure.collected = true;
        return treasure.gold;
      }
    }
    return 0;
  }

  // Check collision with obstacles and cave walls
  resolveCollision(playerX, playerY, playerSize, newX, newY) {
    const halfSize = playerSize / 2;
    const wrapped = this.wrapCoordinates(newX, newY);

    // Check cave walls
    for (const wall of this.caveWalls) {
      if (wrapped.x + halfSize > wall.x &&
          wrapped.x - halfSize < wall.x + wall.width &&
          wrapped.y + halfSize > wall.y &&
          wrapped.y - halfSize < wall.y + wall.height) {
        return { x: playerX, y: playerY, collided: true, obstacle: wall, isWall: true };
      }
    }

    // Check obstacles
    for (const obs of this.obstacles) {
      if (obs.destroyed) continue;

      if (wrapped.x + halfSize > obs.x &&
          wrapped.x - halfSize < obs.x + obs.width &&
          wrapped.y + halfSize > obs.y &&
          wrapped.y - halfSize < obs.y + obs.height) {
        return { x: playerX, y: playerY, collided: true, obstacle: obs, isWall: false };
      }
    }

    // Return wrapped coordinates for infinite map
    return { x: wrapped.x, y: wrapped.y, collided: false };
  }

  // Destroy an obstacle
  destroyObstacle(obstacle) {
    if (obstacle && !obstacle.isWall) {
      obstacle.destroyed = true;
    }
  }
}
