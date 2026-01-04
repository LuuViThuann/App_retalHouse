// routes/banner.js
const express = require('express');
const router = express.Router();
const Banner = require('../models/banner');
const multer = require('multer');
const cloudinary = require('../config/cloudinary');
const { CloudinaryStorage } = require('multer-storage-cloudinary');

// Cấu hình Cloudinary Storage cho multer
const storage = new CloudinaryStorage({
  cloudinary: cloudinary,
  params: {
    folder: 'banners', // Thư mục trong Cloudinary
    allowed_formats: ['jpg', 'jpeg', 'png', 'webp'],
    transformation: [{ width: 1920, height: 600, crop: 'limit' }], // Tùy chọn: resize ảnh 
  },
});

const upload = multer({
  storage,
  limits: { fileSize: 5 * 1024 * 1024 }, // 5MB
  fileFilter: (req, file, cb) => {
    // Kiểm tra extension file
    const allowedExtensions = /\.(jpeg|jpg|png|webp)$/i;
    const extname = allowedExtensions.test(file.originalname);
    
    // Kiểm tra MIME type
    const allowedMimeTypes = /^image\/(jpeg|jpg|png|webp|octet-stream)/i;
    const mimetype = allowedMimeTypes.test(file.mimetype);
    
    console.log('File:', file.originalname, 'Extension:', extname, 'MIME:', file.mimetype, 'MIMEValid:', mimetype);
    
    if (extname) {
      return cb(null, true);
    }
    cb(new Error('Chỉ chấp nhận file ảnh (JPEG, JPG, PNG, WebP)'));
  },
});

// Middleware kiểm tra admin
const isAdmin = async (req, res, next) => {
  try {
    const token = req.headers.authorization?.split('Bearer ')[1];
    if (!token) return res.status(401).json({ message: 'Không có token' });

    const decoded = await require('firebase-admin').auth().verifyIdToken(token);
    const user = await require('../models/usermodel').findOne({ _id: decoded.uid });

    if (user?.role !== 'admin') {
      return res.status(403).json({ message: 'Bạn không có quyền admin' });
    }
    req.user = decoded;
    next();
  } catch (err) {
    console.error('Admin check error:', err);
    res.status(401).json({ message: 'Token không hợp lệ' });
  }
};

// Helper function: Xóa ảnh trên Cloudinary
const deleteCloudinaryImage = async (imageUrl) => {
  try {
    // Extract public_id từ URL Cloudinary
    // URL format: https://res.cloudinary.com/{cloud_name}/image/upload/v{version}/{public_id}.{format}
    const urlParts = imageUrl.split('/');
    const publicIdWithExt = urlParts[urlParts.length - 1];
    const publicId = `banners/${publicIdWithExt.split('.')[0]}`;
    
    const result = await cloudinary.uploader.destroy(publicId);
    console.log('Cloudinary delete result:', result);
    return result;
  } catch (error) {
    console.error('Error deleting from Cloudinary:', error);
    throw error;
  }
};

// Lấy tất cả banner (công khai - chỉ active)
router.get('/', async (req, res) => {
  try {
    const banners = await Banner.find({ isActive: true }).sort({ position: 1 });
    res.json(banners);
  } catch (err) {
    console.error('Get banners error:', err);
    res.status(500).json({ message: err.message });
  }
});

// Admin: Lấy tất cả banner (kể cả không active)
router.get('/admin', isAdmin, async (req, res) => {
  try {
    const banners = await Banner.find().sort({ position: 1 });
    res.json(banners);
  } catch (err) {
    console.error('Get admin banners error:', err);
    res.status(500).json({ message: err.message });
  }
});

// Thêm banner mới
router.post('/', isAdmin, upload.single('image'), async (req, res) => {
  try {
    console.log('Create banner - Body:', req.body);
    console.log('Create banner - File:', req.file);

    const { title, description, link, isActive, position } = req.body;
    
    // Kiểm tra file upload
    if (!req.file) {
      return res.status(400).json({ message: 'Vui lòng upload ảnh' });
    }

    // Cloudinary tự động trả về URL trong req.file.path
    const banner = new Banner({
      title: title.trim(),
      description: description ? description.trim() : '',
      link: link ? link.trim() : '',
      isActive: isActive === 'true' || isActive === true,
      position: parseInt(position) || 0,
      imageUrl: req.file.path, // URL từ Cloudinary
      cloudinaryId: req.file.filename, // Public ID để xóa sau này
    });

    await banner.save();
    console.log('Banner created successfully:', banner._id);
    res.status(201).json(banner);
  } catch (err) {
    console.error('Create banner error:', err);
    // Nếu lỗi, xóa ảnh vừa upload trên Cloudinary
    if (req.file?.path) {
      try {
        await deleteCloudinaryImage(req.file.path);
      } catch (deleteErr) {
        console.error('Failed to delete uploaded image:', deleteErr);
      }
    }
    res.status(400).json({ message: err.message });
  }
});

// Cập nhật banner
router.put('/:id', isAdmin, upload.single('image'), async (req, res) => {
  try {
    console.log('Update banner - ID:', req.params.id);
    console.log('Update banner - Body:', req.body);
    console.log('Update banner - File:', req.file);

    const banner = await Banner.findById(req.params.id);
    if (!banner) {
      // Nếu không tìm thấy banner, xóa ảnh vừa upload
      if (req.file?.path) {
        await deleteCloudinaryImage(req.file.path);
      }
      return res.status(404).json({ message: 'Không tìm thấy banner' });
    }

    const updateData = {
      title: req.body.title ? req.body.title.trim() : banner.title,
      description: req.body.description ? req.body.description.trim() : banner.description,
      link: req.body.link ? req.body.link.trim() : banner.link,
      isActive: req.body.isActive === 'true' || req.body.isActive === true,
      position: req.body.position ? parseInt(req.body.position) : banner.position,
      updatedAt: Date.now(),
    };

    // Nếu có ảnh mới, xóa ảnh cũ trên Cloudinary và cập nhật
    if (req.file) {
      const oldImageUrl = banner.imageUrl;
      
      // Cập nhật với ảnh mới
      updateData.imageUrl = req.file.path;
      updateData.cloudinaryId = req.file.filename;
      
      // Xóa ảnh cũ sau khi cập nhật thành công
      try {
        if (oldImageUrl && oldImageUrl.includes('cloudinary.com')) {
          await deleteCloudinaryImage(oldImageUrl);
          console.log('Old image deleted from Cloudinary');
        }
      } catch (deleteErr) {
        console.warn('Could not delete old image:', deleteErr.message);
      }
    }

    const updated = await Banner.findByIdAndUpdate(
      req.params.id,
      updateData,
      { new: true }
    );
    
    console.log('Banner updated successfully:', updated._id);
    res.json(updated);
  } catch (err) {
    console.error('Update banner error:', err);
    // Nếu lỗi, xóa ảnh mới vừa upload
    if (req.file?.path) {
      try {
        await deleteCloudinaryImage(req.file.path);
      } catch (deleteErr) {
        console.error('Failed to delete uploaded image:', deleteErr);
      }
    }
    res.status(400).json({ message: err.message });
  }
});

// Xóa banner
router.delete('/:id', isAdmin, async (req, res) => {
  try {
    console.log('Delete banner - ID:', req.params.id);

    const banner = await Banner.findById(req.params.id);
    if (!banner) {
      return res.status(404).json({ message: 'Không tìm thấy banner' });
    }

    // Xóa ảnh trên Cloudinary
    try {
      if (banner.imageUrl && banner.imageUrl.includes('cloudinary.com')) {
        await deleteCloudinaryImage(banner.imageUrl);
        console.log('Banner image deleted from Cloudinary');
      }
    } catch (deleteErr) {
      console.warn('Could not delete banner image from Cloudinary:', deleteErr.message);
    }

    // Xóa document từ database
    await Banner.findByIdAndDelete(req.params.id);
    
    console.log('Banner deleted successfully:', req.params.id);
    res.json({ message: 'Xóa banner thành công' });
  } catch (err) {
    console.error('Delete banner error:', err);
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;