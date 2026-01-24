// Main game controller
class Game {
  constructor() {
    this.canvas = document.getElementById('gameCanvas');
    this.ctx = this.canvas.getContext('2d');
    this.canvas.width = CANVAS_WIDTH;
    this.canvas.height = CANVAS_HEIGHT;

    // Generate player ID (or use stored one)
    this.playerId = localStorage.getItem('playerId') || this.generatePlayerId();
    localStorage.setItem('playerId', this.playerId);

    // Initialize game objects
    this.map = new GameMap();
    this.player = new Player(
      MAP_WIDTH * TILE_SIZE / 2,
      MAP_HEIGHT * TILE_SIZE / 2
    );
    this.effects = new EffectsManager(this.canvas);

    // Camera
    this.cameraX = 0;
    this.cameraY = 0;

    // Mouse position (world coordinates)
    this.mouseX = this.player.x;
    this.mouseY = this.player.y;

    // UI elements
    this.goldDisplay = document.getElementById('gold-value');
    this.envDisplay = document.getElementById('environment-display');

    // Flash effects
    this.flashType = null;
    this.flashTimer = 0;

    // Socket connection
    this.socket = null;
    this.connected = false;

    // Initialize
    this.setupInput();
    this.connectToServer();
    this.gameLoop();
  }

  generatePlayerId() {
    return 'player_' + Math.random().toString(36).substr(2, 9);
  }

  connectToServer() {
    try {
      this.socket = io('http://localhost:3000');

      this.socket.on('connect', () => {
        console.log('Connected to server');
        this.connected = true;
        this.socket.emit('join', this.playerId);
      });

      this.socket.on('playerData', (data) => {
        console.log('Player data received:', data);
        this.player.gold = data.gold;
        this.updateGoldDisplay();
      });

      this.socket.on('goldUpdated', (data) => {
        console.log('Gold updated:', data);
        this.player.gold = data.gold;
        this.updateGoldDisplay();
      });

      this.socket.on('disconnect', () => {
        console.log('Disconnected from server');
        this.connected = false;
      });

      this.socket.on('connect_error', (error) => {
        console.log('Connection error:', error.message);
        this.connected = false;
      });
    } catch (e) {
      console.log('Could not connect to server:', e);
      this.connected = false;
    }
  }

  setupInput() {
    // Mouse move - update target position
    this.canvas.addEventListener('mousemove', (e) => {
      const rect = this.canvas.getBoundingClientRect();
      const screenX = e.clientX - rect.left;
      const screenY = e.clientY - rect.top;

      // Convert to world coordinates
      this.mouseX = screenX + this.cameraX;
      this.mouseY = screenY + this.cameraY;
    });

    // Keep mouse position updated when not moving
    this.canvas.addEventListener('mouseenter', (e) => {
      const rect = this.canvas.getBoundingClientRect();
      const screenX = e.clientX - rect.left;
      const screenY = e.clientY - rect.top;
      this.mouseX = screenX + this.cameraX;
      this.mouseY = screenY + this.cameraY;
    });
  }

  update() {
    // Get current environment
    const env = this.map.getEnvironmentAt(this.player.x, this.player.y);

    // Update player
    const playerResult = this.player.update(this.mouseX, this.mouseY, this.map, env);

    // Check if hit obstacle
    if (playerResult.hitObstacle) {
      this.player.removeGold(OBSTACLE_GOLD_PENALTY);
      this.updateGoldDisplay();
      this.sendGoldUpdate(-OBSTACLE_GOLD_PENALTY);
      this.flashType = 'damage';
      this.flashTimer = 8;

      // Destroy the obstacle
      if (playerResult.obstacle) {
        this.map.destroyObstacle(playerResult.obstacle);
      }
    }

    // Check treasure collision
    const treasureGold = this.map.checkTreasureCollision(this.player.x, this.player.y, this.player.size);
    if (treasureGold > 0) {
      this.player.addGold(treasureGold);
      this.updateGoldDisplay();
      this.sendGoldUpdate(treasureGold);
      this.flashType = 'gold';
      this.flashTimer = 8;
    }

    // Update camera to follow player (centered)
    this.cameraX = this.player.x - CANVAS_WIDTH / 2;
    this.cameraY = this.player.y - CANVAS_HEIGHT / 2;

    // Update effects
    this.effects.update(env);

    // Update flash timer
    if (this.flashTimer > 0) {
      this.flashTimer--;
    } else {
      this.flashType = null;
    }

    // Update environment display and send to server
    if (env) {
      this.updateEnvDisplay(env);
      this.sendEnvironmentUpdate(env);
    }
  }

  draw() {
    const ctx = this.ctx;

    // Get shake offset
    const shake = this.effects.getShakeOffset();

    // Save context and apply shake
    ctx.save();
    ctx.translate(shake.x, shake.y);

    // Clear canvas
    ctx.fillStyle = '#1a1a2e';
    ctx.fillRect(-10, -10, CANVAS_WIDTH + 20, CANVAS_HEIGHT + 20);

    // Draw map
    this.map.draw(ctx, this.cameraX, this.cameraY);

    // Draw player
    this.player.draw(ctx, this.cameraX, this.cameraY);

    // Restore context (remove shake for UI elements)
    ctx.restore();

    // Draw particle effects (on top, not affected by shake)
    this.effects.draw(ctx);

    // Draw environment overlay (covers full screen)
    this.effects.drawOverlay(ctx);

    // Draw flash effects
    if (this.flashType === 'gold') {
      this.effects.flashGold(ctx);
    } else if (this.flashType === 'damage') {
      this.effects.flashDamage(ctx);
    }

    // Draw cursor indicator
    this.drawCursor();

    // Draw connection status
    this.drawConnectionStatus();
  }

  drawCursor() {
    const screenX = this.mouseX - this.cameraX;
    const screenY = this.mouseY - this.cameraY;

    // Draw crosshair
    this.ctx.strokeStyle = 'rgba(255, 255, 255, 0.6)';
    this.ctx.lineWidth = 2;

    this.ctx.beginPath();
    this.ctx.moveTo(screenX - 12, screenY);
    this.ctx.lineTo(screenX + 12, screenY);
    this.ctx.moveTo(screenX, screenY - 12);
    this.ctx.lineTo(screenX, screenY + 12);
    this.ctx.stroke();

    // Outer circle
    this.ctx.beginPath();
    this.ctx.arc(screenX, screenY, 8, 0, Math.PI * 2);
    this.ctx.stroke();
  }

  drawConnectionStatus() {
    const status = this.connected ? 'Connected' : 'Offline';
    const color = this.connected ? '#2ecc71' : '#e74c3c';

    this.ctx.fillStyle = color;
    this.ctx.font = '14px Courier New';
    this.ctx.textAlign = 'right';
    this.ctx.fillText(status, CANVAS_WIDTH - 10, 20);
    this.ctx.textAlign = 'left';
  }

  updateGoldDisplay() {
    this.goldDisplay.textContent = this.player.gold;

    // Color based on value
    if (this.player.gold < 0) {
      this.goldDisplay.style.color = '#e74c3c';
    } else {
      this.goldDisplay.style.color = '#ffd700';
    }
  }

  updateEnvDisplay(env) {
    this.envDisplay.style.display = 'block';
    this.envDisplay.innerHTML = `
      <strong>${env.name}</strong><br>
      Temp: ${env.temperature}°C | Humidity: ${env.humidity}%<br>
      Wind: ${env.windSpeed} km/h | Sound: ${env.soundLevel} dB
    `;
  }

  sendGoldUpdate(change) {
    if (this.connected && this.socket) {
      this.socket.emit('updateGold', {
        playerId: this.playerId,
        goldChange: change,
        newTotal: this.player.gold
      });
    }
  }

  sendEnvironmentUpdate(env) {
    if (this.connected && this.socket) {
      this.socket.emit('environmentUpdate', {
        playerId: this.playerId,
        environment: env
      });
    }
  }

  gameLoop() {
    this.update();
    this.draw();
    requestAnimationFrame(() => this.gameLoop());
  }
}

// Start game when page loads
window.addEventListener('load', () => {
  window.game = new Game();
});
