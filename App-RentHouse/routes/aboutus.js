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
  
    // Ưu tiên kiểm tra mimetype
    if (allowedMimes.includes(file.mimetype)) {
      return cb(null, true);
    }
  
    // Nếu mimetype bị sai (application/octet-stream, image/jpg...), kiểm tra phần mở rộng
    if (['.jpg', '.jpeg', '.png', '.gif', '.webp'].includes(ext)) {
      // Gán lại mimetype đúng để tránh lỗi sau này (tùy chọn nhưng tốt)
      if (ext === '.jpg' || ext === '.jpeg') file.mimetype = 'image/jpeg';
      if (ext === '.png') file.mimetype = 'image/png';
      if (ext === '.gif') file.mimetype = 'image/gif';
      if (ext === '.webp') file.mimetype = 'image/webp';
      return cb(null, true);
    }
  
    // Từ chối nếu không hợp lệ
    cb(new Error('Chỉ hỗ trợ ảnh định dạng: JPEG, PNG, GIF, WebP'), false);
  };
  const uploadAboutUs = multer({
    storage,
    limits: { fileSize: 100 * 1024 * 1024 }, // 100MB
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
    // Không giới hạn loại file cho feedback (cho phép cả video, pdf...)
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
        // Cập nhật
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
        // Tạo mới (chỉ cho phép 1 bản active)
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
  
      // Xóa file thật
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
  
      // Xóa tất cả ảnh
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
  
  // ✅ User: Gửi feedback
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
  
  // ✅ User: Lấy feedback của mình
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
  
  // ✅ Admin: Lấy tất cả feedback
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
  
  //  Admin: Cập nhật trạng thái feedback
  router.patch('/admin/feedback/:id/status', verifyAdmin, async (req, res) => {
    try {
      const { status, adminResponse } = req.body;
  
      if (!status || !['pending', 'reviewing', 'resolved', 'closed'].includes(status)) {
        return res.status(400).json({ message: 'Trạng thái không hợp lệ' });
      }
  
      const updateData = {
        status,
        respondedBy: req.userId,
        respondedAt: new Date(),
        updatedAt: new Date(),
      };
  
      // Chỉ cập nhật adminResponse nếu có gửi lên
      if (adminResponse !== undefined) {
        updateData.adminResponse = adminResponse.trim() === '' ? null : adminResponse.trim();
      }
  
      const feedback = await Feedback.findByIdAndUpdate(
        req.params.id,
        updateData,
        { new: true, runValidators: true }
      );
  
      if (!feedback) {
        return res.status(404).json({ message: 'Không tìm thấy feedback' });
      }
  
      res.json({
        message: 'Cập nhật trạng thái thành công',
        data: feedback,
      });
    } catch (err) {
      console.error('Lỗi cập nhật feedback:', err);
      res.status(500).json({ message: 'Lỗi server', error: err.message });
    }
  });
  
  // Admin: Xóa feedback
  router.delete('/admin/feedback/:id', verifyAdmin, async (req, res) => {
    try {
      const feedback = await Feedback.findByIdAndDelete(req.params.id);
  
      if (!feedback) {
        return res.status(404).json({ message: 'Không tìm thấy feedback' });
      }
  
      // Xóa file đính kèm
      for (const fileUrl of feedback.attachments) {
        const filePath = path.join(__dirname, '..', fileUrl.replace(/^\//, ''));
        try {
          await fs.unlink(filePath);
        } catch (err) {
          console.warn(`Không thể xóa file: ${filePath}`);
        }
      }
  
      res.json({ message: 'Xóa feedback thành công' });
    } catch (err) {
      res.status(500).json({ message: 'Lỗi server', error: err.message });
    }
  });
  
  // ✅ Admin: Thống kê feedback
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
  
  module.exports = router;