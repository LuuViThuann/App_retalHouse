const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const admin = require('firebase-admin');
const multer = require('multer');
const redis = require('redis');
const { v4: uuidv4 } = require('uuid');
const Rental = require('../models/Rental');
const Conversation = require('../models/conversation');
const Message = require('../models/message');

const storage = multer.diskStorage({
  destination: './uploads/',
  filename: (req, file, cb) => {
    cb(null, `${Date.now()}-${file.originalname}`);
  },
});
const upload = multer({ storage });

const redisClient = redis.createClient({
  url: process.env.REDIS_URL || 'redis://localhost:6379',
});
redisClient.on('error', (err) => console.log('Redis Client Error', err));
redisClient.connect().catch((err) => console.error('Redis Connection Error:', err));

const authMiddleware = async (req, res, next) => {
  const token = req.header('Authorization')?.replace('Bearer ', '');
  if (!token) return res.status(401).json({ message: 'No token provided' });
  try {
    const decodedToken = await admin.auth().verifyIdToken(token);
    req.userId = decodedToken.uid;
    next();
  } catch (err) {
    res.status(401).json({ message: 'Invalid token' });
  }
};

const adjustTimestamps = (obj) => {
  const adjusted = { ...obj.toObject() };
  adjusted.createdAt = new Date(adjusted.createdAt.getTime() + 7 * 60 * 60 * 1000);
  return adjusted;
};

module.exports = (io) => {
  // Create or get a conversation
  router.post('/conversations', authMiddleware, async (req, res) => {
    try {
      const { rentalId, landlordId } = req.body;
      const userId = req.userId;

      if (!mongoose.Types.ObjectId.isValid(rentalId)) {
        return res.status(400).json({ message: 'Invalid rentalId format' });
      }
      if (!landlordId || typeof landlordId !== 'string' || landlordId.trim() === '') {
        return res.status(400).json({ message: 'Invalid landlordId' });
      }
      if (userId === landlordId) {
        return res.status(403).json({ message: 'You cannot start a conversation with yourself' });
      }
      const rental = await Rental.findById(rentalId);
      if (!rental) {
        return res.status(404).json({ message: 'Rental not found' });
      }

      let landlordData = { username: rental.contactInfo?.name || 'Chủ nhà', avatarBase64: '' };
      let userData = { username: 'Chủ nhà', avatarBase64: '' };
      try {
        const landlordDoc = await admin.firestore().collection('Users').doc(landlordId).get();
        if (landlordDoc.exists) landlordData = { ...landlordDoc.data(), username: landlordDoc.data().username || landlordData.username };
      } catch (err) {}
      try {
        const landlordMongo = await mongoose.model('User').findOne({ _id: landlordId }).select('avatarBase64 username');
        if (landlordMongo) {
          landlordData.avatarBase64 = landlordMongo.avatarBase64 || '';
          landlordData.username = landlordMongo.username || landlordData.username;
        }
      } catch (err) {}
      try {
        const userDoc = await admin.firestore().collection('Users').doc(userId).get();
        if (userDoc.exists) userData = userDoc.data();
      } catch (err) {}
      try {
        const userMongo = await mongoose.model('User').findOne({ _id: userId }).select('avatarBase64 username');
        if (userMongo) {
          userData.avatarBase64 = userMongo.avatarBase64 || '';
          userData.username = userMongo.username || userData.username;
        }
      } catch (err) {}

      let conversation = await Conversation.findOne({
        rentalId,
        $or: [
          { participants: [userId, landlordId] },
          { participants: [landlordId, userId] }
        ]
      }).populate('lastMessage');
      if (!conversation) {
        conversation = new Conversation({
          rentalId,
          participants: [userId, landlordId],
          lastMessage: null,
          isPending: true,
        });
        await conversation.save();
      }

      let rentalData = null;
      try {
        const rentalDoc = await Rental.findById(rentalId).select('title images contactInfo');
        if (rentalDoc) {
          rentalData = {
            id: rentalDoc._id.toString(),
            title: rentalDoc.title,
            image: rentalDoc.images[0] || '',
            contactName: rentalDoc.contactInfo?.name || 'Chủ nhà',
          };
        }
      } catch (err) {}

      const adjustedConversation = {
        ...conversation.toObject(),
        _id: conversation._id.toString(),
        createdAt: new Date(conversation.createdAt.getTime() + 7 * 60 * 60 * 1000),
        updatedAt: conversation.updatedAt ? new Date(conversation.updatedAt.getTime() + 7 * 60 * 60 * 1000) : null,
        lastMessage: conversation.lastMessage
          ? {
              ...conversation.lastMessage.toObject(),
              _id: conversation.lastMessage._id.toString(),
              conversationId: conversation.lastMessage.conversationId.toString(),
              createdAt: new Date(conversation.lastMessage.createdAt.getTime() + 7 * 60 * 60 * 1000),
              updatedAt: conversation.lastMessage.updatedAt ? new Date(conversation.lastMessage.updatedAt.getTime() + 7 * 60 * 60 * 1000) : null,
              sender: {
                id: conversation.lastMessage.senderId,
                username: conversation.lastMessage.senderId === userId ? userData.username : landlordData.username,
                avatarBase64: conversation.lastMessage.senderId === userId ? userData.avatarBase64 : landlordData.avatarBase64,
              }
            }
          : null,
        landlord: {
          id: landlordId,
          username: landlordData.username,
          avatarBase64: landlordData.avatarBase64,
        },
        user: {
          id: userId,
          username: userData.username,
          avatarBase64: userData.avatarBase64,
        },
        rental: rentalData,
      };

      await redisClient.del(`conversations:${userId}`);
      await redisClient.del(`conversations:${landlordId}`);

      const userConversations = await Conversation.find({ participants: userId }).populate('lastMessage').lean();
      const enrichedUserConversations = await Promise.all(
        userConversations.map(async (conv) => {
          const otherParticipantId = conv.participants.find((p) => p !== userId) || '';
          let participantData = { username: 'Chủ nhà', avatarBase64: '' };
          let userData2 = { username: 'Chủ nhà', avatarBase64: '' };
          let rentalData = null;

          try {
            const rentalDoc = await Rental.findById(conv.rentalId).select('contactInfo');
            if (rentalDoc) {
              participantData.username = rentalDoc.contactInfo?.name || 'Chủ nhà';
            }
          } catch (err) {}
          try {
            const participantDoc = await admin.firestore().collection('Users').doc(otherParticipantId).get();
            if (participantDoc.exists) participantData = { ...participantDoc.data(), username: participantDoc.data().username || participantData.username };
          } catch (err) {}
          try {
            const participantMongo = await mongoose.model('User').findOne({ _id: otherParticipantId }).select('avatarBase64 username');
            if (participantMongo) {
              participantData.avatarBase64 = participantMongo.avatarBase64 || '';
              participantData.username = participantMongo.username || participantData.username;
            }
          } catch (err) {}
          try {
            const userDoc2 = await admin.firestore().collection('Users').doc(userId).get();
            if (userDoc2.exists) userData2 = userDoc2.data();
          } catch (err) {}
          try {
            const userMongo2 = await mongoose.model('User').findOne({ _id: userId }).select('avatarBase64 username');
            if (userMongo2) {
              userData2.avatarBase64 = userMongo2.avatarBase64 || '';
              userData2.username = userMongo2.username || userData2.username;
            }
          } catch (err) {}
          try {
            const rental = await Rental.findById(conv.rentalId).select('title images contactInfo');
            if (rental) {
              rentalData = {
                id: rental._id.toString(),
                title: rental.title,
                image: rental.images[0] || '',
                contactName: rental.contactInfo?.name || 'Chủ nhà',
              };
            }
          } catch (err) {}

          return {
            ...conv,
            _id: conv._id.toString(),
            createdAt: new Date(conv.createdAt.getTime() + 7 * 60 * 60 * 1000),
            updatedAt: conv.updatedAt ? new Date(conv.updatedAt.getTime() + 7 * 60 * 60 * 1000) : null,
            lastMessage: conv.lastMessage
              ? {
                  ...conv.lastMessage,
                  _id: conv.lastMessage._id.toString(),
                  conversationId: conv.lastMessage.conversationId.toString(),
                  createdAt: new Date(conv.lastMessage.createdAt.getTime() + 7 * 60 * 60 * 1000),
                  updatedAt: conv.lastMessage.updatedAt ? new Date(conv.lastMessage.updatedAt.getTime() + 7 * 60 * 60 * 1000) : null,
                  sender: {
                    id: conv.lastMessage.senderId,
                    username: conv.lastMessage.senderId === userId ? userData2.username : participantData.username,
                    avatarBase64: conv.lastMessage.senderId === userId ? userData2.avatarBase64 : participantData.avatarBase64,
                  }
                }
              : null,
            landlord: {
              id: otherParticipantId,
              username: participantData.username,
              avatarBase64: participantData.avatarBase64,
            },
            user: {
              id: userId,
              username: userData2.username,
              avatarBase64: userData2.avatarBase64,
            },
            rental: rentalData,
          };
        })
      );

      await redisClient.setEx(`conversations:${userId}`, 3600, JSON.stringify(enrichedUserConversations));

      res.status(201).json(adjustedConversation);
    } catch (err) {
      res.status(500).json({ message: 'Server error', error: err.message });
    }
  });

  router.get('/messages/:conversationId', authMiddleware, async (req, res) => {
    try {
      const { conversationId } = req.params;
      const { cursor, limit = 10 } = req.query;
      if (!mongoose.Types.ObjectId.isValid(conversationId)) {
        return res.status(400).json({ message: 'Invalid conversationId format' });
      }
      const conversation = await Conversation.findById(conversationId);
      if (!conversation || !conversation.participants.includes(req.userId)) {
        return res.status(403).json({ message: 'Unauthorized or conversation not found' });
      }
      const query = { conversationId: new mongoose.Types.ObjectId(conversationId) };
      if (cursor) {
        query._id = { $lt: cursor };
      }
      const messages = await Message.find(query)
        .sort({ createdAt: -1 })
        .limit(parseInt(limit))
        .lean();

      const senderIds = [...new Set(messages.map(msg => msg.senderId))];
      const senderAvatars = {};
      for (const senderId of senderIds) {
        let avatarBase64 = '';
        let username = 'Chủ nhà';
        try {
          const rentalDoc = await Rental.findOne({ userId: senderId }).select('contactInfo');
          if (rentalDoc) {
            username = rentalDoc.contactInfo?.name || 'Chủ nhà';
          }
        } catch (err) {}
        try {
          const userMongo = await mongoose.model('User').findOne({ _id: senderId }).select('avatarBase64 username');
          if (userMongo) {
            avatarBase64 = userMongo.avatarBase64 || '';
            username = userMongo.username || username;
          }
        } catch (err) {}
        if (!username || !avatarBase64) {
          try {
            const userDoc = await admin.firestore().collection('Users').doc(senderId).get();
            if (userDoc.exists) {
              const data = userDoc.data();
              avatarBase64 = avatarBase64 || data.avatarBase64 || '';
              username = data.username || username;
            }
          } catch (err) {}
        }
        senderAvatars[senderId] = { avatarBase64, username };
      }

      const nextCursor = messages.length === parseInt(limit) ? messages[messages.length - 1]._id : null;
      const adjustedMessages = messages.map((msg) => ({
        ...msg,
        _id: msg._id.toString(),
        conversationId: msg.conversationId.toString(),
        createdAt: new Date(msg.createdAt.getTime() + 7 * 60 * 60 * 1000),
        updatedAt: msg.updatedAt ? new Date(msg.updatedAt.getTime() + 7 * 60 * 60 * 1000) : null,
        sender: {
          id: msg.senderId,
          username: senderAvatars[msg.senderId]?.username || 'Chủ nhà',
          avatarBase64: senderAvatars[msg.senderId]?.avatarBase64 || '',
        }
      }));
      res.json({ messages: adjustedMessages, nextCursor });
    } catch (err) {
      res.status(500).json({ message: err.message });
    }
  });

  router.post('/messages', authMiddleware, upload.array('images'), async (req, res) => {
    try {
      const { conversationId, content = '' } = req.body;
      if (!mongoose.Types.ObjectId.isValid(conversationId)) {
        return res.status(400).json({ message: 'Invalid conversationId' });
      }
      if (!content && (!req.files || req.files.length === 0)) {
        return res.status(400).json({ message: 'Message must have either content or images' });
      }
      const conversation = await Conversation.findById(conversationId);
      if (!conversation || !conversation.participants.includes(req.userId)) {
        return res.status(403).json({ message: 'Unauthorized or conversation not found' });
      }
      const imageUrls = req.files ? req.files.map(file => `/uploads/${file.filename}`) : [];
      const message = new Message({
        conversationId,
        senderId: req.userId,
        content,
        images: imageUrls,
      });
      await message.save();
      conversation.lastMessage = message._id;
      conversation.isPending = false;
      await conversation.save();
      await redisClient.del(`conversations:${conversation.participants[0]}`);
      await redisClient.del(`conversations:${conversation.participants[1]}`);

      let avatarBase64 = '';
      let username = 'Chủ nhà';
      try {
        const rentalDoc = await Rental.findOne({ userId: req.userId }).select('contactInfo');
        if (rentalDoc) {
          username = rentalDoc.contactInfo?.name || 'Chủ nhà';
        }
      } catch (err) {}
      try {
        const userMongo = await mongoose.model('User').findOne({ _id: req.userId }).select('avatarBase64 username');
        if (userMongo) {
          avatarBase64 = userMongo.avatarBase64 || '';
          username = userMongo.username || username;
        }
      } catch (err) {}
      if (!avatarBase64 || !username) {
        try {
          const userDoc = await admin.firestore().collection('Users').doc(req.userId).get();
          if (userDoc.exists) {
            const data = userDoc.data();
            avatarBase64 = avatarBase64 || data.avatarBase64 || '';
            username = data.username || username;
          }
        } catch (err) {}
      }

      const messageData = {
        _id: message._id.toString(),
        conversationId: message.conversationId.toString(),
        senderId: message.senderId,
        content: message.content,
        images: message.images,
        createdAt: new Date(message.createdAt.getTime() + 7 * 60 * 60 * 1000),
        updatedAt: message.updatedAt ? new Date(message.updatedAt.getTime() + 7 * 60 * 60 * 1000) : null,
        sender: {
          id: req.userId,
          username: username,
          avatarBase64: avatarBase64,
        }
      };

      console.log(`Emitting receiveMessage to room ${conversationId}:`, JSON.stringify(messageData, null, 2));
      if (io) {
        io.to(conversationId).emit('receiveMessage', messageData);
      } else {
        console.error('Socket.IO instance is not initialized');
      }
      res.status(201).json(messageData);
    } catch (err) {
      res.status(500).json({ message: err.message });
    }
  });

  router.delete('/messages/:messageId', authMiddleware, async (req, res) => {
    try {
      const { messageId } = req.params;
      if (!mongoose.Types.ObjectId.isValid(messageId)) {
        return res.status(400).json({ message: 'Invalid messageId format' });
      }
      const message = await Message.findById(messageId);
      if (!message) {
        return res.status(404).json({ message: 'Message not found' });
      }
      if (message.senderId !== req.userId) {
        return res.status(403).json({ message: 'Unauthorized: You can only delete your own messages' });
      }
      const conversation = await Conversation.findById(message.conversationId);
      if (!conversation || !conversation.participants.includes(req.userId)) {
        return res.status(403).json({ message: 'Unauthorized or conversation not found' });
      }

      await Message.deleteOne({ _id: messageId });

      if (conversation.lastMessage?.toString() === messageId) {
        const lastMessage = await Message.findOne({ conversationId: conversation._id })
          .sort({ createdAt: -1 })
          .lean();
        conversation.lastMessage = lastMessage ? lastMessage._id : null;
        await conversation.save();
      }

      await redisClient.del(`conversations:${conversation.participants[0]}`);
      await redisClient.del(`conversations:${conversation.participants[1]}`);

      const deleteData = { messageId: messageId.toString() };
      console.log(`Emitting deleteMessage to room ${conversation._id}:`, JSON.stringify(deleteData, null, 2));
      if (io) {
        io.to(conversation._id.toString()).emit('deleteMessage', deleteData);
      } else {
        console.error('Socket.IO instance is not initialized for deleteMessage');
      }

      res.status(200).json({ message: 'Message deleted successfully' });
    } catch (err) {
      res.status(500).json({ message: err.message });
    }
  });

  router.patch('/messages/:messageId', authMiddleware, upload.array('images'), async (req, res) => {
    try {
      const { messageId } = req.params;
      let { content, removeImages } = req.body;
      content = content ? content.trim() : '';

      if (!mongoose.Types.ObjectId.isValid(messageId)) {
        return res.status(400).json({ message: 'Invalid messageId format' });
      }
      if (!content && (!req.files || req.files.length === 0) && (!removeImages || removeImages.length === 0)) {
        return res.status(400).json({ message: 'At least one of content or images must be provided' });
      }
      const message = await Message.findById(messageId);
      if (!message) {
        return res.status(404).json({ message: 'Message not found' });
      }
      if (message.senderId !== req.userId) {
        return res.status(403).json({ message: 'Unauthorized: You can only edit your own messages' });
      }
      const conversation = await Conversation.findById(message.conversationId);
      if (!conversation || !conversation.participants.includes(req.userId)) {
        return res.status(403).json({ message: 'Unauthorized or conversation not found' });
      }

      if (content) {
        message.content = content;
      }

      let updatedImages = message.images;
      if (removeImages) {
        try {
          removeImages = JSON.parse(removeImages);
          if (Array.isArray(removeImages)) {
            updatedImages = updatedImages.filter(url => !removeImages.includes(url));
          }
        } catch (err) {
          console.warn('Invalid removeImages format:', removeImages);
        }
      }
      if (req.files && req.files.length > 0) {
        const newImageUrls = req.files.map(file => `/uploads/${file.filename}`);
        updatedImages = [...updatedImages, ...newImageUrls];
      }
      message.images = updatedImages;

      message.updatedAt = new Date();
      await message.save();

      let avatarBase64 = '';
      let username = 'Chủ nhà';
      try {
        const rentalDoc = await Rental.findOne({ userId: req.userId }).select('contactInfo');
        if (rentalDoc) {
          username = rentalDoc.contactInfo?.name || 'Chủ nhà';
        }
      } catch (err) {}
      try {
        const userMongo = await mongoose.model('User').findOne({ _id: req.userId }).select('avatarBase64 username');
        if (userMongo) {
          avatarBase64 = userMongo.avatarBase64 || '';
          username = userMongo.username || username;
        }
      } catch (err) {}
      if (!avatarBase64 || !username) {
        try {
          const userDoc = await admin.firestore().collection('Users').doc(req.userId).get();
          if (userDoc.exists) {
            const data = userDoc.data();
            avatarBase64 = avatarBase64 || data.avatarBase64 || '';
            username = data.username || username;
          }
        } catch (err) {}
      }

      const messageData = {
        _id: message._id.toString(),
        conversationId: message.conversationId.toString(),
        senderId: message.senderId,
        content: message.content,
        images: message.images,
        createdAt: new Date(message.createdAt.getTime() + 7 * 60 * 60 * 1000),
        updatedAt: new Date(message.updatedAt.getTime() + 7 * 60 * 60 * 1000),
        sender: {
          id: req.userId,
          username: username,
          avatarBase64: avatarBase64,
        }
      };

      console.log(`Emitting updateMessage to room ${conversation._id}:`, JSON.stringify(messageData, null, 2));
      if (io) {
        io.to(conversation._id.toString()).emit('updateMessage', messageData);
      } else {
        console.error('Socket.IO instance is not initialized for updateMessage');
      }

      res.status(200).json(messageData);
    } catch (err) {
      res.status(500).json({ message: err.message });
    }
  });

  router.get('/conversations', authMiddleware, async (req, res) => {
    try {
      const userId = req.userId;
      const cached = await redisClient.get(`conversations:${userId}`);
      if (cached) {
        return res.json(JSON.parse(cached));
      }
      const conversations = await Conversation.find({ participants: userId }).populate('lastMessage').lean();
      const enrichedConversations = await Promise.all(
        conversations.map(async (conv) => {
          const otherParticipantId = conv.participants.find((p) => p !== userId) || '';
          let participantData = { username: 'Chủ nhà', avatarBase64: '' };
          let userData = { username: 'Chủ nhà', avatarBase64: '' };
          let rentalData = null;
          try {
            const rentalDoc = await Rental.findById(conv.rentalId).select('contactInfo');
            if (rentalDoc) {
              participantData.username = rentalDoc.contactInfo?.name || 'Chủ nhà';
            }
          } catch (err) {}
          try {
            const participantDoc = await admin.firestore().collection('Users').doc(otherParticipantId).get();
            if (participantDoc.exists) participantData = { ...participantDoc.data(), username: participantDoc.data().username || participantData.username };
          } catch (err) {}
          try {
            const participantMongo = await mongoose.model('User').findOne({ _id: otherParticipantId }).select('avatarBase64 username');
            if (participantMongo) {
              participantData.avatarBase64 = participantMongo.avatarBase64 || '';
              participantData.username = participantMongo.username || participantData.username;
            }
          } catch (err) {}
          try {
            const userDoc = await admin.firestore().collection('Users').doc(userId).get();
            if (userDoc.exists) userData = userDoc.data();
          } catch (err) {}
          try {
            const userMongo = await mongoose.model('User').findOne({ _id: userId }).select('avatarBase64 username');
            if (userMongo) {
              userData.avatarBase64 = userMongo.avatarBase64 || '';
              userData.username = userMongo.username || userData.username;
            }
          } catch (err) {}
          try {
            const rental = await Rental.findById(conv.rentalId).select('title images contactInfo');
            if (rental) {
              rentalData = {
                id: rental._id.toString(),
                title: rental.title,
                image: rental.images[0] || '',
                contactName: rental.contactInfo?.name || 'Chủ nhà',
              };
            }
          } catch (err) {}
          return {
            ...conv,
            _id: conv._id.toString(),
            createdAt: new Date(conv.createdAt.getTime() + 7 * 60 * 60 * 1000),
            updatedAt: conv.updatedAt ? new Date(conv.updatedAt.getTime() + 7 * 60 * 60 * 1000) : null,
            lastMessage: conv.lastMessage
              ? {
                  ...conv.lastMessage,
                  _id: conv.lastMessage._id.toString(),
                  conversationId: conv.lastMessage.conversationId.toString(),
                  createdAt: new Date(conv.lastMessage.createdAt.getTime() + 7 * 60 * 60 * 1000),
                  updatedAt: conv.lastMessage.updatedAt ? new Date(conv.lastMessage.updatedAt.getTime() + 7 * 60 * 60 * 1000) : null,
                  sender: {
                    id: conv.lastMessage.senderId,
                    username: conv.lastMessage.senderId === userId ? userData.username : participantData.username,
                    avatarBase64: conv.lastMessage.senderId === userId ? userData.avatarBase64 : participantData.avatarBase64,
                  }
                }
              : null,
            landlord: {
              id: otherParticipantId,
              username: participantData.username,
              avatarBase64: participantData.avatarBase64,
            },
            user: {
              id: userId,
              username: userData.username,
              avatarBase64: userData.avatarBase64,
            },
            rental: rentalData,
          };
        })
      );
      await redisClient.setEx(`conversations:${userId}`, 3600, JSON.stringify(enrichedConversations));
      res.json(enrichedConversations);
    } catch (err) {
      res.status(500).json({ message: err.message });
    }
  });

  return router;
};