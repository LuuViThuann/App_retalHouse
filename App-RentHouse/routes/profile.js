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
  // Handle both Mongoose documents and plain objects
  const adjusted = { ...obj };
  adjusted.createdAt = new Date(new Date(adjusted.createdAt).getTime() + 7 * 60 * 60 * 1000);
  if (adjusted.updatedAt) {
    adjusted.updatedAt = new Date(new Date(adjusted.updatedAt).getTime() + 7 * 60 * 60 * 1000);
  }
  return adjusted;
};

// Get user's posts (Danh sách bài đăng của tôi)
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

// Get user's recent comments and replies (Bình luận gần đây nhất)
router.get('/recent-comments', authMiddleware, async (req, res) => {
  try {
    const { page = 1, limit = 10 } = req.query;
    const skip = (Number(page) - 1) * Number(limit);

    // Fetch comments by user
    const comments = await Comment.find({ userId: req.userId })
      .populate({
        path: 'rentalId',
        select: 'title',
      })
      .populate({
        path: 'userId',
        select: 'avatarBase64 username',
      })
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(Number(limit))
      .lean();

    // Fetch replies by user
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
        select: 'username',
      })
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(Number(limit))
      .lean();

    // Combine comments and replies
    const combined = [
      ...comments.map((comment) => ({
        type: 'Comment',
        _id: comment._id?.toString() || '',
        rentalId: comment.rentalId?._id?.toString() || '',
        rentalTitle: comment.rentalId?.title || 'Unknown Rental',
        userId: {
          _id: comment.userId?._id?.toString() || req.userId,
          username: comment.userId?.username || 'Unknown User',
          avatarBase64: comment.userId?.avatarBase64 || '',
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
          avatarBase64: '', // Replies don't need avatarBase64
        },
        content: reply.content || '',
        images: reply.images || [],
        parentReplyId: reply.parentReplyId?.toString() || null,
        createdAt: new Date(reply.createdAt),
        likes: reply.likes || [],
      })),
    ];

    // Adjust timestamps
    const adjustedCombined = combined.map(adjustTimestamps);

    // Sort by createdAt and apply pagination
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

// Get user's notifications (Thông báo)
router.get('/notifications', authMiddleware, async (req, res) => {
  try {
    const { page = 1, limit = 10 } = req.query;
    const skip = (Number(page) - 1) * Number(limit);

    const userRentals = await Rental.find({ userId: req.userId }).select('_id').lean();
    const rentalIds = userRentals.map((rental) => rental._id);

    const [comments, total] = await Promise.all([
      Comment.find({ 
        rentalId: { $in: rentalIds },
        userId: { $ne: req.userId } // Exclude comments from current user
      })
        .populate('userId', 'username')
        .populate('rentalId', 'title')
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(Number(limit))
        .lean(),
      Comment.countDocuments({ 
        rentalId: { $in: rentalIds },
        userId: { $ne: req.userId } // Exclude comments from current user
      }),
    ]);

    const notifications = comments.map((comment) => ({
      type: 'Comment',
      message: `${comment.userId?.username || 'Unknown'} đã bình luận về bài viết của bạn : "${comment.rentalId?.title || 'Unknown'}"`,
      content: comment.content,
      createdAt: new Date(comment.createdAt.getTime() + 7 * 60 * 60 * 1000),
      rentalId: comment.rentalId?._id,
      commentId: comment._id,
    }));

    res.json({
      notifications,
      total,
      page: Number(page),
      pages: Math.ceil(total / Number(limit)),
    });
  } catch (err) {
    console.error('Fetch notifications error:', err.stack);
    res.status(500).json({ message: 'Failed to fetch notifications', error: err.message });
  }
}); 

// Delete notification
router.delete('/notifications/:id', authMiddleware, async (req, res) => {
  try {
    const { id } = req.params;
    
    // Verify that the notification belongs to the user
    const notification = await Notification.findOne({ 
      _id: id,
      userId: req.userId 
    });

    if (!notification) {
      return res.status(404).json({ message: 'Notification not found or unauthorized' });
    }

    await Notification.findByIdAndDelete(id);
    res.json({ message: 'Notification deleted successfully' });
  } catch (err) {
    console.error('Delete notification error:', err);
    res.status(500).json({ message: 'Failed to delete notification', error: err.message });
  }
});
module.exports = router;