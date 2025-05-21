require('dotenv').config();
const express = require('express');
const mongoose = require('mongoose');
const admin = require('firebase-admin');
const multer = require('multer');
const { Comment, Reply, LikeComment } = require('../models/comments');
const Rental = require('../models/Rental');

// Configure multer for file uploads
const storage = multer.diskStorage({
  destination: './Uploads/',
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

module.exports = (io) => {
  const router = express.Router();

  // Get comments for a rental
  router.get('/comments/:rentalId', async (req, res) => {
    try {
      const { rentalId } = req.params;
      const { page = 1, limit = 5 } = req.query;
      if (!mongoose.Types.ObjectId.isValid(rentalId)) return res.status(400).json({ message: 'Invalid rentalId format' });

      const skip = (parseInt(page) - 1) * parseInt(limit);
      const comments = await Comment.find({ rentalId })
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(parseInt(limit))
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
      })
        .populate('userId', 'username')
        .lean();

      const totalComments = await Comment.countDocuments({ rentalId });

      const replyMap = new Map();
      replies.forEach((reply) => {
        reply.createdAt = new Date(reply.createdAt.getTime() + 7 * 60 * 60 * 1000);
        reply.likes = likes
          .filter(
            (like) =>
              like.targetId.toString() === reply._id.toString() && like.targetType === 'Reply'
          )
          .map((like) => ({
            ...like,
            createdAt: new Date(like.createdAt.getTime() + 7 * 60 * 60 * 1000),
          }));
        const commentIdStr = reply.commentId.toString();
        if (!replyMap.has(commentIdStr)) {
          replyMap.set(commentIdStr, []);
        }
        replyMap.get(commentIdStr).push(reply);
      });

      const buildReplyTree = (replyList, parentId = null) => {
        return replyList
          .filter((reply) =>
            parentId
              ? reply.parentReplyId?.toString() === parentId
              : !reply.parentReplyId
          )
          .map((reply) => ({
            ...reply,
            replies: buildReplyTree(replyList, reply._id.toString()),
          }));
      };

      const adjustedComments = comments.map((comment) => {
        const commentObj = adjustTimestamps(comment);
        commentObj.replies = buildReplyTree(replyMap.get(comment._id.toString()) || []);
        commentObj.likes = likes
          .filter(
            (like) =>
              like.targetId.toString() === comment._id.toString() &&
              like.targetType === 'Comment'
          )
          .map((like) => ({
            ...like,
            createdAt: new Date(like.createdAt.getTime() + 7 * 60 * 60 * 1000),
          }));
        return commentObj;
      });

      res.json({
        comments: adjustedComments,
        totalComments,
        currentPage: parseInt(page),
        totalPages: Math.ceil(totalComments / parseInt(limit)),
      });
    } catch (err) {
      res.status(500).json({ message: err.message });
    }
  });

  // Create a new comment
  router.post('/comments', authMiddleware, upload.array('images'), async (req, res) => {
    try {
      const { rentalId, content, rating } = req.body;
      if (!rentalId || !content) return res.status(400).json({ message: 'Missing required fields' });
      if (!mongoose.Types.ObjectId.isValid(rentalId)) return res.status(400).json({ message: 'Invalid rentalId format' });
      const rental = await Rental.findById(rentalId);
      if (!rental) return res.status(404).json({ message: 'Rental not found' });
      const imageUrls = req.files.map((file) => `/uploads/${file.filename}`);
      const comment = new Comment({
        rentalId: new mongoose.Types.ObjectId(rentalId),
        userId: req.userId,
        content,
        rating: rating ? Number(rating) : 0,
        images: imageUrls,
      });
      const savedComment = await comment.save();
      const populatedComment = await Comment.findById(savedComment._id).populate(
        'userId',
        'avatarBase64 username'
      );
      const adjustedComment = adjustTimestamps(populatedComment);
      adjustedComment.replies = [];
      adjustedComment.likes = [];

      // Emit Socket.IO event for new comment
      io.emit('newComment', adjustedComment);

      res.status(201).json(adjustedComment);
    } catch (err) {
      res.status(400).json({ message: err.message });
    }
  });

  // Update a comment
  router.put(
    '/comments/:commentId',
    authMiddleware,
    upload.array('images'),
    async (req, res) => {
      try {
        const { commentId } = req.params;
        const { content, imagesToRemove } = req.body;
        if (!mongoose.Types.ObjectId.isValid(commentId) || !content)
          return res.status(400).json({ message: 'Invalid format or missing content' });
        const comment = await Comment.findById(commentId);
        if (!comment || comment.userId !== req.userId)
          return res.status(403).json({ message: 'Unauthorized or not found' });

        comment.content = content;
        if (imagesToRemove) {
          const imagesToRemoveArray = Array.isArray(imagesToRemove)
            ? imagesToRemove
            : JSON.parse(imagesToRemove || '[]');
          comment.images = comment.images.filter(
            (img) => !imagesToRemoveArray.includes(img)
          );
        }
        if (req.files.length > 0) {
          const newImageUrls = req.files.map((file) => `/uploads/${file.filename}`);
          comment.images = [...comment.images, ...newImageUrls];
        }

        const updatedComment = await comment.save();
        const populatedComment = await Comment.findById(commentId).populate(
          'userId',
          'avatarBase64 username'
        );

        const replies = await Reply.find({ commentId }).populate('userId', 'username').lean();
        const likes = await LikeComment.find({
          $or: [
            { targetId: commentId, targetType: 'Comment' },
            { targetId: { $in: replies.map((r) => r._id) }, targetType: 'Reply' },
          ],
        })
          .populate('userId', 'username')
          .lean();

        const replyMap = new Map();
        replies.forEach((reply) => {
          reply.createdAt = new Date(reply.createdAt.getTime() + 7 * 60 * 60 * 1000);
          reply.likes = likes
            .filter(
              (like) =>
                like.targetId.toString() === reply._id.toString() &&
                like.targetType === 'Reply'
            )
            .map((like) => ({
              ...like,
              createdAt: new Date(like.createdAt.getTime() + 7 * 60 * 60 * 1000),
            }));
          const commentIdStr = reply.commentId.toString();
          if (!replyMap.has(commentIdStr)) {
            replyMap.set(commentIdStr, []);
          }
          replyMap.get(commentIdStr).push(reply);
        });

        const buildReplyTree = (replyList, parentId = null) => {
          return replyList
            .filter((reply) =>
              parentId
                ? reply.parentReplyId?.toString() === parentId
                : !reply.parentReplyId
            )
            .map((reply) => ({
              ...reply,
              replies: buildReplyTree(replyList, reply._id.toString()),
            }));
        };

        const adjustedComment = adjustTimestamps(populatedComment);
        adjustedComment.replies = buildReplyTree(replyMap.get(commentId) || []);
        adjustedComment.likes = likes
          .filter(
            (like) =>
              like.targetId.toString() === commentId && like.targetType === 'Comment'
          )
          .map((like) => ({
            ...like,
            createdAt: new Date(like.createdAt.getTime() + 7 * 60 * 60 * 1000),
          }));

        // Emit Socket.IO event for updated comment
        io.emit('updateComment', adjustedComment);

        res.status(200).json(adjustedComment);
      } catch (err) {
        res.status(400).json({ message: err.message });
      }
    }
  );

  // Delete a comment
  router.delete('/comments/:commentId', authMiddleware, async (req, res) => {
    try {
      const { commentId } = req.params;
      if (!mongoose.Types.ObjectId.isValid(commentId))
        return res.status(400).json({ message: 'Invalid commentId format' });
      const comment = await Comment.findById(commentId);
      if (!comment || comment.userId !== req.userId)
        return res.status(403).json({ message: 'Unauthorized or not found' });
      await Reply.deleteMany({ commentId });
      await LikeComment.deleteMany({ targetId: commentId, targetType: 'Comment' });
      await Comment.findByIdAndDelete(commentId);

      // Emit Socket.IO event for deleted comment
      io.emit('deleteComment', { commentId });

      res.json({ message: 'Comment deleted successfully' });
    } catch (err) {
      res.status(500).json({ message: err.message });
    }
  });

  // Create a reply to a comment
  router.post(
    '/comments/:commentId/replies',
    authMiddleware,
    upload.array('images'),
    async (req, res) => {
      try {
        const { commentId } = req.params;
        const { content, parentReplyId } = req.body;
        if (!content || !mongoose.Types.ObjectId.isValid(commentId))
          return res.status(400).json({ message: 'Missing content or invalid format' });
        const comment = await Comment.findById(commentId);
        if (!comment) return res.status(404).json({ message: 'Comment not found' });
        if (parentReplyId && !mongoose.Types.ObjectId.isValid(parentReplyId)) {
          return res.status(400).json({ message: 'Invalid parentReplyId format' });
        }
        if (parentReplyId) {
          const parentReply = await Reply.findById(parentReplyId);
          if (!parentReply || parentReply.commentId.toString() !== commentId) {
            return res.status(404).json({
              message: 'Parent reply not found or does not belong to this comment',
            });
          }
        }
        const imageUrls = req.files.map((file) => `/uploads/${file.filename}`);
        const reply = new Reply({
          commentId,
          parentReplyId: parentReplyId || null,
          userId: req.userId,
          content,
          images: imageUrls,
        });
        const savedReply = await reply.save();
        const populatedReply = await Reply.findById(savedReply._id).populate(
          'userId',
          'username'
        );

        const commentWithReplies = await Comment.findById(commentId).populate(
          'userId',
          'avatarBase64 username'
        );
        const replies = await Reply.find({ commentId }).populate('userId', 'username').lean();
        const likes = await LikeComment.find({
          $or: [
            { targetId: commentId, targetType: 'Comment' },
            { targetId: { $in: replies.map((r) => r._id) }, targetType: 'Reply' },
          ],
        })
          .populate('userId', 'username')
          .lean();

        const replyMap = new Map();
        replies.forEach((reply) => {
          reply.createdAt = new Date(reply.createdAt.getTime() + 7 * 60 * 60 * 1000);
          reply.likes = likes
            .filter(
              (like) =>
                like.targetId.toString() === reply._id.toString() &&
                like.targetType === 'Reply'
            )
            .map((like) => ({
              ...like,
              createdAt: new Date(like.createdAt.getTime() + 7 * 60 * 60 * 1000),
            }));
          const commentIdStr = reply.commentId.toString();
          if (!replyMap.has(commentIdStr)) {
            replyMap.set(commentIdStr, []);
          }
          replyMap.get(commentIdStr).push(reply);
        });

        const buildReplyTree = (replyList, parentId = null) => {
          return replyList
            .filter((reply) =>
              parentId
                ? reply.parentReplyId?.toString() === parentId
                : !reply.parentReplyId
            )
            .map((reply) => ({
              ...reply,
              replies: buildReplyTree(replyList, reply._id.toString()),
            }));
        };

        const adjustedComment = adjustTimestamps(commentWithReplies);
        adjustedComment.replies = buildReplyTree(replyMap.get(commentId) || []);
        adjustedComment.likes = likes
          .filter(
            (like) =>
              like.targetId.toString() === commentId && like.targetType === 'Comment'
          )
          .map((like) => ({
            ...like,
            createdAt: new Date(like.createdAt.getTime() + 7 * 60 * 60 * 1000),
          }));

        // Emit Socket.IO event for new reply
        io.emit('newReply', adjustedComment);

        res.status(201).json(adjustedComment);
      } catch (err) {
        res.status(400).json({ message: err.message });
      }
    }
  );

  // Update a reply
  router.put(
    '/comments/:commentId/replies/:replyId',
    authMiddleware,
    upload.array('images'),
    async (req, res) => {
      try {
        const { commentId, replyId } = req.params;
        const { content, imagesToRemove } = req.body;
        if (
          !mongoose.Types.ObjectId.isValid(commentId) ||
          !mongoose.Types.ObjectId.isValid(replyId) ||
          !content
        ) {
          return res.status(400).json({ message: 'Invalid format or missing content' });
        }
        const reply = await Reply.findById(replyId);
        if (
          !reply ||
          reply.userId !== req.userId ||
          reply.commentId.toString() !== commentId
        ) {
          return res.status(403).json({ message: 'Unauthorized or reply not found' });
        }

        reply.content = content;
        if (imagesToRemove) {
          const imagesToRemoveArray = Array.isArray(imagesToRemove)
            ? imagesToRemove
            : JSON.parse(imagesToRemove || '[]');
          reply.images = reply.images.filter(
            (img) => !imagesToRemoveArray.includes(img)
          );
        }
        if (req.files.length > 0) {
          const newImageUrls = req.files.map((file) => `/uploads/${file.filename}`);
          reply.images = [...reply.images, ...newImageUrls];
        }

        const updatedReply = await reply.save();
        const comment = await Comment.findById(commentId).populate(
          'userId',
          'avatarBase64 username'
        );
        const replies = await Reply.find({ commentId }).populate('userId', 'username').lean();
        const likes = await LikeComment.find({
          $or: [
            { targetId: commentId, targetType: 'Comment' },
            { targetId: { $in: replies.map((r) => r._id) }, targetType: 'Reply' },
          ],
        })
          .populate('userId', 'username')
          .lean();

        const replyMap = new Map();
        replies.forEach((reply) => {
          reply.createdAt = new Date(reply.createdAt.getTime() + 7 * 60 * 60 * 1000);
          reply.likes = likes
            .filter(
              (like) =>
                like.targetId.toString() === reply._id.toString() &&
                like.targetType === 'Reply'
            )
            .map((like) => ({
              ...like,
              createdAt: new Date(like.createdAt.getTime() + 7 * 60 * 60 * 1000),
            }));
          const commentIdStr = reply.commentId.toString();
          if (!replyMap.has(commentIdStr)) {
            replyMap.set(commentIdStr, []);
          }
          replyMap.get(commentIdStr).push(reply);
        });

        const buildReplyTree = (replyList, parentId = null) => {
          return replyList
            .filter((reply) =>
              parentId
                ? reply.parentReplyId?.toString() === parentId
                : !reply.parentReplyId
            )
            .map((reply) => ({
              ...reply,
              replies: buildReplyTree(replyList, reply._id.toString()),
            }));
        };

        const adjustedComment = adjustTimestamps(comment);
        adjustedComment.replies = buildReplyTree(replyMap.get(commentId) || []);
        adjustedComment.likes = likes
          .filter(
            (like) =>
              like.targetId.toString() === commentId && like.targetType === 'Comment'
          )
          .map((like) => ({
            ...like,
            createdAt: new Date(like.createdAt.getTime() + 7 * 60 * 60 * 1000),
          }));

        // Emit Socket.IO event for updated reply
        io.emit('updateReply', adjustedComment);

        res.status(200).json(adjustedComment);
      } catch (err) {
        res.status(400).json({ message: err.message });
      }
    }
  );

  // Delete a reply
  router.delete(
    '/comments/:commentId/replies/:replyId',
    authMiddleware,
    async (req, res) => {
      try {
        const { commentId, replyId } = req.params;
        if (
          !mongoose.Types.ObjectId.isValid(commentId) ||
          !mongoose.Types.ObjectId.isValid(replyId)
        ) {
          return res.status(400).json({ message: 'Invalid format' });
        }
        const reply = await Reply.findById(replyId);
        if (
          !reply ||
          reply.userId !== req.userId ||
          reply.commentId.toString() !== commentId
        ) {
          return res.status(403).json({ message: 'Unauthorized or reply not found' });
        }
        await Reply.deleteMany({
          $or: [{ _id: replyId }, { parentReplyId: replyId }],
        });
        await LikeComment.deleteMany({ targetId: replyId, targetType: 'Reply' });

        const comment = await Comment.findById(commentId).populate(
          'userId',
          'avatarBase64 username'
        );
        const replies = await Reply.find({ commentId }).populate('userId', 'username').lean();
        const likes = await LikeComment.find({
          $or: [
            { targetId: commentId, targetType: 'Comment' },
            { targetId: { $in: replies.map((r) => r._id) }, targetType: 'Reply' },
          ],
        })
          .populate('userId', 'username')
          .lean();

        const replyMap = new Map();
        replies.forEach((reply) => {
          reply.createdAt = new Date(reply.createdAt.getTime() + 7 * 60 * 60 * 1000);
          reply.likes = likes
            .filter(
              (like) =>
                like.targetId.toString() === reply._id.toString() &&
                like.targetType === 'Reply'
            )
            .map((like) => ({
              ...like,
              createdAt: new Date(like.createdAt.getTime() + 7 * 60 * 60 * 1000),
            }));
          const commentIdStr = reply.commentId.toString();
          if (!replyMap.has(commentIdStr)) {
            replyMap.set(commentIdStr, []);
          }
          replyMap.get(commentIdStr).push(reply);
        });

        const buildReplyTree = (replyList, parentId = null) => {
          return replyList
            .filter((reply) =>
              parentId
                ? reply.parentReplyId?.toString() === parentId
                : !reply.parentReplyId
            )
            .map((reply) => ({
              ...reply,
              replies: buildReplyTree(replyList, reply._id.toString()),
            }));
        };

        const adjustedComment = adjustTimestamps(comment);
        adjustedComment.replies = buildReplyTree(replyMap.get(commentId) || []);
        adjustedComment.likes = likes
          .filter(
            (like) =>
              like.targetId.toString() === commentId && like.targetType === 'Comment'
          )
          .map((like) => ({
            ...like,
            createdAt: new Date(like.createdAt.getTime() + 7 * 60 * 60 * 1000),
          }));

        // Emit Socket.IO event for deleted reply
        io.emit('deleteReply', { commentId, replyId });

        res.status(200).json({
          message: 'Reply deleted successfully',
          comment: adjustedComment,
        });
      } catch (err) {
        res.status(500).json({ message: err.message });
      }
    }
  );

  // Like a comment
  router.post('/comments/:commentId/like', authMiddleware, async (req, res) => {
    try {
      const { commentId } = req.params;
      if (!mongoose.Types.ObjectId.isValid(commentId))
        return res.status(400).json({ message: 'Invalid commentId format' });
      const comment = await Comment.findById(commentId);
      if (!comment) return res.status(404).json({ message: 'Comment not found' });

      const existingLike = await LikeComment.findOne({
        targetId: commentId,
        targetType: 'Comment',
        userId: req.userId,
      });
      if (existingLike) {
        await LikeComment.deleteOne({ _id: existingLike._id });
        const populatedComment = await Comment.findById(commentId).populate(
          'userId',
          'avatarBase64 username'
        );
        const replies = await Reply.find({ commentId }).populate('userId', 'username').lean();
        const likes = await LikeComment.find({
          $or: [
            { targetId: commentId, targetType: 'Comment' },
            { targetId: { $in: replies.map((r) => r._id) }, targetType: 'Reply' },
          ],
        })
          .populate('userId', 'username')
          .lean();

        const replyMap = new Map();
        replies.forEach((reply) => {
          reply.createdAt = new Date(reply.createdAt.getTime() + 7 * 60 * 60 * 1000);
          reply.likes = likes
            .filter(
              (like) =>
                like.targetId.toString() === reply._id.toString() &&
                like.targetType === 'Reply'
            )
            .map((like) => ({
              ...like,
              createdAt: new Date(like.createdAt.getTime() + 7 * 60 * 60 * 1000),
            }));
          const commentIdStr = reply.commentId.toString();
          if (!replyMap.has(commentIdStr)) {
            replyMap.set(commentIdStr, []);
          }
          replyMap.get(commentIdStr).push(reply);
        });

        const buildReplyTree = (replyList, parentId = null) => {
          return replyList
            .filter((reply) =>
              parentId
                ? reply.parentReplyId?.toString() === parentId
                : !reply.parentReplyId
            )
            .map((reply) => ({
              ...reply,
              replies: buildReplyTree(replyList, reply._id.toString()),
            }));
        };

        const adjustedComment = adjustTimestamps(populatedComment);
        adjustedComment.replies = buildReplyTree(replyMap.get(commentId) || []);
        adjustedComment.likes = likes
          .filter(
            (like) =>
              like.targetId.toString() === commentId && like.targetType === 'Comment'
          )
          .map((like) => ({
            ...like,
            createdAt: new Date(like.createdAt.getTime() + 7 * 60 * 60 * 1000),
          }));

        // Emit Socket.IO event for unliked comment
        io.emit('unlikeComment', { commentId, userId: req.userId });

        return res.status(200).json({
          message: 'Unliked',
          likesCount: adjustedComment.likes.length,
          comment: adjustedComment,
        });
      }

      const like = new LikeComment({
        targetId: commentId,
        targetType: 'Comment',
        userId: req.userId,
      });
      await like.save();

      const populatedComment = await Comment.findById(commentId).populate(
        'userId',
        'avatarBase64 username'
      );
      const replies = await Reply.find({ commentId }).populate('userId', 'username').lean();
      const likes = await LikeComment.find({
        $or: [
          { targetId: commentId, targetType: 'Comment' },
          { targetId: { $in: replies.map((r) => r._id) }, targetType: 'Reply' },
        ],
      })
        .populate('userId', 'username')
        .lean();

      const replyMap = new Map();
      replies.forEach((reply) => {
        reply.createdAt = new Date(reply.createdAt.getTime() + 7 * 60 * 60 * 1000);
        reply.likes = likes
          .filter(
            (like) =>
              like.targetId.toString() === reply._id.toString() &&
              like.targetType === 'Reply'
          )
          .map((like) => ({
            ...like,
            createdAt: new Date(like.createdAt.getTime() + 7 * 60 * 60 * 1000),
          }));
        const commentIdStr = reply.commentId.toString();
        if (!replyMap.has(commentIdStr)) {
          replyMap.set(commentIdStr, []);
        }
        replyMap.get(commentIdStr).push(reply);
      });

      const buildReplyTree = (replyList, parentId = null) => {
        return replyList
          .filter((reply) =>
            parentId
              ? reply.parentReplyId?.toString() === parentId
              : !reply.parentReplyId
          )
          .map((reply) => ({
            ...reply,
            replies: buildReplyTree(replyList, reply._id.toString()),
          }));
      };

      const adjustedComment = adjustTimestamps(populatedComment);
      adjustedComment.replies = buildReplyTree(replyMap.get(commentId) || []);
      adjustedComment.likes = likes
        .filter(
          (like) =>
            like.targetId.toString() === commentId && like.targetType === 'Comment'
        )
        .map((like) => ({
          ...like,
          createdAt: new Date(like.createdAt.getTime() + 7 * 60 * 60 * 1000),
        }));

      // Emit Socket.IO event for liked comment
      io.emit('likeComment', { commentId, userId: req.userId });

      res.status(200).json({
        message: 'Liked',
        likesCount: adjustedComment.likes.length,
        comment: adjustedComment,
      });
    } catch (err) {
      res.status(400).json({ message: err.message });
    }
  });

  // Unlike a comment
  router.delete('/comments/:commentId/unlike', authMiddleware, async (req, res) => {
    try {
      const { commentId } = req.params;
      if (!mongoose.Types.ObjectId.isValid(commentId))
        return res.status(400).json({ message: 'Invalid commentId format' });
      const comment = await Comment.findById(commentId);
      if (!comment) return res.status(404).json({ message: 'Comment not found' });

      await LikeComment.deleteOne({
        targetId: commentId,
        targetType: 'Comment',
        userId: req.userId,
      });

      const populatedComment = await Comment.findById(commentId).populate(
        'userId',
        'avatarBase64 username'
      );
      const replies = await Reply.find({ commentId }).populate('userId', 'username').lean();
      const likes = await LikeComment.find({
        $or: [
          { targetId: commentId, targetType: 'Comment' },
          { targetId: { $in: replies.map((r) => r._id) }, targetType: 'Reply' },
        ],
      })
        .populate('userId', 'username')
        .lean();

      const replyMap = new Map();
      replies.forEach((reply) => {
        reply.createdAt = new Date(reply.createdAt.getTime() + 7 * 60 * 60 * 1000);
        reply.likes = likes
          .filter(
            (like) =>
              like.targetId.toString() === reply._id.toString() &&
              like.targetType === 'Reply'
          )
          .map((like) => ({
            ...like,
            createdAt: new Date(like.createdAt.getTime() + 7 * 60 * 60 * 1000),
          }));
        const commentIdStr = reply.commentId.toString();
        if (!replyMap.has(commentIdStr)) {
          replyMap.set(commentIdStr, []);
        }
        replyMap.get(commentIdStr).push(reply);
      });

      const buildReplyTree = (replyList, parentId = null) => {
        return replyList
          .filter((reply) =>
            parentId
              ? reply.parentReplyId?.toString() === parentId
              : !reply.parentReplyId
          )
          .map((reply) => ({
            ...reply,
            replies: buildReplyTree(replyList, reply._id.toString()),
          }));
      };

      const adjustedComment = adjustTimestamps(populatedComment);
      adjustedComment.replies = buildReplyTree(replyMap.get(commentId) || []);
      adjustedComment.likes = likes
        .filter(
          (like) =>
            like.targetId.toString() === commentId && like.targetType === 'Comment'
        )
        .map((like) => ({
          ...like,
          createdAt: new Date(like.createdAt.getTime() + 7 * 60 * 60 * 1000),
        }));

      // Emit Socket.IO event for unliked comment
      io.emit('unlikeComment', { commentId, userId: req.userId });

      res.status(200).json({
        message: 'Unliked',
        likesCount: adjustedComment.likes.length,
        comment: adjustedComment,
      });
    } catch (err) {
      res.status(400).json({ message: err.message });
    }
  });

  // Like a reply
  router.post(
    '/comments/:commentId/replies/:replyId/like',
    authMiddleware,
    async (req, res) => {
      try {
        const { commentId, replyId } = req.params;
        if (
          !mongoose.Types.ObjectId.isValid(commentId) ||
          !mongoose.Types.ObjectId.isValid(replyId)
        ) {
          return res.status(400).json({ message: 'Invalid format' });
        }
        const reply = await Reply.findById(replyId);
        if (!reply || reply.commentId.toString() !== commentId)
          return res.status(404).json({ message: 'Reply not found' });

        const existingLike = await LikeComment.findOne({
          targetId: replyId,
          targetType: 'Reply',
          userId: req.userId,
        });
        if (existingLike) {
          await LikeComment.deleteOne({ _id: existingLike._id });
          const comment = await Comment.findById(commentId).populate(
            'userId',
            'avatarBase64 username'
          );
          const replies = await Reply.find({ commentId })
            .populate('userId', 'username')
            .lean();
          const likes = await LikeComment.find({
            $or: [
              { targetId: commentId, targetType: 'Comment' },
              { targetId: { $in: replies.map((r) => r._id) }, targetType: 'Reply' },
            ],
          })
            .populate('userId', 'username')
            .lean();

          const replyMap = new Map();
          replies.forEach((reply) => {
            reply.createdAt = new Date(reply.createdAt.getTime() + 7 * 60 * 60 * 1000);
            reply.likes = likes
              .filter(
                (like) =>
                  like.targetId.toString() === reply._id.toString() &&
                  like.targetType === 'Reply'
              )
              .map((like) => ({
                ...like,
                createdAt: new Date(like.createdAt.getTime() + 7 * 60 * 60 * 1000),
              }));
            const commentIdStr = reply.commentId.toString();
            if (!replyMap.has(commentIdStr)) {
              replyMap.set(commentIdStr, []);
            }
            replyMap.get(commentIdStr).push(reply);
          });

          const buildReplyTree = (replyList, parentId = null) => {
            return replyList
              .filter((reply) =>
                parentId
                  ? reply.parentReplyId?.toString() === parentId
                  : !reply.parentReplyId
              )
              .map((reply) => ({
                ...reply,
                replies: buildReplyTree(replyList, reply._id.toString()),
              }));
          };

          const adjustedComment = adjustTimestamps(comment);
          adjustedComment.replies = buildReplyTree(replyMap.get(commentId) || []);
          adjustedComment.likes = likes
            .filter(
              (like) =>
                like.targetId.toString() === commentId &&
                like.targetType === 'Comment'
            )
            .map((like) => ({
              ...like,
              createdAt: new Date(like.createdAt.getTime() + 7 * 60 * 60 * 1000),
            }));

          // Emit Socket.IO event for unliked reply
          io.emit('unlikeReply', { commentId, replyId, userId: req.userId });

          return res.status(200).json({
            message: 'Unliked reply',
            likesCount: adjustedComment.replies.find(
              (r) => r._id.toString() === replyId
            ).likes.length,
            comment: adjustedComment,
          });
        }

        const like = new LikeComment({
          targetId: replyId,
          targetType: 'Reply',
          userId: req.userId,
        });
        await like.save();

        const comment = await Comment.findById(commentId).populate(
          'userId',
          'avatarBase64 username'
        );
        const replies = await Reply.find({ commentId }).populate('userId', 'username').lean();
        const likes = await LikeComment.find({
          $or: [
            { targetId: commentId, targetType: 'Comment' },
            { targetId: { $in: replies.map((r) => r._id) }, targetType: 'Reply' },
          ],
        })
          .populate('userId', 'username')
          .lean();

        const replyMap = new Map();
        replies.forEach((reply) => {
          reply.createdAt = new Date(reply.createdAt.getTime() + 7 * 60 * 60 * 1000);
          reply.likes = likes
            .filter(
              (like) =>
                like.targetId.toString() === reply._id.toString() &&
                like.targetType === 'Reply'
            )
            .map((like) => ({
              ...like,
              createdAt: new Date(like.createdAt.getTime() + 7 * 60 * 60 * 1000),
            }));
          const commentIdStr = reply.commentId.toString();
          if (!replyMap.has(commentIdStr)) {
            replyMap.set(commentIdStr, []);
          }
          replyMap.get(commentIdStr).push(reply);
        });

        const buildReplyTree = (replyList, parentId = null) => {
          return replyList
            .filter((reply) =>
              parentId
                ? reply.parentReplyId?.toString() === parentId
                : !reply.parentReplyId
            )
            .map((reply) => ({
              ...reply,
              replies: buildReplyTree(replyList, reply._id.toString()),
            }));
        };

        const adjustedComment = adjustTimestamps(comment);
        adjustedComment.replies = buildReplyTree(replyMap.get(commentId) || []);
        adjustedComment.likes = likes
          .filter(
            (like) =>
              like.targetId.toString() === commentId && like.targetType === 'Comment'
          )
          .map((like) => ({
            ...like,
            createdAt: new Date(like.createdAt.getTime() + 7 * 60 * 60 * 1000),
          }));

        // Emit Socket.IO event for liked reply
        io.emit('likeReply', { commentId, replyId, userId: req.userId });

        res.status(200).json({
          message: 'Liked reply',
          likesCount: adjustedComment.replies.find(
            (r) => r._id.toString() === replyId
          ).likes.length,
          comment: adjustedComment,
        });
      } catch (err) {
        res.status(400).json({ message: err.message });
      }
    }
  );

  // Unlike a reply
  router.delete(
    '/comments/:commentId/replies/:replyId/unlike',
    authMiddleware,
    async (req, res) => {
      try {
        const { commentId, replyId } = req.params;
        if (
          !mongoose.Types.ObjectId.isValid(commentId) ||
          !mongoose.Types.ObjectId.isValid(replyId)
        ) {
          return res.status(400).json({ message: 'Invalid format' });
        }
        const reply = await Reply.findById(replyId);
        if (!reply || reply.commentId.toString() !== commentId)
          return res.status(404).json({ message: 'Reply not found' });

        await LikeComment.deleteOne({
          targetId: replyId,
          targetType: 'Reply',
          userId: req.userId,
        });

        const comment = await Comment.findById(commentId).populate(
          'userId',
          'avatarBase64 username'
        );
        const replies = await Reply.find({ commentId }).populate('userId', 'username').lean();
        const likes = await LikeComment.find({
          $or: [
            { targetId: commentId, targetType: 'Comment' },
            { targetId: { $in: replies.map((r) => r._id) }, targetType: 'Reply' },
          ],
        })
          .populate('userId', 'username')
          .lean();

        const replyMap = new Map();
        replies.forEach((reply) => {
          reply.createdAt = new Date(reply.createdAt.getTime() + 7 * 60 * 60 * 1000);
          reply.likes = likes
            .filter(
              (like) =>
                like.targetId.toString() === reply._id.toString() &&
                like.targetType === 'Reply'
            )
            .map((like) => ({
              ...like,
              createdAt: new Date(like.createdAt.getTime() + 7 * 60 * 60 * 1000),
            }));
          const commentIdStr = reply.commentId.toString();
          if (!replyMap.has(commentIdStr)) {
            replyMap.set(commentIdStr, []);
          }
          replyMap.get(commentIdStr).push(reply);
        });

        const buildReplyTree = (replyList, parentId = null) => {
          return replyList
            .filter((reply) =>
              parentId
                ? reply.parentReplyId?.toString() === parentId
                : !reply.parentReplyId
            )
            .map((reply) => ({
              ...reply,
              replies: buildReplyTree(replyList, reply._id.toString()),
            }));
        };

        const adjustedComment = adjustTimestamps(comment);
        adjustedComment.replies = buildReplyTree(replyMap.get(commentId) || []);
        adjustedComment.likes = likes
          .filter(
            (like) =>
              like.targetId.toString() === commentId && like.targetType === 'Comment'
          )
          .map((like) => ({
            ...like,
            createdAt: new Date(like.createdAt.getTime() + 7 * 60 * 60 * 1000),
          }));

        // Emit Socket.IO event for unliked reply
        io.emit('unlikeReply', { commentId, replyId, userId: req.userId });

        res.status(200).json({
          message: 'Unliked reply',
          likesCount: adjustedComment.replies.find(
            (r) => r._id.toString() === replyId
          ).likes.length,
          comment: adjustedComment,
        });
      } catch (err) {
        res.status(400).json({ message: err.message });
      }
    }
  );

  return router;
};