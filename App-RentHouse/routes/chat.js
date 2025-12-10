const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const admin = require('firebase-admin');
const { OAuth2Client } = require('google-auth-library');
const multer = require('multer');
const redis = require('redis');
const Rental = require('../models/Rental');
const Conversation = require('../models/conversation');
const Message = require('../models/message');
const cloudinary = require('../config/cloudinary');

const googleClient = new OAuth2Client(process.env.GOOGLE_CLIENT_ID);

// ===================== MULTER CONFIGURATION =====================
const storage = multer.memoryStorage();
const upload = multer({
  storage,
  limits: { fileSize: 50 * 1024 * 1024 }, // 50MB per file
  fileFilter: (req, file, cb) => {
    // ✅ Simplified validation - chỉ check extension
    const filename = file.originalname.toLowerCase();
    const allowedExtensions = /\.(jpeg|jpg|png|webp|gif)$/i;
    
    const hasValidExtension = allowedExtensions.test(filename);
    
    console.log('📎 File Upload Check:', {
      filename: file.originalname,
      extension: filename.match(/\.\w+$/)?.[0] || 'unknown',
      mimetype: file.mimetype,
      isValid: hasValidExtension,
    });
    
    if (hasValidExtension) {
      return cb(null, true);
    }
    
    cb(new Error('Chỉ chấp nhận file ảnh (JPEG, JPG, PNG, WebP, GIF)'));
  },
});
// ===================== CLOUDINARY HELPERS =====================
const uploadImageToCloudinary = async (fileBuffer, originalName) => {
  try {
    const base64Image = fileBuffer.toString('base64');
    
    let mimeType = 'image/jpeg';
    const ext = originalName.match(/\.(jpg|jpeg|png|gif|webp)$/i);
    if (ext) {
      const extension = ext[1].toLowerCase();
      const mimeTypeMap = {
        'jpg': 'image/jpeg',
        'jpeg': 'image/jpeg',
        'png': 'image/png',
        'gif': 'image/gif',
        'webp': 'image/webp'
      };
      mimeType = mimeTypeMap[extension] || 'image/jpeg';
    }
    
    const dataUri = `data:${mimeType};base64,${base64Image}`;
    
    console.log('☁️ Uploading to Cloudinary:', {
      filename: originalName,
      mimeType: mimeType,
      size: `${(fileBuffer.length / 1024).toFixed(2)} KB`
    });
    
    const result = await cloudinary.uploader.upload(dataUri, {
      folder: 'chat_images',
      resource_type: 'auto',
      quality: 'auto:good',
      fetch_format: 'auto',
    });
    
    console.log('✅ Cloudinary upload success:', result.secure_url);
    
    // Return full Cloudinary URL
    return result.secure_url;
  } catch (error) {
    console.error('❌ Cloudinary upload error:', error);
    throw new Error('Failed to upload image to Cloudinary');
  }
};

const deleteImagesFromCloudinary = async (imageUrls) => {
  try {
    for (const url of imageUrls) {
      // Extract public_id from Cloudinary URL
      // Example: https://res.cloudinary.com/demo/image/upload/v1234567890/chat_images/abc123.jpg
      const matches = url.match(/\/chat_images\/([^/.]+)/);
      if (matches && matches[1]) {
        const publicId = `chat_images/${matches[1]}`;
        console.log('🗑️ Deleting from Cloudinary:', publicId);
        await cloudinary.uploader.destroy(publicId).catch(err => 
          console.warn(`⚠️ Failed to delete image ${publicId}:`, err.message)
        );
      }
    }
  } catch (error) {
    console.error('❌ Error deleting images from Cloudinary:', error);
  }
};

// ===================== REDIS CONFIGURATION =====================
const redisClient = redis.createClient({
  url: process.env.REDIS_URL || 'redis://localhost:6379',
});
redisClient.on('error', (err) => console.log('Redis Client Error', err));
redisClient.connect().catch((err) => console.error('Redis Connection Error:', err));

// ===================== DATABASE INDEXES =====================
Conversation.collection.createIndex({ participants: 1, rentalId: 1 });
Message.collection.createIndex({ conversationId: 1, createdAt: 1 });

// ===================== AUTH MIDDLEWARE =====================
const authMiddleware = async (req, res, next) => {
  try {
    const authHeader = req.header('Authorization');
    if (!authHeader?.startsWith('Bearer ')) {
      console.error('No token provided in Authorization header');
      return res.status(401).json({ message: 'No token provided', error: 'Missing Authorization header' });
    }
    const token = authHeader.replace('Bearer ', '');

    let decodedToken;
    try {
      decodedToken = await admin.auth().verifyIdToken(token, true);
      req.userId = decodedToken.uid;
    } catch (firebaseError) {
      try {
        const ticket = await googleClient.verifyIdToken({
          idToken: token,
          audience: process.env.GOOGLE_CLIENT_ID,
        });
        const payload = ticket.getPayload();
        if (!payload) {
          console.error('Invalid Google token payload');
          throw new Error('Invalid Google token payload');
        }
        if (payload.exp * 1000 < Date.now()) {
          console.error('Google token expired');
          return res.status(401).json({ message: 'Token expired', error: 'Google token has expired' });
        }
        req.userId = payload['sub'];
        decodedToken = {
          uid: payload['sub'],
          name: payload['name'] || payload['email'],
          email: payload['email'],
          picture: payload['picture'] || '',
        };
      } catch (googleError) {
        console.error('Token verification error:', {
          firebaseError: firebaseError.message,
          googleError: googleError.message,
        });
        return res.status(401).json({
          message: 'Invalid or expired token',
          error: 'Token verification failed',
        });
      }
    }

    const userCacheKey = `user:${req.userId}`;
    let userData = await redisClient.get(userCacheKey);

    if (!userData) {
      const userDoc = await admin.firestore().collection('Users').doc(req.userId).get();
      userData = userDoc.exists ? userDoc.data() : {
        uid: req.userId,
        username: decodedToken.name || decodedToken.email,
        avatarUrl: decodedToken.picture || '',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      await redisClient.setEx(userCacheKey, 86400, JSON.stringify(userData));

      if (!userDoc.exists) {
        await admin.firestore().collection('Users').doc(req.userId).set(userData);
      }
    } else {
      userData = JSON.parse(userData);
    }

    req.userData = userData;
    next();
  } catch (err) {
    console.error('Authentication error:', err.message);
    res.status(401).json({ 
      message: 'Invalid or expired token',
      error: err.message 
    });
  }
};

// ===================== UTILITY FUNCTIONS =====================
const adjustTimestamps = (obj) => {
  const adjusted = { ...obj };
  adjusted.createdAt = new Date(adjusted.createdAt.getTime() + 7 * 60 * 60 * 1000);
  adjusted.updatedAt = adjusted.updatedAt ? new Date(adjusted.updatedAt.getTime() + 7 * 60 * 60 * 1000) : null;
  return adjusted;
};

const convertUnreadCounts = (unreadCounts) => {
  if (unreadCounts instanceof Map) {
    return Object.fromEntries(unreadCounts);
  } else if (unreadCounts && typeof unreadCounts === 'object') {
    return unreadCounts;
  }
  return {};
};

const getUserData = async (userId) => {
  const cacheKey = `user:${userId}`;
  let userData = await redisClient.get(cacheKey);
  if (userData) {
    return JSON.parse(userData);
  }
  try {
    const userDoc = await admin.firestore().collection('Users').doc(userId).get();
    userData = userDoc.exists ? userDoc.data() : { username: 'User', avatarUrl: '' };
    const userMongo = await mongoose.model('User').findOne({ _id: userId }).select('avatarUrl username').lean();
    if (userMongo) {
      userData = { ...userData, ...userMongo };
    }
    await redisClient.setEx(cacheKey, 86400, JSON.stringify(userData));
    return userData;
  } catch (err) {
    console.error(`Error fetching user data for ${userId}:`, err.message);
    return { username: 'User', avatarUrl: '' };
  }
};

// ===================== ROUTES =====================
module.exports = (io) => {
  
  // ==================== GET CONVERSATIONS ====================
  router.get('/conversations', authMiddleware, async (req, res) => {
    try {
      const userId = req.userId;
      const cached = await redisClient.get(`conversations:${userId}`);
      if (cached) {
        return res.json(JSON.parse(cached));
      }
      
      const conversations = await Conversation.find({ participants: userId }).populate('lastMessage').lean();
      if (!conversations || conversations.length === 0) {
        return res.status(200).json([]);
      }
      
      const enrichedConversations = await Promise.all(
        conversations.map(async (conv) => {
          const otherParticipantId = conv.participants.find((p) => p !== userId) || '';
          let participantData = { username: 'Chủ nhà', avatarUrl: '' };
          let userData = { username: 'Chủ nhà', avatarUrl: '' };
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
            const participantMongo = await mongoose.model('User').findOne({ _id: otherParticipantId }).select('avatarUrl username');
            if (participantMongo) {
              participantData.avatarUrl = participantMongo.avatarUrl || '';
              participantData.username = participantMongo.username || participantData.username;
            }
          } catch (err) {}
          
          try {
            const userDoc = await admin.firestore().collection('Users').doc(userId).get();
            if (userDoc.exists) userData = userDoc.data();
          } catch (err) {}
          
          try {
            const userMongo = await mongoose.model('User').findOne({ _id: userId }).select('avatarUrl username');
            if (userMongo) {
              userData.avatarUrl = userMongo.avatarUrl || '';
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
            ...adjustTimestamps(conv),
            _id: conv._id.toString(),
            unreadCounts: convertUnreadCounts(conv.unreadCounts),
            lastMessage: conv.lastMessage
              ? {
                  ...adjustTimestamps(conv.lastMessage),
                  _id: conv.lastMessage._id.toString(),
                  conversationId: conv.lastMessage.conversationId.toString(),
                  sender: {
                    id: conv.lastMessage.senderId,
                    username: conv.lastMessage.senderId === userId ? userData.username : participantData.username,
                    avatarUrl: conv.lastMessage.senderId === userId ? userData.avatarUrl : participantData.avatarUrl,
                  }
                }
              : null,
            landlord: {
              id: otherParticipantId,
              username: participantData.username,
              avatarUrl: participantData.avatarUrl,
            },
            user: {
              id: userId,
              username: userData.username,
              avatarUrl: userData.avatarUrl,
            },
            rental: rentalData,
          };
        })
      );
      
      await redisClient.setEx(`conversations:${userId}`, 3600, JSON.stringify(enrichedConversations));
      res.json(enrichedConversations);
    } catch (err) {
      console.error('Error in GET /conversations:', err.message);
      res.status(500).json({ message: 'Failed to load conversations', error: err.message });
    }
  });

  // ==================== CREATE CONVERSATION ====================
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

      let landlordData = { username: rental.contactInfo?.name || 'Chủ nhà', avatarUrl: '' };
      let userData = { username: 'Chủ nhà', avatarUrl: '' };
      
      try {
        const landlordDoc = await admin.firestore().collection('Users').doc(landlordId).get();
        if (landlordDoc.exists) landlordData = { ...landlordDoc.data(), username: landlordDoc.data().username || landlordData.username };
      } catch (err) {}
      
      try {
        const landlordMongo = await mongoose.model('User').findOne({ _id: landlordId }).select('avatarUrl username');
        if (landlordMongo) {
          landlordData.avatarUrl = landlordMongo.avatarUrl || '';
          landlordData.username = landlordMongo.username || landlordData.username;
        }
      } catch (err) {}
      
      try {
        const userDoc = await admin.firestore().collection('Users').doc(userId).get();
        if (userDoc.exists) userData = userDoc.data();
      } catch (err) {}
      
      try {
        const userMongo = await mongoose.model('User').findOne({ _id: userId }).select('avatarUrl username');
        if (userMongo) {
          userData.avatarUrl = userMongo.avatarUrl || '';
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
          unreadCounts: new Map([[userId, 0], [landlordId, 0]]),
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
        ...adjustTimestamps(conversation.toObject()),
        _id: conversation._id.toString(),
        unreadCounts: convertUnreadCounts(conversation.unreadCounts),
        lastMessage: conversation.lastMessage
          ? {
              ...adjustTimestamps(conversation.lastMessage.toObject()),
              _id: conversation.lastMessage._id.toString(),
              conversationId: conversation.lastMessage.conversationId.toString(),
              sender: {
                id: conversation.lastMessage.senderId,
                username: conversation.lastMessage.senderId === userId ? userData.username : landlordData.username,
                avatarUrl: conversation.lastMessage.senderId === userId ? userData.avatarUrl : landlordData.avatarUrl,
              }
            }
          : null,
        landlord: {
          id: landlordId,
          username: landlordData.username,
          avatarUrl: landlordData.avatarUrl,
        },
        user: {
          id: userId,
          username: userData.username,
          avatarUrl: userData.avatarUrl,
        },
        rental: rentalData,
      };

      await redisClient.del(`conversations:${userId}`);
      await redisClient.del(`conversations:${landlordId}`);

      res.status(201).json(adjustedConversation);
    } catch (err) {
      console.error('Error in POST /conversations:', err.message);
      res.status(500).json({ message: 'Server error', error: err.message });
    }
  });

  // ==================== DELETE CONVERSATION ====================
  router.delete('/conversations/:conversationId', authMiddleware, async (req, res) => {
    try {
      const { conversationId } = req.params;
      const userId = req.userId;

      if (!mongoose.Types.ObjectId.isValid(conversationId)) {
        return res.status(400).json({ message: 'Invalid conversationId format' });
      }

      const conversation = await Conversation.findById(conversationId);
      if (!conversation || !conversation.participants.includes(userId)) {
        return res.status(403).json({ message: 'Unauthorized or conversation not found' });
      }

      const messages = await Message.find({ conversationId }).lean();
      const allImageUrls = messages.flatMap(msg => msg.images || []);
      if (allImageUrls.length > 0) {
        console.log(`🗑️ Deleting ${allImageUrls.length} images from deleted conversation...`);
        await deleteImagesFromCloudinary(allImageUrls);
      }

      await Message.deleteMany({ conversationId });
      await Conversation.deleteOne({ _id: conversationId });

      const participants = conversation.participants;
      for (const participantId of participants) {
        await redisClient.del(`conversations:${participantId}`);
      }

      if (io) {
        io.to(conversationId).emit('deleteConversation', { conversationId });
      }

      res.status(200).json({ message: 'Conversation deleted successfully' });
    } catch (err) {
      console.error('Error in DELETE /conversations:', err.message);
      res.status(500).json({ message: 'Server error', error: err.message });
    }
  });

  // ==================== GET MESSAGES ====================
  router.get('/messages/:conversationId', authMiddleware, async (req, res) => {
    try {
      const { conversationId } = req.params;
      const { cursor, limit = 10 } = req.query;
      const userId = req.userId;

      if (!mongoose.Types.ObjectId.isValid(conversationId)) {
        return res.status(400).json({ message: 'Invalid conversationId format' });
      }
      
      const conversation = await Conversation.findById(conversationId);
      if (!conversation || !conversation.participants.includes(userId)) {
        return res.status(403).json({ message: 'Unauthorized or conversation not found' });
      }

      conversation.unreadCounts.set(userId, 0);
      await conversation.save();
      await redisClient.del(`conversations:${userId}`);

      const query = { conversationId: new mongoose.Types.ObjectId(conversationId) };
      if (cursor) {
        query._id = { $gt: cursor };
      }
      
      const messages = await Message.find(query)
        .sort({ createdAt: 1 })
        .limit(parseInt(limit))
        .lean();

      const senderIds = [...new Set(messages.map(msg => msg.senderId))];
      const senderAvatars = {};
      
      for (const senderId of senderIds) {
        let avatarUrl = '';
        let username = 'Chủ nhà';
        
        try {
          const rentalDoc = await Rental.findOne({ userId: senderId }).select('contactInfo');
          if (rentalDoc) {
            username = rentalDoc.contactInfo?.name || 'Chủ nhà';
          }
        } catch (err) {}
        
        try {
          const userMongo = await mongoose.model('User').findOne({ _id: senderId }).select('avatarUrl username');
          if (userMongo) {
            avatarUrl = userMongo.avatarUrl || '';
            username = userMongo.username || username;
          }
        } catch (err) {}
        
        if (!username || !avatarUrl) {
          try {
            const userDoc = await admin.firestore().collection('Users').doc(senderId).get();
            if (userDoc.exists) {
              const data = userDoc.data();
              avatarUrl = avatarUrl || data.avatarUrl || '';
              username = data.username || username;
            }
          } catch (err) {}
        }
        
        senderAvatars[senderId] = { avatarUrl, username };
      }

      const nextCursor = messages.length === parseInt(limit) ? messages[messages.length - 1]._id : null;
      const adjustedMessages = messages.map((msg) => ({
        ...adjustTimestamps(msg),
        _id: msg._id.toString(),
        conversationId: msg.conversationId.toString(),
        sender: {
          id: msg.senderId,
          username: senderAvatars[msg.senderId]?.username || 'Chủ nhà',
          avatarUrl: senderAvatars[msg.senderId]?.avatarUrl || '',
        }
      }));

      res.json({ messages: adjustedMessages, nextCursor });
    } catch (err) {
      console.error('Error in GET /messages:', err.message);
      res.status(500).json({ message: err.message });
    }
  });

  // ==================== SEND MESSAGE ====================

  router.post('/messages', authMiddleware, upload.array('images'), async (req, res) => {
    try {
      const { conversationId, content = '' } = req.body;
      const userId = req.userId;

      console.log('📨 POST /messages - Body:', { conversationId, content, filesCount: req.files?.length || 0 });

      if (!mongoose.Types.ObjectId.isValid(conversationId)) {
        return res.status(400).json({ message: 'Invalid conversationId' });
      }
      if (!content && (!req.files || req.files.length === 0)) {
        return res.status(400).json({ message: 'Message must have either content or images' });
      }
      
      const conversation = await Conversation.findById(conversationId);
      if (!conversation || !conversation.participants.includes(userId)) {
        return res.status(403).json({ message: 'Unauthorized or conversation not found' });
      }

      const recipientId = conversation.participants.find(p => p !== userId);
      if (recipientId) {
        const currentCount = conversation.unreadCounts.get(recipientId) || 0;
        conversation.unreadCounts.set(recipientId, currentCount + 1);
        conversation.unreadCounts.set(userId, 0);
      }

      const imageUrls = [];
      if (req.files && req.files.length > 0) {
        console.log(`📤 Uploading ${req.files.length} images to Cloudinary...`);
        for (const file of req.files) {
          try {
            const cloudinaryUrl = await uploadImageToCloudinary(file.buffer, file.originalname);
            imageUrls.push(cloudinaryUrl);
            console.log(`✅ Image uploaded: ${file.originalname}`);
          } catch (uploadError) {
            console.error('❌ Error uploading image:', uploadError.message);
            // Delete already uploaded images on error
            if (imageUrls.length > 0) {
              await deleteImagesFromCloudinary(imageUrls);
            }
            return res.status(500).json({ 
              message: 'Failed to upload image',
              error: uploadError.message 
            });
          }
        }
        console.log(`✅ Successfully uploaded ${imageUrls.length} images`);
      }

      const message = new Message({
        conversationId,
        senderId: userId,
        content,
        images: imageUrls,
      });
      await message.save();
      
      conversation.lastMessage = message._id;
      conversation.isPending = false;
      await conversation.save();

      await redisClient.del(`conversations:${conversation.participants[0]}`);
      await redisClient.del(`conversations:${conversation.participants[1]}`);

      let avatarUrl = '';
      let username = 'Chủ nhà';
      
      try {
        const rentalDoc = await Rental.findOne({ userId }).select('contactInfo');
        if (rentalDoc) {
          username = rentalDoc.contactInfo?.name || 'Chủ nhà';
        }
      } catch (err) {
        console.warn('⚠️ Could not fetch rental info:', err.message);
      }
      
      try {
        const userMongo = await mongoose.model('User').findOne({ _id: userId }).select('avatarUrl username');
        if (userMongo) {
          avatarUrl = userMongo.avatarUrl || '';
          username = userMongo.username || username;
        }
      } catch (err) {
        console.warn('⚠️ Could not fetch user from MongoDB:', err.message);
      }
      
      if (!avatarUrl || !username) {
        try {
          const userDoc = await admin.firestore().collection('Users').doc(userId).get();
          if (userDoc.exists) {
            const data = userDoc.data();
            avatarUrl = avatarUrl || data.avatarUrl || '';
            username = data.username || username;
          }
        } catch (err) {
          console.warn('⚠️ Could not fetch user from Firestore:', err.message);
        }
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
          id: userId,
          username: username,
          avatarUrl: avatarUrl,
        }
      };

      if (io) {
        io.to(conversationId).emit('receiveMessage', messageData);
        io.to(conversationId).emit('updateConversation', {
          ...adjustTimestamps(conversation.toObject()),
          _id: conversation._id.toString(),
          unreadCounts: convertUnreadCounts(conversation.unreadCounts),
        });
      }

      console.log('✅ Message sent successfully:', messageData._id);
      res.status(201).json(messageData);
    } catch (err) {
      console.error('❌ Error in POST /messages:', err.message);
      res.status(500).json({ 
        message: 'Có lỗi xảy ra từ server!',
        error: err.message 
      });
    }
  });

  // ==================== EDIT MESSAGE ====================
// ✅ FIXED: PATCH /messages/:messageId with proper removeImages handling

router.patch('/messages/:messageId', authMiddleware, upload.array('images'), async (req, res) => {
  try {
    const { messageId } = req.params;
    let { content, removeImages } = req.body;
    content = content ? content.trim() : '';

    console.log('🔧 ========== EDIT MESSAGE REQUEST ==========');
    console.log('🔧 MessageId:', messageId);
    console.log('🔧 Content:', content);
    console.log('🔧 RemoveImages (raw):', removeImages);
    console.log('🔧 RemoveImages type:', typeof removeImages);

    // ✅ CRITICAL FIX: Parse removeImages properly
    let removeImagesList = [];
    if (removeImages) {
      try {
        // Handle both cases: already an array or JSON string
        if (typeof removeImages === 'string') {
          removeImagesList = JSON.parse(removeImages);
        } else if (Array.isArray(removeImages)) {
          removeImagesList = removeImages;
        }
        
        console.log('✅ Parsed removeImages:', removeImagesList);
        console.log('✅ RemoveImages count:', removeImagesList.length);
      } catch (parseErr) {
        console.warn('⚠️ Failed to parse removeImages, treating as empty:', parseErr.message);
        removeImagesList = [];
      }
    }

    if (!mongoose.Types.ObjectId.isValid(messageId)) {
      return res.status(400).json({ message: 'Invalid messageId format' });
    }
    if (!content && (!req.files || req.files.length === 0) && removeImagesList.length === 0) {
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

    console.log('📋 Current message state:');
    console.log('   - Content:', message.content);
    console.log('   - Images:', message.images.length);
    for (let i = 0; i < message.images.length; i++) {
      console.log(`      [${i}] ${message.images[i]}`);
    }

    // ✅ Update content if provided
    if (content) {
      message.content = content;
      console.log('✅ Content updated');
    }

    // ✅ Start with existing images
    let updatedImages = [...message.images];
    console.log(`📸 Starting with ${updatedImages.length} existing images`);

    // ✅ Remove images from Cloudinary if specified
    if (removeImagesList.length > 0) {
      console.log(`🗑️ Removing ${removeImagesList.length} images from Cloudinary...`);
      
      // Filter and validate URLs to remove
      const validRemoveUrls = removeImagesList.filter(url => {
        const isValid = typeof url === 'string' && url.startsWith('https://');
        if (!isValid) {
          console.warn(`⚠️ Skipping invalid URL: ${url}`);
        }
        return isValid;
      });

      if (validRemoveUrls.length > 0) {
        await deleteImagesFromCloudinary(validRemoveUrls);
        // Filter out removed images from array
        updatedImages = updatedImages.filter(url => !validRemoveUrls.includes(url));
        console.log(`✅ After removal: ${updatedImages.length} images remain`);
      }
    }

    // ✅ Upload new images to Cloudinary
    if (req.files && req.files.length > 0) {
      console.log(`📤 Uploading ${req.files.length} new images...`);
      const uploadedUrls = [];
      
      for (let i = 0; i < req.files.length; i++) {
        const file = req.files[i];
        try {
          const cloudinaryUrl = await uploadImageToCloudinary(file.buffer, file.originalname);
          uploadedUrls.push(cloudinaryUrl);
          updatedImages.push(cloudinaryUrl);
          console.log(`✅ [${i}] New image uploaded: ${file.originalname}`);
          console.log(`   URL: ${cloudinaryUrl}`);
        } catch (uploadError) {
          console.error(`❌ Error uploading image [${i}]:`, uploadError.message);
          
          // ✅ Delete newly uploaded images on error
          if (uploadedUrls.length > 0) {
            console.log(`🗑️ Rolling back ${uploadedUrls.length} uploaded images...`);
            await deleteImagesFromCloudinary(uploadedUrls);
          }
          
          return res.status(500).json({ 
            message: 'Failed to upload new image',
            error: uploadError.message 
          });
        }
      }
      console.log(`✅ Successfully uploaded ${req.files.length} new images`);
    }

    // ✅ Update message with new images array
    message.images = updatedImages;
    message.updatedAt = new Date();
    await message.save();

    console.log('✅ ========== MESSAGE SAVED ==========');
    console.log(`   - Content: ${message.content}`);
    console.log(`   - Total images: ${updatedImages.length}`);
    for (let i = 0; i < updatedImages.length; i++) {
      console.log(`      [${i}] ${updatedImages[i]}`);
    }

    // ✅ Fetch sender info
    let avatarUrl = '';
    let username = 'Chủ nhà';
    
    try {
      const rentalDoc = await Rental.findOne({ userId: req.userId }).select('contactInfo');
      if (rentalDoc) {
        username = rentalDoc.contactInfo?.name || 'Chủ nhà';
      }
    } catch (err) {
      console.warn('⚠️ Could not fetch rental info:', err.message);
    }
    
    try {
      const userMongo = await mongoose.model('User').findOne({ _id: req.userId }).select('avatarUrl username');
      if (userMongo) {
        avatarUrl = userMongo.avatarUrl || '';
        username = userMongo.username || username;
      }
    } catch (err) {
      console.warn('⚠️ Could not fetch user from MongoDB:', err.message);
    }
    
    if (!avatarUrl || !username) {
      try {
        const userDoc = await admin.firestore().collection('Users').doc(req.userId).get();
        if (userDoc.exists) {
          const data = userDoc.data();
          avatarUrl = avatarUrl || data.avatarUrl || '';
          username = data.username || username;
        }
      } catch (err) {
        console.warn('⚠️ Could not fetch user from Firestore:', err.message);
      }
    }

    // ✅ Return updated message with correct images array
    const messageData = {
      _id: message._id.toString(),
      conversationId: message.conversationId.toString(),
      senderId: message.senderId,
      content: message.content,
      images: message.images, // ✅ ENSURE: This is always an array
      createdAt: new Date(message.createdAt.getTime() + 7 * 60 * 60 * 1000),
      updatedAt: new Date(message.updatedAt.getTime() + 7 * 60 * 60 * 1000),
      sender: {
        id: req.userId,
        username: username,
        avatarUrl: avatarUrl,
      }
    };

    console.log('📤 ========== SENDING RESPONSE ==========');
    console.log('📤 Response images array:', JSON.stringify(messageData.images));
    console.log('📤 Response images count:', messageData.images.length);
    console.log('📤 Response images is Array:', Array.isArray(messageData.images));

    if (io) {
      io.to(conversation._id.toString()).emit('updateMessage', messageData);
      console.log('🔔 Socket event emitted: updateMessage');
    }

    console.log('✅ Edit message completed successfully');
    res.status(200).json(messageData);
  } catch (err) {
    console.error('❌ ========== ERROR IN EDIT MESSAGE ==========');
    console.error('❌ Error:', err.message);
    console.error('❌ Stack:', err.stack);
    res.status(500).json({ 
      message: 'Có lỗi xảy ra từ server!',
      error: err.message 
    });
  }
});


  // ==================== DELETE MESSAGE ====================
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

      if (message.images && message.images.length > 0) {
        console.log(`🗑️ Deleting ${message.images.length} images from Cloudinary...`);
        await deleteImagesFromCloudinary(message.images);
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
      if (io) {
        io.to(conversation._id.toString()).emit('deleteMessage', deleteData);
      }

      res.status(200).json({ message: 'Message deleted successfully' });
    } catch (err) {
      console.error('❌ Error in DELETE /messages:', err.message);
      res.status(500).json({ message: err.message });
    }
  });



  return router;
};