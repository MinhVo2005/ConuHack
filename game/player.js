// Player class
class Player {
  constructor(x, y) {
    this.x = x;
    this.y = y;
    this.size = PLAYER_SIZE;
    this.baseSpeed = PLAYER_SPEED;
    this.speed = PLAYER_SPEED;
    this.gold = 0;
    this.velocityX = 0;
    this.velocityY = 0;
    this.collisionCooldown = 0;

    // Animation
    this.animFrame = 0;
    this.animTimer = 0;
    this.facing = 'down';
  }

  update(targetX, targetY, map, currentEnv) {
    // Wrap target position to handle infinite map cursor
    const maxX = MAP_WIDTH * TILE_SIZE;
    const maxY = MAP_HEIGHT * TILE_SIZE;

    // Calculate direction to cursor
    let dx = targetX - this.x;
    let dy = targetY - this.y;

    // Handle wrap-around for cursor direction
    if (Math.abs(dx) > maxX / 2) {
      dx = dx > 0 ? dx - maxX : dx + maxX;
    }
    if (Math.abs(dy) > maxY / 2) {
      dy = dy > 0 ? dy - maxY : dy + maxY;
    }

    const dist = Math.sqrt(dx * dx + dy * dy);

    // Determine facing direction
    if (Math.abs(dx) > Math.abs(dy)) {
      this.facing = dx > 0 ? 'right' : 'left';
    } else {
      this.facing = dy > 0 ? 'down' : 'up';
    }

    // Calculate base movement
    let moveSpeed = this.baseSpeed;

    // Apply wind effect if in windy zone
    if (currentEnv && currentEnv.type === ENV_TYPES.WINDY && currentEnv.windDirection) {
      const windStrength = currentEnv.windSpeed / 50;
      const moveDir = { x: dx / dist, y: dy / dist };

      // Dot product to see if moving with or against wind
      const windAlignment = moveDir.x * currentEnv.windDirection.x + moveDir.y * currentEnv.windDirection.y;

      // Speed up if moving with wind, slow down if against
      moveSpeed = this.baseSpeed * (1 + windAlignment * windStrength);
      moveSpeed = Math.max(0.5, Math.min(6, moveSpeed));
    }

    this.speed = moveSpeed;

    // Only move if cursor is far enough from player
    if (dist > 5) {
      this.velocityX = (dx / dist) * this.speed;
      this.velocityY = (dy / dist) * this.speed;

      const newX = this.x + this.velocityX;
      const newY = this.y + this.velocityY;

      // Check collision
      const result = map.resolveCollision(this.x, this.y, this.size, newX, newY);

      if (result.collided) {
        // Try to slide along walls
        const resultX = map.resolveCollision(this.x, this.y, this.size, newX, this.y);
        const resultY = map.resolveCollision(this.x, this.y, this.size, this.x, newY);

        if (!resultX.collided) {
          this.x = resultX.x;
          this.y = resultX.y;
        } else if (!resultY.collided) {
          this.x = resultY.x;
          this.y = resultY.y;
        }

        // Handle collision penalty (only for obstacles, not walls)
        if (this.collisionCooldown <= 0 && !result.isWall) {
          this.collisionCooldown = 30;
          return { hitObstacle: true, obstacle: result.obstacle };
        }
      } else {
        this.x = result.x;
        this.y = result.y;
      }

      // Animation
      this.animTimer++;
      if (this.animTimer > 8) {
        this.animFrame = (this.animFrame + 1) % 4;
        this.animTimer = 0;
      }
    } else {
      this.velocityX = 0;
      this.velocityY = 0;
    }

    if (this.collisionCooldown > 0) {
      this.collisionCooldown--;
    }

    return { hitObstacle: false };
  }

  draw(ctx, cameraX, cameraY) {
    const screenX = this.x - cameraX;
    const screenY = this.y - cameraY;

    // Draw shadow
    ctx.fillStyle = 'rgba(0, 0, 0, 0.3)';
    ctx.beginPath();
    ctx.ellipse(screenX, screenY + this.size / 2 + 4, this.size / 2, this.size / 4, 0, 0, Math.PI * 2);
    ctx.fill();

    // Colors
    const bodyColor = '#4a90d9';
    const skinColor = '#ffd5b5';
    const outlineColor = '#2c5282';
    const hairColor = '#5d4037';

    // Animation bob
    const bobOffset = Math.sin(this.animFrame * Math.PI / 2) * 2;

    // Body
    ctx.fillStyle = bodyColor;
    ctx.fillRect(screenX - 10, screenY - 14 + bobOffset, 20, 20);

    // Body outline
    ctx.strokeStyle = outlineColor;
    ctx.lineWidth = 2;
    ctx.strokeRect(screenX - 10, screenY - 14 + bobOffset, 20, 20);

    // Head
    ctx.fillStyle = skinColor;
    ctx.fillRect(screenX - 8, screenY - 26 + bobOffset, 16, 14);

    // Hair
    ctx.fillStyle = hairColor;
    ctx.fillRect(screenX - 8, screenY - 28 + bobOffset, 16, 6);

    // Eyes based on direction
    ctx.fillStyle = '#333';
    if (this.facing === 'down') {
      ctx.fillRect(screenX - 5, screenY - 20 + bobOffset, 4, 4);
      ctx.fillRect(screenX + 1, screenY - 20 + bobOffset, 4, 4);
    } else if (this.facing === 'up') {
      // Back of head - no eyes
    } else if (this.facing === 'left') {
      ctx.fillRect(screenX - 6, screenY - 20 + bobOffset, 4, 4);
    } else {
      ctx.fillRect(screenX + 2, screenY - 20 + bobOffset, 4, 4);
    }

    // Legs animation
    const legOffset = Math.abs(Math.sin(this.animFrame * Math.PI / 2)) * 5;
    ctx.fillStyle = '#2c5282';
    ctx.fillRect(screenX - 8, screenY + 6, 6, 6 + legOffset);
    ctx.fillRect(screenX + 2, screenY + 6, 6, 6 + (5 - legOffset));
  }

  addGold(amount) {
    this.gold += amount;
  }

  removeGold(amount) {
    this.gold -= amount;
  }
}
