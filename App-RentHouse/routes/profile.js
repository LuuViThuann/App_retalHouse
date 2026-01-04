require('dotenv').config();
const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const admin = require('firebase-admin');
const Rental = require('../models/Rental');
const { Comment, Reply } = require('../models/comments');

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
  const adjusted = { ...obj };
  adjusted.createdAt = new Date(new Date(adjusted.createdAt).getTime() + 7 * 60 * 60 * 1000);
  if (adjusted.updatedAt) {
    adjusted.updatedAt = new Date(new Date(adjusted.updatedAt).getTime() + 7 * 60 * 60 * 1000);
  }
  return adjusted;
};

// Create notification helper
const createNotification = async ({ userId, type, message, content, rentalId, commentId, replyId }) => {
  try {
    const notification = new Notification({
      userId,
      type,
      message,
      content,
      rentalId,
      commentId,
      replyId
    });
    await notification.save();
  } catch (err) {
    console.error('Error creating notification:', err);
  }
};

// Post a comment (Add this endpoint if not already present)
router.post('/comment', authMiddleware, async (req, res) => {
  try {
    const { rentalId, content, rating, images } = req.body;
    const comment = new Comment({
      userId: req.userId,
      rentalId,
      content,
      rating,
      images
    });
    await comment.save();

    // Create notification for the rental owner (if not the same user)
    const rental = await Rental.findById(rentalId).select('userId title');
    if (rental.userId !== req.userId) {
      const user = await admin.auth().getUser(req.userId);
      await createNotification({
        userId: rental.userId,
        type: 'Comment',
        message: `${user.displayName || 'Unknown'} đã bình luận về bài viết của bạn: "${rental.title}"`,
        content,
        rentalId,
        commentId: comment._id
      });
    }

    res.status(201).json(comment);
  } catch (err) {
    console.error('Error posting comment:', err);
    res.status(500).json({ message: 'Failed to post comment', error: err.message });
  }
});

// Post a reply (Add this endpoint if not already present)
router.post('/reply', authMiddleware, async (req, res) => {
  try {
    const { commentId, content, images, parentReplyId } = req.body;
    const reply = new Reply({
      userId: req.userId,
      commentId,
      content,
      images,
      parentReplyId
    });
    await reply.save();

    // Update comment with reply
    await Comment.findByIdAndUpdate(commentId, { $push: { replies: reply._id } });

    // Create notification for the rental owner (if not the same user)
    const comment = await Comment.findById(commentId).populate('rentalId');
    if (comment.rentalId.userId !== req.userId) {
      const user = await admin.auth().getUser(req.userId);
      await createNotification({
        userId: comment.rentalId.userId,
        type: 'Reply',
        message: `${user.displayName || 'Unknown'} đã phản hồi bình luận trên bài viết của bạn: "${comment.rentalId.title}"`,
        content,
        rentalId: comment.rentalId._id,
        commentId,
        replyId: reply._id
      });
    }

    res.status(201).json(reply);
  } catch (err) {
    console.error('Error posting reply:', err);
    res.status(500).json({ message: 'Failed to post reply', error: err.message });
  }
});

// Get user's posts
router.get('/my-posts', authMiddleware, async (req, res) => {
  try {
    const { page = 1, limit = 10 } = req.query;
    const skip = (Number(page) - 1) * Number(limit);

    const rentals = await Rental.find({ userId: req.userId })
      .skip(skip)
      .limit(Number(limit))
      .sort({ createdAt: -1 })
      .lean();

    const total = await Rental.countDocuments({ userId: req.userId });

    const adjustedRentals = rentals.map(adjustTimestamps);

    res.json({
      rentals: adjustedRentals,
      total,
      page: Number(page),
      pages: Math.ceil(total / Number(limit)),
    });
  } catch (err) {
    console.error('Error fetching user posts:', err);
    res.status(500).json({ message: 'Failed to fetch posts', error: err.message });
  }
});

// ✅ FIX: Get user's recent comments and replies
router.get('/recent-comments', authMiddleware, async (req, res) => {
  try {
    const { page = 1, limit = 10 } = req.query;
    const skip = (Number(page) - 1) * Number(limit);

    // ✅ THÊM avatarUrl vào populate
    const comments = await Comment.find({ userId: req.userId })
      .populate({
        path: 'rentalId',
        select: 'title',
      })
      .populate({
        path: 'userId',
        select: 'username avatarBase64 avatarUrl', // ✅ THÊM avatarUrl
      })
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(Number(limit))
      .lean();

    const replies = await Reply.find({ userId: req.userId })
      .populate({
        path: 'commentId',
        populate: {
          path: 'rentalId',
          select: 'title',
        },
      })
      .populate({
        path: 'userId',
        select: 'username avatarBase64 avatarUrl', // ✅ THÊM avatarUrl
      })
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(Number(limit))
      .lean();

    const combined = [
      ...comments.map((comment) => ({
        type: 'Comment',
        _id: comment._id?.toString() || '',
        rentalId: comment.rentalId?._id?.toString() || '',
        rentalTitle: comment.rentalId?.title || 'Unknown Rental',
        userId: {
          _id: comment.userId?._id?.toString() || req.userId,
          username: comment.userId?.username || 'Unknown User',
          avatarBase64: comment.userId?.avatarBase64 || '', // Backward compatible
          avatarUrl: comment.userId?.avatarUrl || null, // ✅ THÊM avatarUrl
        },
        content: comment.content || '',
        rating: comment.rating || 0,
        images: comment.images || [],
        isHidden: comment.isHidden || false,
        createdAt: new Date(comment.createdAt),
        replies: comment.replies || [],
        likes: comment.likes || [],
      })),
      ...replies.map((reply) => ({
        type: 'Reply',
        _id: reply._id?.toString() || '',
        commentId: reply.commentId?._id?.toString() || '',
        rentalId: reply.commentId?.rentalId?._id?.toString() || '',
        rentalTitle: reply.commentId?.rentalId?.title || 'Unknown Rental',
        userId: {
          _id: reply.userId?._id?.toString() || req.userId,
          username: reply.userId?.username || 'Unknown User',
          avatarBase64: reply.userId?.avatarBase64 || '', // Backward compatible
          avatarUrl: reply.userId?.avatarUrl || null, // ✅ THÊM avatarUrl
        },
        content: reply.content || '',
        images: reply.images || [],
        parentReplyId: reply.parentReplyId?.toString() || null,
        createdAt: new Date(reply.createdAt),
        likes: reply.likes || [],
      })),
    ];

    const adjustedCombined = combined.map(adjustTimestamps);

    adjustedCombined.sort((a, b) => b.createdAt - a.createdAt);
    const paginated = adjustedCombined.slice(skip, skip + Number(limit));
    const total = adjustedCombined.length;

    res.json({
      comments: paginated,
      total,
      page: Number(page),
      pages: Math.ceil(total / Number(limit)),
    });
  } catch (err) {
    console.error('Error fetching recent comments:', err);
    res.status(500).json({ message: 'Failed to fetch comments', error: err.message });
  }
});

router.delete('/reply/:id', authMiddleware, async (req, res) => {
  try {
    const { id } = req.params;
    const reply = await Reply.findById(id);
    if (!reply) {
      return res.status(404).json({ message: 'Reply not found' });
    }
    if (reply.userId.toString() !== req.userId) {
      return res.status(401).json({ message: 'Unauthorized' });
    }

    if (reply.commentId) {
      await Comment.findByIdAndUpdate(
        reply.commentId,
        { $pull: { replies: id } }
      );
    }

    await Reply.findByIdAndDelete(id);
    res.json({ message: 'Reply deleted successfully' });
  } catch (err) {
    console.error('Delete reply error:', err);
    res.status(500).json({ message: 'Failed to delete reply', error: err.message });
  }
});

// ✅ FIX: Lấy tất cả comment và reply trên các bài đăng của user hiện tại
router.get('/my-posts-comments', authMiddleware, async (req, res) => {
  try {
    const { page = 1, limit = 10 } = req.query;
    const skip = (Number(page) - 1) * Number(limit);

    // Lấy danh sách bài đăng của user hiện tại
    const myRentals = await Rental.find({ userId: req.userId }).select('_id');
    const myRentalIds = myRentals.map(r => r._id);

    // ✅ THÊM avatarUrl vào populate
    const comments = await Comment.find({
      rentalId: { $in: myRentalIds },
      userId: { $ne: req.userId }
    })
      .populate('userId', 'username avatarBase64 avatarUrl') // ✅ THÊM avatarUrl
      .populate('rentalId', 'title')
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(Number(limit))
      .lean();

    // Lấy reply trên các comment của các bài đăng đó
    const commentIds = comments.map(c => c._id);
    const replies = await Reply.find({
      commentId: { $in: commentIds },
      userId: { $ne: req.userId }
    })
      .populate('userId', 'username avatarBase64 avatarUrl') // ✅ THÊM avatarUrl
      .populate({
        path: 'commentId',
        populate: { path: 'rentalId', select: 'title' }
      })
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(Number(limit))
      .lean();

    // Gộp lại
    const combined = [
      ...comments.map(comment => ({
        type: 'Comment',
        _id: comment._id?.toString() || '',
        rentalId: comment.rentalId?._id?.toString() || '',
        rentalTitle: comment.rentalId?.title || 'Unknown Rental',
        userId: {
          _id: comment.userId?._id?.toString() || '',
          username: comment.userId?.username || 'Unknown User',
          avatarBase64: comment.userId?.avatarBase64 || '', // Backward compatible
          avatarUrl: comment.userId?.avatarUrl || null, // ✅ THÊM avatarUrl
        },
        content: comment.content || '',
        rating: comment.rating || 0,
        images: comment.images || [],
        isHidden: comment.isHidden || false,
        createdAt: new Date(comment.createdAt),
        replies: comment.replies || [],
        likes: comment.likes || [],
      })),
      ...replies.map(reply => ({
        type: 'Reply',
        _id: reply._id?.toString() || '',
        commentId: reply.commentId?._id?.toString() || '',
        rentalId: reply.commentId?.rentalId?._id?.toString() || '',
        rentalTitle: reply.commentId?.rentalId?.title || 'Unknown Rental',
        userId: {
          _id: reply.userId?._id?.toString() || '',
          username: reply.userId?.username || 'Unknown User',
          avatarBase64: reply.userId?.avatarBase64 || '', // Backward compatible
          avatarUrl: reply.userId?.avatarUrl || null, // ✅ THÊM avatarUrl
        },
        content: reply.content || '',
        images: reply.images || [],
        parentReplyId: reply.parentReplyId?.toString() || null,
        createdAt: new Date(reply.createdAt),
        likes: reply.likes || [],
      })),
    ];

    // Sắp xếp và phân trang
    combined.sort((a, b) => b.createdAt - a.createdAt);
    const paginated = combined.slice(0, Number(limit));
    const total = combined.length;

    res.json({
      comments: paginated,
      total,
      page: Number(page),
      pages: Math.ceil(total / Number(limit)),
    });
  } catch (err) {
    console.error('Error fetching comments on my posts:', err);
    res.status(500).json({ message: 'Failed to fetch comments on my posts', error: err.message });
  }
});

module.exports = router;