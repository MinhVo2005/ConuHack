// Visual effects manager
class EffectsManager {
  constructor(canvas) {
    this.canvas = canvas;
    this.particles = [];
    this.currentEnv = null;
    this.shakeTimer = 0;
    this.shakeOffsetX = 0;
    this.shakeOffsetY = 0;

    // Overlay properties (drawn on canvas, not DOM)
    this.overlayAlpha = 0;
    this.overlayColor = null;
    this.frostAlpha = 0;
    this.brightnessMultiplier = 1;
    this.blurAmount = 0;
  }

  update(env) {
    // Update current environment
    if (env && (!this.currentEnv || this.currentEnv.type !== env.type)) {
      this.transitionTo(env);
    }
    this.currentEnv = env;

    // Update particles
    this.updateParticles();

    // Generate new particles based on environment
    if (env) {
      this.generateParticles(env);
    }

    // Update shake for jungle
    if (env && env.type === ENV_TYPES.JUNGLE) {
      this.shakeTimer++;
      this.shakeOffsetX = (Math.random() - 0.5) * 8;
      this.shakeOffsetY = (Math.random() - 0.5) * 8;
    } else {
      this.shakeOffsetX = 0;
      this.shakeOffsetY = 0;
      this.shakeTimer = 0;
    }
  }

  transitionTo(env) {
    // Reset effects
    this.overlayAlpha = 0;
    this.overlayColor = null;
    this.frostAlpha = 0;
    this.brightnessMultiplier = 1;
    this.blurAmount = 0;

    // Apply environment-specific effects
    switch (env.type) {
      case ENV_TYPES.BEACH:
        this.overlayColor = 'rgba(255, 255, 200, 0.35)';
        this.overlayAlpha = 1;
        this.brightnessMultiplier = 1.3;
        break;

      case ENV_TYPES.CAVE:
        this.overlayColor = 'rgba(0, 0, 20, 0.75)';
        this.overlayAlpha = 1;
        this.blurAmount = 1;
        break;

      case ENV_TYPES.ARCTIC:
        this.frostAlpha = 0.6;
        this.overlayColor = 'rgba(200, 230, 255, 0.15)';
        this.overlayAlpha = 1;
        break;

      case ENV_TYPES.RAIN:
        this.overlayColor = 'rgba(30, 50, 30, 0.25)';
        this.overlayAlpha = 1;
        break;

      case ENV_TYPES.WINDY:
        this.overlayColor = 'rgba(200, 220, 255, 0.1)';
        this.overlayAlpha = 1;
        break;
    }

    // Clear old particles when changing zones
    this.particles = [];
  }

  generateParticles(env) {
    switch (env.type) {
      case ENV_TYPES.RAIN:
        // Generate more rain drops for visibility
        for (let i = 0; i < 3; i++) {
          if (Math.random() < 0.8) {
            this.particles.push({
              type: 'rain',
              x: Math.random() * CANVAS_WIDTH,
              y: -10 - Math.random() * 50,
              vx: -3,
              vy: 18 + Math.random() * 6,
              length: 15 + Math.random() * 10,
              life: 80
            });
          }
        }
        break;

      case ENV_TYPES.ARCTIC:
        // Generate snowflakes
        if (Math.random() < 0.4) {
          this.particles.push({
            type: 'snow',
            x: Math.random() * CANVAS_WIDTH,
            y: -10,
            vx: Math.random() * 2 - 1,
            vy: 1.5 + Math.random() * 2,
            size: 3 + Math.random() * 5,
            life: 250
          });
        }
        break;

      case ENV_TYPES.WINDY:
        // Generate wind streaks
        if (Math.random() < 0.25) {
          const windDir = env.windDirection || { x: 1, y: 0 };
          this.particles.push({
            type: 'wind',
            x: windDir.x > 0 ? -30 : CANVAS_WIDTH + 30,
            y: Math.random() * CANVAS_HEIGHT,
            vx: windDir.x * 25,
            vy: windDir.y * 25,
            length: 40 + Math.random() * 50,
            life: 60
          });
        }
        break;
    }
  }

  updateParticles() {
    for (let i = this.particles.length - 1; i >= 0; i--) {
      const p = this.particles[i];
      p.x += p.vx;
      p.y += p.vy;
      p.life--;

      // Remove dead particles
      if (p.life <= 0 || p.y > CANVAS_HEIGHT + 30 || p.x < -60 || p.x > CANVAS_WIDTH + 60) {
        this.particles.splice(i, 1);
      }
    }
  }

  getShakeOffset() {
    return { x: this.shakeOffsetX, y: this.shakeOffsetY };
  }

  draw(ctx) {
    // Draw particles
    for (const p of this.particles) {
      switch (p.type) {
        case 'rain':
          // More visible rain
          ctx.strokeStyle = 'rgba(180, 200, 255, 0.7)';
          ctx.lineWidth = 2;
          ctx.beginPath();
          ctx.moveTo(p.x, p.y);
          ctx.lineTo(p.x + p.vx * 0.5, p.y + p.length);
          ctx.stroke();

          // Add a slight glow
          ctx.strokeStyle = 'rgba(150, 180, 255, 0.3)';
          ctx.lineWidth = 4;
          ctx.beginPath();
          ctx.moveTo(p.x, p.y);
          ctx.lineTo(p.x + p.vx * 0.5, p.y + p.length);
          ctx.stroke();
          break;

        case 'snow':
          const alpha = Math.min(1, p.life / 100);
          ctx.fillStyle = `rgba(255, 255, 255, ${alpha})`;
          ctx.beginPath();
          ctx.arc(p.x, p.y, p.size, 0, Math.PI * 2);
          ctx.fill();

          // Snow sparkle
          ctx.fillStyle = `rgba(200, 230, 255, ${alpha * 0.5})`;
          ctx.beginPath();
          ctx.arc(p.x, p.y, p.size * 1.5, 0, Math.PI * 2);
          ctx.fill();
          break;

        case 'wind':
          const windAlpha = p.life / 60;
          ctx.strokeStyle = `rgba(200, 220, 255, ${windAlpha * 0.5})`;
          ctx.lineWidth = 2;
          ctx.beginPath();
          ctx.moveTo(p.x, p.y);
          ctx.lineTo(p.x - p.vx * (p.length / 25), p.y - p.vy * (p.length / 25));
          ctx.stroke();
          break;
      }
    }
  }

  // Draw overlays on canvas (covers full canvas properly)
  drawOverlay(ctx) {
    // Main color overlay
    if (this.overlayColor && this.overlayAlpha > 0) {
      ctx.fillStyle = this.overlayColor;
      ctx.fillRect(0, 0, CANVAS_WIDTH, CANVAS_HEIGHT);
    }

    // Frost effect for arctic
    if (this.frostAlpha > 0) {
      const gradient = ctx.createRadialGradient(
        CANVAS_WIDTH / 2, CANVAS_HEIGHT / 2, CANVAS_WIDTH * 0.3,
        CANVAS_WIDTH / 2, CANVAS_HEIGHT / 2, CANVAS_WIDTH * 0.7
      );
      gradient.addColorStop(0, 'rgba(200, 230, 255, 0)');
      gradient.addColorStop(1, `rgba(200, 230, 255, ${this.frostAlpha})`);
      ctx.fillStyle = gradient;
      ctx.fillRect(0, 0, CANVAS_WIDTH, CANVAS_HEIGHT);

      // Ice crystals on edges
      ctx.fillStyle = `rgba(220, 240, 255, ${this.frostAlpha * 0.4})`;
      for (let i = 0; i < 20; i++) {
        const x = Math.random() < 0.5 ? Math.random() * 100 : CANVAS_WIDTH - Math.random() * 100;
        const y = Math.random() * CANVAS_HEIGHT;
        ctx.beginPath();
        ctx.arc(x, y, 3 + Math.random() * 8, 0, Math.PI * 2);
        ctx.fill();
      }
    }

    // Vignette effect for caves (darker edges)
    if (this.currentEnv && this.currentEnv.type === ENV_TYPES.CAVE) {
      const vignetteGradient = ctx.createRadialGradient(
        CANVAS_WIDTH / 2, CANVAS_HEIGHT / 2, CANVAS_WIDTH * 0.2,
        CANVAS_WIDTH / 2, CANVAS_HEIGHT / 2, CANVAS_WIDTH * 0.6
      );
      vignetteGradient.addColorStop(0, 'rgba(0, 0, 0, 0)');
      vignetteGradient.addColorStop(1, 'rgba(0, 0, 0, 0.6)');
      ctx.fillStyle = vignetteGradient;
      ctx.fillRect(0, 0, CANVAS_WIDTH, CANVAS_HEIGHT);
    }
  }

  // Flash effect when collecting treasure
  flashGold(ctx) {
    ctx.fillStyle = 'rgba(255, 215, 0, 0.4)';
    ctx.fillRect(0, 0, CANVAS_WIDTH, CANVAS_HEIGHT);
  }

  // Flash effect when hitting obstacle
  flashDamage(ctx) {
    ctx.fillStyle = 'rgba(255, 0, 0, 0.4)';
    ctx.fillRect(0, 0, CANVAS_WIDTH, CANVAS_HEIGHT);
  }
}
