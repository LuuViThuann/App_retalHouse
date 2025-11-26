// routes/news.js
const express = require('express');
const router = express.Router();
const News = require('../models/news');
const SavedArticle = require('../models/savedArticle');
const multer = require('multer');
const path = require('path');
const fs = require('fs');

// Cấu hình multer
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const uploadPath = 'Uploads/news/';
    if (!fs.existsSync(uploadPath)) {
      fs.mkdirSync(uploadPath, { recursive: true });
    }
    cb(null, uploadPath);
  },
  filename: (req, file, cb) => {
    cb(null, 'news_' + Date.now() + path.extname(file.originalname));
  },
});

const upload = multer({
  storage,
  limits: { fileSize: 10 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    const allowedExtensions = /\.(jpeg|jpg|png|webp)$/i;
    const extname = allowedExtensions.test(path.extname(file.originalname));
    
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

// Middleware kiểm tra user đã đăng nhập
const isAuth = async (req, res, next) => {
  try {
    const token = req.headers.authorization?.split('Bearer ')[1];
    if (!token) return res.status(401).json({ message: 'Không có token' });

    const decoded = await require('firebase-admin').auth().verifyIdToken(token);
    req.user = decoded;
    next();
  } catch (err) {
    console.error('Auth check error:', err);
    res.status(401).json({ message: 'Token không hợp lệ' });
  }
};

// ================== ROUTES CÔNG KHAI ==================

// Lấy tin tức công khai (active + featured)
router.get('/', async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 10;
    const skip = (page - 1) * limit;

    const news = await News.find({ isActive: true })
      .sort({ featured: -1, createdAt: -1 })
      .skip(skip)
      .limit(limit);

    const total = await News.countDocuments({ isActive: true });

    res.json({
      data: news,
      pagination: {
        total,
        page,
        limit,
        pages: Math.ceil(total / limit),
      },
    });
  } catch (err) {
    console.error('Get news error:', err);
    res.status(500).json({ message: err.message });
  }
});

// Lấy tin tức nổi bật (featured)
router.get('/featured', async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 3;
    const news = await News.find({ isActive: true, featured: true })
      .sort({ createdAt: -1 })
      .limit(limit);

    res.json(news);
  } catch (err) {
    console.error('Get featured news error:', err);
    res.status(500).json({ message: err.message });
  }
});

// ================== ROUTES CÓ YÊUAU ĐĂNG NHẬP ==================

// Lấy tất cả tin tức đã lưu của user (PHẢI TRƯỚC :id)
router.get('/user/saved-articles', isAuth, async (req, res) => {
  try {
    const userId = req.user.uid;
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 10;
    const skip = (page - 1) * limit;

    console.log('Fetching saved articles for user:', userId);

    // Lấy danh sách newsId đã lưu
    const savedArticles = await SavedArticle.find({ userId })
      .sort({ savedAt: -1 })
      .skip(skip)
      .limit(limit);

    const newsIds = savedArticles.map(item => item.newsId);

    // Lấy thông tin tin tức
    const news = await News.find({ _id: { $in: newsIds }, isActive: true });

    // Sắp xếp theo thứ tự lưu
    const orderedNews = newsIds
      .map(id => news.find(n => n._id.toString() === id.toString()))
      .filter(Boolean);

    const total = await SavedArticle.countDocuments({ userId });

    res.json({
      data: orderedNews,
      pagination: {
        total,
        page,
        limit,
        pages: Math.ceil(total / limit),
      },
    });
  } catch (err) {
    console.error('Get saved articles error:', err);
    res.status(500).json({ message: err.message });
  }
});

// Lưu tin tức
router.post('/:newsId/save', isAuth, async (req, res) => {
  try {
    const { newsId } = req.params;
    const userId = req.user.uid;

    console.log('Saving article - User:', userId, 'News:', newsId);

    // Kiểm tra tin tức tồn tại
    const news = await News.findById(newsId);
    if (!news) {
      return res.status(404).json({ message: 'Không tìm thấy tin tức' });
    }

    // Kiểm tra đã lưu chưa
    const existing = await SavedArticle.findOne({ userId, newsId });
    if (existing) {
      return res.status(400).json({ message: 'Bạn đã lưu tin tức này' });
    }

    // Tạo record lưu
    const saved = new SavedArticle({ userId, newsId });
    await saved.save();

    console.log('Article saved successfully:', saved._id);
    res.status(201).json({
      message: 'Đã lưu tin tức',
      data: saved,
    });
  } catch (err) {
    console.error('Save article error:', err);
    res.status(500).json({ message: err.message });
  }
});

// Bỏ lưu tin tức
router.delete('/:newsId/unsave', isAuth, async (req, res) => {
  try {
    const { newsId } = req.params;
    const userId = req.user.uid;

    console.log('Unsaving article - User:', userId, 'News:', newsId);

    const result = await SavedArticle.findOneAndDelete({ userId, newsId });

    if (!result) {
      return res.status(404).json({ message: 'Không tìm thấy tin tức đã lưu' });
    }

    console.log('Article unsaved successfully');
    res.json({ message: 'Đã bỏ lưu tin tức' });
  } catch (err) {
    console.error('Unsave article error:', err);
    res.status(500).json({ message: err.message });
  }
});

// Kiểm tra tin tức có được lưu không
router.get('/:newsId/is-saved', isAuth, async (req, res) => {
  try {
    const { newsId } = req.params;
    const userId = req.user.uid;

    console.log('Checking if saved - User:', userId, 'News:', newsId);

    const saved = await SavedArticle.findOne({ userId, newsId });

    res.json({ isSaved: !!saved });
  } catch (err) {
    console.error('Check saved article error:', err);
    res.status(500).json({ message: err.message });
  }
});

// Lấy chi tiết tin tức (PHẢI SAU /user/saved-articles và /:newsId/...)
router.get('/:id', async (req, res) => {
  try {
    const news = await News.findByIdAndUpdate(
      req.params.id,
      { $inc: { views: 1 } },
      { new: true }
    );

    if (!news || !news.isActive) {
      return res.status(404).json({ message: 'Không tìm thấy tin tức' });
    }

    res.json(news);
  } catch (err) {
    console.error('Get news detail error:', err);
    res.status(500).json({ message: err.message });
  }
});

// ================== ROUTES ADMIN ==================

// Admin: Lấy tất cả tin tức (kể cả không active)
router.get('/admin/all', isAdmin, async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 10;
    const skip = (page - 1) * limit;

    const news = await News.find()
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit);

    const total = await News.countDocuments();

    res.json({
      data: news,
      pagination: {
        total,
        page,
        limit,
        pages: Math.ceil(total / limit),
      },
    });
  } catch (err) {
    console.error('Get admin news error:', err);
    res.status(500).json({ message: err.message });
  }
});

// Admin: Thêm tin tức mới
router.post('/', isAdmin, upload.single('image'), async (req, res) => {
  try {
    console.log('Create news - Body:', req.body);
    console.log('Create news - File:', req.file);

    const { title, content, summary, author, category, featured } = req.body;

    if (!req.file) {
      return res.status(400).json({ message: 'Vui lòng upload ảnh' });
    }

    if (!title || !content) {
      return res.status(400).json({ message: 'Tiêu đề và nội dung không được bỏ trống' });
    }

    const news = new News({
      title: title.trim(),
      content: content,
      summary: summary ? summary.trim() : title.trim().substring(0, 100),
      imageUrl: `/Uploads/news/${req.file.filename}`,
      author: author ? author.trim() : 'Admin',
      category: category ? category.trim() : 'Tin tức',
      featured: featured === 'true' || featured === true,
      isActive: true,
    });

    await news.save();
    console.log('News created successfully:', news._id);
    res.status(201).json(news);
  } catch (err) {
    console.error('Create news error:', err);
    res.status(400).json({ message: err.message });
  }
});

// Admin: Cập nhật tin tức
router.put('/:id', isAdmin, upload.single('image'), async (req, res) => {
  try {
    console.log('Update news - ID:', req.params.id);
    console.log('Update news - Body:', req.body);

    const news = await News.findById(req.params.id);
    if (!news) {
      return res.status(404).json({ message: 'Không tìm thấy tin tức' });
    }

    const updateData = {
      title: req.body.title ? req.body.title.trim() : news.title,
      content: req.body.content ? req.body.content : news.content,
      summary: req.body.summary ? req.body.summary.trim() : news.summary,
      author: req.body.author ? req.body.author.trim() : news.author,
      category: req.body.category ? req.body.category.trim() : news.category,
      featured: req.body.featured === 'true' || req.body.featured === true,
      isActive: req.body.isActive === 'true' || req.body.isActive === true,
      updatedAt: Date.now(),
    };

    if (req.file) {
      const oldImagePath = '.' + news.imageUrl;
      if (fs.existsSync(oldImagePath)) {
        try {
          fs.unlinkSync(oldImagePath);
          console.log('Old image deleted:', oldImagePath);
        } catch (unlinkErr) {
          console.warn('Could not delete old image:', unlinkErr.message);
        }
      }
      updateData.imageUrl = `/Uploads/news/${req.file.filename}`;
    }

    const updated = await News.findByIdAndUpdate(
      req.params.id,
      updateData,
      { new: true }
    );

    console.log('News updated successfully:', updated._id);
    res.json(updated);
  } catch (err) {
    console.error('Update news error:', err);
    res.status(400).json({ message: err.message });
  }
});

// Admin: Xóa tin tức
router.delete('/:id', isAdmin, async (req, res) => {
  try {
    console.log('Delete news - ID:', req.params.id);

    const news = await News.findById(req.params.id);
    if (!news) {
      return res.status(404).json({ message: 'Không tìm thấy tin tức' });
    }

    const imagePath = '.' + news.imageUrl;
    if (fs.existsSync(imagePath)) {
      try {
        fs.unlinkSync(imagePath);
        console.log('News image deleted:', imagePath);
      } catch (unlinkErr) {
        console.warn('Could not delete news image:', unlinkErr.message);
      }
    }

    await News.findByIdAndDelete(req.params.id);
    
    console.log('News deleted successfully:', req.params.id);
    res.json({ message: 'Xóa tin tức thành công' });
  } catch (err) {
    console.error('Delete news error:', err);
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;