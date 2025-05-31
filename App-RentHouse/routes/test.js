require('dotenv').config();

const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const Rental = require('../models/Rental');
const Favorite = require('../models/favorite');
const { Comment, Reply, LikeComment } = require('../models/comments');
const admin = require('firebase-admin');
const multer = require('multer');
const path = require('path');
const redis = require('redis');
const sharp = require('sharp');
const { Client } = require('@elastic/elasticsearch');

// sử dụng redis để lưu trữ các thông tin tạm thời
const redisClient = redis.createClient({
  url: process.env.REDIS_URL || 'redis://localhost:6379',
});
redisClient.on('error', (err) => console.log('Redis Client Error', err));
redisClient.connect();

const elasticClient = new Client({
  node: process.env.ELASTICSEARCH_URL || 'http://localhost:9200',
  maxRetries: 3,
  requestTimeout: 30000,
  sniffOnStart: false,
  sniffOnConnectionFault: false,
});

// Cấu hình multer để lưu trữ file upload
const storage = multer.diskStorage({
  destination: './uploads/',
  filename: (req, file, cb) => {
    cb(null, `${Date.now()}-${file.originalname}`);
  },
});
const upload = multer({ storage });

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

// Helper function to adjust timestamps for +7 timezone
const adjustTimestamps = (obj) => {
  const adjusted = { ...obj.toObject() };
  adjusted.createdAt = new Date(adjusted.createdAt.getTime() + 7 * 60 * 60 * 1000);
  return adjusted;
};

const syncRentalToElasticsearch = async (rental) => {
  try {
    const response = await elasticClient.index({
      index: 'rentals',
      id: rental._id.toString(),
      body: {
        title: rental.title,
        price: parseFloat(rental.price) || 0,
        location: rental.location.short,
        propertyType: rental.propertyType,
        status: rental.status,
        area: parseFloat(rental.area.total) || 0,
        createdAt: rental.createdAt,
        images: rental.images || [], // Add images array
      },
    });
    console.log(`Synced rental ${rental._id} to Elasticsearch`, response);
  } catch (err) {
    console.error('Error syncing to Elasticsearch:', err);
    throw err;
  }
};

const buildMongoQuery = ({ search, minPrice, maxPrice, propertyTypes, status }) => {
  const query = {};
  if (search) {
    query.$or = [
      { title: { $regex: search, $options: 'i' } },
      { 'location.short': { $regex: search, $options: 'i' } },
    ];
  }
  if (minPrice || maxPrice) {
    query.price = {};
    if (minPrice) query.price.$gte = Number(minPrice);
    if (maxPrice) query.price.$lte = Number(maxPrice);
  }
  if (propertyTypes && propertyTypes.length > 0) {
    query.propertyType = { $in: propertyTypes };
  }
  if (status) query.status = status;
  return query;
};

router.get('/rentals/search', [sanitizeHeadersMiddleware], async (req, res) => {
  try {
    const { search, minPrice, maxPrice, propertyType, status, page = 1, limit = 10 } = req.query;
    const propertyTypes = propertyType ? (Array.isArray(propertyType) ? propertyType : [propertyType]) : [];
    const skip = (Number(page) - 1) * Number(limit);

    const cacheKey = `search:${search || ''}:${minPrice || ''}:${maxPrice || ''}:${propertyTypes.join(',')}:${status || ''}:${page}:${limit}`;
    const cachedResult = await redisClient.get(cacheKey);
    if (cachedResult) {
      console.log('Serving from cache:', cacheKey);
      return res.json(JSON.parse(cachedResult));
    }

    console.log('Search query:', { search, minPrice, maxPrice, propertyTypes, status, page, limit });

    if (search && req.header('Authorization')) {
      const token = req.header('Authorization').replace('Bearer ', '');
      try {
        const decodedToken = await admin.auth().verifyIdToken(token);
        const userId = decodedToken.uid;
        const searchKey = `search:${userId}`;
        await redisClient.lPush(searchKey, search);
        await redisClient.lTrim(searchKey, 0, 9);
        console.log(`Saved search "${search}" for user ${userId}`);
      } catch (err) {
        console.error('Error saving search history:', err);
      }
    }

    let rentals = [];
    let total = 0;

    try {
      const query = {
        bool: {
          must: [],
          filter: [],
        },
      };

      if (search) {
        query.bool.must.push({
          multi_match: {
            query: search,
            fields: ['title^2', 'location'],
            fuzziness: 'AUTO',
          },
        });
      }

      if (minPrice || maxPrice) {
        const priceFilter = {};
        if (minPrice) priceFilter.gte = Number(minPrice);
        if (maxPrice) priceFilter.lte = Number(maxPrice);
        query.bool.filter.push({ range: { price: priceFilter } });
      }

      if (propertyTypes.length > 0) {
        query.bool.filter.push({
          terms: { propertyType: propertyTypes },
        });
      }

      if (status) {
        query.bool.filter.push({ term: { status } });
      }

      console.log('Elasticsearch query:', JSON.stringify(query, null, 2));
      const response = await elasticClient.search({
        index: 'rentals',
        from: skip,
        size: Number(limit),
        body: { query },
      });

      const rentalIds = response.hits.hits.map(hit => hit._id);
      total = response.hits.total.value;
      rentals = await Rental.find({ _id: { $in: rentalIds } }).lean();
    } catch (esErr) {
      console.error('Elasticsearch search failed:', esErr);
      const mongoQuery = buildMongoQuery({ search, minPrice, maxPrice, propertyTypes, status });
      rentals = await Rental.find(mongoQuery).skip(skip).limit(Number(limit)).lean();
      total = await Rental.countDocuments(mongoQuery);
    }

    const result = {
      rentals,
      total,
      page: Number(page),
      pages: Math.ceil(total / Number(limit)),
    };

    await redisClient.setEx(cacheKey, 300, JSON.stringify(result));
    res.json(result);
  } catch (err) {
    console.error('Error fetching rentals:', err);
    res.status(500).json({ message: 'Failed to fetch rentals', error: err.message });
  }
});


// Rental routes
router.get('/rentals', async (req, res) => {
  try {
    const { search, minPrice, maxPrice, propertyType, status } = req.query;
    let query = {};
    if (search) query.$or = [{ title: { $regex: search, $options: 'i' } }, { 'location.short': { $regex: search, $options: 'i' } }];
    if (minPrice || maxPrice) {
      query.price = {};
      if (minPrice) query.price.$gte = Number(minPrice);
      if (maxPrice) query.price.$lte = Number(maxPrice);
    }
    if (propertyType) query.propertyType = propertyType;
    if (status) query.status = status;
    const rentals = await Rental.find(query);
    res.json(rentals);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});
router.get('/search-history', [sanitizeHeadersMiddleware, authMiddleware], async (req, res) => {
  try {
    const searchKey = `search:${req.userId}`;
    const history = await redisClient.lRange(searchKey, 0, -1);
    res.json(history);
  } catch (err) {
    console.error('Error fetching search history:', err);
    res.status(500).json({ message: 'Failed to fetch search history', error: err.message });
  }
});
router.get('/rentals/:id', async (req, res) => {
  try {
    const rental = await Rental.findById(req.params.id);
    if (!rental) return res.status(404).json({ message: 'Rental not found' });

    const comments = await Comment.find({ rentalId: req.params.id })
      .populate('userId', 'avatarBase64 username');
    
    const commentIds = comments.map(c => c._id);
    const replies = await Reply.find({ commentId: { $in: commentIds } })
      .populate('userId', 'username')
      .lean();
    
    const likes = await LikeComment.find({
      $or: [
        { targetId: { $in: commentIds }, targetType: 'Comment' },
        { targetId: { $in: replies.map(r => r._id) }, targetType: 'Reply' },
      ]
    }).populate('userId', 'username').lean();

    // Build reply hierarchy
    const replyMap = new Map();
    replies.forEach(reply => {
      reply.createdAt = new Date(reply.createdAt.getTime() + 7 * 60 * 60 * 1000);
      reply.likes = likes.filter(like => like.targetId.toString() === reply._id.toString() && like.targetType === 'Reply')
        .map(like => ({ ...like, createdAt: new Date(like.createdAt.getTime() + 7 * 60 * 60 * 1000) }));
      const commentIdStr = reply.commentId.toString();
      if (!replyMap.has(commentIdStr)) {
        replyMap.set(commentIdStr, []);
      }
      replyMap.get(commentIdStr).push(reply);
    });

    // Build nested replies
    const buildReplyTree = (replyList, parentId = null) => {
      return replyList
        .filter(reply => (parentId ? reply.parentReplyId?.toString() === parentId : !reply.parentReplyId))
        .map(reply => ({
          ...reply,
          replies: buildReplyTree(replyList, reply._id.toString())
        }));
    };

    const adjustedComments = comments.map(comment => {
      const commentObj = adjustTimestamps(comment);
      commentObj.replies = buildReplyTree(replyMap.get(comment._id.toString()) || []);
      commentObj.likes = likes.filter(like => like.targetId.toString() === comment._id.toString() && like.targetType === 'Comment')
        .map(like => ({ ...like, createdAt: new Date(like.createdAt.getTime() + 7 * 60 * 60 * 1000) }));
      return commentObj;
    });

    const totalRatings = adjustedComments.reduce((sum, comment) => sum + (comment.rating || 0), 0);
    const averageRating = adjustedComments.length > 0 ? totalRatings / adjustedComments.length : 0;

    res.json({
      ...rental.toObject(),
      comments: adjustedComments,
      averageRating,
      reviewCount: adjustedComments.length
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

router.post('/rentals', authMiddleware, upload.array('images'), async (req, res) => {
  try {
    const imageUrls = req.files.map(file => `/uploads/${file.filename}`);
    const contactInfoName = req.body.contactInfoName || req.user.displayName || 'Chủ nhà';
    const contactInfoPhone = req.body.contactInfoPhone || req.user.phoneNumber || 'Không có số điện thoại';
    const rental = new Rental({
      title: req.body.title,
      price: req.body.price,
      area: { total: req.body.areaTotal, livingRoom: req.body.areaLivingRoom, bedrooms: req.body.areaBedrooms, bathrooms: req.body.areaBathrooms },
      location: { short: req.body.locationShort, fullAddress: req.body.locationFullAddress },
      propertyType: req.body.propertyType,
      furniture: req.body.furniture ? req.body.furniture.split(',').map(item => item.trim()) : [],
      amenities: req.body.amenities ? req.body.amenities.split(',').map(item => item.trim()) : [],
      surroundings: req.body.surroundings ? req.body.surroundings.split(',').map(item => item.trim()) : [],
      rentalTerms: { minimumLease: req.body.rentalTermsMinimumLease, deposit: req.body.rentalTermsDeposit, paymentMethod: req.body.rentalTermsPaymentMethod, renewalTerms: req.body.rentalTermsRenewalTerms },
      contactInfo: { name: contactInfoName, phone: contactInfoPhone, availableHours: req.body.contactInfoAvailableHours },
      userId: req.userId,
      images: imageUrls,
      status: req.body.status || 'available',
    });
    const newRental = await rental.save();
    await syncRentalToElasticsearch(newRental);
    res.status(201).json(newRental);
  } catch (err) {
    res.status(400).json({ message: err.message });
  }
});

router.put('/rentals/:id', authMiddleware, upload.array('images'), async (req, res) => {
  try {
    const rental = await Rental.findById(req.params.id);
    if (!rental || rental.userId !== req.userId) return res.status(403).json({ message: 'Unauthorized or not found' });
    const updatedData = {};
    if (req.body.title) updatedData.title = req.body.title;
    if (req.body.price) updatedData.price = req.body.price;
    if (req.body.areaTotal || req.body.areaLivingRoom || req.body.areaBedrooms || req.body.areaBathrooms) {
      updatedData.area = { total: req.body.areaTotal || rental.area.total, livingRoom: req.body.areaLivingRoom || rental.area.livingRoom, bedrooms: req.body.areaBedrooms || rental.area.bedrooms, bathrooms: req.body.areaBathrooms || rental.area.bathrooms };
    }
    if (req.body.locationShort || req.body.locationFullAddress) {
      updatedData.location = { short: req.body.locationShort || rental.location.short, fullAddress: req.body.locationFullAddress || rental.location.fullAddress };
    }
    if (req.body.propertyType) updatedData.propertyType = req.body.propertyType;
    if (req.body.furniture) updatedData.furniture = req.body.furniture.split(',').map(item => item.trim());
    if (req.body.amenities) updatedData.amenities = req.body.amenities.split(',').map(item => item.trim());
    if (req.body.surroundings) updatedData.surroundings = req.body.surroundings.split(',').map(item => item.trim());
    if (req.body.rentalTermsMinimumLease || req.body.rentalTermsDeposit || req.body.rentalTermsPaymentMethod || req.body.rentalTermsRenewalTerms) {
      updatedData.rentalTerms = { minimumLease: req.body.rentalTermsMinimumLease || rental.rentalTerms.minimumLease, deposit: req.body.rentalTermsDeposit || rental.rentalTerms.deposit, paymentMethod: req.body.rentalTermsPaymentMethod || rental.rentalTerms.paymentMethod, renewalTerms: req.body.rentalTermsRenewalTerms || rental.rentalTerms.renewalTerms };
    }
    if (req.body.contactInfoName || req.body.contactInfoPhone || req.body.contactInfoAvailableHours) {
      updatedData.contactInfo = { name: req.body.contactInfoName || rental.contactInfo.name, phone: req.body.contactInfoPhone || rental.contactInfo.phone, availableHours: req.body.contactInfoAvailableHours || rental.contactInfo.availableHours };
    }
    if (req.files.length > 0) updatedData.images = req.files.map(file => `/uploads/${file.filename}`);
    if (req.body.status) updatedData.status = req.body.status;
    const updatedRental = await Rental.findByIdAndUpdate(req.params.id, updatedData, { new: true });
     await syncRentalToElasticsearch(updatedRental);
    res.json(updatedRental);
  } catch (err) {
    res.status(400).json({ message: err.message });
  }
});

router.delete('/rentals/:id', authMiddleware, async (req, res) => {
  try {
    const rental = await Rental.findById(req.params.id);
    if (!rental || rental.userId !== req.userId) return res.status(403).json({ message: 'Unauthorized or not found' });
    await Rental.findByIdAndDelete(req.params.id);
    res.json({ message: 'Rental deleted successfully' });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});



module.exports = router;
