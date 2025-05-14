require('dotenv').config();

const express = require('express');
const router = express.Router();
const Rental = require('../models/Rental');
const Favorite = require('../models/favorite'); // Import the Favorite model
const Comment = require('../models/comments'); // Import the Comment model
const admin = require('firebase-admin');
const multer = require('multer');
const path = require('path');

// Cấu hình multer để upload ảnh
const storage = multer.diskStorage({
  destination: './uploads/',
  filename: (req, file, cb) => {
    cb(null, `${Date.now()}-${file.originalname}`);
  },
});
const upload = multer({ storage });

// Middleware xác thực Firebase token
const authMiddleware = async (req, res, next) => {
  const token = req.header('Authorization')?.replace('Bearer ', '');
  if (!token) {
    return res.status(401).json({ message: 'No token provided' });
  }
  try {
    const decodedToken = await admin.auth().verifyIdToken(token);
    req.userId = decodedToken.uid;
    next();
  } catch (err) {
    res.status(401).json({ message: 'Invalid token' });
  }
};

// Route để lấy danh sách tất cả các rental hoặc tìm kiếm theo query
router.get('/rentals', async (req, res) => {
  try {
    const { search, minPrice, maxPrice, propertyType, status } = req.query;
    let query = {};

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

    if (propertyType) {
      query.propertyType = propertyType;
    }

    if (status) {
      query.status = status;
    }

    const rentals = await Rental.find(query);
    res.json(rentals);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// Route để lấy thông tin chi tiết của một rental theo ID ----------------------------------------------
router.get('/rentals/:id', async (req, res) => {
  try {
    const rental = await Rental.findById(req.params.id);
    if (!rental) {
      return res.status(404).json({ message: 'Rental not found' });
    }
    // Fetch comments for this rental
    const comments = await Comment.find({ rentalId: req.params.id })
      .populate('userId', 'avatarBase64 username')
      .populate('replies.userId', 'username')
      .populate('likes.userId', 'username');
    res.json({ ...rental.toObject(), comments });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});
//  -----------------------------------------------------------------------------------------
// Route để tạo mới một rental
router.post('/rentals', authMiddleware, upload.array('images'), async (req, res) => {
  try {
    const imageUrls = req.files.map(file => `/uploads/${file.filename}`);

    // Use authenticated user's details as default for contactInfo
    const contactInfoName = req.body.contactInfoName || req.user.displayName || 'Chủ nhà';
    const contactInfoPhone = req.body.contactInfoPhone || req.user.phoneNumber || 'Không có số điện thoại';

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
        fullAddress: req.body.locationFullAddress,
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
      images: imageUrls,
      status: req.body.status || 'available',
    });
    const newRental = await rental.save();
    res.status(201).json(newRental);
  } catch (err) {
    res.status(400).json({ message: err.message });
  }
});

// Route để cập nhật thông tin bài đăng
router.put('/rentals/:id', authMiddleware, upload.array('images'), async (req, res) => {
  try {
    const rental = await Rental.findById(req.params.id);
    if (!rental) {
      return res.status(404).json({ message: 'Rental not found' });
    }

    if (rental.userId !== req.userId) {
      return res.status(403).json({ message: 'You are not authorized to update this rental' });
    }

    const updatedData = {};
    if (req.body.title) updatedData.title = req.body.title;
    if (req.body.price) updatedData.price = req.body.price;
    if (req.body.areaTotal || req.body.areaLivingRoom || req.body.areaBedrooms || req.body.areaBathrooms) {
      updatedData.area = {
        total: req.body.areaTotal || rental.area.total,
        livingRoom: req.body.areaLivingRoom || rental.area.livingRoom,
        bedrooms: req.body.areaBedrooms || rental.area.bedrooms,
        bathrooms: req.body.areaBathrooms || rental.area.bathrooms,
      };
    }
    if (req.body.locationShort || req.body.locationFullAddress) {
      updatedData.location = {
        short: req.body.locationShort || rental.location.short,
        fullAddress: req.body.locationFullAddress || rental.location.fullAddress,
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
    if (req.files.length > 0) updatedData.images = req.files.map(file => `/uploads/${file.filename}`);
    if (req.body.status) updatedData.status = req.body.status;

    const updatedRental = await Rental.findByIdAndUpdate(req.params.id, updatedData, { new: true });
    res.json(updatedRental);
  } catch (err) {
    res.status(400).json({ message: err.message });
  }
});

// Route để xóa một bài đăng
router.delete('/rentals/:id', authMiddleware, async (req, res) => {
  try {
    const rental = await Rental.findById(req.params.id);
    if (!rental) {
      return res.status(404).json({ message: 'Rental not found' });
    }

    if (rental.userId !== req.userId) {
      return res.status(403).json({ message: 'You are not authorized to delete this rental' });
    }

    await Rental.findByIdAndDelete(req.params.id);
    res.json({ message: 'Rental deleted successfully' });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// Route để thêm bài đăng vào danh sách yêu thích
router.post('/favorites', authMiddleware, async (req, res) => {
  try {
    const { rentalId } = req.body;

    const rental = await Rental.findById(rentalId);
    if (!rental) {
      return res.status(404).json({ message: 'Rental not found' });
    }

    const existingFavorite = await Favorite.findOne({ userId: req.userId, rentalId });
    if (existingFavorite) {
      return res.status(400).json({ message: 'Rental already in favorites' });
    }

    const favorite = new Favorite({
      userId: req.userId,
      rentalId,
    });
    await favorite.save();

    res.status(201).json({ message: 'Added to favorites', favorite });
  } catch (err) {
    res.status(400).json({ message: err.message });
  }
});

// Route để xóa bài đăng khỏi danh sách yêu thích
router.delete('/favorites/:rentalId', authMiddleware, async (req, res) => {
  try {
    const rentalId = req.params.rentalId;

    const rental = await Rental.findById(rentalId);
    if (!rental) {
      return res.status(404).json({ message: 'Rental not found' });
    }

    const result = await Favorite.findOneAndDelete({ userId: req.userId, rentalId });
    if (!result) {
      return res.status(404).json({ message: 'Favorite not found' });
    }

    res.json({ message: 'Removed from favorites' });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// Route để lấy danh sách yêu thích của người dùng
router.get('/favorites', authMiddleware, async (req, res) => {
  try {
    const favorites = await Favorite.find({ userId: req.userId }).populate('rentalId');
    res.json(favorites);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// -------------------------------------------------------------------------------------------------------------------
// Route để lấy danh sách bình luận của một bài đăng
router.get('/comments/:rentalId', async (req, res) => {
  try {
    const { rentalId } = req.params;
    const comments = await Comment.find({ rentalId })
      .populate('userId', 'avatarBase64 username')
      .populate('replies.userId', 'username')
      .populate('likes.userId', 'username');
    res.json(comments);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// Route để thêm bình luận vào bài đăng
router.post('/comments', authMiddleware, async (req, res) => {
  try {
    const { rentalId, content } = req.body;
    if (!rentalId || !content) {
      return res.status(400).json({ message: 'Missing required fields' });
    }

    const rental = await Rental.findById(rentalId);
    if (!rental) {
      return res.status(404).json({ message: 'Rental not found' });
    }

    const comment = new Comment({
      rentalId,
      userId: req.userId,
      content,
    });
    await comment.save();

    res.status(201).json(comment);
  } catch (err) {
    res.status(400).json({ message: err.message });
  }
});

// Route để thêm phản hồi (reply) cho bình luận
router.post('/comments/:commentId/replies', authMiddleware, async (req, res) => {
  try {
    const { commentId } = req.params;
    const { content } = req.body;
    if (!content) {
      return res.status(400).json({ message: 'Missing content' });
    }

    const comment = await Comment.findById(commentId);
    if (!comment) {
      return res.status(404).json({ message: 'Comment not found' });
    }

    comment.replies.push({ userId: req.userId, content });
    await comment.save();

    res.status(201).json(comment);
  } catch (err) {
    res.status(400).json({ message: err.message });
  }
});


// Route để like một bình luận
router.post('/comments/:commentId/like', authMiddleware, async (req, res) => {
  try {
    const { commentId } = req.params;
    const comment = await Comment.findById(commentId);
    if (!comment) {
      return res.status(404).json({ message: 'Comment not found' });
    }

    const existingLike = comment.likes.find(like => like.userId.toString() === req.userId);
    if (existingLike) {
      return res.status(400).json({ message: 'Already liked' });
    }

    comment.likes.push({ userId: req.userId });
    await comment.save();

    res.status(200).json({ message: 'Liked', likesCount: comment.likes.length });
  } catch (err) {
    res.status(400).json({ message: err.message });
  }
});

// Route để unlike một bình luận
router.delete('/comments/:commentId/unlike', authMiddleware, async (req, res) => {
  try {
    const { commentId } = req.params;
    const comment = await Comment.findById(commentId);
    if (!comment) {
      return res.status(404).json({ message: 'Comment not found' });
    }

    comment.likes = comment.likes.filter(like => like.userId.toString() !== req.userId);
    await comment.save();

    res.status(200).json({ message: 'Unliked', likesCount: comment.likes.length });
  } catch (err) {
    res.status(400).json({ message: err.message });
  }
});


module.exports = router;