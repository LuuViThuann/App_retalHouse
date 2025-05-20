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

require('./models/conversation');
require('./models/message');

const serviceAccount = require('./app-rentalhouse-firebase-admin.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST'],
  },
});
const PORT = process.env.PORT || 3000;
const MONGODB_URI = process.env.MONGODB_URI;

const redisClient = redis.createClient({
  url: process.env.REDIS_URL || 'redis://localhost:6379',
});
redisClient.on('error', (err) => console.log('Redis Client Error', err));
redisClient.connect().catch((err) => console.error('Redis Connection Error:', err));

app.use(cors());
app.use(express.json());
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

mongoose.connect(MONGODB_URI)
  .then(() => {
    console.log('Connected to MongoDB');
  })
  .catch((err) => {
    console.error('Error connecting to MongoDB:', err);
  });

app.use('/api/auth', authRoutes);
app.use('/api', rentalRoutes);

io.on('connection', (socket) => {
  console.log('A user connected:', socket.id);

  socket.on('joinConversation', (conversationId) => {
    socket.join(conversationId);
    console.log(`User ${socket.id} joined conversation ${conversationId}`);
  });

  socket.on('sendMessage', async ({ conversationId, senderId, content }) => {
    try {
      const Message = mongoose.model('Message');
      const Conversation = mongoose.model('Conversation');

      const message = new Message({
        conversationId,
        senderId,
        content,
        createdAt: new Date(),
      });
      await message.save();

      await Conversation.findByIdAndUpdate(conversationId, {
        lastMessage: message._id,
        updatedAt: new Date(),
        isPending: false,
      });

      const populatedMessage = await Message.findById(message._id)
        .populate('senderId', 'username avatarBase64')
        .lean();

      // Adjust timestamp for +7 timezone
      const adjustedMessage = {
        ...populatedMessage,
        createdAt: new Date(new Date(populatedMessage.createdAt).getTime() + 7 * 60 * 60 * 1000),
      };

      io.to(conversationId).emit('receiveMessage', adjustedMessage);

      // Invalidate Redis cache for participants
      const conversation = await Conversation.findById(conversationId);
      for (const participant of conversation.participants) {
        await redisClient.del(`conversations:${participant}`);
      }
    } catch (err) {
      console.error('Error sending message:', err);
      socket.emit('error', { message: 'Failed to send message' });
    }
  });

  socket.on('disconnect', () => {
    console.log('User disconnected:', socket.id);
  });
});

app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ message: 'Something went wrong!' });
});

server.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});