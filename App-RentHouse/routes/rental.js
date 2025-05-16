require('dotenv').config();

const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const Rental = require('../models/Rental');
const Favorite = require('../models/favorite');
const Comment = require('../models/comments');
const admin = require('firebase-admin');
const multer = require('multer');
const path = require('path');

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

router.get('/rentals/:id', async (req, res) => {
  try {
    const rental = await Rental.findById(req.params.id);
    if (!rental) return res.status(404).json({ message: 'Rental not found' });
    const comments = await Comment.find({ rentalId: req.params.id })
      .populate('userId', 'avatarBase64 username')
      .populate('replies.userId', 'username')
      .populate('likes.userId', 'username')
      .populate('replies.likes.userId', 'username'); // Added population for reply likes
    const adjustedComments = comments.map(comment => {
      const commentObj = comment.toObject();
      commentObj.createdAt = new Date(comment.createdAt.getTime() + 7 * 60 * 60 * 1000);
      commentObj.replies = commentObj.replies.map(reply => ({
        ...reply,
        createdAt: new Date(reply.createdAt.getTime() + 7 * 60 * 60 * 1000),
        likes: reply.likes.map(like => ({
          ...like,
          createdAt: new Date(like.createdAt.getTime() + 7 * 60 * 60 * 1000)
        }))
      }));
      commentObj.likes = commentObj.likes.map(like => ({ ...like, createdAt: new Date(like.createdAt.getTime() + 7 * 60 * 60 * 1000) }));
      return commentObj;
    });
    const totalRatings = adjustedComments.reduce((sum, comment) => sum + (comment.rating || 0), 0);
    const averageRating = adjustedComments.length > 0 ? totalRatings / adjustedComments.length : 0;
    res.json({ ...rental.toObject(), comments: adjustedComments, averageRating, reviewCount: adjustedComments.length });
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

router.post('/favorites', authMiddleware, async (req, res) => {
  try {
    const { rentalId } = req.body;
    const rental = await Rental.findById(rentalId);
    if (!rental) return res.status(404).json({ message: 'Rental not found' });
    const existingFavorite = await Favorite.findOne({ userId: req.userId, rentalId });
    if (existingFavorite) return res.status(400).json({ message: 'Rental already in favorites' });
    const favorite = new Favorite({ userId: req.userId, rentalId });
    await favorite.save();
    res.status(201).json({ message: 'Added to favorites', favorite });
  } catch (err) {
    res.status(400).json({ message: err.message });
  }
});

router.delete('/favorites/:rentalId', authMiddleware, async (req, res) => {
  try {
    const rentalId = req.params.rentalId;
    const rental = await Rental.findById(rentalId);
    if (!rental) return res.status(404).json({ message: 'Rental not found' });
    const result = await Favorite.findOneAndDelete({ userId: req.userId, rentalId });
    if (!result) return res.status(404).json({ message: 'Favorite not found' });
    res.json({ message: 'Removed from favorites' });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

router.get('/favorites', authMiddleware, async (req, res) => {
  try {
    const favorites = await Favorite.find({ userId: req.userId }).populate('rentalId');
    res.json(favorites);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

router.get('/comments/:rentalId', async (req, res) => {
  try {
    const { rentalId } = req.params;
    if (!mongoose.Types.ObjectId.isValid(rentalId)) return res.status(400).json({ message: 'Invalid rentalId format' });
    const comments = await Comment.find({ rentalId })
      .populate('userId', 'avatarBase64 username')
      .populate('replies.userId', 'username')
      .populate('likes.userId', 'username')
      .populate('replies.likes.userId', 'username');
    const adjustedComments = comments.map(comment => {
      const commentObj = comment.toObject();
      commentObj.createdAt = new Date(comment.createdAt.getTime() + 7 * 60 * 60 * 1000);
      commentObj.replies = commentObj.replies.map(reply => ({
        ...reply,
        createdAt: new Date(reply.createdAt.getTime() + 7 * 60 * 60 * 1000),
        likes: reply.likes.map(like => ({
          ...like,
          createdAt: new Date(like.createdAt.getTime() + 7 * 60 * 60 * 1000)
        }))
      }));
      commentObj.likes = commentObj.likes.map(like => ({ ...like, createdAt: new Date(like.createdAt.getTime() + 7 * 60 * 60 * 1000) }));
      return commentObj;
    });
    res.json(adjustedComments);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

router.post('/comments', authMiddleware, upload.array('images'), async (req, res) => {
  try {
    const { rentalId, content, rating } = req.body;
    if (!rentalId || !content) return res.status(400).json({ message: 'Missing required fields' });
    if (!mongoose.Types.ObjectId.isValid(rentalId)) return res.status(400).json({ message: 'Invalid rentalId format' });
    const rental = await Rental.findById(rentalId);
    if (!rental) return res.status(404).json({ message: 'Rental not found' });
    const imageUrls = req.files.map(file => `/uploads/${file.filename}`);
    const comment = new Comment({
      rentalId: new mongoose.Types.ObjectId(rentalId),
      userId: req.userId,
      content,
      rating: rating ? Number(rating) : 0,
      images: imageUrls,
    });
    const savedComment = await comment.save();
    const populatedComment = await Comment.findById(savedComment._id)
      .populate('userId', 'avatarBase64 username')
      .populate('replies.userId', 'username')
      .populate('likes.userId', 'username')
      .populate('replies.likes.userId', 'username');
    const adjustedComment = {
      ...populatedComment.toObject(),
      createdAt: new Date(populatedComment.createdAt.getTime() + 7 * 60 * 60 * 1000),
      replies: populatedComment.replies.map(reply => ({
        ...reply.toObject(),
        createdAt: new Date(reply.createdAt.getTime() + 7 * 60 * 60 * 1000),
        likes: reply.likes.map(like => ({
          ...like,
          createdAt: new Date(like.createdAt.getTime() + 7 * 60 * 60 * 1000)
        }))
      })),
      likes: populatedComment.likes.map(like => ({ ...like.toObject(), createdAt: new Date(like.createdAt.getTime() + 7 * 60 * 60 * 1000) })),
    };
    res.status(201).json(adjustedComment);
  } catch (err) {
    res.status(400).json({ message: err.message });
  }
});

router.put('/comments/:commentId', authMiddleware, async (req, res) => {
  try {
    const { commentId } = req.params;
    const { content } = req.body;
    if (!mongoose.Types.ObjectId.isValid(commentId) || !content) return res.status(400).json({ message: 'Invalid format or missing content' });
    const comment = await Comment.findById(commentId);
    if (!comment || comment.userId !== req.userId) return res.status(403).json({ message: 'Unauthorized or not found' });
    comment.content = content;
    const updatedComment = await comment.save();
    const populatedComment = await Comment.findById(commentId)
      .populate('userId', 'avatarBase64 username')
      .populate('replies.userId', 'username')
      .populate('likes.userId', 'username')
      .populate('replies.likes.userId', 'username');
    const adjustedComment = {
      ...populatedComment.toObject(),
      createdAt: new Date(populatedComment.createdAt.getTime() + 7 * 60 * 60 * 1000),
      replies: populatedComment.replies.map(reply => ({
        ...reply.toObject(),
        createdAt: new Date(reply.createdAt.getTime() + 7 * 60 * 60 * 1000),
        likes: reply.likes.map(like => ({
          ...like,
          createdAt: new Date(like.createdAt.getTime() + 7 * 60 * 60 * 1000)
        }))
      })),
      likes: populatedComment.likes.map(like => ({ ...like.toObject(), createdAt: new Date(like.createdAt.getTime() + 7 * 60 * 60 * 1000) })),
    };
    res.status(200).json(adjustedComment);
  } catch (err) {
    res.status(400).json({ message: err.message });
  }
});

router.delete('/comments/:commentId', authMiddleware, async (req, res) => {
  try {
    const { commentId } = req.params;
    if (!mongoose.Types.ObjectId.isValid(commentId)) return res.status(400).json({ message: 'Invalid commentId format' });
    const comment = await Comment.findById(commentId);
    if (!comment || comment.userId !== req.userId) return res.status(403).json({ message: 'Unauthorized or not found' });
    await Comment.findByIdAndDelete(commentId);
    res.json({ message: 'Comment deleted successfully' });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

router.post('/comments/:commentId/replies', authMiddleware, async (req, res) => {
  try {
    const { commentId } = req.params;
    const { content } = req.body;
    if (!content || !mongoose.Types.ObjectId.isValid(commentId)) return res.status(400).json({ message: 'Missing content or invalid format' });
    const comment = await Comment.findById(commentId);
    if (!comment) return res.status(404).json({ message: 'Comment not found' });
    comment.replies.push({ userId: req.userId, content });
    const savedComment = await comment.save();
    const populatedComment = await Comment.findById(commentId)
      .populate('userId', 'avatarBase64 username')
      .populate('replies.userId', 'username')
      .populate('likes.userId', 'username')
      .populate('replies.likes.userId', 'username');
    const adjustedComment = {
      ...populatedComment.toObject(),
      createdAt: new Date(populatedComment.createdAt.getTime() + 7 * 60 * 60 * 1000),
      replies: populatedComment.replies.map(reply => ({
        ...reply.toObject(),
        createdAt: new Date(reply.createdAt.getTime() + 7 * 60 * 60 * 1000),
        likes: reply.likes.map(like => ({
          ...like,
          createdAt: new Date(like.createdAt.getTime() + 7 * 60 * 60 * 1000)
        }))
      })),
      likes: populatedComment.likes.map(like => ({ ...like.toObject(), createdAt: new Date(like.createdAt.getTime() + 7 * 60 * 60 * 1000) })),
    };
    res.status(201).json(adjustedComment);
  } catch (err) {
    res.status(400).json({ message: err.message });
  }
});

router.put('/comments/:commentId/replies/:replyId', authMiddleware, async (req, res) => {
  try {
    const { commentId, replyId } = req.params;
    const { content } = req.body;
    if (!mongoose.Types.ObjectId.isValid(commentId) || !mongoose.Types.ObjectId.isValid(replyId) || !content) return res.status(400).json({ message: 'Invalid format or missing content' });
    const comment = await Comment.findById(commentId);
    if (!comment) return res.status(404).json({ message: 'Comment not found' });
    const reply = comment.replies.id(replyId);
    if (!reply || reply.userId !== req.userId) return res.status(403).json({ message: 'Unauthorized or reply not found' });
    reply.content = content;
    const updatedComment = await comment.save();
    const populatedComment = await Comment.findById(commentId)
      .populate('userId', 'avatarBase64 username')
      .populate('replies.userId', 'username')
      .populate('likes.userId', 'username')
      .populate('replies.likes.userId', 'username');
    const adjustedComment = {
      ...populatedComment.toObject(),
      createdAt: new Date(populatedComment.createdAt.getTime() + 7 * 60 * 60 * 1000),
      replies: populatedComment.replies.map(reply => ({
        ...reply.toObject(),
        createdAt: new Date(reply.createdAt.getTime() + 7 * 60 * 60 * 1000),
        likes: reply.likes.map(like => ({
          ...like,
          createdAt: new Date(like.createdAt.getTime() + 7 * 60 * 60 * 1000)
        }))
      })),
      likes: populatedComment.likes.map(like => ({ ...like.toObject(), createdAt: new Date(like.createdAt.getTime() + 7 * 60 * 60 * 1000) })),
    };
    res.status(200).json(adjustedComment);
  } catch (err) {
    res.status(400).json({ message: err.message });
  }
});

router.delete('/comments/:commentId/replies/:replyId', authMiddleware, async (req, res) => {
  try {
    const { commentId, replyId } = req.params;
    if (!mongoose.Types.ObjectId.isValid(commentId) || !mongoose.Types.ObjectId.isValid(replyId)) return res.status(400).json({ message: 'Invalid format' });
    const comment = await Comment.findById(commentId);
    if (!comment) return res.status(404).json({ message: 'Comment not found' });
    const reply = comment.replies.id(replyId);
    if (!reply || reply.userId !== req.userId) return res.status(403).json({ message: 'Unauthorized or reply not found' });
    comment.replies = comment.replies.filter(r => r._id.toString() !== replyId);
    const updatedComment = await comment.save();
    const populatedComment = await Comment.findById(commentId)
      .populate('userId', 'avatarBase64 username')
      .populate('replies.userId', 'username')
      .populate('likes.userId', 'username')
      .populate('replies.likes.userId', 'username');
    const adjustedComment = {
      ...populatedComment.toObject(),
      createdAt: new Date(populatedComment.createdAt.getTime() + 7 * 60 * 60 * 1000),
      replies: populatedComment.replies.map(reply => ({
        ...reply.toObject(),
        createdAt: new Date(reply.createdAt.getTime() + 7 * 60 * 60 * 1000),
        likes: reply.likes.map(like => ({
          ...like,
          createdAt: new Date(like.createdAt.getTime() + 7 * 60 * 60 * 1000)
        }))
      })),
      likes: populatedComment.likes.map(like => ({ ...like.toObject(), createdAt: new Date(like.createdAt.getTime() + 7 * 60 * 60 * 1000) })),
    };
    res.status(200).json({ message: 'Reply deleted successfully', comment: adjustedComment });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

router.post('/comments/:commentId/like', authMiddleware, async (req, res) => {
  try {
    const { commentId } = req.params;
    if (!mongoose.Types.ObjectId.isValid(commentId)) return res.status(400).json({ message: 'Invalid commentId format' });
    const comment = await Comment.findById(commentId);
    if (!comment) return res.status(404).json({ message: 'Comment not found' });
    const existingLike = comment.likes.find(like => like.userId === req.userId);
    if (existingLike) {
      comment.likes = comment.likes.filter(like => like.userId !== req.userId);
      await comment.save();
      const populatedComment = await Comment.findById(commentId)
        .populate('userId', 'avatarBase64 username')
        .populate('replies.userId', 'username')
        .populate('likes.userId', 'username')
        .populate('replies.likes.userId', 'username');
      const adjustedComment = {
        ...populatedComment.toObject(),
        createdAt: new Date(populatedComment.createdAt.getTime() + 7 * 60 * 60 * 1000),
        replies: populatedComment.replies.map(reply => ({
          ...reply.toObject(),
          createdAt: new Date(reply.createdAt.getTime() + 7 * 60 * 60 * 1000),
          likes: reply.likes.map(like => ({
            ...like,
            createdAt: new Date(like.createdAt.getTime() + 7 * 60 * 60 * 1000)
          }))
        })),
        likes: populatedComment.likes.map(like => ({ ...like.toObject(), createdAt: new Date(like.createdAt.getTime() + 7 * 60 * 60 * 1000) })),
      };
      return res.status(200).json({ message: 'Unliked', likesCount: comment.likes.length, comment: adjustedComment });
    }
    comment.likes.push({ userId: req.userId });
    await comment.save();
    const populatedComment = await Comment.findById(commentId)
      .populate('userId', 'avatarBase64 username')
      .populate('replies.userId', 'username')
      .populate('likes.userId', 'username')
      .populate('replies.likes.userId', 'username');
    const adjustedComment = {
      ...populatedComment.toObject(),
      createdAt: new Date(populatedComment.createdAt.getTime() + 7 * 60 * 60 * 1000),
      replies: populatedComment.replies.map(reply => ({
        ...reply.toObject(),
        createdAt: new Date(reply.createdAt.getTime() + 7 * 60 * 60 * 1000),
        likes: reply.likes.map(like => ({
          ...like,
          createdAt: new Date(like.createdAt.getTime() + 7 * 60 * 60 * 1000)
        }))
      })),
      likes: populatedComment.likes.map(like => ({ ...like.toObject(), createdAt: new Date(like.createdAt.getTime() + 7 * 60 * 60 * 1000) })),
    };
    res.status(200).json({ message: 'Liked', likesCount: comment.likes.length, comment: adjustedComment });
  } catch (err) {
    res.status(400).json({ message: err.message });
  }
});

router.delete('/comments/:commentId/unlike', authMiddleware, async (req, res) => {
  try {
    const { commentId } = req.params;
    if (!mongoose.Types.ObjectId.isValid(commentId)) return res.status(400).json({ message: 'Invalid commentId format' });
    const comment = await Comment.findById(commentId);
    if (!comment) return res.status(404).json({ message: 'Comment not found' });
    comment.likes = comment.likes.filter(like => like.userId !== req.userId);
    await comment.save();
    const populatedComment = await Comment.findById(commentId)
      .populate('userId', 'avatarBase64 username')
      .populate('replies.userId', 'username')
      .populate('likes.userId', 'username')
      .populate('replies.likes.userId', 'username');
    const adjustedComment = {
      ...populatedComment.toObject(),
      createdAt: new Date(populatedComment.createdAt.getTime() + 7 * 60 * 60 * 1000),
      replies: populatedComment.replies.map(reply => ({
        ...reply.toObject(),
        createdAt: new Date(reply.createdAt.getTime() + 7 * 60 * 60 * 1000),
        likes: reply.likes.map(like => ({
          ...like,
          createdAt: new Date(like.createdAt.getTime() + 7 * 60 * 60 * 1000)
        }))
      })),
      likes: populatedComment.likes.map(like => ({ ...like.toObject(), createdAt: new Date(like.createdAt.getTime() + 7 * 60 * 60 * 1000) })),
    };
    res.status(200).json({ message: 'Unliked', likesCount: comment.likes.length, comment: adjustedComment });
  } catch (err) {
    res.status(400).json({ message: err.message });
  }
});

// New routes for reply likes
router.post('/comments/:commentId/replies/:replyId/like', authMiddleware, async (req, res) => {
  try {
    const { commentId, replyId } = req.params;
    if (!mongoose.Types.ObjectId.isValid(commentId) || !mongoose.Types.ObjectId.isValid(replyId)) {
      return res.status(400).json({ message: 'Invalid format' });
    }
    const comment = await Comment.findById(commentId);
    if (!comment) return res.status(404).json({ message: 'Comment not found' });
    const reply = comment.replies.id(replyId);
    if (!reply) return res.status(404).json({ message: 'Reply not found' });
    const existingLike = reply.likes.find(like => like.userId === req.userId);
    if (existingLike) {
      reply.likes = reply.likes.filter(like => like.userId !== req.userId);
      await comment.save();
      const populatedComment = await Comment.findById(commentId)
        .populate('userId', 'avatarBase64 username')
        .populate('replies.userId', 'username')
        .populate('likes.userId', 'username')
        .populate('replies.likes.userId', 'username');
      const adjustedComment = {
        ...populatedComment.toObject(),
        createdAt: new Date(populatedComment.createdAt.getTime() + 7 * 60 * 60 * 1000),
        replies: populatedComment.replies.map(reply => ({
          ...reply.toObject(),
          createdAt: new Date(reply.createdAt.getTime() + 7 * 60 * 60 * 1000),
          likes: reply.likes.map(like => ({
            ...like,
            createdAt: new Date(like.createdAt.getTime() + 7 * 60 * 60 * 1000)
          }))
        })),
        likes: populatedComment.likes.map(like => ({ ...like.toObject(), createdAt: new Date(like.createdAt.getTime() + 7 * 60 * 60 * 1000) })),
      };
      return res.status(200).json({ message: 'Unliked reply', likesCount: reply.likes.length, comment: adjustedComment });
    }
    reply.likes.push({ userId: req.userId });
    await comment.save();
    const populatedComment = await Comment.findById(commentId)
      .populate('userId', 'avatarBase64 username')
      .populate('replies.userId', 'username')
      .populate('likes.userId', 'username')
      .populate('replies.likes.userId', 'username');
    const adjustedComment = {
      ...populatedComment.toObject(),
      createdAt: new Date(populatedComment.createdAt.getTime() + 7 * 60 * 60 * 1000),
      replies: populatedComment.replies.map(reply => ({
        ...reply.toObject(),
        createdAt: new Date(reply.createdAt.getTime() + 7 * 60 * 60 * 1000),
        likes: reply.likes.map(like => ({
          ...like,
          createdAt: new Date(like.createdAt.getTime() + 7 * 60 * 60 * 1000)
        }))
      })),
      likes: populatedComment.likes.map(like => ({ ...like.toObject(), createdAt: new Date(like.createdAt.getTime() + 7 * 60 * 60 * 1000) })),
    };
    res.status(200).json({ message: 'Liked reply', likesCount: reply.likes.length, comment: adjustedComment });
  } catch (err) {
    res.status(400).json({ message: err.message });
  }
});

router.delete('/comments/:commentId/replies/:replyId/unlike', authMiddleware, async (req, res) => {
  try {
    const { commentId, replyId } = req.params;
    if (!mongoose.Types.ObjectId.isValid(commentId) || !mongoose.Types.ObjectId.isValid(replyId)) {
      return res.status(400).json({ message: 'Invalid format' });
    }
    const comment = await Comment.findById(commentId);
    if (!comment) return res.status(404).json({ message: 'Comment not found' });
    const reply = comment.replies.id(replyId);
    if (!reply) return res.status(404).json({ message: 'Reply not found' });
    reply.likes = reply.likes.filter(like => like.userId !== req.userId);
    await comment.save();
    const populatedComment = await Comment.findById(commentId)
      .populate('userId', 'avatarBase64 username')
      .populate('replies.userId', 'username')
      .populate('likes.userId', 'username')
      .populate('replies.likes.userId', 'username');
    const adjustedComment = {
      ...populatedComment.toObject(),
      createdAt: new Date(populatedComment.createdAt.getTime() + 7 * 60 * 60 * 1000),
      replies: populatedComment.replies.map(reply => ({
        ...reply.toObject(),
        createdAt: new Date(reply.createdAt.getTime() + 7 * 60 * 60 * 1000),
        likes: reply.likes.map(like => ({
          ...like,
          createdAt: new Date(like.createdAt.getTime() + 7 * 60 * 60 * 1000)
        }))
      })),
      likes: populatedComment.likes.map(like => ({ ...like.toObject(), createdAt: new Date(like.createdAt.getTime() + 7 * 60 * 60 * 1000) })),
    };
    res.status(200).json({ message: 'Unliked reply', likesCount: reply.likes.length, comment: adjustedComment });
  } catch (err) {
    res.status(400).json({ message: err.message });
  }
});

module.exports = router;