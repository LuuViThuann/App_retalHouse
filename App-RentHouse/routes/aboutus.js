require('dotenv').config();
const express = require('express');
const router = express.Router();
const admin = require('firebase-admin');
const multer = require('multer');
const cloudinary = require('../config/cloudinary');
const { CloudinaryStorage } = require('multer-storage-cloudinary');

const AboutUs = require('../models/abouUs');
const Feedback = require('../models/feedback');

// ==================== CLOUDINARY STORAGE CONFIG ====================

// Storage cho AboutUs
const aboutUsStorage = new CloudinaryStorage({
  cloudinary: cloudinary,
  params: {
    folder: 'aboutus',
    allowed_formats: ['jpg', 'jpeg', 'png', 'gif', 'webp'],
    transformation: [{ width: 1920, height: 1080, crop: 'limit' }],
  },
});

// Storage cho Feedback
const feedbackStorage = new CloudinaryStorage({
  cloudinary: cloudinary,
  params: {
    folder: 'feedback',
    allowed_formats: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'pdf', 'doc', 'docx'],
    resource_type: 'auto', // Hỗ trợ cả ảnh và file
  },
});

const uploadAboutUs = multer({
  storage: aboutUsStorage,
  limits: { fileSize: 50 * 1024 * 1024 }, // 10MB
  fileFilter: (req, file, cb) => {
   
    const allowedMimes = [
      'image/jpeg',
      'image/jpg', 
      'image/png',
      'image/gif',
      'image/webp',
      'image/heic',  // iOS format
      'image/heif',  // iOS format
      'application/octet-stream', // Fallback for some devices
    ];
    
    // Kiểm tra theo MIME type
    if (allowedMimes.includes(file.mimetype)) {
      console.log('  ✅ MIME type accepted');
      return cb(null, true);
    }
    
    // Kiểm tra theo extension (fallback)
    const ext = file.originalname.split('.').pop().toLowerCase();
    const allowedExts = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'heic', 'heif'];
    
    if (allowedExts.includes(ext)) {
      console.log('  ✅ Extension accepted:', ext);
      return cb(null, true);
    }
    
    // Reject
    console.log('  ❌ File rejected');
    cb(new Error(`Định dạng file không được hỗ trợ: ${file.mimetype} (${file.originalname})`), false);
  },
});

const uploadFeedback = multer({
  storage: feedbackStorage,
  limits: { fileSize: 50 * 1024 * 1024 }, // 10MB
});

// ==================== HELPER FUNCTIONS ====================

// Xóa nhiều ảnh/file trên Cloudinary
const deleteCloudinaryFiles = async (cloudinaryIds) => {
  if (!cloudinaryIds || cloudinaryIds.length === 0) {
    return [];
  }
  
  const results = [];
  for (const publicId of cloudinaryIds) {
    try {
      const result = await cloudinary.uploader.destroy(publicId, {
        resource_type: 'auto', // Xóa cả image và raw file
      });
      results.push({ publicId, result });
      console.log('Cloudinary delete:', publicId, result);
    } catch (error) {
      console.error('Error deleting from Cloudinary:', publicId, error);
      results.push({ publicId, error: error.message });
    }
  }
  return results;
};

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

// GET: Lấy AboutUs active (công khai)
router.get('/aboutus', async (req, res) => {
  try {
    const aboutUs = await AboutUs.getActive();

    if (!aboutUs) {
      return res.status(404).json({ message: 'Chưa có nội dung About Us', data: null });
    }

    res.json({ message: 'Thành công', data: aboutUs });
  } catch (err) {
    console.error('Error fetching AboutUs:', err);
    res.status(500).json({ message: 'Lỗi server' });
  }
});

// GET: Admin lấy tất cả AboutUs
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

// POST: Admin tạo/cập nhật AboutUs
router.post('/admin/aboutus', verifyAdmin, uploadAboutUs.array('images', 20), async (req, res) => {
  let uploadedFiles = [];
  
  try {
  
    const { title, description, id } = req.body;

    // Validation
    if (!title?.trim() || !description?.trim()) {
      console.error('❌ Validation failed: Missing title or description');
      
      // Xóa ảnh đã upload nếu validation fail
      if (req.files?.length > 0) {
        uploadedFiles = req.files.map(f => f.filename);
        await deleteCloudinaryFiles(uploadedFiles);
      }
      return res.status(400).json({ message: 'Vui lòng nhập đầy đủ tiêu đề và mô tả' });
    }

    // Tạo mảng images từ Cloudinary
    const newImages = req.files
      ? req.files.map((file, index) => ({
          url: file.path,
          cloudinaryId: file.filename,
          order: index,
        }))
      : [];

    console.log('📸 New images:', newImages.length);

    let aboutUs;
    
    if (id && id.trim() !== '') {
      // ============ CẬP NHẬT ============
      console.log('🔄 Updating AboutUs with id:', id);
      
      aboutUs = await AboutUs.findById(id);
      
      if (!aboutUs) {
        console.error('❌ AboutUs not found:', id);
        
        // Xóa ảnh đã upload
        if (req.files?.length > 0) {
          uploadedFiles = req.files.map(f => f.filename);
          await deleteCloudinaryFiles(uploadedFiles);
        }
        return res.status(404).json({ message: 'Không tìm thấy nội dung About Us' });
      }

      // Cập nhật thông tin
      aboutUs.title = title.trim();
      aboutUs.description = description.trim();
      aboutUs.updatedAt = new Date();
      
      // Thêm ảnh mới vào cuối (giữ ảnh cũ)
      if (newImages.length > 0) {
        const currentMaxOrder = aboutUs.images.length > 0 
          ? Math.max(...aboutUs.images.map(img => img.order || 0))
          : -1;
        
        newImages.forEach((img, index) => {
          aboutUs.images.push({
            url: img.url,
            cloudinaryId: img.cloudinaryId,
            order: currentMaxOrder + index + 1
          });
        });
      }
      
      await aboutUs.save();
      
      console.log('✅ AboutUs updated successfully');
      return res.status(200).json({ 
        message: 'Cập nhật thành công', 
        data: aboutUs 
      });
      
    } else {
      // ============ TẠO MỚI ============
      console.log('✨ Creating new AboutUs');
      
      // Deactivate tất cả AboutUs cũ
      await AboutUs.updateMany({}, { $set: { isActive: false } });

      aboutUs = new AboutUs({
        title: title.trim(),
        description: description.trim(),
        images: newImages,
        createdBy: req.userId,
        isActive: true,
        createdAt: new Date(),
        updatedAt: new Date(),
      });
      
      await aboutUs.save();
      
      console.log('✅ AboutUs created successfully');
      return res.status(201).json({ 
        message: 'Tạo mới thành công', 
        data: aboutUs 
      });
    }
    
  } catch (err) {
    console.error('❌ Error saving AboutUs:', err);
    console.error('Stack trace:', err.stack);
    
    // Xóa ảnh đã upload nếu có lỗi
    if (req.files?.length > 0) {
      uploadedFiles = req.files.map(f => f.filename);
      await deleteCloudinaryFiles(uploadedFiles);
    }
    
    res.status(500).json({ 
      message: 'Lỗi server', 
      error: err.message,
      details: process.env.NODE_ENV === 'development' ? err.stack : undefined
    });
  }
});
// DELETE: Admin xóa 1 ảnh trong AboutUs
router.delete('/admin/aboutus/:id/image', verifyAdmin, async (req, res) => {
  try {
    const { imageUrl } = req.body;
    
    const aboutUs = await AboutUs.findById(req.params.id);
    if (!aboutUs) {
      return res.status(404).json({ message: 'Không tìm thấy About Us' });
    }

    // Tìm image cần xóa
    const imageToDelete = aboutUs.images.find(img => img.url === imageUrl);
    if (!imageToDelete) {
      return res.status(404).json({ message: 'Không tìm thấy ảnh' });
    }

    // Xóa khỏi Cloudinary
    if (imageToDelete.cloudinaryId) {
      await deleteCloudinaryFiles([imageToDelete.cloudinaryId]);
    }

    // Xóa khỏi database
    aboutUs.removeImageByUrl(imageUrl);
    await aboutUs.save();

    res.json({ message: 'Xóa ảnh thành công', data: aboutUs });
  } catch (err) {
    console.error('Error deleting image:', err);
    res.status(500).json({ message: 'Lỗi server' });
  }
});

// DELETE: Admin xóa AboutUs
router.delete('/admin/aboutus/:id', verifyAdmin, async (req, res) => {
  try {
    const aboutUs = await AboutUs.findById(req.params.id);
    if (!aboutUs) {
      return res.status(404).json({ message: 'Không tìm thấy About Us' });
    }

    // Xóa tất cả ảnh trên Cloudinary
    const cloudinaryIds = aboutUs.getCloudinaryDeleteInfo();
    if (cloudinaryIds.length > 0) {
      await deleteCloudinaryFiles(cloudinaryIds);
    }

    await AboutUs.findByIdAndDelete(req.params.id);

    res.json({ message: 'Xóa thành công' });
  } catch (err) {
    console.error('Error deleting AboutUs:', err);
    res.status(500).json({ message: 'Lỗi server' });
  }
});

// ==================== FEEDBACK ROUTES ====================

// POST: User gửi feedback
router.post('/feedback', authMiddleware, uploadFeedback.array('attachments'), async (req, res) => {
  let uploadedFiles = [];
  
  try {
    const { title, content, feedbackType, rating } = req.body;
    const User = require('../models/usermodel');

    if (!title || !content) {
      if (req.files?.length > 0) {
        uploadedFiles = req.files.map(f => f.filename);
        await deleteCloudinaryFiles(uploadedFiles);
      }
      return res.status(400).json({ message: 'Vui lòng điền đầy đủ thông tin' });
    }

    const user = await User.findById(req.userId).select('username email');
    if (!user) {
      if (req.files?.length > 0) {
        uploadedFiles = req.files.map(f => f.filename);
        await deleteCloudinaryFiles(uploadedFiles);
      }
      return res.status(404).json({ message: 'Không tìm thấy người dùng' });
    }

    // Tạo mảng attachments từ Cloudinary
    let attachments = [];
    if (req.files && req.files.length > 0) {
      attachments = req.files.map((file) => ({
        url: file.path,
        cloudinaryId: file.filename,
        filename: file.originalname,
        uploadedAt: new Date(),
      }));
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
    
    // Xóa file đã upload nếu có lỗi
    if (req.files?.length > 0) {
      uploadedFiles = req.files.map(f => f.filename);
      await deleteCloudinaryFiles(uploadedFiles);
    }
    
    res.status(500).json({ message: 'Lỗi server', error: err.message });
  }
});

// GET: User lấy feedback của mình
router.get('/feedback/my-feedback', authMiddleware, async (req, res) => {
  try {
    const feedbacks = await Feedback.findByUser(req.userId);

    res.json({
      message: 'Lấy danh sách feedback thành công',
      data: feedbacks,
    });
  } catch (err) {
    res.status(500).json({ message: 'Lỗi server', error: err.message });
  }
});

// DELETE: User xóa feedback (có backup)
router.delete('/feedback/:id', authMiddleware, async (req, res) => {
  try {
    const feedbackId = req.params.id;

    const feedback = await Feedback.findOne({ _id: feedbackId, userId: req.userId });
    if (!feedback) {
      return res.status(404).json({
        message: 'Không tìm thấy feedback hoặc bạn không có quyền xóa'
      });
    }

    // Lưu backup vào Redis
    await createDeleteBackup(feedbackId, feedback.toObject());

    // Xóa attachments trên Cloudinary
    const cloudinaryIds = feedback.getCloudinaryDeleteInfo();
    if (cloudinaryIds.length > 0) {
      await deleteCloudinaryFiles(cloudinaryIds);
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

// POST: User hoàn tác feedback đã xóa
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

// GET: User lấy danh sách feedback đã xóa
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

// DELETE: User xóa vĩnh viễn feedback
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

// ==================== ADMIN FEEDBACK ROUTES ====================

// GET: Admin lấy tất cả feedback
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

// PATCH: Admin cập nhật trạng thái feedback
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

// DELETE: Admin xóa feedback (có backup)
router.delete('/admin/feedback/:id', verifyAdmin, async (req, res) => {
  try {
    const feedback = await Feedback.findById(req.params.id);

    if (!feedback) {
      return res.status(404).json({ message: 'Không tìm thấy feedback' });
    }

    // Lưu backup
    await createDeleteBackup(feedback._id.toString(), feedback.toObject());

    // Xóa attachments trên Cloudinary
    const cloudinaryIds = feedback.getCloudinaryDeleteInfo();
    if (cloudinaryIds.length > 0) {
      await deleteCloudinaryFiles(cloudinaryIds);
    }

    await Feedback.findByIdAndDelete(req.params.id);

    res.json({
      message: 'Xóa feedback thành công. Backup có thể hoàn tác trong 7 ngày.',
      feedbackId: feedback._id.toString()
    });
  } catch (err) {
    console.error('❌ [ADMIN DELETE] Error:', err);
    res.status(500).json({ message: 'Lỗi server', error: err.message });
  }
});

// POST: Admin hoàn tác feedback đã xóa
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

// GET: Admin lấy danh sách feedback đã xóa
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

// DELETE: Admin xóa vĩnh viễn feedback
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

// GET: Admin thống kê feedback
router.get('/admin/feedback/stats', verifyAdmin, async (req, res) => {
  try {
    const stats = await Feedback.getStats();

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