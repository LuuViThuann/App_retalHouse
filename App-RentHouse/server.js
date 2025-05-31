require('dotenv').config();

const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const path = require('path');
const admin = require('firebase-admin');
const http = require('http');
const { Server } = require('socket.io');
const redis = require('redis');

const rentalRoutes = require('./routes/rental');
const authRoutes = require('./routes/auth');
const chatRoutes = require('./routes/chat');
const favoriteRoutes = require('./routes/favorite');
const commentRoutes = require('./routes/comment');
const profileRoutes = require('./routes/profile');

require('./models/conversation');
require('./models/message');

// Initialize Firebase Admin SDK
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(require('./app-rentalhouse-firebase-admin.json')),
  });
  console.log('Firebase Admin SDK initialized');
}

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: ['http://localhost:3000', 'http://localhost:8081'],
    methods: ['GET', 'POST', 'PUT', 'DELETE'],
  },
});
const PORT = process.env.PORT || 3000;
const MONGODB_URI = process.env.MONGODB_URI;

const redisClient = redis.createClient({
  url: process.env.REDIS_URL || 'redis://localhost:6379',
});
redisClient.on('error', (err) => console.log('Redis Client Error', err));
redisClient.connect().catch((err) => console.error('Redis Connection Error:', err));

app.use(cors({
  origin: ['http://localhost:3000', 'http://localhost:8081'],
  methods: ['GET', 'POST', 'PUT', 'DELETE'],
}));
app.use(express.json());
app.use('/Uploads', express.static(path.join(__dirname, 'Uploads')));

mongoose.connect(MONGODB_URI)
  .then(() => {
    console.log('Connected to MongoDB');
  })
  .catch((err) => {
    console.error('Error connecting to MongoDB:', err);
  });

app.use('/api/auth', authRoutes);
app.use('/api', rentalRoutes);
app.use('/api', chatRoutes(io));
app.use('/api', favoriteRoutes);
app.use('/api', commentRoutes(io));
app.use('/api/profile', profileRoutes);


io.use(async (socket, next) => {
  const token = socket.handshake.headers.authorization?.replace('Bearer ', '');
  if (!token) {
    console.log('Socket authentication failed: No token provided');
    return next(new Error('Authentication error: No token provided'));
  }
  try {
    const decodedToken = await admin.auth().verifyIdToken(token);
    socket.userId = decodedToken.uid;
    console.log(`Socket authenticated: User ${socket.userId}, Socket ${socket.id}`);
    next();
  } catch (err) {
    console.error('Socket authentication error:', err.message);
    next(new Error('Authentication error: Invalid token'));
  }
});

io.on('connection', (socket) => {
  console.log(`New client connected: Socket ${socket.id}, User: ${socket.userId}`);

  socket.on('joinConversation', async (conversationId) => {
    if (!mongoose.Types.ObjectId.isValid(conversationId)) {
      console.log(`Invalid conversationId: ${conversationId} from user ${socket.userId}`);
      socket.emit('error', 'Invalid conversationId format');
      return;
    }

    try {
      const Conversation = mongoose.model('Conversation');
      const conversation = await Conversation.findById(conversationId);
      if (!conversation || !conversation.participants.includes(socket.userId)) {
        console.log(`Unauthorized join attempt by user ${socket.userId} for conversation ${conversationId}`);
        socket.emit('error', 'Unauthorized or conversation not found');
        return;
      }

      socket.join(conversationId);
      console.log(`User ${socket.userId} joined conversation room: ${conversationId}`);
    } catch (err) {
      console.error(`Error joining conversation ${conversationId}:`, err.message);
      socket.emit('error', 'Failed to join conversation');
    }
  });

  socket.on('disconnect', () => {
    console.log(`Client disconnected: Socket ${socket.id}, User: ${socket.userId}`);
  });
});

app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ message: 'Something went wrong!' });
});

server.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});