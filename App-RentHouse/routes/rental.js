
require('dotenv').config();
const express = require('express'); // đã xóa ESlint
const router = express.Router();
const mongoose = require('mongoose');
const Rental = require('../models/Rental');
const Favorite = require('../models/favorite');
const { Comment, Reply, LikeComment } = require('../models/comments');
const User = require('../models/usermodel');
const admin = require('firebase-admin');
const multer = require('multer');
const path = require('path');
const redis = require('redis');
const sharp = require('sharp');
const { Client } = require('@elastic/elasticsearch');
const fs = require('fs').promises;
const cloudinary = require('../config/cloudinary');
const { CloudinaryStorage } = require('multer-storage-cloudinary');

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

// ==================== MULTER CLOUDINARY STORAGE ====================
const storage = new CloudinaryStorage({
  cloudinary: cloudinary,
  params: async (req, file) => {
    const isVideo = file.mimetype.startsWith('video/');
    return {
      folder: 'rentals',
      allowed_formats: isVideo 
        ? ['mp4', 'mov', 'avi', 'mkv', 'webm']
        : ['jpg', 'jpeg', 'png', 'webp'],
      resource_type: isVideo ? 'video' : 'image',
      transformation: isVideo 
        ? [{ width: 1280, height: 720, crop: 'limit', quality: 'auto' }]
        : [{ width: 1920, height: 1080, crop: 'limit' }],
    };
  },
}); 

const upload = multer({
  storage,
  limits: { 
    fileSize: 100 * 1024 * 1024, // 100MB for videos
  },
  fileFilter: (req, file, cb) => {
    const allowedImageFormats = /\.(jpeg|jpg|png|webp)$/i;
    const allowedVideoFormats = /\.(mp4|mov|avi|mkv|webm)$/i;
    
    const isImage = allowedImageFormats.test(file.originalname);
    const isVideo = allowedVideoFormats.test(file.originalname);
    
    if (isImage || isVideo) {
      return cb(null, true);
    }
    cb(new Error('Chỉ chấp nhận file ảnh (JPEG, JPG, PNG, WEBP) hoặc video (MP4, MOV, AVI, MKV, WEBM)'));
  },
});

// ==================== HELPER FUNCTIONS ====================
const deleteCloudinaryMedia = async (cloudinaryIds) => {
  if (!cloudinaryIds || cloudinaryIds.length === 0) {
    return [];
  }
  
  const results = [];
  for (const publicId of cloudinaryIds) {
    try {
      // Tự động detect resource_type (image hoặc video)
      let result = await cloudinary.uploader.destroy(publicId, { resource_type: 'image' });
      
      // Nếu không tìm thấy image, thử xóa video
      if (result.result === 'not found') {
        result = await cloudinary.uploader.destroy(publicId, { resource_type: 'video' });
      }
      
      results.push({ publicId, result });
      console.log('✅ Cloudinary delete:', publicId, result);
    } catch (error) {
      console.error('❌ Error deleting from Cloudinary:', publicId, error);
      results.push({ publicId, error: error.message });
    }
  }
  return results;
};

const extractCloudinaryPublicId = (url) => {
  if (!url) return null;
  const match = url.match(/\/rentals\/([^/.]+)/);
  return match ? `rentals/${match[1]}` : null;
};

//====================
const _isNewPost = (createdAt) => {
  if (!createdAt) return false;
  const difference = new Date() - new Date(createdAt);
  const minutes = difference / (1000 * 60);
  return minutes < 30; // 30 phút
};

const verifyAdmin = async (req, res, next) => {
  try {
    const token = req.header('Authorization')?.replace('Bearer ', '');
    if (!token) return res.status(401).json({ message: 'No token provided' });

    const decodedToken = await admin.auth().verifyIdToken(token);
    const uid = decodedToken.uid;
    req.userId = uid;
    req.isAdmin = true;
    next();
  } catch (err) {
    res.status(401).json({ message: 'Authentication failed', error: err.message });
  }
};
// ========== ADMIN ROUTES ========================================================

// ========== ADMIN ROUTES ========================================================

router.get('/admin/users-with-posts', verifyAdmin, async (req, res) => {
  try {
    const page = Math.max(1, parseInt(req.query.page) || 1);
    const limit = Math.min(50, Math.max(10, parseInt(req.query.limit) || 20));
    const skip = (page - 1) * limit;

    const usersWithPosts = await Rental.aggregate([
      {
        $group: {
          _id: '$userId',
          postsCount: { $sum: 1 },
          latestPost: { $max: '$createdAt' },
        },
      },
      { $sort: { latestPost: -1 } },
      { $skip: skip },
      { $limit: limit },
    ]);

    const userIds = usersWithPosts.map(u => u._id);
    const userDetails = await User.find({ _id: { $in: userIds } })
      .select('_id username email phoneNumber role')
      .lean();

    const result = usersWithPosts.map(u => {
      const userDetail = userDetails.find(ud => ud._id.toString() === u._id);
      return {
        id: u._id,
        username: userDetail?.username || 'Chưa cập nhật',
        email: userDetail?.email || '',
        phoneNumber: userDetail?.phoneNumber || '',
        postsCount: u.postsCount,
        latestPost: u.latestPost,
        role: userDetail?.role || 'user',
      };
    });

    const total = await Rental.distinct('userId');

    res.json({
      users: result,
      pagination: {
        page,
        limit,
        total: total.length,
        totalPages: Math.ceil(total.length / limit),
      },
    });
  } catch (err) {
    console.error('Error:', err);
    res.status(500).json({ message: 'Failed to fetch users', error: err.message });
  }
});

// 📄 Admin: Get User Posts
router.get('/admin/user-posts/:userId', verifyAdmin, async (req, res) => {
  try {
    const { userId } = req.params;
    const page = Math.max(1, parseInt(req.query.page) || 1);
    const limit = Math.min(50, Math.max(10, parseInt(req.query.limit) || 10));
    const skip = (page - 1) * limit;

    const rentals = await Rental.find({ userId })
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit)
      .lean();

    const total = await Rental.countDocuments({ userId });

    const rentalsWithBadge = rentals.map(rental => ({
      ...rental,
      isNew: _isNewPost(rental.createdAt),
    }));

    res.json({
      rentals: rentalsWithBadge,
      total,
      page,
      pages: Math.ceil(total / limit),
      hasMore: page < Math.ceil(total / limit),
    });
  } catch (err) {
    console.error('Error:', err);
    res.status(500).json({ message: 'Failed to fetch user posts', error: err.message });
  }
});
// ========== ADMIN EDIT RENTAL ==========
router.patch('/admin/rentals/:rentalId', verifyAdmin, upload.array('media'), async (req, res) => {
  try {
    if (!mongoose.Types.ObjectId.isValid(req.params.rentalId)) {
      return res.status(400).json({ message: 'Invalid rental ID' });
    }

    const rental = await Rental.findById(req.params.rentalId);
    if (!rental) {
      return res.status(404).json({ message: 'Rental not found' });
    }

    const updatedData = {};
    
    if (req.body.title) updatedData.title = req.body.title;
    if (req.body.price) updatedData.price = parseFloat(req.body.price) || rental.price;
    
    if (req.body.areaTotal || req.body.areaLivingRoom || req.body.areaBedrooms || req.body.areaBathrooms) {
      updatedData.area = {
        total: parseFloat(req.body.areaTotal) || rental.area.total,
        livingRoom: parseFloat(req.body.areaLivingRoom) || rental.area.livingRoom,
        bedrooms: parseFloat(req.body.areaBedrooms) || rental.area.bedrooms,
        bathrooms: parseFloat(req.body.areaBathrooms) || rental.area.bathrooms,
      };
    }

    if (req.body.locationShort || req.body.locationFullAddress || req.body.latitude || req.body.longitude) {
      let coordinates = [
        parseFloat(req.body.longitude) || rental.location.coordinates.coordinates[0],
        parseFloat(req.body.latitude) || rental.location.coordinates.coordinates[1],
      ];
      let formattedAddress = rental.location.formattedAddress;
      let geocodingStatus = rental.geocodingStatus || 'pending';

      const { full: fullAddress } = normalizeVietnameseAddress(req.body.locationFullAddress || rental.location.fullAddress);
      if (!fullAddress) {
        return res.status(400).json({ message: 'Invalid or missing full address' });
      }

      if (coordinates[0] === 0 && coordinates[1] === 0 || isNaN(coordinates[0]) || isNaN(coordinates[1])) {
        try {
          const geocodeResult = await geocodeAddressFree(fullAddress);
          coordinates = [geocodeResult.longitude, geocodeResult.latitude];
          formattedAddress = geocodeResult.formattedAddress;
          geocodingStatus = 'success';
        } catch (geocodeError) {
          console.error('Geocoding failed:', geocodeError.message);
          coordinates = [0, 0];
          formattedAddress = fullAddress;
          geocodingStatus = 'failed';
        }
      } else if (req.body.latitude || req.body.longitude) {
        geocodingStatus = 'manual';
      }

      updatedData.location = {
        short: req.body.locationShort || rental.location.short,
        fullAddress: fullAddress,
        formattedAddress: formattedAddress,
        coordinates: {
          type: 'Point',
          coordinates: coordinates,
        },
      };
      updatedData.geocodingStatus = geocodingStatus;
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
        renewalTerms: req.body.rentalTermsRenewalTerms || rental.rentalTerms.renewalTerms,
      };
    }
    if (req.body.contactInfoName || req.body.contactInfoPhone || req.body.contactInfoAvailableHours) {
      updatedData.contactInfo = {
        name: req.body.contactInfoName || rental.contactInfo.name,
        phone: req.body.contactInfoPhone || rental.contactInfo.phone,
        availableHours: req.body.contactInfoAvailableHours || rental.contactInfo.availableHours,
      };
    }
    if (req.body.status) updatedData.status = req.body.status;

    // Handle media removal
    let updatedImages = [...(rental.images || [])];
    let updatedVideos = [...(rental.videos || [])];
    let removedMedia = [];
    
    if (req.body.removedMedia) {
      try {
        if (typeof req.body.removedMedia === 'string') {
          try {
            removedMedia = JSON.parse(req.body.removedMedia);
          } catch (e) {
            removedMedia = req.body.removedMedia.split(',').map(s => s.trim()).filter(Boolean);
          }
        } else if (Array.isArray(req.body.removedMedia)) {
          removedMedia = req.body.removedMedia;
        }
      } catch (e) {
        removedMedia = [req.body.removedMedia].filter(Boolean);
      }
      if (!Array.isArray(removedMedia)) removedMedia = [removedMedia];

      const cloudinaryIdsToDelete = [];
      
      for (const mediaUrl of removedMedia) {
        if (typeof mediaUrl !== 'string') continue;
        
        // Remove from images array
        if (updatedImages.includes(mediaUrl)) {
          updatedImages = updatedImages.filter(img => img !== mediaUrl);
          const publicId = extractCloudinaryPublicId(mediaUrl);
          if (publicId) cloudinaryIdsToDelete.push(publicId);
        }
        
        // Remove from videos array
        if (updatedVideos.includes(mediaUrl)) {
          updatedVideos = updatedVideos.filter(vid => vid !== mediaUrl);
          const publicId = extractCloudinaryPublicId(mediaUrl);
          if (publicId) cloudinaryIdsToDelete.push(publicId);
        }
      }

      // Delete from Cloudinary
      if (cloudinaryIdsToDelete.length > 0) {
        await deleteCloudinaryMedia(cloudinaryIdsToDelete);
      }
    }

    // Handle new media uploads
    if (req.files && req.files.length > 0) {
      const newImages = [];
      const newVideos = [];
      
      req.files.forEach(file => {
        if (file.mimetype.startsWith('video/')) {
          newVideos.push(file.path);
        } else {
          newImages.push(file.path);
        }
      });
      
      updatedImages = [...new Set([...updatedImages, ...newImages])];
      updatedVideos = [...new Set([...updatedVideos, ...newVideos])];
    }

    updatedData.images = updatedImages;
    updatedData.videos = updatedVideos;

    const updatedRental = await Rental.findByIdAndUpdate(
      req.params.rentalId,
      { $set: updatedData },
      { new: true, runValidators: true },
    );

    if (!updatedRental) {
      return res.status(404).json({ message: 'Rental not found after update' });
    }

    await syncRentalToElasticsearch(updatedRental);
    res.json({
      message: 'Rental updated successfully',
      rental: updatedRental,
    });
  } catch (err) {
    console.error('Error updating rental:', err);
    if (err instanceof multer.MulterError) {
      return res.status(400).json({ message: `File upload error: ${err.message}` });
    }
    res.status(500).json({ message: 'Failed to update rental', error: err.message });
  }
});


// ========== ADMIN DELETE RENTAL ==========
router.delete('/admin/rentals/:rentalId', verifyAdmin, async (req, res) => {
  try {
    console.log('═══════════════════════════════════════════');
    console.log('🗑️ DELETE REQUEST RECEIVED');
    console.log('═══════════════════════════════════════════');
    console.log('📌 Rental ID: ' + req.params.rentalId);
    console.log('👤 User ID: ' + req.userId);
    console.log('✅ Admin verified: ' + req.isAdmin);
    
    if (!mongoose.Types.ObjectId.isValid(req.params.rentalId)) {
      return res.status(400).json({ message: 'Invalid rental ID' });
    }

    const rental = await Rental.findById(req.params.rentalId);
    if (!rental) {
      return res.status(404).json({ message: 'Rental not found' });
    }

    // Delete images and videos from Cloudinary
    const cloudinaryIdsToDelete = [];
    
    (rental.images || []).forEach(imageUrl => {
      const publicId = extractCloudinaryPublicId(imageUrl);
      if (publicId) cloudinaryIdsToDelete.push(publicId);
    });
    
    (rental.videos || []).forEach(videoUrl => {
      const publicId = extractCloudinaryPublicId(videoUrl);
      if (publicId) cloudinaryIdsToDelete.push(publicId);
    });

    if (cloudinaryIdsToDelete.length > 0) {
      await deleteCloudinaryMedia(cloudinaryIdsToDelete);
    }

    // Delete from DB
    await Comment.deleteMany({ rentalId: req.params.rentalId });
    await Reply.deleteMany({ commentId: { $in: await Comment.find({ rentalId: req.params.rentalId }).distinct('_id') } });
    await LikeComment.deleteMany({ targetId: req.params.rentalId, targetType: 'Comment' });
    await Favorite.deleteMany({ rentalId: req.params.rentalId });
    await Rental.findByIdAndDelete(req.params.rentalId);

    // Delete from Elasticsearch
    try {
      await elasticClient.delete({
        index: 'rentals',
        id: req.params.rentalId,
      });
      console.log('✅ Deleted from Elasticsearch');
    } catch (esErr) {
      console.warn('⚠️ Elasticsearch delete failed:', esErr.message);
    }

    console.log('═══════════════════════════════════════════');
    console.log('✅ RENTAL DELETED SUCCESSFULLY');
    console.log('═══════════════════════════════════════════');

    res.json({ 
      message: 'Rental deleted successfully',
      deletedRentalId: req.params.rentalId,
    });
  } catch (err) {
    console.error('❌ Error:', err);
    res.status(500).json({ message: 'Failed to delete rental', error: err.message });
  }
});
//=======================================================================
const authMiddleware = async (req, res, next) => {
  const token = req.header('Authorization')?.replace('Bearer ', '');
  if (!token) return res.status(401).json({ message: 'No token provided' });
  try {
    const decodedToken = await admin.auth().verifyIdToken(token);
    req.userId = decodedToken.uid;
    next();
  } catch (err) {
    res.status(401).json({ message: 'Invalid token', error: err.message });
  }
};

const adjustTimestamps = (obj) => {
  const adjusted = { ...obj.toObject() };
  adjusted.createdAt = new Date(adjusted.createdAt.getTime() + 7 * 60 * 60 * 1000);
  return adjusted;
};

const syncRentalToElasticsearch = async (rental) => {
  try {
    const headers = {
      Accept: 'application/json',
      'Content-Type': 'application/json',
    };
    await elasticClient.index({
      index: 'rentals',
      id: rental._id.toString(),
      body: {
        title: rental.title,
        price: parseFloat(rental.price) || 0,
        location: rental.location.short,
        coordinates: {
          lat: rental.location.coordinates?.coordinates?.[1] || 0,
          lon: rental.location.coordinates?.coordinates?.[0] || 0,
        },
        propertyType: rental.propertyType,
        status: rental.status,
        area: parseFloat(rental.area.total) || 0,
        createdAt: rental.createdAt,
        images: rental.images || [],
        geocodingStatus: rental.geocodingStatus || 'pending',
      },
      headers,
    });
    console.log(`Synced rental ${rental._id} to Elasticsearch`);
  } catch (err) {
    console.error('Error syncing to Elasticsearch:', err);
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

const sanitizeHeadersMiddleware = (req, res, next) => {
  if (req.headers.accept && req.headers.accept.includes('application/vnd.elasticsearch+json')) {
    req.headers.accept = 'application/json';
  }
  next();
};

// Chuẩn hóa địa chỉ theo định dạng Việt Nam và tạo nhiều phiên bản địa chỉ
const normalizeVietnameseAddress = (address) => {
  if (!address || typeof address !== 'string') return { full: '', simplified: '', minimal: '' };
  
  let normalized = address.trim().replace(/\s+/g, ' ');
  normalized = normalized.replace(/[<>[\]{}|]/g, '');
  normalized = normalized.replace(/\bP\.?\b/gi, 'Phường');
  normalized = normalized.replace(/\bQ\.?\b/gi, 'Quận');
  normalized = normalized.replace(/\bTP\.?\b/gi, 'Thành phố');
  
  const parts = normalized.split(',').map(part => part.trim()).filter(part => part);
  
  // Địa chỉ đầy đủ
  let fullAddress = normalized;
  if (parts.length >= 3) {
    fullAddress = `${parts[0]}, ${parts[1]}, ${parts[2]}${parts[3] ? `, ${parts[3]}` : ''}${parts[4] ? `, ${parts[4]}` : ''}, Việt Nam`;
  } else {
    fullAddress = `${normalized}, Việt Nam`;
  }
  
  // Địa chỉ rút gọn: đường + thành phố
  let simplifiedAddress = '';
  if (parts.length >= 3) {
    const road = parts[0].includes('Hẻm') ? parts[0] + ' ' + parts[1] : parts[1];
    const city = parts[3] || parts[4] || 'Cần Thơ';
    simplifiedAddress = `${road}, ${city}, Việt Nam`;
  } else {
    simplifiedAddress = `${normalized}, Việt Nam`;
  }
  
  // Địa chỉ tối thiểu: chỉ thành phố ---------------------------------------
  const city = parts[parts.length - 1] || 'Việt Nam';
  const minimalAddress = `${city}, Việt Nam`;
  // ----------------------------------------

  return { full: fullAddress, simplified: simplifiedAddress, minimal: minimalAddress };
};

// Hàm retry với số lần thử lại và delay
const retryOperation = async (operation, maxRetries = 3, delay = 2000) => {
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      return await operation();
    } catch (error) {
      if (attempt === maxRetries) throw error;
      console.log(`Retry attempt ${attempt}/${maxRetries} failed: ${error.message}`);
      await new Promise(resolve => setTimeout(resolve, delay));
    }
  }
};

const geocodeAddressFree = async (address) => {
  try {
    const { full: fullAddress, simplified: simplifiedAddress, minimal: minimalAddress } = normalizeVietnameseAddress(address);
    if (!fullAddress) {
      throw new Error('Invalid or missing address');
    }

    const operation = async () => {
      // Thử với địa chỉ đầy đủ trước
      console.log(`Attempting geocoding with full address: ${fullAddress}`);
      let response = await fetch(
        `https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(fullAddress)}&limit=1&addressdetails=1&countrycodes=vn&accept-language=vi`,
        {
          headers: {
            'User-Agent': 'RentalHouseApp/1.0',
          },
        }
      );
      let data = await response.json();

      if (data.length > 0) {
        return {
          latitude: parseFloat(data[0].lat),
          longitude: parseFloat(data[0].lon),
          formattedAddress: data[0].display_name,
        };
      }

      // Thử với địa chỉ rút gọn
      console.log(`Full address failed, trying simplified address: ${simplifiedAddress}`);
      response = await fetch(
        `https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(simplifiedAddress)}&limit=1&addressdetails=1&countrycodes=vn&accept-language=vi`,
        {
          headers: {
            'User-Agent': 'RentalHouseApp/1.0',
          },
        }
      );
      data = await response.json();

      if (data.length > 0) {
        return {
          latitude: parseFloat(data[0].lat),
          longitude: parseFloat(data[0].lon),
          formattedAddress: data[0].display_name,
        };
      }

      // Thử với địa chỉ tối thiểu
      console.log(`Simplified address failed, trying minimal address: ${minimalAddress}`);
      response = await fetch(
        `https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(minimalAddress)}&limit=1&addressdetails=1&countrycodes=vn&accept-language=vi`,
        {
          headers: {
            'User-Agent': 'RentalHouseApp/1.0',
          },
        }
      );
      data = await response.json();

      if (data.length > 0) {
        return {
          latitude: parseFloat(data[0].lat),
          longitude: parseFloat(data[0].lon),
          formattedAddress: data[0].display_name,
        };
      }

      throw new Error(`No results found for addresses: ${fullAddress}, ${simplifiedAddress}, or ${minimalAddress}`);
    };

    return await retryOperation(operation, 3, 2000);
  } catch (error) {
    console.error('Nominatim geocoding error:', error.message);
    throw error;
  }
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
        query.bool.filter.push({ terms: { propertyType: propertyTypes } });
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
    res.status(500).json({ message: 'Failed to fetch rentals', error: err.message });
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
      ],
    }).populate('userId', 'username').lean();

    const replyMap = new Map();
    replies.forEach(reply => {
      reply.createdAt = new Date(reply.createdAt.getTime() + 7 * 60 * 60 * 1000);
      reply.likes = likes
        .filter(like => like.targetId.toString() === reply._id.toString() && like.targetType === 'Reply')
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
          replies: buildReplyTree(replyList, reply._id.toString()),
        }));
    };

    const adjustedComments = comments.map(comment => {
      const commentObj = adjustTimestamps(comment);
      commentObj.replies = buildReplyTree(replyMap.get(comment._id.toString()) || []);
      commentObj.likes = likes
        .filter(like => like.targetId.toString() === comment._id.toString() && like.targetType === 'Comment')
        .map(like => ({ ...like, createdAt: new Date(like.createdAt.getTime() + 7 * 60 * 60 * 1000) }));
      return commentObj;
    });

    const totalRatings = adjustedComments.reduce((sum, comment) => sum + (comment.rating || 0), 0);
    const averageRating = adjustedComments.length > 0 ? totalRatings / adjustedComments.length : 0;

    res.json({
      ...rental.toObject(),
      comments: adjustedComments,
      averageRating,
      reviewCount: adjustedComments.length,
    });
  } catch (err) {
    res.status(500).json({ message: 'Failed to fetch rental details', error: err.message });
  }
});

router.post('/rentals', authMiddleware, upload.array('media'), async (req, res) => {
  try {
    const contactInfoName = req.body.contactInfoName || req.user?.displayName || 'Chủ nhà';
    const contactInfoPhone = req.body.contactInfoPhone || req.user?.phoneNumber || 'Không có số điện thoại';

    let coordinates = [
      parseFloat(req.body.longitude) || 0,
      parseFloat(req.body.latitude) || 0,
    ];
    let formattedAddress = req.body.locationFullAddress;
    let geocodingStatus = 'pending';

    const { full: fullAddress } = normalizeVietnameseAddress(req.body.locationFullAddress);
    if (!fullAddress) {
      return res.status(400).json({ message: 'Invalid or missing full address' });
    }

    if (
      coordinates[0] === 0 && coordinates[1] === 0 || 
      isNaN(coordinates[0]) || isNaN(coordinates[1])
    ) {
      try {
        console.log(`Geocoding address for new rental: ${fullAddress}`);
        const geocodeResult = await geocodeAddressFree(fullAddress);
        coordinates = [geocodeResult.longitude, geocodeResult.latitude];
        formattedAddress = geocodeResult.formattedAddress;
        geocodingStatus = 'success';
        console.log('Used Nominatim geocoding service');
      } catch (geocodeError) {
        console.error('Geocoding failed:', geocodeError.message);
        coordinates = [0, 0];
        formattedAddress = fullAddress;
        geocodingStatus = 'failed';
        console.warn(`Geocoding failed for address: ${fullAddress}. Saving with default coordinates [0, 0].`);
      }
    } else {
      geocodingStatus = 'manual';
    }

    if (Math.abs(coordinates[0]) > 180 || Math.abs(coordinates[1]) > 90) {
      return res.status(400).json({ message: 'Invalid coordinate values provided' });
    }

    // Separate images and videos from uploaded files
    const images = [];
    const videos = [];
    
    if (req.files && req.files.length > 0) {
      req.files.forEach(file => {
        if (file.mimetype.startsWith('video/')) {
          videos.push(file.path); // Cloudinary URL
        } else {
          images.push(file.path); // Cloudinary URL
        }
      });
    }

    const rental = new Rental({
      title: req.body.title,
      price: req.body.price,
      area: {
        total: req.body.areaTotal,
        livingRoom: req.body.areaLivingRoom,
        bedrooms: req.body.areaBedrooms,
        bathrooms: req.body.areaBathrooms,
      },
      location: {
        short: req.body.locationShort,
        fullAddress: fullAddress,
        formattedAddress: formattedAddress,
        coordinates: {
          type: 'Point',
          coordinates: coordinates,
        },
      },
      propertyType: req.body.propertyType,
      furniture: req.body.furniture ? req.body.furniture.split(',').map(item => item.trim()) : [],
      amenities: req.body.amenities ? req.body.amenities.split(',').map(item => item.trim()) : [],
      surroundings: req.body.surroundings ? req.body.surroundings.split(',').map(item => item.trim()) : [],
      rentalTerms: {
        minimumLease: req.body.rentalTermsMinimumLease,
        deposit: req.body.rentalTermsDeposit,
        paymentMethod: req.body.rentalTermsPaymentMethod,
        renewalTerms: req.body.rentalTermsRenewalTerms,
      },
      contactInfo: {
        name: contactInfoName,
        phone: contactInfoPhone,
        availableHours: req.body.contactInfoAvailableHours,
      },
      userId: req.userId,
      images: images,
      videos: videos,
      status: req.body.status || 'available',
      geocodingStatus: geocodingStatus,
    });

    const newRental = await rental.save();
    await syncRentalToElasticsearch(newRental);
    res.status(201).json({
      message: coordinates[0] === 0 && coordinates[1] === 0 
        ? 'Rental created successfully, but geocoding failed. Coordinates set to [0, 0]. Please update coordinates using /rentals/fix-coordinates/:id.'
        : 'Rental created successfully',
      rental: newRental,
    });
  } catch (err) {
    console.error('Error creating rental:', err);
    if (err instanceof multer.MulterError) {
      return res.status(400).json({ message: `File upload error: ${err.message}` });
    }
    res.status(400).json({ message: 'Failed to create rental', error: err.message });
  }
});

router.patch('/rentals/:id', authMiddleware, upload.array('media'), async (req, res) => {
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

    const updatedData = {};
    if (req.body.title) updatedData.title = req.body.title;
    if (req.body.price) updatedData.price = parseFloat(req.body.price) || rental.price;
    if (req.body.areaTotal || req.body.areaLivingRoom || req.body.areaBedrooms || req.body.areaBathrooms) {
      updatedData.area = {
        total: parseFloat(req.body.areaTotal) || rental.area.total,
        livingRoom: parseFloat(req.body.areaLivingRoom) || rental.area.livingRoom,
        bedrooms: parseFloat(req.body.areaBedrooms) || rental.area.bedrooms,
        bathrooms: parseFloat(req.body.areaBathrooms) || rental.area.bathrooms,
      };
    }
    if (req.body.locationShort || req.body.locationFullAddress || req.body.latitude || req.body.longitude) {
      let coordinates = [
        parseFloat(req.body.longitude) || rental.location.coordinates.coordinates[0],
        parseFloat(req.body.latitude) || rental.location.coordinates.coordinates[1],
      ];
      let formattedAddress = rental.location.formattedAddress;
      let geocodingStatus = rental.geocodingStatus || 'pending';

      const { full: fullAddress } = normalizeVietnameseAddress(req.body.locationFullAddress || rental.location.fullAddress);
      if (!fullAddress) {
        return res.status(400).json({ message: 'Invalid or missing full address' });
      }

      if (
        fullAddress &&
        (coordinates[0] === 0 && coordinates[1] === 0 || isNaN(coordinates[0]) || isNaN(coordinates[1]))
      ) {
        try {
          const geocodeResult = await geocodeAddressFree(fullAddress);
          coordinates = [geocodeResult.longitude, geocodeResult.latitude];
          formattedAddress = geocodeResult.formattedAddress;
          geocodingStatus = 'success';
          console.log('Used Nominatim geocoding service');
        } catch (geocodeError) {
          console.error('Geocoding failed:', geocodeError.message);
          coordinates = [0, 0];
          formattedAddress = fullAddress;
          geocodingStatus = 'failed';
          console.warn(`Geocoding failed for address: ${fullAddress}. Saving with default coordinates [0, 0].`);
        }
      } else if (req.body.latitude || req.body.longitude) {
        geocodingStatus = 'manual';
      }

      updatedData.location = {
        short: req.body.locationShort || rental.location.short,
        fullAddress: fullAddress,
        formattedAddress: formattedAddress,
        coordinates: {
          type: 'Point',
          coordinates: coordinates,
        },
      };
      updatedData.geocodingStatus = geocodingStatus;
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
        renewalTerms: req.body.rentalTermsRenewalTerms || rental.rentalTerms.renewalTerms,
      };
    }
    if (req.body.contactInfoName || req.body.contactInfoPhone || req.body.contactInfoAvailableHours) {
      updatedData.contactInfo = {
        name: req.body.contactInfoName || rental.contactInfo.name,
        phone: req.body.contactInfoPhone || rental.contactInfo.phone,
        availableHours: req.body.contactInfoAvailableHours || rental.contactInfo.availableHours,
      };
    }
    if (req.body.status) updatedData.status = req.body.status;

    // Handle media removal
    let updatedImages = [...(rental.images || [])];
    let updatedVideos = [...(rental.videos || [])];
    let removedMedia = [];
    
    if (req.body.removedMedia) {
      try {
        if (typeof req.body.removedMedia === 'string') {
          try {
            removedMedia = JSON.parse(req.body.removedMedia);
          } catch (e) {
            removedMedia = req.body.removedMedia.split(',').map(s => s.trim()).filter(Boolean);
          }
        } else if (Array.isArray(req.body.removedMedia)) {
          removedMedia = req.body.removedMedia;
        }
      } catch (e) {
        removedMedia = [req.body.removedMedia].filter(Boolean);
      }
      if (!Array.isArray(removedMedia)) removedMedia = [removedMedia];

      const cloudinaryIdsToDelete = [];
      
      for (const mediaUrl of removedMedia) {
        if (typeof mediaUrl !== 'string') continue;
        
        if (updatedImages.includes(mediaUrl)) {
          updatedImages = updatedImages.filter(img => img !== mediaUrl);
          const publicId = extractCloudinaryPublicId(mediaUrl);
          if (publicId) cloudinaryIdsToDelete.push(publicId);
        }
        
        if (updatedVideos.includes(mediaUrl)) {
          updatedVideos = updatedVideos.filter(vid => vid !== mediaUrl);
          const publicId = extractCloudinaryPublicId(mediaUrl);
          if (publicId) cloudinaryIdsToDelete.push(publicId);
        }
      }

      if (cloudinaryIdsToDelete.length > 0) {
        await deleteCloudinaryMedia(cloudinaryIdsToDelete);
      }
    }

    // Handle new media uploads
    if (req.files && req.files.length > 0) {
      const newImages = [];
      const newVideos = [];
      
      req.files.forEach(file => {
        if (file.mimetype.startsWith('video/')) {
          newVideos.push(file.path);
        } else {
          newImages.push(file.path);
        }
      });
      
      updatedImages = [...new Set([...updatedImages, ...newImages])];
      updatedVideos = [...new Set([...updatedVideos, ...newVideos])];
    }

    updatedData.images = updatedImages;
    updatedData.videos = updatedVideos;

    const updatedRental = await Rental.findByIdAndUpdate(
      req.params.id,
      { $set: updatedData },
      { new: true, runValidators: true },
    );

    if (!updatedRental) {
      return res.status(404).json({ message: 'Rental not found after update' });
    }

    await syncRentalToElasticsearch(updatedRental);
    
    res.json({
      message: updatedData.location?.coordinates?.coordinates[0] === 0 && updatedData.location?.coordinates?.coordinates[1] === 0 
        ? 'Rental updated successfully, but geocoding failed. Coordinates set to [0, 0]. Please update coordinates using /rentals/fix-coordinates/:id.'
        : 'Rental updated successfully',
      rental: {
        _id: updatedRental._id.toString(),
        id: updatedRental._id.toString(),
        ...updatedRental.toObject(),
      },
    });
  } catch (err) {
    console.error('Error updating rental:', err);
    if (err instanceof multer.MulterError) {
      return res.status(400).json({ message: `File upload error: ${err.message}` });
    }
    res.status(500).json({ message: 'Failed to update rental', error: err.message });
  }
});
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

    // Delete images and videos from Cloudinary
    const cloudinaryIdsToDelete = [];
    
    (rental.images || []).forEach(imageUrl => {
      const publicId = extractCloudinaryPublicId(imageUrl);
      if (publicId) cloudinaryIdsToDelete.push(publicId);
    });
    
    (rental.videos || []).forEach(videoUrl => {
      const publicId = extractCloudinaryPublicId(videoUrl);
      if (publicId) cloudinaryIdsToDelete.push(publicId);
    });

    if (cloudinaryIdsToDelete.length > 0) {
      await deleteCloudinaryMedia(cloudinaryIdsToDelete);
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
router.post('/rentals/geocode/:id', authMiddleware, async (req, res) => {
  try {
    if (!mongoose.Types.ObjectId.isValid(req.params.id)) {
      return res.status(400).json({ message: 'Invalid rental ID format' });
    }

    const rental = await Rental.findById(req.params.id);
    if (!rental) {
      return res.status(404).json({ message: 'Rental not found' });
    }

    if (rental.userId !== req.userId) {
      return res.status(403).json({ message: 'Unauthorized: You do not own this rental' });
    }

    const { full: fullAddress } = normalizeVietnameseAddress(req.body.address || rental.location?.fullAddress);
    if (!fullAddress) {
      return res.status(400).json({ 
        message: 'No address provided. Include address in request body or ensure rental has fullAddress' 
      });
    }

    console.log(`Geocoding address: ${fullAddress}`);

    let geocodeResult;
    try {
      geocodeResult = await geocodeAddressFree(fullAddress);
      console.log('Used Nominatim geocoding service');
    } catch (geocodeError) {
      console.error('Geocoding failed:', geocodeError.message);
      return res.status(400).json({ 
        message: 'Failed to geocode address', 
        error: geocodeError.message,
        addressTried: fullAddress,
      });
    }

    const updatedRental = await Rental.findByIdAndUpdate(
      req.params.id,
      {
        $set: {
          'location.coordinates': {
            type: 'Point',
            coordinates: [geocodeResult.longitude, geocodeResult.latitude],
          },
          'location.formattedAddress': geocodeResult.formattedAddress,
          geocodingStatus: 'success',
        },
      },
      { new: true, runValidators: true },
    );

    await syncRentalToElasticsearch(updatedRental);

    res.json({
      message: 'Address geocoded successfully',
      address: fullAddress,
      geocodedAddress: geocodeResult.formattedAddress,
      coordinates: [geocodeResult.longitude, geocodeResult.latitude],
      rental: {
        id: updatedRental._id,
        title: updatedRental.title,
        location: updatedRental.location,
        geocodingStatus: updatedRental.geocodingStatus,
      },
    });
  } catch (err) {
    console.error('Error geocoding address:', err);
    res.status(500).json({ message: 'Failed to geocode address', error: err.message });
  }
});

router.post('/rentals/geocode-all', authMiddleware, async (req, res) => {
  try {
    const rentalsToGeocode = await Rental.find({
      userId: req.userId,
      $or: [
        { 'location.coordinates.coordinates': [0, 0] },
        { 'location.coordinates.coordinates': { $exists: false } },
        { 'location.coordinates': { $exists: false } },
      ],
      'location.fullAddress': { $exists: true, $ne: '' },
    });

    console.log(`Found ${rentalsToGeocode.length} rentals to geocode for user ${req.userId}`);

    const results = {
      success: [],
      failed: [],
      total: rentalsToGeocode.length,
    };

    for (const rental of rentalsToGeocode) {
      try {
        console.log(`Geocoding rental ${rental._id}: ${rental.location.fullAddress}`);
        const geocodeResult = await geocodeAddressFree(rental.location.fullAddress);
        
        await Rental.findByIdAndUpdate(
          rental._id,
          {
            $set: {
              'location.coordinates': {
                type: 'Point',
                coordinates: [geocodeResult.longitude, geocodeResult.latitude],
              },
              'location.formattedAddress': geocodeResult.formattedAddress,
              geocodingStatus: 'success',
            },
          },
          { new: true, runValidators: true },
        );

        results.success.push({
          id: rental._id,
          title: rental.title,
          address: rental.location.fullAddress,
          geocodedAddress: geocodeResult.formattedAddress,
          coordinates: [geocodeResult.longitude, geocodeResult.latitude],
        });

        await new Promise(resolve => setTimeout(resolve, 100));
      } catch (error) {
        console.error(`Failed to geocode rental ${rental._id}:`, error.message);
        results.failed.push({
          id: rental._id,
          title: rental.title,
          address: rental.location.fullAddress,
          error: error.message,
        });
      }
    }

    res.json({
      message: `Geocoded ${results.success.length}/${results.total} rentals`,
      results,
    });
  } catch (err) {
    console.error('Error in batch geocoding:', err);
    res.status(500).json({ message: 'Failed to batch geocode', error: err.message });
  }
});

router.patch('/rentals/fix-coordinates/:id', authMiddleware, async (req, res) => {
  try {
    if (!mongoose.Types.ObjectId.isValid(req.params.id)) {
      return res.status(400).json({ message: 'Invalid rental ID format' });
    }

    const rental = await Rental.findById(req.params.id);
    if (!rental) {
      return res.status(404).json({ message: 'Rental not found' });
    }

    if (rental.userId !== req.userId) {
      return res.status(403).json({ message: 'Unauthorized: You do not own this rental' });
    }

    let newLatitude = parseFloat(req.body.latitude);
    let newLongitude = parseFloat(req.body.longitude);

    if (isNaN(newLatitude) || isNaN(newLongitude)) {
      return res.status(400).json({ 
        message: 'Please provide valid latitude and longitude in request body',
        example: { latitude: 10.762622, longitude: 106.660172 },
      });
    }

    if (Math.abs(newLongitude) > 180 || Math.abs(newLatitude) > 90) {
      return res.status(400).json({ message: 'Invalid coordinate values provided' });
    }

    const updatedRental = await Rental.findByIdAndUpdate(
      req.params.id,
      {
        $set: {
          'location.coordinates': {
            type: 'Point',
            coordinates: [newLongitude, newLatitude],
          },
          geocodingStatus: 'manual',
        },
      },
      { new: true, runValidators: true },
    );

    await syncRentalToElasticsearch(updatedRental);

    res.json({
      message: 'Coordinates updated successfully',
      oldCoordinates: rental.location?.coordinates?.coordinates,
      newCoordinates: [newLongitude, newLatitude],
      rental: {
        id: updatedRental._id,
        title: updatedRental.title,
        coordinates: updatedRental.location.coordinates.coordinates,
        geocodingStatus: updatedRental.geocodingStatus,
      },
    });
  } catch (err) {
    console.error('Error fixing coordinates:', err);
    res.status(500).json({ message: 'Failed to fix coordinates', error: err.message });
  }
});

// Cập nhật route /rentals/nearby/:id trong file routes
router.get('/rentals/nearby/:id', async (req, res) => {
  try {
    const { radius = 10, page = 1, limit = 10, minPrice, maxPrice } = req.query;
    const skip = (Number(page) - 1) * Number(limit);
    
    console.log(`Fetching nearby rentals for ID: ${req.params.id} with radius: ${radius}km, page: ${page}, limit: ${limit}, minPrice: ${minPrice}, maxPrice: ${maxPrice}`);
    
    if (!mongoose.Types.ObjectId.isValid(req.params.id)) {
      return res.status(400).json({ message: 'Invalid rental ID format' });
    }
    
    const rental = await Rental.findById(req.params.id);
    if (!rental) {
      console.log(`Rental with ID ${req.params.id} not found`);
      return res.status(404).json({ message: 'Rental not found' });
    }
    
    console.log('Found rental:', {
      id: rental._id,
      title: rental.title,
      coordinates: rental.location?.coordinates?.coordinates || rental.coordinates,
      geocodingStatus: rental.geocodingStatus,
    });
    
    // Xử lý coordinates với nhiều trường hợp khác nhau
    let coordinates;
    
    // Trường hợp 1: coordinates nằm trong location.coordinates.coordinates (GeoJSON format)
    if (rental.location?.coordinates?.coordinates && 
        Array.isArray(rental.location.coordinates.coordinates) && 
        rental.location.coordinates.coordinates.length === 2) {
      coordinates = rental.location.coordinates.coordinates;
    }
    // Trường hợp 2: coordinates nằm trực tiếp trong rental.coordinates
    else if (rental.coordinates && Array.isArray(rental.coordinates) && rental.coordinates.length === 2) {
      coordinates = rental.coordinates;
    }
    // Trường hợp 3: coordinates nằm trong location.coordinates (không phải GeoJSON)
    else if (rental.location?.coordinates && Array.isArray(rental.location.coordinates) && rental.location.coordinates.length === 2) {
      coordinates = rental.location.coordinates;
    }
    else {
      console.log('Invalid coordinates structure:', {
        locationCoordinates: rental.location?.coordinates,
        directCoordinates: rental.coordinates
      });
      return res.status(400).json({ message: 'Rental has invalid coordinate structure' });
    }
    
    const [longitude, latitude] = coordinates;
    
    if (typeof longitude !== 'number' || typeof latitude !== 'number' ||
        isNaN(longitude) || isNaN(latitude) ||
        Math.abs(longitude) > 180 || Math.abs(latitude) > 90) {
      console.log('Invalid coordinate values:', { longitude, latitude });
      return res.status(400).json({ message: 'Rental has invalid coordinate values' });
    }

    // Xử lý price filter
    let priceFilter = {};
    if (minPrice || maxPrice) {
      if (minPrice) priceFilter.$gte = Number(minPrice);
      if (maxPrice) priceFilter.$lte = Number(maxPrice);
    }
    
    if (longitude === 0 && latitude === 0) {
      console.log('Coordinates are both zero - likely invalid');
      // Trả về danh sách các nhà trọ khác trong cùng khu vực để gợi ý
      const locationParts = rental.location?.fullAddress?.split(',') || [];
      const wardInfo = locationParts.length > 1 ? locationParts[1].trim() : '';
      
      const query = {
        _id: { $ne: new mongoose.Types.ObjectId(req.params.id) },
        status: 'available',
        ...(wardInfo && { 'location.fullAddress': { $regex: wardInfo, $options: 'i' } }),
      };
      if (Object.keys(priceFilter).length > 0) {
        query.price = priceFilter;
      }

      const nearbyRentals = await Rental.find(query)
        .skip(skip)
        .limit(Number(limit))
        .lean();
      
      return res.json({
        rentals: nearbyRentals.map(rental => ({
          ...rental,
          distance: null,
          coordinates: rental.location?.coordinates?.coordinates || rental.coordinates || [0, 0]
        })),
        total: nearbyRentals.length,
        page: Number(page),
        pages: Math.ceil(nearbyRentals.length / Number(limit)),
        warning: 'Rental coordinates are invalid ([0, 0]). Showing rentals in the same area instead.',
        searchMethod: 'location_fallback'
      });
    }
    
    console.log('Using coordinates:', { longitude, latitude });
    
    const radiusInMeters = parseFloat(radius) * 1000;
    const radiusInRadians = radiusInMeters / 6378100;
    
    // Đếm tổng số nhà trọ gần đây
    const geoQuery = {
      'location.coordinates': {
        $geoWithin: {
          $centerSphere: [[longitude, latitude], radiusInRadians],
        },
      },
      _id: { $ne: new mongoose.Types.ObjectId(req.params.id) },
      status: 'available',
    };
    if (Object.keys(priceFilter).length > 0) {
      geoQuery.price = priceFilter;
    }
    const total = await Rental.countDocuments(geoQuery);
    
    // Tìm nhà trọ gần đây bằng $geoNear
    const nearbyRentals = await Rental.aggregate([
      {
        $geoNear: {
          near: { type: 'Point', coordinates: [longitude, latitude] },
          distanceField: 'distance',
          maxDistance: radiusInMeters,
          spherical: true,
          query: {
            _id: { $ne: new mongoose.Types.ObjectId(req.params.id) },
            status: 'available',
            ...(Object.keys(priceFilter).length > 0 ? { price: priceFilter } : {}),
          },
        },
      },
      { $skip: skip },
      { $limit: Number(limit) },
      {
        $project: {
          title: 1,
          price: 1,
          location: 1,
          images: 1,
          propertyType: 1,
          createdAt: 1,
          geocodingStatus: 1,
          distance: 1,
          coordinates: '$location.coordinates.coordinates' // Đảm bảo coordinates được trả về
        },
      },
    ]);
    
    console.log(`Found ${nearbyRentals.length} nearby rentals`);
    
    const transformedRentals = nearbyRentals.map(rental => ({
      ...rental,
      coordinates: rental.coordinates || rental.location?.coordinates?.coordinates || [0, 0],
      distance: rental.distance ? (rental.distance / 1000).toFixed(2) : null,
      distanceKm: rental.distance ? (rental.distance / 1000).toFixed(2) + 'km' : 'N/A'
    }));
    
    res.json({
      rentals: transformedRentals,
      total,
      page: Number(page),
      pages: Math.ceil(total / Number(limit)),
      searchMethod: 'geospatial',
      centerCoordinates: { longitude, latitude },
      radiusKm: parseFloat(radius)
    });
    
  } catch (err) {
    console.error('Error fetching nearby rentals:', err);
    if (err.name === 'CastError') {
      return res.status(400).json({ message: 'Invalid rental ID format', error: err.message });
    }
    res.status(500).json({ message: 'Failed to fetch nearby rentals', error: err.message });
  }
});

router.get('/rentals/nearby-fallback/:id', async (req, res) => {
  try {
    const { radius = 5 } = req.query;
    
    if (!mongoose.Types.ObjectId.isValid(req.params.id)) {
      return res.status(400).json({ message: 'Invalid rental ID format' });
    }

    const rental = await Rental.findById(req.params.id);
    if (!rental) {
      return res.status(404).json({ message: 'Rental not found' });
    }

    const coordinates = rental.location?.coordinates?.coordinates;
    if (!coordinates || coordinates.length !== 2) {
      return res.status(400).json({ message: 'Rental has invalid coordinates' });
    }

    const [targetLon, targetLat] = coordinates;
    
    const nearbyRentals = await Rental.aggregate([
      {
        $match: {
          _id: { $ne: new mongoose.Types.ObjectId(req.params.id) },
          status: 'available',
          'location.coordinates.coordinates': { $exists: true, $ne: [0, 0] },
        },
      },
      {
        $addFields: {
          distance: {
            $sqrt: {
              $add: [
                {
                  $pow: [
                    { $multiply: [{ $subtract: [{ $arrayElemAt: ['$location.coordinates.coordinates', 0] }, targetLon] }, 111.32] },
                    2,
                  ],
                },
                {
                  $pow: [
                    { $multiply: [{ $subtract: [{ $arrayElemAt: ['$location.coordinates.coordinates', 1] }, targetLat] }, 110.54] },
                    2,
                  ],
                },
              ],
            },
          },
        },
      },
      {
        $match: {
          distance: { $lte: parseFloat(radius) },
        },
      },
      {
        $sort: { distance: 1 },
      },
      {
        $limit: 20,
      },
      {
        $project: {
          title: 1,
          price: 1,
          location: 1,
          images: 1,
          propertyType: 1,
          createdAt: 1,
          geocodingStatus: 1,
          distance: 1,
        },
      },
    ]);

    res.json(nearbyRentals);
  } catch (err) {
    console.error('Error in fallback nearby rentals:', err);
    res.status(500).json({ message: 'Failed to fetch nearby rentals', error: err.message });
  }
});

// ==================== AI SUGGEST ROUTES ====================

router.get('/ai-suggest', async (req, res) => {
  try {
    const { q, minPrice, maxPrice, propertyType, limit = 5 } = req.query;

    // Validate input
    if (!q || q.toString().trim().length < 3) {
      return res.status(400).json({
        success: false,
        message: 'Search query must be at least 3 characters',
        data: [],
      });
    }

    const limitNum = Math.min(parseInt(limit) || 5, 10);
    const searchQuery = q.toString().trim();

    // Build MongoDB query
    const query = {
      status: 'available',
      $or: [
        { title: { $regex: searchQuery, $options: 'i' } },
        { 'location.short': { $regex: searchQuery, $options: 'i' } },
        { 'location.fullAddress': { $regex: searchQuery, $options: 'i' } },
        { propertyType: { $regex: searchQuery, $options: 'i' } },
        { amenities: { $regex: searchQuery, $options: 'i' } },
        { furniture: { $regex: searchQuery, $options: 'i' } },
      ],
    };

    // Add price filter if provided
    if (minPrice || maxPrice) {
      query.price = {};
      if (minPrice) query.price.$gte = Number(minPrice);
      if (maxPrice) query.price.$lte = Number(maxPrice);
    } else {
      // Default price range: 0 - 20 triệu/tháng
      query.price = { $lte: 20000000 };
    }

    // Add property type filter if provided
    if (propertyType) {
      query.propertyType = propertyType;
    }

    // Execute query
    const results = await Rental.find(query)
      .select(
        'title price location propertyType images area amenities createdAt contactInfo'
      )
      .limit(limitNum)
      .sort({ createdAt: -1 })
      .lean();

    // Transform results
    const transformedResults = results.map((rental) => ({
      id: rental._id.toString(),
      title: rental.title,
      price: rental.price,
      location: {
        short: rental.location?.short || '',
        fullAddress: rental.location?.fullAddress || '',
      },
      propertyType: rental.propertyType,
      images: rental.images || [],
      area: rental.area?.total || 0,
      amenities: (rental.amenities || []).slice(0, 3), // Lấy 3 tiện nghi đầu
      bedrooms: rental.area?.bedrooms || 0,
      bathrooms: rental.area?.bathrooms || 0,
      contactInfo: {
        name: rental.contactInfo?.name || 'Chủ nhà',
        phone: rental.contactInfo?.phone || '',
      },
      createdAt: rental.createdAt,
    }));

    res.json({
      success: true,
      data: transformedResults,
      count: transformedResults.length,
      searchQuery,
    });
  } catch (err) {
    console.error('Error in AI suggest:', err);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch suggestions',
      error: err.message,
      data: [],
    });
  }
});


router.get('/ai-suggest/advanced', async (req, res) => {
  try {
    const { q } = req.query;

    if (!q || q.toString().trim().length < 3) {
      return res.status(400).json({
        success: false,
        message: 'Search query required',
        data: [],
      });
    }

    const searchQuery = q.toString().trim().toLowerCase();

    // Parse natural language query
    const parsedParams = _parseNaturalLanguageQuery(searchQuery);

    // Build query
    const query = { status: 'available' };

    // Text search
    query.$or = [
      { title: { $regex: searchQuery, $options: 'i' } },
      { 'location.short': { $regex: searchQuery, $options: 'i' } },
      { 'location.fullAddress': { $regex: searchQuery, $options: 'i' } },
      { propertyType: { $regex: searchQuery, $options: 'i' } },
      { amenities: { $in: parsedParams.amenities.map(a => new RegExp(a, 'i')) } },
    ];

    // Price filter
    if (parsedParams.maxPrice) {
      query.price = { $lte: parsedParams.maxPrice };
    } else {
      query.price = { $lte: 20000000 };
    }
    if (parsedParams.minPrice) {
      query.price.$gte = parsedParams.minPrice;
    }

    // Property type filter
    if (parsedParams.propertyType) {
      query.propertyType = {
        $regex: parsedParams.propertyType,
        $options: 'i',
      };
    }

    // Area filter
    if (parsedParams.area) {
      query['area.total'] = { $gte: parsedParams.area - 10 };
    }

    // Rooms filter
    if (parsedParams.bedrooms) {
      query['area.bedrooms'] = parsedParams.bedrooms;
    }

    // Location filter
    if (parsedParams.locations.length > 0) {
      query.$or = query.$or.concat(
        parsedParams.locations.map((loc) => ({
          'location.fullAddress': { $regex: loc, $options: 'i' },
        }))
      );
    }

    // Execute query
    const results = await Rental.find(query)
      .select(
        'title price location propertyType images area amenities createdAt contactInfo'
      )
      .limit(5)
      .sort({ createdAt: -1 })
      .lean();

    // Transform results
    const transformedResults = results.map((rental) => ({
      id: rental._id.toString(),
      title: rental.title,
      price: rental.price,
      location: {
        short: rental.location?.short || '',
        fullAddress: rental.location?.fullAddress || '',
      },
      propertyType: rental.propertyType,
      images: rental.images || [],
      area: rental.area?.total || 0,
      amenities: (rental.amenities || []).slice(0, 3),
      bedrooms: rental.area?.bedrooms || 0,
      bathrooms: rental.area?.bathrooms || 0,
      contactInfo: {
        name: rental.contactInfo?.name || 'Chủ nhà',
        phone: rental.contactInfo?.phone || '',
      },
    }));

    res.json({
      success: true,
      data: transformedResults,
      count: transformedResults.length,
      parsedParams, // Debug info
      searchQuery,
    });
  } catch (err) {
    console.error('Error in advanced AI suggest:', err);
    res.status(500).json({
      success: false,
      message: 'Failed to process request',
      error: err.message,
      data: [],
    });
  }
});


module.exports = router;