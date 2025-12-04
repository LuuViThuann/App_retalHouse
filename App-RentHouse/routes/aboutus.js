require('dotenv').config();
const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const admin = require('firebase-admin');
const multer = require('multer');
const path = require('path');
const { promises: fs } = require('fs');

const AboutUs = require('../models/abouUs');
const Feedback = require('../models/feedback');

const storage = multer.diskStorage({
    destination: './uploads/aboutus/',
    filename: (req, file, cb) => {
      cb(null, `${Date.now()}-${file.originalname}`);
    },
  });
  const imageFileFilter = (req, file, cb) => {
    const allowedMimes = ['image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp'];
    const ext = path.extname(file.originalname).toLowerCase();
  
    if (allowedMimes.includes(file.mimetype)) {
      return cb(null, true);
    }
  
    if (['.jpg', '.jpeg', '.png', '.gif', '.webp'].includes(ext)) {
      if (ext === '.jpg' || ext === '.jpeg') file.mimetype = 'image/jpeg';
      if (ext === '.png') file.mimetype = 'image/png';
      if (ext === '.gif') file.mimetype = 'image/gif';
      if (ext === '.webp') file.mimetype = 'image/webp';
      return cb(null, true);
    }
  
    cb(new Error('Chỉ hỗ trợ ảnh định dạng: JPEG, PNG, GIF, WebP'), false);
  };
  
  const uploadAboutUs = multer({
    storage,
    limits: { fileSize: 100 * 1024 * 1024 },
    fileFilter: imageFileFilter,
  });
  
  const uploadFeedback = multer({
    storage: multer.diskStorage({
      destination: './uploads/feedback/',
      filename: (req, file, cb) => {
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        cb(null, `${uniqueSuffix}-${file.originalname}`);
      },
    }),
    limits: { fileSize: 100 * 1024 * 1024 },
  });
  
  // ==================== MIDDLEWARE ====================
  const verifyAdmin = async (req, res, next) => {
    try {
      const token = req.header('Authorization')?.replace('Bearer ', '');
      if (!token) return res.status(401).json({ message: 'Không có token' });
  
      const decodedToken = await admin.auth().verifyIdToken(token);
      const uid = decodedToken.uid;
  
      const User = require('../models/usermodel');
      const mongoUser = await User.findOne({ _id: uid });
      if (!mongoUser || mongoUser.role !== 'admin') {
        return res.status(403).json({ message: 'Chỉ admin mới có quyền' });
      }
  
      req.userId = uid;
      req.isAdmin = true;
      next();
    } catch (err) {
      res.status(401).json({ message: 'Token không hợp lệ' });
    }
  };

  const authMiddleware = async (req, res, next) => {
    try {
      const token = req.header('Authorization')?.replace('Bearer ', '');
      if (!token) return res.status(401).json({ message: 'Không có token' });
  
      const decodedToken = await admin.auth().verifyIdToken(token);
      req.userId = decodedToken.uid;
      next();
    } catch (err) {
      res.status(401).json({ message: 'Token không hợp lệ' });
    }
  };

  // ==================== REDIS HELPER FUNCTIONS ====================
  let redisClient = null;

  // Hàm khởi tạo Redis client từ server.js
  const setRedisClient = (client) => {
    redisClient = client;
  };

  const createDeleteBackup = async (feedbackId, feedbackData) => {
    try {
      if (!redisClient) {
        console.warn('⚠️ [REDIS BACKUP] Redis client not available, skipping backup');
        return;
      }

      const backupKey = `feedback:deleted:${feedbackId}`;
      const ttl = 7 * 24 * 60 * 60; // 7 ngày
      
      await redisClient.setEx(
        backupKey,
        ttl,
        JSON.stringify({
          ...feedbackData,
          deletedAt: new Date(),
        })
      );
      
      console.log(`✅ [REDIS BACKUP] Feedback ${feedbackId} backed up to Redis`);
    } catch (err) {
      console.error('❌ [REDIS BACKUP] Error creating backup:', err);
    }
  };

  const restoreFromBackup = async (feedbackId) => {
    try {
      if (!redisClient) {
        console.warn('⚠️ [REDIS RESTORE] Redis client not available');
        return null;
      }

      const backupKey = `feedback:deleted:${feedbackId}`;
      const backupData = await redisClient.get(backupKey);
      
      if (!backupData) {
        return null;
      }
      
      return JSON.parse(backupData);
    } catch (err) {
      console.error('❌ [REDIS RESTORE] Error restoring backup:', err);
      return null;
    }
  };

  const getDeletedFeedbacks = async (userId) => {
    try {
      if (!redisClient) {
        console.warn('⚠️ [GET DELETED] Redis client not available');
        return [];
      }

      const keys = await redisClient.keys('feedback:deleted:*');
      
      if (!keys || keys.length === 0) {
        return [];
      }

      const deletedFeedbacks = [];

      for (const key of keys) {
        const data = await redisClient.get(key);
        if (data) {
          const parsed = JSON.parse(data);
          
          if (!userId || parsed.userId === userId) {
            deletedFeedbacks.push({
              id: key.replace('feedback:deleted:', ''),
              ...parsed
            });
          }
        }
      }

      return deletedFeedbacks.sort((a, b) => 
        new Date(b.deletedAt) - new Date(a.deletedAt)
      );
    } catch (err) {
      console.error('❌ [GET DELETED] Error:', err);
      return [];
    }
  };
  
  // ==================== ABOUT US ROUTES ====================
  
  router.get('/aboutus', async (req, res) => {
    try {
      const aboutUs = await AboutUs.findOne({ isActive: true })
        .select('-createdBy -__v')
        .lean();
  
      if (!aboutUs) {
        return res.status(404).json({ message: 'Chưa có nội dung About Us', data: null });
      }
  
      res.json({ message: 'Thành công', data: aboutUs });
    } catch (err) {
      console.error('Error fetching AboutUs:', err);
      res.status(500).json({ message: 'Lỗi server' });
    }
  });
  
  router.get('/admin/aboutus', verifyAdmin, async (req, res) => {
    try {
      const aboutUsList = await AboutUs.find()
        .select('-__v')
        .sort({ createdAt: -1 })
        .lean();
  
      res.json({ message: 'Thành công', data: aboutUsList });
    } catch (err) {
      console.error('Error fetching admin AboutUs:', err);
      res.status(500).json({ message: 'Lỗi server' });
    }
  });

  router.post('/admin/aboutus', verifyAdmin, uploadAboutUs.array('images', 20), async (req, res) => {
    try {
      const { title, description, id } = req.body;
  
      if (!title?.trim() || !description?.trim()) {
        return res.status(400).json({ message: 'Vui lòng nhập đầy đủ tiêu đề và mô tả' });
      }
  
      const newImages = req.files
        ? req.files.map(file => `/uploads/aboutus/${file.filename}`)
        : [];
  
      let aboutUs;
      if (id) {
        aboutUs = await AboutUs.findByIdAndUpdate(
          id,
          {
            title: title.trim(),
            description: description.trim(),
            $push: { images: { $each: newImages } },
            updatedAt: new Date(),
          },
          { new: true, runValidators: true }
        );
  
        if (!aboutUs) {
          return res.status(404).json({ message: 'Không tìm thấy nội dung About Us' });
        }
  
        res.json({ message: 'Cập nhật thành công', data: aboutUs });
      } else {
        await AboutUs.updateMany({}, { $set: { isActive: false } });
  
        aboutUs = new AboutUs({
          title: title.trim(),
          description: description.trim(),
          images: newImages,
          createdBy: req.userId,
          isActive: true,
        });
        await aboutUs.save();
  
        res.status(201).json({ message: 'Tạo mới thành công', data: aboutUs });
      }
    } catch (err) {
      console.error('Error saving AboutUs:', err);
      res.status(500).json({ message: 'Lỗi server', error: err.message });
    }
  });

  router.delete('/admin/aboutus/:id/image', verifyAdmin, async (req, res) => {
    try {
      const { imageUrl } = req.body;
      if (!imageUrl || !imageUrl.startsWith('/uploads/aboutus/')) {
        return res.status(400).json({ message: 'URL ảnh không hợp lệ' });
      }
  
      const aboutUs = await AboutUs.findByIdAndUpdate(
        req.params.id,
        { $pull: { images: imageUrl } },
        { new: true }
      );
  
      if (!aboutUs) {
        return res.status(404).json({ message: 'Không tìm thấy About Us' });
      }
  
      const filePath = path.join(__dirname, '..', imageUrl.replace(/^\//, ''));
      await fs.unlink(filePath).catch(() => console.warn('File đã bị xóa trước đó:', filePath));
  
      res.json({ message: 'Xóa ảnh thành công', data: aboutUs });
    } catch (err) {
      console.error('Error deleting image:', err);
      res.status(500).json({ message: 'Lỗi server' });
    }
  });

  router.delete('/admin/aboutus/:id', verifyAdmin, async (req, res) => {
    try {
      const aboutUs = await AboutUs.findByIdAndDelete(req.params.id);
      if (!aboutUs) {
        return res.status(404).json({ message: 'Không tìm thấy About Us' });
      }
  
      for (const imageUrl of aboutUs.images) {
        const filePath = path.join(__dirname, '..', imageUrl.replace(/^\//, ''));
        await fs.unlink(filePath).catch(() => {});
      }
  
      res.json({ message: 'Xóa thành công' });
    } catch (err) {
      console.error('Error deleting AboutUs:', err);
      res.status(500).json({ message: 'Lỗi server' });
    }
  });
  
  // ==================== FEEDBACK ROUTES ====================
  
  router.post('/feedback', authMiddleware, uploadFeedback.array('attachments'), async (req, res) => {
    try {
      const { title, content, feedbackType, rating } = req.body;
      const User = require('../models/usermodel');
  
      if (!title || !content) {
        return res.status(400).json({ message: 'Vui lòng điền đầy đủ thông tin' });
      }
  
      const user = await User.findById(req.userId).select('username email');
      if (!user) {
        return res.status(404).json({ message: 'Không tìm thấy người dùng' });
      }
  
      let attachments = [];
      if (req.files && req.files.length > 0) {
        attachments = req.files.map(file => `/uploads/feedback/${file.filename}`);
      }
  
      const feedback = new Feedback({
        userId: req.userId,
        userName: user.username || 'Người dùng ẩn danh',
        userEmail: user.email,
        title,
        content,
        feedbackType: feedbackType || 'suggestion',
        rating: rating ? Math.min(5, Math.max(1, parseInt(rating))) : 3,
        attachments,
      });
  
      await feedback.save();
  
      res.status(201).json({
        message: 'Gửi feedback thành công, cảm ơn bạn!',
        data: feedback,
      });
    } catch (err) {
      console.error('Error creating feedback:', err);
      res.status(500).json({ message: 'Lỗi server', error: err.message });
    }
  });
  
  router.get('/feedback/my-feedback', authMiddleware, async (req, res) => {
    try {
      const feedbacks = await Feedback.find({ userId: req.userId })
        .select('-__v')
        .sort({ createdAt: -1 })
        .lean();
  
      res.json({
        message: 'Lấy danh sách feedback thành công',
        data: feedbacks,
      });
    } catch (err) {
      res.status(500).json({ message: 'Lỗi server', error: err.message });
    }
  });

  // ==================== USER: XÓA FEEDBACK (CÓ BACKUP) ====================
  router.delete('/feedback/:id', authMiddleware, async (req, res) => {
    try {
      const feedbackId = req.params.id;

      const feedback = await Feedback.findOne({ _id: feedbackId, userId: req.userId }); 
      if (!feedback) {
        return res.status(404).json({ 
          message: 'Không tìm thấy feedback hoặc bạn không có quyền xóa' 
        });
      }

      // Lưu backup vào Redis trước khi xóa
      await createDeleteBackup(feedbackId, feedback.toObject());

      // Xóa các file đính kèm
      if (feedback.attachments && feedback.attachments.length > 0) {
        for (const fileUrl of feedback.attachments) {
          const filePath = path.join(__dirname, '..', fileUrl.replace(/^\//, ''));
          await fs.unlink(filePath).catch(() => {
            console.warn(`File không tồn tại hoặc đã bị xóa: ${filePath}`);
          });
        }
      }

      await Feedback.findByIdAndDelete(feedbackId);

      res.json({ 
        message: 'Xóa phản hồi thành công. Bạn có thể hoàn tác trong 7 ngày.',
        feedbackId: feedbackId,
        canRestore: true
      });
    } catch (err) {
      console.error('Error deleting user feedback:', err);
      res.status(500).json({ message: 'Lỗi server' });
    }
  });

  // ==================== USER: HOÀN TÁC FEEDBACK ĐÃ XÓA ====================
  router.post('/feedback/:id/restore', authMiddleware, async (req, res) => {
    try {
      const feedbackId = req.params.id;

      const backupData = await restoreFromBackup(feedbackId);

      if (!backupData) {
        return res.status(404).json({ 
          message: 'Không tìm thấy bản backup feedback hoặc hết thời gian hoàn tác (7 ngày)' 
        });
      }

      if (backupData.userId !== req.userId) {
        return res.status(403).json({ 
          message: 'Bạn không có quyền hoàn tác feedback này' 
        });
      }

      const restoredFeedback = new Feedback({
        _id: feedbackId,
        ...backupData,
        deletedAt: undefined,
      });

      await restoredFeedback.save();

      if (redisClient) {
        await redisClient.del(`feedback:deleted:${feedbackId}`);
      }

      console.log(`✅ [RESTORE] Feedback ${feedbackId} restored successfully`);

      res.json({
        message: 'Hoàn tác phản hồi thành công',
        data: restoredFeedback
      });
    } catch (err) {
      console.error('❌ [RESTORE] Error restoring feedback:', err);
      res.status(500).json({ message: 'Lỗi server', error: err.message });
    }
  });

  // ==================== USER: LẤY DANH SÁCH FEEDBACK ĐÃ XÓA ====================
  router.get('/feedback/deleted/list', authMiddleware, async (req, res) => {
    try {
      const deletedFeedbacks = await getDeletedFeedbacks(req.userId);

      res.json({
        message: 'Lấy danh sách feedback đã xóa thành công',
        data: deletedFeedbacks
      });
    } catch (err) {
      console.error('❌ [GET DELETED] Error:', err);
      res.status(500).json({ message: 'Lỗi server', error: err.message });
    }
  });

  // ==================== USER: XÓA VĨNH VIỄN FEEDBACK ====================
  router.delete('/feedback/:id/permanent', authMiddleware, async (req, res) => {
    try {
      const feedbackId = req.params.id;

      const backupData = await restoreFromBackup(feedbackId);

      if (!backupData) {
        return res.status(404).json({ 
          message: 'Không tìm thấy bản backup feedback' 
        });
      }

      if (backupData.userId !== req.userId) {
        return res.status(403).json({ 
          message: 'Bạn không có quyền xóa vĩnh viễn feedback này' 
        });
      }

      if (redisClient) {
        await redisClient.del(`feedback:deleted:${feedbackId}`);
      }

      res.json({
        message: 'Feedback đã được xóa vĩnh viễn'
      });
    } catch (err) {
      console.error('❌ [PERMANENT DELETE] Error:', err);
      res.status(500).json({ message: 'Lỗi server', error: err.message });
    }
  });

  // ==================== ADMIN: LẤY TẤT CẢ FEEDBACK ====================
  router.get('/admin/feedback', verifyAdmin, async (req, res) => {
    try {
      const { status, feedbackType, page = 1, limit = 20 } = req.query;
      const skip = (parseInt(page) - 1) * parseInt(limit);
  
      const filter = {};
      if (status) filter.status = status;
      if (feedbackType) filter.feedbackType = feedbackType;
  
      const [feedbacks, total] = await Promise.all([
        Feedback.find(filter)
          .select('-__v')
          .sort({ createdAt: -1 })
          .skip(skip)
          .limit(parseInt(limit))
          .lean(),
        Feedback.countDocuments(filter),
      ]);
  
      res.json({
        message: 'Lấy danh sách feedback thành công',
        data: feedbacks,
        pagination: {
          page: parseInt(page),
          limit: parseInt(limit),
          total,
          pages: Math.ceil(total / parseInt(limit)),
        },
      });
    } catch (err) {
      res.status(500).json({ message: 'Lỗi server', error: err.message });
    }
  });

  // ==================== ADMIN: CẬP NHẬT TRẠNG THÁI FEEDBACK ====================
  router.patch('/admin/feedback/:id/status', verifyAdmin, async (req, res) => {
    try {
      const { status, adminResponse } = req.body;
      const Notification = require('../models/notification');
  
      console.log('🔵 [FEEDBACK STATUS UPDATE] Starting update...');
      console.log('📋 feedbackId:', req.params.id);
      console.log('📊 newStatus:', status);

      if (!status || !['pending', 'reviewing', 'resolved', 'closed'].includes(status)) {
        return res.status(400).json({ message: 'Trạng thái không hợp lệ' });
      }
  
      const feedback = await Feedback.findById(req.params.id);
      if (!feedback) {
        return res.status(404).json({ message: 'Không tìm thấy feedback' });
      }

      const updateData = {
        status,
        respondedBy: req.userId,
        respondedAt: new Date(),
        updatedAt: new Date(),
      };
  
      if (adminResponse !== undefined) {
        updateData.adminResponse = adminResponse.trim() === '' ? null : adminResponse.trim();
      }
  
      const updatedFeedback = await Feedback.findByIdAndUpdate(
        req.params.id,
        updateData,
        { new: true, runValidators: true }
      );

      // Gửi thông báo
      const notificationMessages = {
        pending: {
          title: 'Phản hồi của bạn đã được tiếp nhận',
          message: 'Chúng tôi đang xem xét phản hồi của bạn. Cảm ơn bạn đã gửi ý kiến!',
        },
        reviewing: {
          title: 'Phản hồi của bạn đang được xem xét',
          message: 'Đội ngũ của chúng tôi đang phân tích phản hồi của bạn. Vui lòng chờ...',
        },
        resolved: {
          title: 'Phản hồi của bạn đã được giải quyết',
          message: updatedFeedback.adminResponse || 'Cảm ơn bạn đã giúp chúng tôi cải thiện dịch vụ!',
        },
        closed: {
          title: 'Phản hồi của bạn đã được đóng',
          message: updatedFeedback.adminResponse || 'Vụ việc đã được đóng. Nếu có thêm câu hỏi, vui lòng liên hệ lại.',
        },
      };
  
      const notificationData = notificationMessages[status];
  
      const notification = new Notification({
        userId: feedback.userId,
        type: 'feedback_response',
        title: notificationData.title,
        message: notificationData.message,
        details: {
          feedbackId: req.params.id,
          feedbackTitle: feedback.title,
          previousStatus: feedback.status,
          newStatus: status,
          adminResponse: updatedFeedback.adminResponse,
        },
        read: false,
        createdAt: new Date(),
      });
  
      await notification.save();

      res.json({
        message: 'Cập nhật trạng thái thành công',
        data: updatedFeedback,
      });
    } catch (err) {
      console.error('❌ [FEEDBACK STATUS UPDATE] ERROR:', err);
      res.status(500).json({ message: 'Lỗi server', error: err.message });
    }
  });

  // ==================== ADMIN: XÓA FEEDBACK (CÓ BACKUP) ====================
  router.delete('/admin/feedback/:id', verifyAdmin, async (req, res) => {
    try {
      const feedback = await Feedback.findByIdAndDelete(req.params.id);

      if (!feedback) {
        return res.status(404).json({ message: 'Không tìm thấy feedback' });
      }

      await createDeleteBackup(feedback._id.toString(), feedback.toObject());

      for (const fileUrl of feedback.attachments) {
        const filePath = path.join(__dirname, '..', fileUrl.replace(/^\//, ''));
        try {
          await fs.unlink(filePath);
        } catch (err) {
          console.warn(`Không thể xóa file: ${filePath}`);
        }
      }

      res.json({ 
        message: 'Xóa feedback thành công. Backup có thể hoàn tác trong 7 ngày.',
        feedbackId: feedback._id.toString()
      });
    } catch (err) {
      console.error('❌ [ADMIN DELETE] Error:', err);
      res.status(500).json({ message: 'Lỗi server', error: err.message });
    }
  });

  // ==================== ADMIN: HOÀN TÁC FEEDBACK ĐÃ XÓA ====================
  router.post('/admin/feedback/:id/restore', verifyAdmin, async (req, res) => {
    try {
      const feedbackId = req.params.id;

      const backupData = await restoreFromBackup(feedbackId);

      if (!backupData) {
        return res.status(404).json({ 
          message: 'Không tìm thấy bản backup feedback' 
        });
      }

      const restoredFeedback = new Feedback({
        _id: feedbackId,
        ...backupData,
        deletedAt: undefined,
      });

      await restoredFeedback.save();

      if (redisClient) {
        await redisClient.del(`feedback:deleted:${feedbackId}`);
      }

      console.log(`✅ [ADMIN RESTORE] Feedback ${feedbackId} restored`);

      res.json({
        message: 'Hoàn tác feedback thành công',
        data: restoredFeedback
      });
    } catch (err) {
      console.error('❌ [ADMIN RESTORE] Error:', err);
      res.status(500).json({ message: 'Lỗi server', error: err.message });
    }
  });

  // ==================== ADMIN: LẤY DANH SÁCH FEEDBACK ĐÃ XÓA ====================
  router.get('/admin/feedback/deleted/list', verifyAdmin, async (req, res) => {
    try {
      const deletedFeedbacks = await getDeletedFeedbacks(null); // null = lấy tất cả

      res.json({
        message: 'Lấy danh sách feedback đã xóa thành công',
        count: deletedFeedbacks.length,
        data: deletedFeedbacks
      });
    } catch (err) {
      console.error('❌ [ADMIN GET DELETED] Error:', err);
      res.status(500).json({ message: 'Lỗi server', error: err.message });
    }
  });

  // ==================== ADMIN: XÓA VĨNH VIỄN FEEDBACK ====================
  router.delete('/admin/feedback/:id/permanent', verifyAdmin, async (req, res) => {
    try {
      const feedbackId = req.params.id;

      const backupData = await restoreFromBackup(feedbackId);

      if (!backupData) {
        return res.status(404).json({ 
          message: 'Không tìm thấy bản backup feedback' 
        });
      }

      if (redisClient) {
        await redisClient.del(`feedback:deleted:${feedbackId}`);
      }

      res.json({
        message: 'Feedback đã được xóa vĩnh viễn khỏi hệ thống'
      });
    } catch (err) {
      console.error('❌ [ADMIN PERMANENT DELETE] Error:', err);
      res.status(500).json({ message: 'Lỗi server', error: err.message });
    }
  });

  // ==================== ADMIN: THỐNG KÊ FEEDBACK ====================
  router.get('/admin/feedback/stats', verifyAdmin, async (req, res) => {
    try {
      const stats = await Feedback.aggregate([
        {
          $facet: {
            byStatus: [
              { $group: { _id: '$status', count: { $sum: 1 } } },
            ],
            byType: [
              { $group: { _id: '$feedbackType', count: { $sum: 1 } } },
            ],
            averageRating: [
              { $group: { _id: null, avg: { $avg: '$rating' } } },
            ],
            totalFeedbacks: [{ $count: 'total' }],
          },
        },
      ]);
  
      res.json({
        message: 'Lấy thống kê thành công',
        data: stats[0],
      });
    } catch (err) {
      res.status(500).json({ message: 'Lỗi server', error: err.message });
    }
  });

  // Export hàm để gọi từ server.js
  module.exports = router;
  module.exports.setRedisClient = setRedisClient;