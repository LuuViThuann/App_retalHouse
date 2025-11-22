// routes/banner.js
const express = require('express');
const router = express.Router();
const Banner = require('../models/banner');
const multer = require('multer');
const path = require('path');
const fs = require('fs');

// Cấu hình multer để lưu ảnh banner
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const uploadPath = 'Uploads/banners/';
    if (!fs.existsSync(uploadPath)) {
      fs.mkdirSync(uploadPath, { recursive: true });
    }
    cb(null, uploadPath);
  },
  filename: (req, file, cb) => {
    cb(null, 'banner_' + Date.now() + path.extname(file.originalname));
  },
});

const upload = multer({
  storage,
  limits: { fileSize: 5 * 1024 * 1024 }, // 5MB
  fileFilter: (req, file, cb) => {
    // Kiểm tra extension file (PRIMARY - vì MIME type có thể bị sai)
    const allowedExtensions = /\.(jpeg|jpg|png|webp)$/i;
    const extname = allowedExtensions.test(path.extname(file.originalname));
    
    // Kiểm tra MIME type (SECONDARY - fallback nếu extension đúng)
    const allowedMimeTypes = /^image\/(jpeg|jpg|png|webp|octet-stream)/i;
    const mimetype = allowedMimeTypes.test(file.mimetype);
    
    console.log('File:', file.originalname, 'Extension:', extname, 'MIME:', file.mimetype, 'MIMEValid:', mimetype);
    
    // Chỉ cần extension đúng là được (MIME type có thể bị sai từ Flutter)
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
    // Log request body và file
    console.log('Create banner - Body:', req.body);
    console.log('Create banner - File:', req.file);

    const { title, description, link, isActive, position } = req.body;
    
    // Kiểm tra các field bắt buộc
    if (!req.file) {
      return res.status(400).json({ message: 'Vui lòng upload ảnh' });
    }
   

    const banner = new Banner({
      title: title.trim(),
      description: description ? description.trim() : '',
      link: link ? link.trim() : '',
      isActive: isActive === 'true' || isActive === true,
      position: parseInt(position) || 0,
      imageUrl: `/Uploads/banners/${req.file.filename}`,
    });

    await banner.save();
    console.log('Banner created successfully:', banner._id);
    res.status(201).json(banner);
  } catch (err) {
    console.error('Create banner error:', err);
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

    // Nếu có ảnh mới, xóa ảnh cũ
    if (req.file) {
      const oldImagePath = '.' + banner.imageUrl;
      if (fs.existsSync(oldImagePath)) {
        try {
          fs.unlinkSync(oldImagePath);
          console.log('Old image deleted:', oldImagePath);
        } catch (unlinkErr) {
          console.warn('Could not delete old image:', unlinkErr.message);
        }
      }
      updateData.imageUrl = `/Uploads/banners/${req.file.filename}`;
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

    // Xóa file ảnh
    const imagePath = '.' + banner.imageUrl;
    if (fs.existsSync(imagePath)) {
      try {
        fs.unlinkSync(imagePath);
        console.log('Banner image deleted:', imagePath);
      } catch (unlinkErr) {
        console.warn('Could not delete banner image:', unlinkErr.message);
      }
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