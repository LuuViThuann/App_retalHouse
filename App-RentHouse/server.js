// File này là file chính của server, nơi khởi tạo server và kết nối với MongoDB
require('dotenv').config();

// Import các thư viện cần thiết ---------------
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const path = require('path');
const admin = require('firebase-admin');
const http = require('http');
const { Server } = require('socket.io');
const redis = require('redis');

// Import các route để xử lý yêu cầu trong server - API ---------------
const rentalRoutes = require('./routes/rental');
const authRoutes = require('./routes/auth');

// Ensure MongoDB models are loaded (assuming they are in the models directory)
require('./models/conversation');
require('./models/message');

// Khởi tạo Firebase Admin SDK
const serviceAccount = require('./app-rentalhouse-firebase-admin.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

// Khởi tạo Express app và cấu hình các middleware
const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: '*', // Adjust to your frontend URL in production
    methods: ['GET', 'POST'],
  },
});
const PORT = process.env.PORT || 3000;
const MONGODB_URI = process.env.MONGODB_URI;

// Initialize Redis client
const redisClient = redis.createClient({
  url: process.env.REDIS_URL || 'redis://localhost:6379',
});
redisClient.on('error', (err) => console.log('Redis Client Error', err));
redisClient.connect().catch((err) => console.error('Redis Connection Error:', err));

// Middleware cần thiết cho server 
app.use(cors());
app.use(express.json());
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// Kết nối đến MongoDB 
mongoose.connect(MONGODB_URI)
  .then(() => {
    console.log('Connected to MongoDB');
  })
  .catch((err) => {
    console.error('Error connecting to MongoDB:', err);
  });


// Sử dụng các route đã import chạy hiển thị các dữ liệu trong API 
app.use('/api/auth', authRoutes);
app.use('/api', rentalRoutes);

// Socket.IO connection handling
io.on('connection', (socket) => {
  console.log('A user connected:', socket.id);

  // Join a conversation room
  socket.on('joinConversation', (conversationId) => {
    socket.join(conversationId);
    console.log(`User ${socket.id} joined conversation ${conversationId}`);
  });

  // Handle sending a message
  socket.on('sendMessage', async ({ conversationId, senderId, content }) => {
    try {
      const Message = mongoose.model('Message');
      const Conversation = mongoose.model('Conversation');

      // Save the message to MongoDB
      const message = new Message({
        conversationId,
        senderId,
        content,
        createdAt: new Date(),
      });
      await message.save();

      // Update the conversation's last message
      await Conversation.findByIdAndUpdate(conversationId, {
        lastMessage: message._id,
        updatedAt: new Date(),
      });

      // Emit the message to the room
      io.to(conversationId).emit('receiveMessage', {
        _id: message._id,
        conversationId,
        senderId,
        content,
        createdAt: message.createdAt,
      });

      // Invalidate Redis cache for this conversation
      await redisClient.del(`conversation:${conversationId}`);
    } catch (err) {
      console.error('Error sending message:', err);
      socket.emit('error', { message: 'Failed to send message' });
    }
  });

  socket.on('disconnect', () => {
    console.log('User disconnected:', socket.id);
  });
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ message: 'Something went wrong!' });
});

// Route chính để kiểm tra server hoạt động 
server.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});