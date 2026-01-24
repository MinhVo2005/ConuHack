const express = require('express');
const { createServer } = require('http');
const { Server } = require('socket.io');
const cors = require('cors');
const db = require('./db');
const path = require('path');

const app = express();
const httpServer = createServer(app);
const io = new Server(httpServer, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"]
  }
});

app.use(cors());
app.use(express.json());

// Serve game static files
app.use('/game', express.static(path.join(__dirname, '../game')));

// REST API endpoints for mobile app
app.get('/api/player/:id', (req, res) => {
  const player = db.getOrCreatePlayer(req.params.id);
  res.json(player);
});

app.get('/api/player/:id/gold', (req, res) => {
  const gold = db.getPlayerGold(req.params.id);
  res.json({ gold });
});

// Socket.io for real-time game communication
io.on('connection', (socket) => {
  console.log('Client connected:', socket.id);

  // Player joins with their ID
  socket.on('join', (playerId) => {
    socket.playerId = playerId;
    const player = db.getOrCreatePlayer(playerId);
    socket.join(playerId); // Join room for this player
    socket.emit('playerData', player);
    console.log(`Player ${playerId} joined with ${player.gold} gold`);
  });

  // Update gold (from game events)
  socket.on('updateGold', (data) => {
    const { playerId, goldChange, newTotal } = data;
    const player = db.updatePlayerGold(playerId, newTotal);

    // Broadcast to all clients in this player's room (game + mobile app)
    io.to(playerId).emit('goldUpdated', {
      gold: player.gold,
      change: goldChange
    });

    console.log(`Player ${playerId} gold: ${player.gold} (${goldChange >= 0 ? '+' : ''}${goldChange})`);
  });

  // Send environment data to server (for future mobile app integration)
  socket.on('environmentUpdate', (data) => {
    const { playerId, environment } = data;
    io.to(playerId).emit('environmentData', environment);
  });

  socket.on('disconnect', () => {
    console.log('Client disconnected:', socket.id);
  });
});

// Initialize database and start server
const PORT = process.env.PORT || 3000;

async function start() {
  await db.initDb();
  console.log('Database initialized');

  httpServer.listen(PORT, () => {
    console.log(`Server running on http://localhost:${PORT}`);
    console.log(`Game available at http://localhost:${PORT}/game`);
  });
}

start().catch(err => {
  console.error('Failed to start server:', err);
  process.exit(1);
});
