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
app.use('/api', rentalRoutes(io));

io.on('connection', (socket) => {
  console.log('New client connected:', socket.id);

  socket.on('joinConversation', (conversationId) => {
    console.log(`User joined conversation: ${conversationId}`);
    socket.join(conversationId);
  });

  socket.on('sendMessage', async (data) => {
    console.log(`Received sendMessage: ${JSON.stringify(data)}`);
    const { conversationId, senderId, content } = data;

    if (!mongoose.Types.ObjectId.isValid(conversationId)) {
      socket.emit('error', 'Invalid conversationId format');
      return;
    }

    try {
      const Conversation = mongoose.model('Conversation');
      const Message = mongoose.model('Message');
      const conversation = await Conversation.findById(conversationId);
      if (!conversation || !conversation.participants.includes(senderId)) {
        socket.emit('error', 'Unauthorized or conversation not found');
        return;
      }

      const message = new Message({
        conversationId,
        senderId,
        content,
        images: [],
      });

      await message.save();

      conversation.lastMessage = message._id;
      conversation.isPending = false;
      await conversation.save();

      await redisClient.del(`conversations:${conversation.participants[0]}`);
      await redisClient.del(`conversations:${conversation.participants[1]}`);

      const messageData = {
        _id: message._id.toString(),
        conversationId: message.conversationId.toString(),
        senderId: message.senderId,
        content: message.content,
        images: message.images,
        createdAt: message.createdAt,
      };

      io.to(conversationId).emit('receiveMessage', messageData);
    } catch (err) {
      console.error('Error in sendMessage:', err);
      socket.emit('error', 'Failed to send message');
    }
  });

  socket.on('disconnect', () => {
    console.log('Client disconnected:', socket.id);
  });
});
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ message: 'Something went wrong!' });
});

server.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});