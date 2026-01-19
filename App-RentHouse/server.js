require('dotenv').config();

const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const path = require('path');
const admin = require('firebase-admin');
const http = require('http');
const { Server } = require('socket.io');
const redis = require('redis');

const poiRoutes = require('./routes/poi-routes');
const aiRecommendationRoutes = require('./routes/ai-recommendations');
const rentalRoutes = require('./routes/rental');
const authRoutes = require('./routes/auth');
const chatRoutes = require('./routes/chat');
const favoriteRoutes = require('./routes/favorite');
const commentRoutes = require('./routes/comment');
const profileRoutes = require('./routes/profile');
const bookingRoutes = require('./routes/booking');
const vnpayRoutes = require('./routes/vnpayRoutes');

const bannerRoutes = require('./routes/banner');
const newsRoutes = require('./routes/news');
const aboutUsFeedbackRoutes = require('./routes/aboutus');
const notificationRoutes = require('./routes/notifications');
const analyticsRoutes = require('./routes/analytics');
const aiChatRoutes = require('./routes/ai-chat');

require('./models/conversation');
require('./models/message');
require('./models/news');
require('./models/savedArticle');
require('./models/Payment');

// Initialize Firebase Admin SDK
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(require('./app-rentalhouse-firebase-admin.json')),
  });
  console.log('✅ Firebase Admin SDK initialized');
}

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: ['http://localhost:3000', 'http://localhost:8081'],
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'],
    credentials: true,
  },
});

const PORT = process.env.PORT || 3000;
const MONGODB_URI = process.env.MONGODB_URI;

// ==================== REDIS CLIENT SETUP ====================
const redisClient = redis.createClient({
  url: process.env.REDIS_URL || 'redis://localhost:6379',
});

redisClient.on('error', (err) => console.error('❌ Redis Client Error:', err));
redisClient.on('connect', () => console.log('✅ Redis Client Connected'));
redisClient.on('ready', () => console.log('✅ Redis Client Ready'));

redisClient.connect().catch((err) => {
  console.error('❌ Redis Connection Error:', err);
  console.warn('⚠️ Server continuing without Redis - some features may be limited');
});

// ==================== MIDDLEWARE ====================
app.use(express.urlencoded({ limit: '50mb', extended: true }));
app.use(express.json({ limit: '50mb' }));


app.use(cors({
  origin: ['http://localhost:3000', 'http://localhost:8081'],
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'],
  credentials: true,
}));

//app.use(express.json());
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));
app.use('/Uploads', express.static(path.join(__dirname, 'Uploads')));

// ==================== DATABASE CONNECTION ====================
mongoose.connect(MONGODB_URI)
  .then(() => {
    console.log('✅ Connected to MongoDB');
  })
  .catch((err) => {
    console.error('❌ Error connecting to MongoDB:', err);
  });

// ==================== WAIT FOR REDIS TO BE READY ==================== 
let redisReady = false;

const waitForRedis = new Promise((resolve) => {
  const checkRedisReady = async () => {
    try {
      await redisClient.ping();
      console.log('✅ Redis is ready for operations');
      redisReady = true;
      resolve();
    } catch (err) {
      console.log('⏳ Waiting for Redis to be ready...');
      setTimeout(checkRedisReady, 1000);
    }
  };
  checkRedisReady();
});

// ==================== INITIALIZE REDIS FOR ROUTES ====================
waitForRedis.then(() => {
  // Inject Redis client vào aboutus routes
  if (aboutUsFeedbackRoutes.setRedisClient) {
    aboutUsFeedbackRoutes.setRedisClient(redisClient);
    console.log('✅ Redis client injected into aboutus routes');
  }

  // Inject Redis client vào notification routes
  if (notificationRoutes.setRedisClient) {
    notificationRoutes.setRedisClient(redisClient);
    console.log('✅ Redis client injected into notification routes');
  }
});

// ==================== ROUTES (NON-REDIS DEPENDENT) ====================
app.locals.redisClient = redisClient;

waitForRedis.then(() => {
  console.log('✅ Redis client available in app.locals for all routes');
});

app.use('/api/ai', aiRecommendationRoutes);
app.use('/api/ai', aiChatRoutes);
app.use('/api/poi', poiRoutes);

app.use('/api/auth', authRoutes);
app.use('/api', rentalRoutes);
app.use('/api/vnpay', vnpayRoutes);

app.use('/api', chatRoutes(io));
app.use('/api', favoriteRoutes);
app.use('/api', commentRoutes(io));
app.use('/api/profile', profileRoutes);
app.use('/api', bookingRoutes);

app.use('/api/banners', bannerRoutes);
app.use('/api/news', newsRoutes);

// ==================== ROUTES (REDIS DEPENDENT) ====================
// These routes are registered immediately but Redis client is injected when ready
app.use('/api', aboutUsFeedbackRoutes);
app.use('/api', notificationRoutes);
app.use('/api/analytics', analyticsRoutes);

// ==================== SOCKET.IO MIDDLEWARE ====================
io.use(async (socket, next) => {
  const token = socket.handshake.headers.authorization?.replace('Bearer ', '');
  if (!token) {
    console.log('❌ Socket authentication failed: No token provided');
    return next(new Error('Authentication error: No token provided'));
  }
  try {
    const decodedToken = await admin.auth().verifyIdToken(token);
    socket.userId = decodedToken.uid;
    console.log(`✅ Socket authenticated: User ${socket.userId}, Socket ${socket.id}`);
    next();
  } catch (err) {
    console.error('❌ Socket authentication error:', err.message);
    next(new Error('Authentication error: Invalid token'));
  }
});

// ==================== SOCKET.IO EVENTS ====================
io.on('connection', (socket) => {
  console.log(`✅ New client connected: Socket ${socket.id}, User: ${socket.userId}`);

  socket.on('joinConversation', async (conversationId) => {
    if (!mongoose.Types.ObjectId.isValid(conversationId)) {
      console.log(`❌ Invalid conversationId: ${conversationId} from user ${socket.userId}`);
      socket.emit('error', 'Invalid conversationId format');
      return;
    }

    try {
      const Conversation = mongoose.model('Conversation');
      const conversation = await Conversation.findById(conversationId);
      if (!conversation || !conversation.participants.includes(socket.userId)) {
        console.log(`❌ Unauthorized join attempt by user ${socket.userId} for conversation ${conversationId}`);
        socket.emit('error', 'Unauthorized or conversation not found');
        return;
      }

      socket.join(conversationId);
      console.log(`✅ User ${socket.userId} joined conversation room: ${conversationId}`);
    } catch (err) {
      console.error(`❌ Error joining conversation ${conversationId}:`, err.message);
      socket.emit('error', 'Failed to join conversation');
    }
  });

  socket.on('disconnect', () => {
    console.log(`✅ Client disconnected: Socket ${socket.id}, User: ${socket.userId}`);
  });
});

// ==================== ERROR HANDLING ====================
app.use((err, req, res, next) => {
  console.error('❌ Error:', err.stack);

  if (err.type === 'entity.too.large') {
    return res.status(413).json({ message: 'File hoặc dữ liệu gửi lên quá lớn!' });
  }

  res.status(500).json({ message: 'Có lỗi xảy ra từ server!' });
});

// ==================== 404 HANDLER ====================
app.use((req, res) => {
  res.status(404).json({ message: 'Endpoint not found' });
});

// ==================== SERVER START ====================
server.listen(PORT, () => {
  console.log(`🚀 Server is running on port ${PORT}`);
  console.log(`📍 Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`✅ MongoDB: Connected`);
  console.log(`✅ Redis: ${redisReady ? 'Connected' : 'Connecting...'}`);
  console.log(`✅ Firebase Admin: Initialized`);
  console.log(`✅ Socket.IO: Ready`);
  console.log(" ========= > BACKEND ĐÃ AUTO RELOAD < ========= ");

});

// ==================== GRACEFUL SHUTDOWN ====================
process.on('SIGTERM', async () => {
  console.log('🛑 SIGTERM received, shutting down gracefully...');
  server.close(async () => {
    console.log('🛑 Server closed');
    try {
      await redisClient.quit();
      console.log('✅ Redis connection closed');
    } catch (err) {
      console.warn('⚠️ Error closing Redis:', err);
    }
    try {
      await mongoose.connection.close();
      console.log('✅ MongoDB connection closed');
    } catch (err) {
      console.warn('⚠️ Error closing MongoDB:', err);
    }
    process.exit(0);
  });
});

process.on('SIGINT', async () => {
  console.log('🛑 SIGINT received, shutting down gracefully...');
  server.close(async () => {
    console.log('🛑 Server closed');
    try {
      await redisClient.quit();
      console.log('✅ Redis connection closed');
    } catch (err) {
      console.warn('⚠️ Error closing Redis:', err);
    }
    try {
      await mongoose.connection.close();
      console.log('✅ MongoDB connection closed');
    } catch (err) {
      console.warn('⚠️ Error closing MongoDB:', err);
    }
    process.exit(0);
  });
});