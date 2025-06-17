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
const fs = require('fs').promises;

// Redis client
const redisClient = redis.createClient({
  url: process.env.REDIS_URL || 'redis://localhost:6379',
});
redisClient.on('error', (err) => console.log('Redis Client Error', err));
redisClient.connect();

// Elasticsearch client
const elasticClient = new Client({
  node: process.env.ELASTICSEARCH_URL || 'http://localhost:9200',
  maxRetries: 3,
  requestTimeout: 30000,
  sniffOnStart: false,
  sniffOnConnectionFault: false,
});

// Multer storage configuration
const storage = multer.diskStorage({
  destination: './uploads/',
  filename: (req, file, cb) => {
    cb(null, `${Date.now()}-${file.originalname}`);
  },
});
const upload = multer({ storage });
router.use('/uploads', express.static(path.join(__dirname, '..', 'uploads')));

// Authentication middleware
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

// Sync rental to Elasticsearch (non-blocking)
const syncRentalToElasticsearch = async (rental) => {
  try {
    const headers = {
      Accept: 'application/json',
      'Content-Type': 'application/json',
    };
    console.log('Elasticsearch sync headers:', headers);
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
        images: rental.images || [],
      },
      headers,
    });
    console.log(`Synced rental ${rental._id} to Elasticsearch`, response);
  } catch (err) {
    console.error('Error syncing to Elasticsearch:', err);
  }
};

// Build MongoDB query
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

// Sanitize headers middleware
const sanitizeHeadersMiddleware = (req, res, next) => {
  if (req.headers.accept && req.headers.accept.includes('application/vnd.elasticsearch+json')) {
    req.headers.accept = 'application/json';
  }
  next();
};

// Search rentals
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
        headers: {
          Accept: 'application/json',
          'Content-Type': 'application/json',
        },
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

// Get all rentals
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

// Get search history
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

// Get rental by ID
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

// Create rental
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
    syncRentalToElasticsearch(newRental);
    res.status(201).json(newRental);
  } catch (err) {
    console.error('Error creating rental:', err);
    if (err instanceof multer.MulterError) {
      return res.status(400).json({ message: `File upload error: ${err.message}` });
    }
    res.status(400).json({ message: 'Failed to create rental', error: err.message });
  }
});

// Update rental
router.patch('/rentals/:id', authMiddleware, upload.array('images'), async (req, res) => {
  try {
    // Kiểm tra ID hợp lệ
    if (!mongoose.Types.ObjectId.isValid(req.params.id)) {
      return res.status(400).json({ message: 'Invalid rental ID' });
    }

    // Tìm rental
    const rental = await Rental.findById(req.params.id);
    if (!rental) {
      return res.status(404).json({ message: 'Rental not found' });
    }
    if (rental.userId !== req.userId) {
      return res.status(403).json({ message: 'Unauthorized: You do not own this rental' });
    }

    // Chuẩn bị dữ liệu cập nhật
    const updatedData = {};
    if (req.body.title) updatedData.title = req.body.title;
    if (req.body.price) updatedData.price = parseFloat(req.body.price) || rental.price;
    if (req.body.areaTotal || req.body.areaLivingRoom || req.body.areaBedrooms || req.body.areaBathrooms) {
      updatedData.area = {
        total: parseFloat(req.body.areaTotal) || rental.area.total,
        livingRoom: parseFloat(req.body.areaLivingRoom) || rental.area.livingRoom,
        bedrooms: parseFloat(req.body.areaBedrooms) || rental.area.bedrooms,
        bathrooms: parseFloat(req.body.areaBathrooms) || rental.area.bathrooms
      };
    }
    if (req.body.locationShort || req.body.locationFullAddress) {
      updatedData.location = {
        short: req.body.locationShort || rental.location.short,
        fullAddress: req.body.locationFullAddress || rental.location.fullAddress
      };
    }
    if (req.body.propertyType) updatedData.propertyType = req.body.propertyType;
    if (req.body.furniture) updatedData.furniture = req.body.furniture.split(',').map(item => item.trim());
    if (req.body.amenities) updatedData.amenities = req.body.amenities.split(',').map(item => item.trim());
    if (req.body.surroundings) updatedData.surroundings = req.body.surroundings.split(',').map(item => item.trim());
    if (req.body.rentalTermsMinimumLease || req.body.rentalTermsDeposit || req.body.rentalTermsPaymentMethod || req.body.rentalTermsRenewalTerms) {
      updatedData.rentalTerms = {
        minimumLease: req.body.rentalTermsMinimumLease || rental.rentalTerms.minimumLease,
        deposit: req.body.rentalTermsDeposit || rental.rentalTerms.deposit,
        paymentMethod: req.body.rentalTermsPaymentMethod || rental.rentalTerms.paymentMethod,
        renewalTerms: req.body.rentalTermsRenewalTerms || rental.rentalTerms.renewalTerms
      };
    }
    if (req.body.contactInfoName || req.body.contactInfoPhone || req.body.contactInfoAvailableHours) {
      updatedData.contactInfo = {
        name: req.body.contactInfoName || rental.contactInfo.name,
        phone: req.body.contactInfoPhone || rental.contactInfo.phone,
        availableHours: req.body.contactInfoAvailableHours || rental.contactInfo.availableHours
      };
    }
    if (req.body.status) updatedData.status = req.body.status;

    // Xử lý ảnh
    let updatedImages = [...rental.images];
    let removedImages = [];
    if (req.body.removedImages) {
      try {
        // Nếu là string, thử parse JSON, nếu lỗi thì tách theo dấu phẩy
        if (typeof req.body.removedImages === 'string') {
          try {
            removedImages = JSON.parse(req.body.removedImages);
          } catch (e) {
            removedImages = req.body.removedImages.split(',').map(s => s.trim()).filter(Boolean);
          }
        } else if (Array.isArray(req.body.removedImages)) {
          removedImages = req.body.removedImages;
        }
      } catch (e) {
        removedImages = [req.body.removedImages].filter(Boolean);
      }
      if (!Array.isArray(removedImages)) removedImages = [removedImages];

      for (const image of removedImages) {
        if (typeof image !== 'string' || !image.startsWith('/uploads/')) continue;
        if (updatedImages.includes(image)) {
          updatedImages = updatedImages.filter(img => img !== image);
          const filePath = path.join(__dirname, '..', 'uploads', image.replace(/^\/uploads\//, ''));
          try {
            await fs.unlink(filePath);
          } catch (err) {
            // Nếu file không tồn tại thì bỏ qua, lỗi khác thì báo lỗi
            if (err.code !== 'ENOENT') {
              return res.status(500).json({ message: `Failed to delete image: ${image}`, error: err.message });
            }
          }
        }
      }
    }

    // Thêm ảnh mới
    if (req.files && req.files.length > 0) {
      const newImages = req.files.map(file => `/uploads/${file.filename}`);
      updatedImages = [...new Set([...updatedImages, ...newImages])];
    }

    // Luôn cập nhật lại trường images
    updatedData.images = updatedImages;

    // Cập nhật rental
    const updatedRental = await Rental.findByIdAndUpdate(
      req.params.id,
      { $set: updatedData },
      { new: true, runValidators: true }
    );

    if (!updatedRental) {
      return res.status(404).json({ message: 'Rental not found after update' });
    }

    // Đồng bộ Elasticsearch
    syncRentalToElasticsearch(updatedRental);

    res.json(updatedRental);
  } catch (err) {
    if (err instanceof multer.MulterError) {
      return res.status(400).json({ message: `File upload error: ${err.message}` });
    }
    res.status(500).json({ message: 'Failed to update rental', error: err.message });
  }
});

// Delete rental
router.delete('/rentals/:id', authMiddleware, async (req, res) => {
  try {
    if (!mongoose.Types.ObjectId.isValid(req.params.id)) {
      return res.status(400).json({ message: 'Invalid rental ID' });
    }

    const rental = await Rental.findById(req.params.id);
    if (!rental) {
      return res.status(404).json({ message: 'Rental not found' });
    }
    if (rental.userId !== req.userId) {
      return res.status(403).json({ message: 'Unauthorized: You do not own this rental' });
    }

    for (const image of rental.images) {
      if (!image.startsWith('/uploads/')) {
        console.warn(`Invalid image path format during deletion: ${image}`);
        continue;
      }
      const filePath = path.join(__dirname, '..', 'Uploads', image.replace(/^\/uploads\//, ''));
      try {
        await fs.access(filePath);
        await fs.unlink(filePath);
        console.log(`Deleted image: ${filePath}`);
      } catch (err) {
        console.error(`Error deleting image ${filePath}: ${err.message}`);
        if (err.code !== 'ENOENT') {
          console.warn(`Non-ENOENT error during deletion: ${err.message}`);
        }
      }
    }

    await Comment.deleteMany({ rentalId: req.params.id });
    await Reply.deleteMany({ commentId: { $in: await Comment.find({ rentalId: req.params.id }).distinct('_id') } });
    await LikeComment.deleteMany({ targetId: req.params.id, targetType: 'Comment' });
    await Favorite.deleteMany({ rentalId: req.params.id });

    await Rental.findByIdAndDelete(req.params.id);

    try {
      await elasticClient.delete({
        index: 'rentals',
        id: req.params.id,
        headers: {
          Accept: 'application/json',
          'Content-Type': 'application/json',
        },
      });
      console.log(`Deleted rental ${req.params.id} from Elasticsearch`);
    } catch (esErr) {
      console.error('Error deleting from Elasticsearch:', esErr);
    }

    res.json({ message: 'Rental deleted successfully' });
  } catch (err) {
    console.error('Error deleting rental:', err);
    res.status(500).json({ message: 'Failed to delete rental', error: err.message });
  }
});

// Handle unsupported methods
router.all('/rentals/:id', (req, res) => {
  console.warn(`Received unsupported method ${req.method} for /rentals/:id`, {
    headers: req.headers,
    body: req.body,
  });
  res.status(405).json({
    message: `Method ${req.method} not allowed. Use PATCH to update rentals.`,
  });
});

module.exports = router;