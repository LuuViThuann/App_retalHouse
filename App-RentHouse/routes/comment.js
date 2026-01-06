require('dotenv').config();
const express = require('express');
const mongoose = require('mongoose');
const admin = require('firebase-admin');
const multer = require('multer');
const { Comment, Reply, LikeComment } = require('../models/comments');
const Rental = require('../models/Rental');
const Notification = require('../models/notification');

const cloudinary = require('../config/cloudinary');
const { CloudinaryStorage } = require('multer-storage-cloudinary');

// Cấu hình Cloudinary Storage cho multer
const storage = new CloudinaryStorage({
  cloudinary: cloudinary,
  params: {
    folder: 'comments', // Thư mục trong Cloudinary
    allowed_formats: ['jpg', 'jpeg', 'png', 'webp'],
    transformation: [{ width: 1920, height: 1080, crop: 'limit' }],
  },
});

const upload = multer({
  storage,
  limits: { fileSize: 100 * 1024 * 1024 }, // 100MB
  fileFilter: (req, file, cb) => {
    const allowedExtensions = /\.(jpeg|jpg|png|webp)$/i;
    const extname = allowedExtensions.test(file.originalname);
    
    const allowedMimeTypes = /^image\/(jpeg|jpg|png|webp|octet-stream)/i;
    const mimetype = allowedMimeTypes.test(file.mimetype);
    
    if (extname) {
      return cb(null, true);
    }
    cb(new Error('Chỉ chấp nhận file ảnh (JPEG, JPG, PNG, WebP)'));
  },
});

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

// Helper function: Xóa ảnh trên Cloudinary
const deleteCloudinaryImage = async (imageUrl) => {
  try {
    const urlParts = imageUrl.split('/');
    const publicIdWithExt = urlParts[urlParts.length - 1];
    const publicId = `comments/${publicIdWithExt.split('.')[0]}`;
    
    const result = await cloudinary.uploader.destroy(publicId);
    console.log('Cloudinary delete result:', result);
    return result;
  } catch (error) {
    console.error('Error deleting from Cloudinary:', error);
    throw error;
  }
};


// Helper function to adjust timestamps for +7 timezone
const adjustTimestamps = (obj) => {
  const adjusted = { ...obj.toObject() };
  adjusted.createdAt = new Date(adjusted.createdAt.getTime() + 7 * 60 * 60 * 1000);
  return adjusted;
};
//  Create notification helper
const createCommentNotification = async ({
  userId,
  rentalId,
  rentalTitle,
  commentId,
  commenterName,
  commentContent,
  rating
}) => {
  try {
    const notification = new Notification({
      userId,
      type: 'Comment',
      title: `${commenterName} đã bình luận`,
      message: `${commenterName} đã bình luận về bài viết của bạn: "${rentalTitle}"`,
      rentalId,
      commentId,
      details: {
        rentalTitle,
        commenterName,
        commentContent,
        rating: rating || 0
      },
      read: false
    });
    await notification.save();
    console.log('✅ Comment notification created:', notification._id);
  } catch (err) {
    console.error('❌ Error creating comment notification:', err);
  }
};

//  Create reply notification helper
const createReplyNotification = async ({
  userId,
  rentalId,
  rentalTitle,
  commentId,
  replyId,
  replierName,
  replyContent,
  originalComment,
  notificationType = 'Reply' // 'Reply' for rental owner, 'Comment_Reply' for comment author
}) => {
  try {
    const notification = new Notification({
      userId,
      type: notificationType,
      title: notificationType === 'Comment_Reply' 
        ? `${replierName} đã phản hồi bình luận của bạn`
        : `${replierName} đã phản hồi bình luận`,
      message: notificationType === 'Comment_Reply'
        ? `${replierName} đã phản hồi bình luận của bạn`
        : `${replierName} đã phản hồi bình luận trên bài viết của bạn: "${rentalTitle}"`,
      rentalId,
      commentId,
      replyId,
      details: {
        rentalTitle,
        replierName,
        replyContent,
        originalComment: originalComment || ''
      },
      read: false
    });
    await notification.save();
    console.log('Reply notification created:', notification._id);
  } catch (err) {
    console.error('Error creating reply notification:', err);
  }
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
        .populate('userId', 'username avatarBase64 avatarUrl');

      const commentIds = comments.map(c => c._id);
      const replies = await Reply.find({ commentId: { $in: commentIds } })
        .populate('userId', 'username avatarBase64 avatarUrl')
        .lean();

      const likes = await LikeComment.find({
        $or: [
          { targetId: { $in: commentIds }, targetType: 'Comment' },
          { targetId: { $in: replies.map(r => r._id) }, targetType: 'Reply' },
        ],
      })
        .populate('userId', 'username avatarBase64 avatarUrl')
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
      
      // Lấy URL từ Cloudinary
      const imageUrls = req.files.map((file) => file.path);
      
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
        'username avatarBase64 avatarUrl' 
      );
      
      const adjustedComment = adjustTimestamps(populatedComment);
      adjustedComment.replies = [];
      adjustedComment.likes = [];

      //  Create notification for rental owner ===================
      if (rental.userId.toString() !== req.userId) {
        const currentUser = await admin.auth().getUser(req.userId);
        await createCommentNotification({
          userId: rental.userId,
          rentalId: rental._id,
          rentalTitle: rental.title,
          commentId: savedComment._id,
          commenterName: currentUser.displayName || 'Người dùng ẩn danh',
          commentContent: content,
          rating: rating || 0
        });
      }

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
        
        // Xóa ảnh cũ trên Cloudinary
        if (imagesToRemove) {
          const imagesToRemoveArray = Array.isArray(imagesToRemove)
            ? imagesToRemove
            : JSON.parse(imagesToRemove || '[]');
          
          // Xóa từ Cloudinary
          for (const imageUrl of imagesToRemoveArray) {
            await deleteCloudinaryImage(imageUrl);
          }
          
          comment.images = comment.images.filter(
            (img) => !imagesToRemoveArray.includes(img)
          );
        }
        
        // Thêm ảnh mới từ Cloudinary
        if (req.files.length > 0) {
          const newImageUrls = req.files.map((file) => file.path);
          comment.images = [...comment.images, ...newImageUrls];
        }

        const updatedComment = await comment.save();
        const populatedComment = await Comment.findById(commentId).populate(
          'userId',
          'username avatarBase64 avatarUrl' // 
        );

        const replies = await Reply.find({ commentId }).populate('userId', 'username avatarBase64 avatarUrl').lean();
        const likes = await LikeComment.find({
          $or: [
            { targetId: commentId, targetType: 'Comment' },
            { targetId: { $in: replies.map((r) => r._id) }, targetType: 'Reply' },
          ],
        })
          .populate('userId', 'username avatarBase64 avatarUrl')
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
      
      // Xóa ảnh của comment trên Cloudinary
      for (const imageUrl of comment.images) {
        await deleteCloudinaryImage(imageUrl);
      }
      
      // Lấy tất cả replies và xóa ảnh của chúng
      const replies = await Reply.find({ commentId });
      for (const reply of replies) {
        for (const imageUrl of reply.images) {
          await deleteCloudinaryImage(imageUrl);
        }
      }
      
      await Reply.deleteMany({ commentId });
      await LikeComment.deleteMany({ targetId: commentId, targetType: 'Comment' });
      await Comment.findByIdAndDelete(commentId);

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
        
        // Lấy URL từ Cloudinary
        const imageUrls = req.files.map((file) => file.path);
        
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
          'username avatarBase64 avatarUrl' // ✅
        );

        const commentWithReplies = await Comment.findById(commentId).populate(
          'userId',
          'username avatarBase64 avatarUrl' // ✅
        );
        const replies = await Reply.find({ commentId }).populate('userId', 'username avatarBase64 avatarUrl').lean();
        const likes = await LikeComment.find({
          $or: [
            { targetId: commentId, targetType: 'Comment' },
            { targetId: { $in: replies.map((r) => r._id) }, targetType: 'Reply' },
          ],
        })
          .populate('userId', 'username avatarBase64 avatarUrl')
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

          //  Get rental info
        const rental = await Rental.findById(comment.rentalId);
        const currentUser = await admin.auth().getUser(req.userId);

        //  Notify rental owner if different from replier
        if (rental && rental.userId.toString() !== req.userId) {
          await createReplyNotification({
            userId: rental.userId,
            rentalId: rental._id,
            rentalTitle: rental.title,
            commentId,
            replyId: savedReply._id,
            replierName: currentUser.displayName || 'Người dùng ẩn danh',
            replyContent: content,
            originalComment: comment.content || '',
            notificationType: 'Reply'
          });
        }

        //  Notify comment author if different from replier and rental owner
        if (comment.userId.toString() !== req.userId && 
            (!rental || rental.userId.toString() !== comment.userId.toString())) {
          await createReplyNotification({
            userId: comment.userId,
            rentalId: rental._id,
            rentalTitle: rental.title,
            commentId,
            replyId: savedReply._id,
            replierName: currentUser.displayName || 'Người dùng ẩn danh',
            replyContent: content,
            originalComment: comment.content || '',
            notificationType: 'Comment_Reply'
          });
        }


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
        
        // Xóa ảnh cũ trên Cloudinary
        if (imagesToRemove) {
          const imagesToRemoveArray = Array.isArray(imagesToRemove)
            ? imagesToRemove
            : JSON.parse(imagesToRemove || '[]');
          
          // Xóa từ Cloudinary
          for (const imageUrl of imagesToRemoveArray) {
            await deleteCloudinaryImage(imageUrl);
          }
          
          reply.images = reply.images.filter(
            (img) => !imagesToRemoveArray.includes(img)
          );
        }
        
        // Thêm ảnh mới từ Cloudinary
        if (req.files.length > 0) {
          const newImageUrls = req.files.map((file) => file.path);
          reply.images = [...reply.images, ...newImageUrls];
        }

        const updatedReply = await reply.save();
        const comment = await Comment.findById(commentId).populate(
          'userId',
          'username avatarBase64 avatarUrl' // ✅
        );
        const replies = await Reply.find({ commentId })
        .populate('userId', 'username avatarBase64 avatarUrl') //
        .lean();
        const likes = await LikeComment.find({
          $or: [
            { targetId: commentId, targetType: 'Comment' },
            { targetId: { $in: replies.map((r) => r._id) }, targetType: 'Reply' },
          ],
        })
          .populate('userId', 'username avatarBase64 avatarUrl')
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
        
        // Xóa ảnh của reply trên Cloudinary
        for (const imageUrl of reply.images) {
          await deleteCloudinaryImage(imageUrl);
        }
        
        // Lấy tất cả child replies và xóa ảnh của chúng
        const childReplies = await Reply.find({ parentReplyId: replyId });
        for (const childReply of childReplies) {
          for (const imageUrl of childReply.images) {
            await deleteCloudinaryImage(imageUrl);
          }
        }
        
        await Reply.deleteMany({
          $or: [{ _id: replyId }, { parentReplyId: replyId }],
        });
        await LikeComment.deleteMany({ targetId: replyId, targetType: 'Reply' });

        const comment = await Comment.findById(commentId).populate(
          'userId',
          'username avatarBase64 avatarUrl' // ✅
        );
        const replies = await Reply.find({ commentId }).populate('userId', 'username avatarBase64 avatarUrl').lean();
        const likes = await LikeComment.find({
          $or: [
            { targetId: commentId, targetType: 'Comment' },
            { targetId: { $in: replies.map((r) => r._id) }, targetType: 'Reply' },
          ],
        })
          .populate('userId', 'username avatarBase64 avatarUrl')
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
          'username avatarBase64 avatarUrl' // ✅
        );
        const replies = await Reply.find({ commentId }).populate('userId', 'username avatarBase64 avatarUrl').lean();
        const likes = await LikeComment.find({
          $or: [
            { targetId: commentId, targetType: 'Comment' },
            { targetId: { $in: replies.map((r) => r._id) }, targetType: 'Reply' },
          ],
        })
        .populate('userId', 'username avatarBase64 avatarUrl')
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
        'username avatarBase64 avatarUrl' // ✅
      );
      const replies = await Reply.find({ commentId }).populate('userId', 'username avatarBase64 avatarUrl').lean();
      const likes = await LikeComment.find({
        $or: [
          { targetId: commentId, targetType: 'Comment' },
          { targetId: { $in: replies.map((r) => r._id) }, targetType: 'Reply' },
        ],
      })
        .populate('userId', 'username avatarBase64 avatarUrl')
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
        'username avatarBase64 avatarUrl' // ✅
      );
      const replies = await Reply.find({ commentId }).populate('userId', 'username avatarBase64 avatarUrl').lean();
      const likes = await LikeComment.find({
        $or: [
          { targetId: commentId, targetType: 'Comment' },
          { targetId: { $in: replies.map((r) => r._id) }, targetType: 'Reply' },
        ],
      })
        .populate('userId', 'username avatarBase64 avatarUrl')
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
            'username avatarBase64 avatarUrl' // ✅
          );
          const replies = await Reply.find({ commentId })
            .populate('userId', 'username avatarBase64 avatarUrl')
            .lean();
          const likes = await LikeComment.find({
            $or: [
              { targetId: commentId, targetType: 'Comment' },
              { targetId: { $in: replies.map((r) => r._id) }, targetType: 'Reply' },
            ],
          })
            .populate('userId', 'username avatarBase64 avatarUrl')
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
          'username avatarBase64 avatarUrl' // ✅
        );
        const replies = await Reply.find({ commentId }).populate('userId', 'username avatarBase64 avatarUrl')
        const likes = await LikeComment.find({
          $or: [
            { targetId: commentId, targetType: 'Comment' },
            { targetId: { $in: replies.map((r) => r._id) }, targetType: 'Reply' },
          ],
        })
          .populate('userId', 'username avatarBase64 avatarUrl')
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
          'username avatarBase64 avatarUrl' // ✅
        );
        const replies = await Reply.find({ commentId }).populate('userId', 'username avatarBase64 avatarUrl').lean();
        const likes = await LikeComment.find({
          $or: [
            { targetId: commentId, targetType: 'Comment' },
            { targetId: { $in: replies.map((r) => r._id) }, targetType: 'Reply' },
          ],
        })
          .populate('userId', 'username avatarBase64 avatarUrl')
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

        // Gửi Socket.IO sự kiện cho reply đã bỏ thích
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