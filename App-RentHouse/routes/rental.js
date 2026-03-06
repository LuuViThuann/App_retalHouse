
require('dotenv').config();
const express = require('express'); // đã xóa ESlint
const router = express.Router();
const mongoose = require('mongoose');

const {
  trackRentalView,
  trackAction,
  trackDetailedInteraction,
  getUserAnalytics
} = require('../middleware/trackingMiddleware');

const Rental = require('../models/Rental');
const Favorite = require('../models/favorite');
const { Comment, Reply, LikeComment } = require('../models/comments');
const Feedback = require('../models/feedback');
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

const Payment = require('../models/Payment');
const vnpayService = require('../service/vnpayService');

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
const normalizePropertyType = (propertyType) => {
  const typeMap = {
    'Căn hộ chung cư': 'Apartment',
    'apartment': 'Apartment',
    'Nhà riêng': 'House',
    'house': 'House',
    'Nhà trọ/Phòng trọ': 'Room',
    'room': 'Room',
    'Biệt thự': 'Villa',
    'villa': 'Villa',
    'Văn phòng': 'Office',
    'office': 'Office',
    'Mặt bằng kinh doanh': 'Shop',
    'shop': 'Shop',
    'Đất nền': 'Land',
    'land': 'Land',
  };

  const normalized = typeMap[propertyType] || typeMap[propertyType?.toLowerCase()];
  return normalized || propertyType;
};
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
      console.error(' Error deleting from Cloudinary:', publicId, error);
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
/**
 * Middleware kiểm tra xem user đã thanh toán hay chưa ====================================================================
 * Nếu chưa, tạo payment request
 */
const checkPaymentStatus = async (req, res, next) => {
  try {
    const { paymentTransactionCode } = req.body;

    //  Nếu không có transaction code → YÊU CẦU CLIENT THANH TOÁN TRƯỚC
    if (!paymentTransactionCode) {
      return res.status(402).json({
        success: false,
        message: 'Vui lòng thanh toán phí đăng bài trước khi đăng bài.',
        requiresPayment: true,
        hint: 'Gọi POST /api/vnpay/create-payment để tạo thanh toán trước',
      });
    }

    // ✅ Tìm payment trong database
    const payment = await Payment.findOne({ transactionCode: paymentTransactionCode });

    if (!payment) {
      return res.status(404).json({
        success: false,
        message: 'Mã thanh toán không hợp lệ hoặc không tồn tại',
        transactionCode: paymentTransactionCode,
      });
    }

    // ✅ Kiểm tra payment có thuộc user này không
    if (payment.userId !== req.userId) {
      return res.status(403).json({
        success: false,
        message: 'Mã thanh toán không thuộc về bạn',
      });
    }

    //  CRITICAL FIX: Chỉ check completed, không block nếu processing
    if (payment.status === 'completed') {
      // ✅ Payment đã hoàn tất → cho phép tạo rental
      console.log(`✅ Payment verified: ${paymentTransactionCode} (completed)`);
      req.paymentTransactionCode = paymentTransactionCode;
      req.payment = payment;
      next();
      return;
    }

    // ⚠️ Payment chưa completed
    console.warn(`⚠️ Payment not completed yet: ${paymentTransactionCode}`);
    console.warn(`   Current status: ${payment.status}`);
    console.warn(`   Created at: ${payment.createdAt}`);
    console.warn(`   Confirmed via: ${payment.confirmedVia || 'NOT_CONFIRMED'}`);

    // 🔥 FIX: Trả về thông tin chi tiết để client có thể retry
    return res.status(402).json({
      success: false,
      message: 'Thanh toán chưa được xác nhận',
      paymentStatus: payment.status,
      transactionCode: paymentTransactionCode,
      createdAt: payment.createdAt,
      confirmedVia: payment.confirmedVia,
      hint: payment.status === 'processing'
        ? 'Vui lòng đợi VNPay xác nhận thanh toán (có thể mất vài giây). Sau đó thử lại.'
        : 'Thanh toán đã thất bại. Vui lòng thanh toán lại.',
      canRetry: payment.status === 'processing', // Client có thể retry nếu processing
    });

  } catch (err) {
    console.error('Error in checkPaymentStatus middleware:', err);
    res.status(500).json({
      success: false,
      message: 'Lỗi kiểm tra trạng thái thanh toán',
      error: err.message,
    });
  }
};

//=============================================================================================================================== NEW 
// ==================== IMPROVED GEOCODING ====================

const normalizeAddressForGeocoding = (address) => {
  if (!address || typeof address !== 'string') return null;

  let normalized = address.trim().replace(/\s+/g, ' ');

  const abbreviations = {
    'P\\.?\\s': 'Phường ',
    'Q\\.?\\s': 'Quận ',
    'TP\\.?\\s': 'Thành phố ',
    'H\\.?\\s': 'Huyện ',
    'TX\\.?\\s': 'Thị xã ',
    'SO\\.?\\s': 'Số ',
    'Đ\\.?\\s': 'Đường ',
  };

  Object.entries(abbreviations).forEach(([pattern, replacement]) => {
    normalized = normalized.replace(new RegExp(pattern, 'gi'), replacement);
  });

  normalized = normalized.replace(/[<>[\]{}|]/g, '');

  if (!normalized.toLowerCase().includes('việt nam') &&
    !normalized.toLowerCase().includes('vietnam')) {
    normalized += ', Việt Nam';
  }

  return normalized;
};

const isValidVietnamAddress = (address) => {
  if (!address || typeof address !== 'string') return false;

  const parts = address.toLowerCase().split(',').map(p => p.trim());

  if (parts.length < 3) return false;

  const vietnamKeywords = [
    'phường', 'huyện', 'quận', 'tỉnh', 'thành phố',
    'thị xã', 'đường', 'khu phố', 'xã', 'hẻm'
  ];

  const fullAddr = address.toLowerCase();
  const hasVietnamKeywords = vietnamKeywords.some(kw => fullAddr.includes(kw));

  return hasVietnamKeywords;
};

const tryNominatimGeocode = async (address, maxRetries = 2) => {
  for (let attempt = 0; attempt < maxRetries; attempt++) {
    try {
      const response = await fetch(
        `https://nominatim.openstreetmap.org/search?` +
        `format=json&` +
        `q=${encodeURIComponent(address)}&` +
        `limit=5&` +
        `countrycodes=vn&` +
        `addressdetails=1&` +
        `accept-language=vi`,
        {
          headers: {
            'User-Agent': 'RentalHouseApp/1.0 (+https://rentalhouse.app)',
            'Accept-Language': 'vi-VN,vi;q=0.9',
          },
          timeout: 12000,
        }
      );

      if (response.status === 429) {
        console.warn(`Rate limited on attempt ${attempt + 1}`);
        await new Promise(resolve => setTimeout(resolve, 2000 * (attempt + 1)));
        continue;
      }

      if (!response.ok) throw new Error(`HTTP ${response.status}`);

      const data = await response.json();

      if (Array.isArray(data) && data.length > 0) {
        for (const item of data) {
          const osmClass = item.class || '';
          const type = item.type || '';

          if ((osmClass === 'place' &&
            (type === 'quarter' || type === 'village' || type === 'neighborhood')) ||
            osmClass === 'highway' ||
            osmClass === 'building') {
            return item;
          }
        }

        return data[0];
      }
    } catch (error) {
      console.error(`Geocoding attempt ${attempt + 1} failed:`, error.message);
      if (attempt < maxRetries - 1) {
        await new Promise(resolve => setTimeout(resolve, 1000 * (attempt + 1)));
      }
    }
  }

  return null;
};

const createSimplifiedAddress = (normalized) => {
  const parts = normalized
    .split(',')
    .map(p => p.trim())
    .filter(p => p.length > 0);

  if (parts.length >= 3) {
    return `${parts[0]}, ${parts[parts.length - 2]}, ${parts[parts.length - 1]}`;
  }
  return normalized;
};

const createMinimalAddress = (normalized) => {
  const parts = normalized
    .split(',')
    .map(p => p.trim())
    .filter(p => p.length > 0);

  if (parts.length >= 2) {
    return `${parts[parts.length - 2]}, ${parts[parts.length - 1]}`;
  }
  return normalized;
};

const extractAddressComponents = (nominatimResult) => {
  try {
    const addr = nominatimResult.address || {};
    return {
      street: addr.road || addr.street || '',
      ward: addr.suburb || addr.hamlet || '',
      district: addr.city_district || addr.county || '',
      city: addr.city || addr.town || '',
      province: addr.state || '',
      country: addr.country || 'Vietnam',
    };
  } catch (e) {
    return {};
  }
};

const isInVietnam = (lat, lon) => {
  return lat >= 8.0 && lat <= 23.5 && lon >= 102.0 && lon <= 109.5;
};

const geocodeAddressFreeImproved = async (address) => {
  try {


    const normalized = normalizeAddressForGeocoding(address);
    if (!normalized) {
      throw new Error('Could not normalize address');
    }

    console.log(`🔍 [GEO] Normalized: ${normalized}`);

    let result = await tryNominatimGeocode(normalized);

    if (!result) {
      const simplified = createSimplifiedAddress(normalized);
      console.log(`🔍 [GEO] Trying simplified: ${simplified}`);
      result = await tryNominatimGeocode(simplified);
    }

    if (!result) {
      const minimal = createMinimalAddress(normalized);
      console.log(`🔍 [GEO] Trying minimal: ${minimal}`);
      result = await tryNominatimGeocode(minimal);
    }

    if (!result) {
      throw new Error(`No results found for addresses`);
    }

    const lat = parseFloat(result.lat);
    const lon = parseFloat(result.lon);

    if (!isInVietnam(lat, lon)) {
      throw new Error(`Location not in Vietnam: ${lat}, ${lon}`);
    }

    return {
      latitude: lat,
      longitude: lon,
      formattedAddress: result.display_name,
      status: 'success',
      addressComponents: extractAddressComponents(result),
    };
  } catch (error) {
    console.error('Geocoding error:', error.message);
    throw error;
  }
};




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


// ========== ADMIN DELETE RENTAL ========== ====================================================================
router.delete('/admin/rentals/:rentalId', verifyAdmin, async (req, res) => {
  try {

    if (!mongoose.Types.ObjectId.isValid(req.params.rentalId)) {
      return res.status(400).json({ message: 'Invalid rental ID' });
    }

    const rental = await Rental.findById(req.params.rentalId);
    if (!rental) {
      return res.status(404).json({ message: 'Rental not found' });
    }

    if (rental.paymentInfo?.paymentId) {
      await Payment.findByIdAndDelete(rental.paymentInfo.paymentId);
      console.log(`✅ Deleted payment record for rental ${req.params.rentalId}`);
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

    console.log('✅ RENTAL DELETED SUCCESSFULLY');

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

  if (search && search.trim()) {
    query.$or = [
      { title: { $regex: search.trim(), $options: 'i' } },
      { 'location.short': { $regex: search.trim(), $options: 'i' } },
      { 'location.fullAddress': { $regex: search.trim(), $options: 'i' } },
    ];
  }

  if (minPrice || maxPrice) {
    query.price = {};
    if (minPrice) query.price.$gte = Number(minPrice);
    if (maxPrice) query.price.$lte = Number(maxPrice);
  }

  // 🔥 FIX: Normalize property types for MongoDB query
  if (propertyTypes && propertyTypes.length > 0) {
    const normalizedTypes = propertyTypes.map(type => normalizePropertyType(type));
    query.propertyType = { $in: normalizedTypes };
    console.log('🏠 MongoDB property type filter:', normalizedTypes);
  }

  if (status) {
    query.status = status;
  } else {
    query.status = 'available';
  }

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
    const {
      search,
      minPrice,
      maxPrice,
      propertyType,
      status,
      page = 1,
      limit = 10
    } = req.query;

    // 🔥 FIX: Normalize property types
    const rawPropertyTypes = propertyType
      ? (Array.isArray(propertyType) ? propertyType : [propertyType])
      : [];

    const propertyTypes = rawPropertyTypes
      .map(type => normalizePropertyType(type))
      .filter(Boolean);

    console.log('🔍 Raw property types:', rawPropertyTypes);
    console.log('🔍 Normalized property types:', propertyTypes);

    const skip = (Number(page) - 1) * Number(limit);

    const cacheKey = `search:${search || ''}:${minPrice || ''}:${maxPrice || ''}:${propertyTypes.sort().join(',')}:${status || ''}:${page}:${limit}`;

    const cachedResult = await redisClient.get(cacheKey);
    if (cachedResult) {
      console.log('✅ Serving from cache:', cacheKey);
      return res.json(JSON.parse(cachedResult));
    }

    console.log('🔍 Search query:', { search, minPrice, maxPrice, propertyTypes, status, page, limit });

    if (search && search.trim() && req.header('Authorization')) {
      const token = req.header('Authorization').replace('Bearer ', '');
      try {
        const decodedToken = await admin.auth().verifyIdToken(token);
        const userId = decodedToken.uid;
        const searchKey = `search:${userId}`;

        const existingHistory = await redisClient.lRange(searchKey, 0, -1);
        const normalizedSearch = search.toLowerCase().trim();
        const isDuplicate = existingHistory.some(
          item => item.toLowerCase().trim() === normalizedSearch
        );

        if (!isDuplicate) {
          await redisClient.lPush(searchKey, search.trim());
          await redisClient.lTrim(searchKey, 0, 19);
          console.log(`✅ Saved search "${search}" for user ${userId}`);
        }
      } catch (err) {
        console.error('Error saving search history:', err);
      }
    }

    let rentals = [];
    let total = 0;

    // ==================== ELASTICSEARCH SEARCH ====================
    try {
      const query = {
        bool: {
          must: [],
          filter: [],
        },
      };

      // Text search
      if (search && search.trim()) {
        query.bool.must.push({
          multi_match: {
            query: search.trim(),
            fields: ['title^3', 'location^2'],
            fuzziness: 'AUTO',
            operator: 'or',
          },
        });
      }

      // Price range filter
      if (minPrice || maxPrice) {
        const priceFilter = {};
        if (minPrice) priceFilter.gte = Number(minPrice);
        if (maxPrice) priceFilter.lte = Number(maxPrice);
        query.bool.filter.push({ range: { price: priceFilter } });
        console.log('💰 Price filter:', priceFilter);
      }

      // 🔥 FIX: Property type filter with lowercase matching
      if (propertyTypes.length > 0) {
        // Use terms query with lowercase values
        query.bool.filter.push({
          terms: {
            'propertyType': propertyTypes.map(t => t.toLowerCase())
          }
        });
        console.log('🏠 Property type filter:', propertyTypes);
      }

      // Status filter
      if (status) {
        query.bool.filter.push({ term: { status } });
      } else {
        query.bool.filter.push({ term: { status: 'available' } });
      }

      console.log('📊 Elasticsearch query:', JSON.stringify(query, null, 2));

      // Execute Elasticsearch search
      const response = await elasticClient.search({
        index: 'rentals',
        from: skip,
        size: Number(limit),
        body: {
          query,
          sort: [
            { _score: { order: 'desc' } },
            { createdAt: { order: 'desc' } }
          ]
        },
      });

      console.log(`📊 Elasticsearch returned ${response.hits.hits.length} hits`);

      const rentalIds = response.hits.hits.map(hit => hit._id);
      total = response.hits.total.value;

      // Fetch full data from MongoDB
      if (rentalIds.length > 0) {
        const rentalsMap = {};
        const dbRentals = await Rental.find({ _id: { $in: rentalIds } }).lean();

        dbRentals.forEach(rental => {
          rentalsMap[rental._id.toString()] = rental;
        });

        rentals = rentalIds
          .map(id => rentalsMap[id])
          .filter(Boolean);
      }

      console.log(`✅ Found ${total} rentals via Elasticsearch`);

    } catch (esErr) {
      console.error('⚠️ Elasticsearch search failed:', esErr.message);

      // ==================== MONGODB FALLBACK ====================
      const mongoQuery = buildMongoQuery({
        search,
        minPrice,
        maxPrice,
        propertyTypes: propertyTypes.length > 0 ? propertyTypes : null,
        status: status || 'available'
      });

      console.log('🔄 MongoDB fallback query:', JSON.stringify(mongoQuery, null, 2));

      rentals = await Rental.find(mongoQuery)
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(Number(limit))
        .lean();

      total = await Rental.countDocuments(mongoQuery);

      console.log(`✅ Found ${total} rentals via MongoDB fallback`);
    }

    const result = {
      success: true,
      rentals,
      total,
      page: Number(page),
      pages: Math.ceil(total / Number(limit)),
      hasMore: (Number(page) * Number(limit)) < total,
      filters: {
        search: search || null,
        minPrice: minPrice ? Number(minPrice) : null,
        maxPrice: maxPrice ? Number(maxPrice) : null,
        propertyTypes: propertyTypes.length > 0 ? propertyTypes : null,
        status: status || 'available',
      }
    };

    await redisClient.setEx(cacheKey, 300, JSON.stringify(result));

    res.json(result);
  } catch (err) {
    console.error('❌ Error in search:', err);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch rentals',
      error: err.message
    });
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

    // Loại bỏ trùng lặp và giữ thứ tự
    const uniqueHistory = [...new Set(history.map(item => item.toLowerCase().trim()))];

    res.json(uniqueHistory);
  } catch (err) {
    console.error('Error fetching search history:', err);
    res.status(500).json({ message: 'Failed to fetch search history', error: err.message });
  }
});
router.delete('/search-history/:query', [sanitizeHeadersMiddleware, authMiddleware], async (req, res) => {
  try {
    const { query } = req.params;
    const searchKey = `search:${req.userId}`;
    const normalizedQuery = query.toLowerCase().trim();

    // Bước 1: Xóa từng mục cụ thể (KHÔNG load toàn bộ)
    const allItems = await redisClient.lRange(searchKey, 0, -1);

    // Tìm index của mục cần xóa
    let deletedCount = 0;
    for (let i = 0; i < allItems.length; i++) {
      if (allItems[i].toLowerCase().trim() === normalizedQuery) {
        await redisClient.lRem(searchKey, 1, allItems[i]);
        deletedCount++;
        console.log(`✅ Deleted: "${allItems[i]}" at index ${i}`);
      }
    }

    if (deletedCount === 0) {
      return res.status(404).json({
        success: false,
        message: 'Mục không tìm thấy',
        deletedQuery: query,
      });
    }

    console.log(`✅ Deleted ${deletedCount} item(s) for user ${req.userId}`);

    res.json({
      success: true,
      message: 'Đã xóa mục lịch sử tìm kiếm',
      deletedQuery: query,
      deletedCount: deletedCount,
    });
  } catch (err) {
    console.error('Error deleting search history item:', err);
    res.status(500).json({
      success: false,
      message: 'Failed to delete search history item',
      error: err.message
    });
  }
});


router.delete('/search-history', [sanitizeHeadersMiddleware, authMiddleware], async (req, res) => {
  try {
    const searchKey = `search:${req.userId}`;
    await redisClient.del(searchKey);

    console.log(`✅ Cleared all search history for user ${req.userId}`);

    res.json({
      success: true,
      message: 'Đã xóa toàn bộ lịch sử tìm kiếm'
    });
  } catch (err) {
    console.error('Error clearing search history:', err);
    res.status(500).json({
      success: false,
      message: 'Failed to clear search history',
      error: err.message
    });
  }
});

//  XEM CÁC BÀI TỪ VỊ TRÍ HIỆN TẠI 
router.get('/rentals/nearby-from-location', async (req, res) => {
  const requestId = Date.now(); // Để track request

  try {
    const { latitude, longitude, radius = 10, page = 1, minPrice, maxPrice } = req.query;
    const limit = req.query.limit ? parseInt(req.query.limit) : null; // ✅ null = lấy tất cả
    const skip = limit ? (Number(page) - 1) * limit : 0;

    console.log(`🔍 [${requestId}] [NEARBY-FROM-LOCATION] Request:`, {
      latitude,
      longitude,
      radius,
      minPrice,
      maxPrice,
      page,
      limit
    });

    // ✅ VALIDATE COORDINATES
    const lat = parseFloat(latitude);
    const lon = parseFloat(longitude);

    if (isNaN(lat) || isNaN(lon)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid coordinates: latitude and longitude must be numbers',
        received: { latitude, longitude }
      });
    }

    if (Math.abs(lon) > 180 || Math.abs(lat) > 90) {
      return res.status(400).json({
        success: false,
        message: 'Coordinates out of valid range',
        received: { latitude: lat, longitude: lon },
        validRange: { latitude: '[-90, 90]', longitude: '[-180, 180]' }
      });
    }

    // ✅ VALIDATE RADIUS
    const radiusNum = parseFloat(radius);
    if (isNaN(radiusNum) || radiusNum <= 0 || radiusNum > 100) {
      return res.status(400).json({
        success: false,
        message: 'Radius must be between 0 and 100 km',
        received: radius
      });
    }

    // ✅ BUILD PRICE FILTER SAFELY
    let priceFilter = {};

    if (minPrice !== undefined && minPrice !== null && minPrice !== '') {
      const minVal = Number(minPrice);
      if (!isNaN(minVal) && minVal >= 0) {
        priceFilter.$gte = minVal;
        console.log(`✅ [${requestId}] Min price filter: >= ${minVal}`);
      }
    }

    if (maxPrice !== undefined && maxPrice !== null && maxPrice !== '') {
      const maxVal = Number(maxPrice);
      if (!isNaN(maxVal) && maxVal > 0) {
        priceFilter.$lte = maxVal;
        console.log(`✅ [${requestId}] Max price filter: <= ${maxVal}`);
      }
    }

    const radiusInMeters = radiusNum * 1000;
    const radiusInRadians = radiusInMeters / 6378100; // Earth's radius in meters

    console.log(`📍 [${requestId}] Search center: [${lon}, ${lat}]`);
    console.log(`📏 [${requestId}] Radius: ${radiusNum}km (${radiusInMeters}m)`);

    // ✅ BUILD QUERY FILTER
    const geoQueryFilter = {
      status: 'available',
    };

    if (Object.keys(priceFilter).length > 0) {
      geoQueryFilter.price = priceFilter;
    }

    let nearbyRentals = [];
    let total = 0;
    let searchMethod = 'geospatial_from_location';

    try {
      // 🔥 CHECK: Ensure geospatial index exists
      const indexes = await Rental.collection.getIndexes();
      const hasGeoIndex = Object.keys(indexes).some(key =>
        indexes[key]['location.coordinates'] === '2dsphere'
      );

      if (!hasGeoIndex) {
        console.warn(`⚠️ [${requestId}] No 2dsphere index, creating...`);
        await Rental.collection.createIndex({ 'location.coordinates': '2dsphere' });
        console.log(`✅ [${requestId}] Geospatial index created`);
      }

      // 🔥 EXECUTE GEOSPATIAL QUERY
      console.log(`🚀 [${requestId}] Executing geospatial aggregation...`);

      nearbyRentals = await Rental.aggregate([
        {
          $geoNear: {
            near: { type: 'Point', coordinates: [lon, lat] },
            distanceField: 'distance',
            maxDistance: radiusInMeters,
            spherical: true,
            query: geoQueryFilter,
          },
        },
        ...(skip > 0 ? [{ $skip: skip }] : []),
        ...(limit ? [{ $limit: limit }] : []), 
        {
          $project: {
            title: 1,
            price: 1,
            location: 1,
            images: 1,
            videos: 1,
            propertyType: 1,
            createdAt: 1,
            distance: 1,
            coordinates: '$location.coordinates.coordinates',
            area: 1,
            furniture: 1,
            amenities: 1,
            surroundings: 1,
            rentalTerms: 1,
            contactInfo: 1,
            status: 1,
            userId: 1,
          },
        },
      ]).maxTimeMS(30000);

      console.log(`✅ [${requestId}] Query returned ${nearbyRentals.length} results`);

      // COUNT TOTAL
      total = await Rental.countDocuments({
        'location.coordinates': {
          $geoWithin: {
            $centerSphere: [[lon, lat], radiusInRadians],
          },
        },
        ...geoQueryFilter,
      }).maxTimeMS(10000);

      console.log(`✅ [${requestId}] Total count: ${total}`);

    } catch (geoError) {
      console.error(`❌ [${requestId}] Geospatial error:`, geoError.message);

      // ✅ FALLBACK: Simple query
      console.log(`⚠️ [${requestId}] Falling back to simple query...`);
      searchMethod = 'fallback_location_based';

      let fallbackQuery = Rental.find(geoQueryFilter)
      .sort({ createdAt: -1 })
      .skip(skip)
      .select('title price location images videos propertyType createdAt area furniture amenities surroundings rentalTerms contactInfo status userId')
      .lean()
      .maxTimeMS(10000);
    
      if (limit) fallbackQuery = fallbackQuery.limit(limit); // ✅ Chỉ limit khi có
      
      nearbyRentals = await fallbackQuery;

      total = await Rental.countDocuments(geoQueryFilter).maxTimeMS(5000);

      console.log(`✅ [${requestId}] Fallback returned ${nearbyRentals.length} results`);

      // Calculate approximate distance
      nearbyRentals = nearbyRentals.map(rental => {
        const [rentLon, rentLat] = rental.location?.coordinates?.coordinates || [0, 0];

        // Haversine formula
        const R = 6371;
        const dLat = (rentLat - lat) * Math.PI / 180;
        const dLon = (rentLon - lon) * Math.PI / 180;
        const a =
          Math.sin(dLat / 2) * Math.sin(dLat / 2) +
          Math.cos(lat * Math.PI / 180) * Math.cos(rentLat * Math.PI / 180) *
          Math.sin(dLon / 2) * Math.sin(dLon / 2);
        const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        const distance = R * c * 1000;

        return { ...rental, distance };
      });
    }

    // ✅ TRANSFORM RESULTS
    const transformedRentals = nearbyRentals.map(rental => ({
      ...rental,
      coordinates: rental.coordinates || rental.location?.coordinates?.coordinates || [0, 0],
      distance: rental.distance ? (rental.distance / 1000).toFixed(2) : null,
      distanceKm: rental.distance ? (rental.distance / 1000).toFixed(2) + 'km' : 'N/A'
    }));

    console.log(`✅ [${requestId}] Response: ${transformedRentals.length} rentals`);

    res.json({
      success: true,
      rentals: transformedRentals,
      total,
      page: Number(page),
      pages: Math.ceil(total / Number(limit)),
      hasMore: limit ? (Number(page) * limit) < total : false,
      searchMethod,
      centerCoordinates: { longitude: lon, latitude: lat },
      radiusKm: radiusNum,
      appliedFilters: {
        minPrice: priceFilter.$gte || null,
        maxPrice: priceFilter.$lte || null,
      }
    });

  } catch (err) {
    console.error(`❌ [${requestId}] CRITICAL Error:`, err);

    res.status(500).json({
      success: false,
      message: 'Failed to fetch rental details',
      error: err.message,
      hint: 'Check server logs for detailed error'
    });
  }
});

router.get('/rentals/nearby/:id', async (req, res) => {
  try {
    const { radius = 10, page = 1, minPrice, maxPrice } = req.query;
    const limit = req.query.limit ? parseInt(req.query.limit) : null; // ✅ null = lấy tất cả
    const skip = limit ? (Number(page) - 1) * limit : 0;

    // ✅ Set timeout headers
    req.setTimeout(60000); // 60 seconds
    res.setTimeout(60000);

    console.log(`🔍 Fetching nearby rentals for ID: ${req.params.id} (radius: ${radius}km)`);
    console.log(`💰 Price filter: min=${minPrice}, max=${maxPrice}`);

    if (!mongoose.Types.ObjectId.isValid(req.params.id)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid rental ID format'
      });
    }

    const rental = await Rental.findById(req.params.id)
      .select('location coordinates')
      .lean();

    if (!rental) {
      console.log(`❌ Rental with ID ${req.params.id} not found`);
      return res.status(404).json({
        success: false,
        message: 'Rental not found'
      });
    }

    // Extract coordinates
    let coordinates;
    if (rental.location?.coordinates?.coordinates &&
      Array.isArray(rental.location.coordinates.coordinates) &&
      rental.location.coordinates.coordinates.length === 2) {
      coordinates = rental.location.coordinates.coordinates;
    } else if (rental.coordinates && Array.isArray(rental.coordinates) && rental.coordinates.length === 2) {
      coordinates = rental.coordinates;
    } else {
      return res.status(400).json({
        success: false,
        message: 'Rental has invalid coordinate structure'
      });
    }

    const [longitude, latitude] = coordinates;

    if (typeof longitude !== 'number' || typeof latitude !== 'number' ||
      isNaN(longitude) || isNaN(latitude) ||
      Math.abs(longitude) > 180 || Math.abs(latitude) > 90) {
      return res.status(400).json({
        success: false,
        message: 'Rental has invalid coordinate values'
      });
    }

    // ============================================
    // BUILD PRICE FILTER - CẬP NHẬT
    // ============================================
    let priceFilter = {};
    if (minPrice !== undefined && minPrice !== null && minPrice !== '') {
      const minVal = Number(minPrice);
      if (!isNaN(minVal)) {
        priceFilter.$gte = minVal;
        console.log(`✅ Min price filter: >= ${minVal}`);
      }
    }
    if (maxPrice !== undefined && maxPrice !== null && maxPrice !== '') {
      const maxVal = Number(maxPrice);
      if (!isNaN(maxVal)) {
        priceFilter.$lte = maxVal;
        console.log(`✅ Max price filter: <= ${maxVal}`);
      }
    }

    // Handle [0, 0] coordinates - fallback to location-based search
    if (longitude === 0 && latitude === 0) {
      console.log('⚠️ Coordinates are [0, 0], using location-based fallback');

      const fullRental = await Rental.findById(req.params.id).select('location').lean();
      const locationParts = fullRental.location?.fullAddress?.split(',') || [];
      const wardInfo = locationParts.length > 1 ? locationParts[1].trim() : '';

      const query = {
        _id: { $ne: new mongoose.Types.ObjectId(req.params.id) },
        status: 'available',
        ...(wardInfo && { 'location.fullAddress': { $regex: wardInfo, $options: 'i' } }),
      };

      // 🔥 Thêm price filter vào query
      if (Object.keys(priceFilter).length > 0) {
        query.price = priceFilter;
        console.log(`✅ Applied price filter to fallback query:`, priceFilter);
      }

      let fallbackQuery = Rental.find(query)
      .select('title price location images videos propertyType createdAt area')
      .skip(skip)
      .lean();
    
      if (limit) fallbackQuery = fallbackQuery.limit(limit); // ✅
      
      const [nearbyRentals, total] = await Promise.all([
        fallbackQuery,
        Rental.countDocuments(query)
      ]);

      console.log(`✅ Fallback search: Found ${nearbyRentals.length} rentals (total: ${total})`);

      return res.json({
        success: true,
        rentals: nearbyRentals.map(rental => ({
          ...rental,
          distance: null,
          coordinates: rental.location?.coordinates?.coordinates || rental.coordinates || [0, 0]
        })),
        total,
        page: Number(page),
        pages: limit ? Math.ceil(total / limit) : 1,
        hasMore: limit ? (Number(page) * limit) < total : false,
        warning: 'Rental coordinates are invalid ([0, 0]). Showing rentals in the same area instead.',
        searchMethod: 'location_fallback'
      });
    }

    const radiusInMeters = parseFloat(radius) * 1000;
    const radiusInRadians = radiusInMeters / 6378100;

    console.log(`📍 Search center: [${longitude}, ${latitude}]`);
    console.log(`📏 Radius: ${radius}km (${radiusInMeters}m)`);

    // ============================================
    // 🔥 GEOSPATIAL QUERY - CẬP NHẬT với price filter
    // ============================================

    // Build query filter object
    const geoQueryFilter = {
      _id: { $ne: new mongoose.Types.ObjectId(req.params.id) },
      status: 'available',
    };

    // 🔥 Thêm price filter vào geo query
    if (Object.keys(priceFilter).length > 0) {
      geoQueryFilter.price = priceFilter;
    }

    const [nearbyRentals, total] = await Promise.all([
      Rental.aggregate([
        {
          $geoNear: {
            near: { type: 'Point', coordinates: [longitude, latitude] },
            distanceField: 'distance',
            maxDistance: radiusInMeters,
            spherical: true,
            query: geoQueryFilter, // 🔥 Áp dụng filter vào geoNear
          },
        },
        ...(skip > 0 ? [{ $skip: skip }] : []),
        ...(limit ? [{ $limit: limit }] : []),
        {
          $project: {
            title: 1,
            price: 1,
            location: 1,
            images: 1,
            videos: 1,
            propertyType: 1,
            createdAt: 1,
            distance: 1,
            coordinates: '$location.coordinates.coordinates',
            area: 1,
            furniture: 1,
            amenities: 1,
            surroundings: 1,
            rentalTerms: 1,
            contactInfo: 1,
            status: 1,
            userId: 1,
          },
        },
      ]),
      // 🔥 Count với price filter
      Rental.countDocuments({
        'location.coordinates': {
          $geoWithin: {
            $centerSphere: [[longitude, latitude], radiusInRadians],
          },
        },
        ...geoQueryFilter,
      })
    ]);

    console.log(`✅ Geospatial query: Found ${nearbyRentals.length} rentals (total: ${total})`);

    const transformedRentals = nearbyRentals.map(rental => ({
      ...rental,
      coordinates: rental.coordinates || rental.location?.coordinates?.coordinates || [0, 0],
      distance: rental.distance ? (rental.distance / 1000).toFixed(2) : null,
      distanceKm: rental.distance ? (rental.distance / 1000).toFixed(2) + 'km' : 'N/A'
    }));

    res.json({
      success: true,
      rentals: transformedRentals,
      total,
      page: Number(page),
      pages: Math.ceil(total / Number(limit)),
      hasMore: limit ? (Number(page) * limit) < total : false,
      searchMethod: 'geospatial',
      centerCoordinates: { longitude, latitude },
      radiusKm: parseFloat(radius),
      appliedFilters: {
        minPrice: Object.keys(priceFilter).includes('$gte') ? priceFilter.$gte : null,
        maxPrice: Object.keys(priceFilter).includes('$lte') ? priceFilter.$lte : null,
      }
    });

  } catch (err) {
    console.error('❌ Error fetching nearby rentals:', err);

    if (err.name === 'CastError') {
      return res.status(400).json({
        success: false,
        message: 'Invalid rental ID format',
        error: err.message
      });
    }

    if (err.message?.includes('timeout')) {
      return res.status(504).json({
        success: false,
        message: 'Request timeout. Please try again.',
        error: 'Gateway Timeout'
      });
    }

    res.status(500).json({
      success: false,
      message: 'Failed to fetch nearby rentals',
      error: err.message
    });
  }
});
// ==================== ADMIN HELPER ====================
router.post('/admin/ensure-geospatial-index', verifyAdmin, async (req, res) => {
  try {
    console.log('🔧 [ENSURE-INDEX] Starting...');

    // Drop old index if exists
    try {
      await Rental.collection.dropIndex('location.coordinates_2dsphere');
      console.log('⚠️ Dropped old index');
    } catch (e) {
      // Index doesn't exist
    }

    // Create new index
    await Rental.collection.createIndex({ 'location.coordinates': '2dsphere' });
    console.log('✅ Geospatial index created');

    // Verify
    const indexes = await Rental.collection.getIndexes();

    res.json({
      success: true,
      message: 'Geospatial index ensured',
      indexes: Object.keys(indexes),
    });

  } catch (err) {
    console.error('❌ Error ensuring index:', err);
    res.status(500).json({
      success: false,
      message: 'Failed to ensure geospatial index',
      error: err.message,
    });
  }
});

router.get('/rentals/:id', trackRentalView, async (req, res) => {
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

router.post('/track-interaction', authMiddleware, trackDetailedInteraction);

router.get('/user-analytics', authMiddleware, getUserAnalytics);

router.post('/rentals', authMiddleware, upload.array('media'), checkPaymentStatus, async (req, res) => {
  try {
    const contactInfoName = req.body.contactInfoName || req.user?.displayName || 'Chủ nhà';
    const contactInfoPhone = req.body.contactInfoPhone || req.user?.phoneNumber || 'Không có số điện thoại';

    // ... (giữ nguyên logic geocoding như cũ)
    let coordinates = [
      parseFloat(req.body.longitude) || 0,
      parseFloat(req.body.latitude) || 0,
    ];
    let formattedAddress = req.body.locationFullAddress;
    let geocodingStatus = 'pending';

    const { full: fullAddress } = normalizeVietnameseAddress(req.body.locationFullAddress);

    let addressComponents = null;
    const images = req.files?.filter(f => !f.mimetype.startsWith('video/')).map(f => f.path) || [];
    const videos = req.files?.filter(f => f.mimetype.startsWith('video/')).map(f => f.path) || [];

    // 🔥 GEOCODE CẢI TIẾN
    if (coordinates[0] === 0 && coordinates[1] === 0 ||
      isNaN(coordinates[0]) || isNaN(coordinates[1])) {
      try {
        console.log(`🔍 Geocoding address: ${fullAddress}`);
        const geocodeResult = await geocodeAddressFreeImproved(fullAddress);

        coordinates = [geocodeResult.longitude, geocodeResult.latitude];
        formattedAddress = geocodeResult.formattedAddress;
        geocodingStatus = geocodeResult.status;
        addressComponents = geocodeResult.addressComponents;

        console.log(`✅ Geocoded successfully`);
        console.log(`   Coordinates: [${coordinates[0]}, ${coordinates[1]}]`);
        console.log(`   Components: ${JSON.stringify(addressComponents)}`);
      } catch (geocodeError) {
        console.error('Geocoding failed:', geocodeError.message);

        return res.status(400).json({
          success: false,
          message: `Geocoding failed: ${geocodeError.message}`,
          hint: 'Please verify your address or use the map picker to set coordinates manually'
        });
      }
    } else {
      geocodingStatus = 'manual';

      // 🔥 Khi user nhập tọa độ thủ công, thử lấy địa chỉ chi tiết
      try {
        const response = await fetch(
          `https://nominatim.openstreetmap.org/reverse?` +
          `format=json&lat=${coordinates[1]}&lon=${coordinates[0]}&` +
          `zoom=18&addressdetails=1&accept-language=vi`,
          {
            headers: { 'User-Agent': 'RentalHouseApp/1.0' },
            timeout: 10000,
          }
        );
        if (response.ok) {
          const data = await response.json();
          addressComponents = extractAddressComponents(data);
        }
      } catch (e) {
        console.warn('Could not get reverse geocoding:', e.message);
      }
    }

    // ✅ Tạo rental object
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

      // 🔥 LƯU THÔNG TIN ĐỊA CHỈ CHI TIẾT
      addressComponents: addressComponents || {},

      paymentInfo: {
        transactionCode: req.paymentTransactionCode,
        paymentId: req.payment._id,
        amount: req.payment.amount,
        status: 'completed',
        paidAt: req.payment.completedAt,
      },
      publishedAt: new Date(),
    });

    const newRental = await rental.save();

    await Payment.updateOne(
      { _id: req.payment._id },
      { rentalId: newRental._id }
    );

    console.log(`✅ Rental created successfully: ${newRental._id}`);
    console.log(`   Geocoding Status: ${geocodingStatus}`);
    console.log(`   Coordinates: [${coordinates[0]}, ${coordinates[1]}]`);

    await syncRentalToElasticsearch(newRental);

    res.status(201).json({
      success: true,
      message: 'Bài đăng tạo thành công',
      rental: newRental,
      geocodingInfo: {
        status: geocodingStatus,
        coordinates: coordinates,
        addressComponents: addressComponents,
      },
    });


  } catch (err) {
    console.error('❌ Error creating rental:', err);
    if (err instanceof multer.MulterError) {
      return res.status(400).json({ message: `File upload error: ${err.message}` });
    }
    res.status(400).json({
      success: false,
      message: 'Failed to create rental',
      error: err.message
    });
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
      return res.status(403).json({
        success: false,
        message: 'Unauthorized: You do not own this rental'
      });
    }

    // ✨ THÊM: Không cho edit nếu chưa thanh toán 
    if (rental.paymentInfo?.status !== 'completed') {
      return res.status(402).json({
        success: false,
        message: 'Bài đăng chưa được xuất bản (chưa thanh toán)',
        paymentStatus: rental.paymentInfo?.status || 'pending',
      });
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


router.get('/rentals/:id/payment-status', authMiddleware, async (req, res) => {
  try {
    const rental = await Rental.findById(req.params.id);

    if (!rental) {
      return res.status(404).json({
        success: false,
        message: 'Bài đăng không tìm thấy',
      });
    }

    if (rental.userId !== req.userId) {
      return res.status(403).json({
        success: false,
        message: 'Bạn không có quyền xem thông tin này',
      });
    }

    const payment = rental.paymentInfo?.paymentId
      ? await Payment.findById(rental.paymentInfo.paymentId)
      : null;

    res.json({
      success: true,
      rental: {
        id: rental._id,
        title: rental.title,
        paymentStatus: rental.getPaymentStatus(),
        publishedAt: rental.publishedAt,
      },
      payment: payment ? payment.getStatusInfo() : null,
    });
  } catch (err) {
    console.error('Error checking payment status:', err);
    res.status(500).json({
      success: false,
      message: 'Lỗi kiểm tra trạng thái thanh toán',
      error: err.message,
    });
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

    // ===
    if (rental.paymentInfo?.paymentId) {
      await Payment.findByIdAndDelete(rental.paymentInfo.paymentId);
      console.log(`✅ Deleted payment record for rental ${req.params.id}`);
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

// Theo dõi hành động  ===============================================================================================
router.post('/rentals/:id/contact', authMiddleware, trackAction('contact'), async (req, res) => {
  try {
    // Xử lý logic contact (gửi email, sms, etc.)
    res.json({
      success: true,
      message: 'Contact request sent successfully'
    });
  } catch (err) {
    res.status(500).json({
      success: false,
      message: 'Failed to send contact request',
      error: err.message
    });
  }
});
router.post('/rentals/:id/share', authMiddleware, trackAction('share'), async (req, res) => {
  try {
    res.json({
      success: true,
      message: 'Share tracked successfully'
    });
  } catch (err) {
    res.status(500).json({
      success: false,
      message: 'Failed to track share',
      error: err.message
    });
  }
});
router.get('/rentals/trending/now', async (req, res) => {
  try {
    const UserInteraction = require('../models/UserInteraction');
    const limit = parseInt(req.query.limit) || 10;

    // Get trending rental IDs
    const trending = await UserInteraction.getTrendingRentals(limit);

    if (trending.length === 0) {
      return res.json({
        success: true,
        rentals: [],
        message: 'No trending data yet'
      });
    }

    // Get full rental data
    const rentalIds = trending.map(t => t._id);
    const rentals = await Rental.find({ _id: { $in: rentalIds }, status: 'available' })
      .lean();

    // Merge with scores
    const rentalsWithScore = rentals.map(rental => {
      const trendData = trending.find(t => t._id.toString() === rental._id.toString());
      return {
        ...rental,
        trendingScore: trendData?.totalScore || 0,
        viewCount: trendData?.viewCount || 0,
        favoriteCount: trendData?.favoriteCount || 0,
        contactCount: trendData?.contactCount || 0
      };
    });

    // Sort by score
    rentalsWithScore.sort((a, b) => b.trendingScore - a.trendingScore);

    res.json({
      success: true,
      rentals: rentalsWithScore,
      count: rentalsWithScore.length
    });
  } catch (err) {
    console.error('Error getting trending rentals:', err);
    res.status(500).json({
      success: false,
      message: 'Failed to get trending rentals',
      error: err.message
    });
  }
});
router.get('/rentals/:id/stats', async (req, res) => {
  try {
    const UserInteraction = require('../models/UserInteraction');
    const rentalId = req.params.id;

    if (!mongoose.Types.ObjectId.isValid(rentalId)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid rental ID'
      });
    }

    const stats = await UserInteraction.getRentalPopularity(rentalId);

    res.json({
      success: true,
      rentalId,
      stats
    });
  } catch (err) {
    console.error('Error getting rental stats:', err);
    res.status(500).json({
      success: false,
      message: 'Failed to get rental stats',
      error: err.message
    });
  }
});
router.get('/admin/export-interactions', verifyAdmin, async (req, res) => {
  try {
    const UserInteraction = require('../models/UserInteraction');
    const limit = parseInt(req.query.limit) || 10000;
    const skip = parseInt(req.query.skip) || 0;

    const interactions = await UserInteraction.find()
      .sort({ timestamp: -1 })
      .skip(skip)
      .limit(limit)
      .lean();

    res.json({
      success: true,
      count: interactions.length,
      data: interactions
    });
  } catch (err) {
    console.error('Error exporting interactions:', err);
    res.status(500).json({
      success: false,
      message: 'Failed to export interactions',
      error: err.message
    });
  }
});
// ==================================================================================================

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

// =================================================================
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

// Thêm vào file routes/rentals.js

// ========== ADMIN DASHBOARD STATISTICS ========================================
router.get('/admin/dashboard', verifyAdmin, async (req, res) => {
  try {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);

    console.log('📊 [DASHBOARD] Fetching stats...');
    console.log('📅 Today:', today.toISOString());
    console.log('📅 Tomorrow:', tomorrow.toISOString());

    // Thực hiện các query song song
    const [
      totalPosts,
      postsToday,
      newUsers,
      totalNews,
      revenueToday,
      totalRevenue,
      feedbackToday
    ] = await Promise.all([
      // Tổng số bài đăng
      Rental.countDocuments(),

      // Bài đăng hôm nay
      Rental.countDocuments({
        createdAt: { $gte: today, $lt: tomorrow }
      }),

      // Người đăng ký mới hôm nay
      User.countDocuments({
        createdAt: { $gte: today, $lt: tomorrow }
      }),

      // Tổng tin tức
      require('../models/news').countDocuments(),

      // Doanh thu hôm nay
      Payment.aggregate([
        {
          $match: {
            status: 'completed',
            completedAt: { $gte: today, $lt: tomorrow }
          }
        },
        {
          $group: {
            _id: null,
            total: { $sum: '$amount' }
          }
        }
      ]).then(result => result.length > 0 ? result[0].total : 0),

      // Tổng doanh thu
      Payment.aggregate([
        {
          $match: {
            status: 'completed'
          }
        },
        {
          $group: {
            _id: null,
            total: { $sum: '$amount' }
          }
        }
      ]).then(result => result.length > 0 ? result[0].total : 0),

      // 🔥 FIX: Feedback hôm nay - PHẢI DÙNG MODEL FEEDBACK
      Feedback.countDocuments({
        createdAt: { $gte: today, $lt: tomorrow }
      })
    ]);

    console.log('✅ [DASHBOARD] Stats fetched:');
    console.log('   Total Posts:', totalPosts);
    console.log('   Posts Today:', postsToday);
    console.log('   New Users:', newUsers);
    console.log('   Total News:', totalNews);
    console.log('   Revenue Today:', revenueToday);
    console.log('   Total Revenue:', totalRevenue);
    console.log('   🔥 Feedback Today:', feedbackToday); // ← QUAN TRỌNG

    res.json({
      totalPosts,
      postsToday,
      newUsers,
      totalNews,
      revenueToday,
      totalRevenue,
      feedbackToday, // ← QUAN TRỌNG
      lastUpdated: new Date().toISOString()
    });

  } catch (err) {
    console.error('❌ [DASHBOARD] Error:', err);
    res.status(500).json({
      message: 'Failed to fetch dashboard statistics',
      error: err.message
    });
  }
});


// ========== ADMIN DASHBOARD CHARTS DATA ========================================

// Doanh thu theo ngày (7 ngày gần nhất)
router.get('/admin/dashboard/revenue-chart', verifyAdmin, async (req, res) => {
  try {
    const days = parseInt(req.query.days) || 7;
    const startDate = new Date();
    startDate.setDate(startDate.getDate() - days);
    startDate.setHours(0, 0, 0, 0);

    const revenueData = await Payment.aggregate([
      {
        $match: {
          status: 'completed',
          completedAt: { $gte: startDate }
        }
      },
      {
        $group: {
          _id: {
            $dateToString: { format: '%Y-%m-%d', date: '$completedAt' }
          },
          total: { $sum: '$amount' },
          count: { $sum: 1 }
        }
      },
      {
        $sort: { _id: 1 }
      }
    ]);

    res.json(revenueData);
  } catch (err) {
    console.error('Error fetching revenue chart:', err);
    res.status(500).json({
      message: 'Failed to fetch revenue chart',
      error: err.message
    });
  }
});

// Thống kê bài đăng theo loại nhà
router.get('/admin/dashboard/property-types', verifyAdmin, async (req, res) => {
  try {
    const propertyTypes = await Rental.aggregate([
      {
        $group: {
          _id: '$propertyType',
          count: { $sum: 1 },
          avgPrice: { $avg: '$price' }
        }
      },
      {
        $sort: { count: -1 }
      }
    ]);

    res.json(propertyTypes);
  } catch (err) {
    console.error('Error fetching property types:', err);
    res.status(500).json({
      message: 'Failed to fetch property types',
      error: err.message
    });
  }
});

// Thống kê người dùng mới theo tháng
router.get('/admin/dashboard/user-growth', verifyAdmin, async (req, res) => {
  try {
    const months = parseInt(req.query.months) || 6;
    const startDate = new Date();
    startDate.setMonth(startDate.getMonth() - months);
    startDate.setDate(1);
    startDate.setHours(0, 0, 0, 0);

    const userGrowth = await User.aggregate([
      {
        $match: {
          createdAt: { $gte: startDate }
        }
      },
      {
        $group: {
          _id: {
            $dateToString: { format: '%Y-%m', date: '$createdAt' }
          },
          count: { $sum: 1 }
        }
      },
      {
        $sort: { _id: 1 }
      }
    ]);

    res.json(userGrowth);
  } catch (err) {
    console.error('Error fetching user growth:', err);
    res.status(500).json({
      message: 'Failed to fetch user growth',
      error: err.message
    });
  }
});

// Top 5 bài đăng có nhiều lượt xem nhất
router.get('/admin/dashboard/top-posts', verifyAdmin, async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 5;

    const topPosts = await Rental.find()
      .select('title price location views images createdAt')
      .sort({ views: -1 })
      .limit(limit)
      .lean();

    res.json(topPosts);
  } catch (err) {
    console.error('Error fetching top posts:', err);
    res.status(500).json({
      message: 'Failed to fetch top posts',
      error: err.message
    });
  }
});

module.exports = router;