// routes/news.js
const express = require('express');
const router = express.Router();
const News = require('../models/news');
const SavedArticle = require('../models/savedArticle');
const multer = require('multer');
const cloudinary = require('../config/cloudinary');
const { CloudinaryStorage } = require('multer-storage-cloudinary');

// Cấu hình Cloudinary Storage cho multer (nhiều ảnh)
const storage = new CloudinaryStorage({
  cloudinary: cloudinary,
  params: {
    folder: 'news', // Thư mục trong Cloudinary
    allowed_formats: ['jpg', 'jpeg', 'png', 'webp'],
    transformation: [{ width: 1920, height: 1080, crop: 'limit' }], // Resize ảnh
  },
});

const upload = multer({
  storage,
  limits: { fileSize: 10 * 1024 * 1024 }, // 10MB
  fileFilter: (req, file, cb) => {
    const allowedExtensions = /\.(jpeg|jpg|png|webp)$/i;
    const extname = allowedExtensions.test(file.originalname);
    
    if (extname) {
      return cb(null, true);
    }
    cb(new Error('Chỉ chấp nhận file ảnh (JPEG, JPG, PNG, WebP)'));
  },
});

// Helper function: Xóa nhiều ảnh trên Cloudinary
const deleteCloudinaryImages = async (cloudinaryIds) => {
  if (!cloudinaryIds || cloudinaryIds.length === 0) {
    return [];
  }
  
  const results = [];
  for (const publicId of cloudinaryIds) {
    try {
      const result = await cloudinary.uploader.destroy(publicId);
      results.push({ publicId, result });
      console.log('Cloudinary delete:', publicId, result);
    } catch (error) {
      console.error('Error deleting from Cloudinary:', publicId, error);
      results.push({ publicId, error: error.message });
    }
  }
  return results;
};

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

    const news = await News.findActive()
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
    const news = await News.findFeatured(limit);
    res.json(news);
  } catch (err) {
    console.error('Get featured news error:', err);
    res.status(500).json({ message: err.message });
  }
});

// Lấy tin tức phổ biến (most views)
router.get('/popular', async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 10;
    const days = parseInt(req.query.days) || 30;
    const news = await News.findPopular(limit, days);
    res.json(news);
  } catch (err) {
    console.error('Get popular news error:', err);
    res.status(500).json({ message: err.message });
  }
});

// Lấy tin tức theo category
router.get('/category/:category', async (req, res) => {
  try {
    const { category } = req.params;
    const limit = parseInt(req.query.limit) || 10;
    const page = parseInt(req.query.page) || 1;
    const skip = (page - 1) * limit;

    const news = await News.findByCategory(category, limit + skip).skip(skip);
    const total = await News.countDocuments({ isActive: true, category });

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
    console.error('Get news by category error:', err);
    res.status(500).json({ message: err.message });
  }
});

// ================== ROUTES CÓ YÊU CẦU ĐĂNG NHẬP ==================

// Lấy tất cả tin tức đã lưu của user
router.get('/user/saved-articles', isAuth, async (req, res) => {
  try {
    const userId = req.user.uid;
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 10;
    const skip = (page - 1) * limit;

    console.log('Fetching saved articles for user:', userId);

    const savedArticles = await SavedArticle.find({ userId })
      .sort({ savedAt: -1 })
      .skip(skip)
      .limit(limit);

    const newsIds = savedArticles.map(item => item.newsId);
    const news = await News.find({ _id: { $in: newsIds }, isActive: true });

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

    const news = await News.findById(newsId);
    if (!news) {
      return res.status(404).json({ message: 'Không tìm thấy tin tức' });
    }

    const existing = await SavedArticle.findOne({ userId, newsId });
    if (existing) {
      return res.status(400).json({ message: 'Bạn đã lưu tin tức này' });
    }

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

    const saved = await SavedArticle.findOne({ userId, newsId });
    res.json({ isSaved: !!saved });
  } catch (err) {
    console.error('Check saved article error:', err);
    res.status(500).json({ message: err.message });
  }
});

// Lấy chi tiết tin tức (auto increment views)
router.get('/:id', async (req, res) => {
  try {
    const news = await News.incrementViews(req.params.id);

    if (!news || !news.isActive) {
      return res.status(404).json({ message: 'Không tìm thấy tin tức' });
    }

    // Lấy tin tức liên quan
    const related = await News.findRelated(news._id, news.category, 5);

    res.json({
      ...news.toJSON(),
      related,
    });
  } catch (err) {
    console.error('Get news detail error:', err);
    res.status(500).json({ message: err.message });
  }
});

// ================== ROUTES ADMIN ==================

// Admin: Lấy tất cả tin tức
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

// Admin: Thêm tin tức mới (multiple images)
router.post('/', isAdmin, upload.array('images', 10), async (req, res) => {
  let uploadedFiles = [];
  
  try {
    console.log('Create news - Body:', req.body);
    console.log('Create news - Files:', req.files?.length);

    const { title, content, summary, author, category, featured } = req.body;

    if (!req.files || req.files.length === 0) {
      return res.status(400).json({ message: 'Vui lòng upload ít nhất 1 ảnh' });
    }

    if (!title || !content) {
      // Xóa ảnh đã upload nếu validation fail
      uploadedFiles = req.files.map(f => f.filename);
      await deleteCloudinaryImages(uploadedFiles);
      return res.status(400).json({ message: 'Tiêu đề và nội dung không được bỏ trống' });
    }

    // Tạo mảng image data từ các file Cloudinary
    const images = req.files.map((file, index) => ({
      url: file.path, // URL từ Cloudinary
      cloudinaryId: file.filename, // Public ID
      order: index,
    }));

    const news = new News({
      title: title.trim(),
      content: content, // JSON Delta format từ Quill
      summary: summary ? summary.trim() : title.trim().substring(0, 100),
      images: images,
      imageUrl: images[0].url, // Ảnh đầu tiên (auto-sync bởi pre-save)
      imageUrls: images.map(img => img.url), // Auto-sync
      author: author ? author.trim() : 'Admin',
      category: category ? category.trim() : 'Tin tức',
      featured: featured === 'true' || featured === true,
      isActive: true,
    });

    await news.save();
    console.log('News created successfully:', news._id, 'Images:', images.length);
    res.status(201).json(news);
  } catch (err) {
    console.error('Create news error:', err);
    
    // Nếu lỗi, xóa tất cả ảnh vừa upload
    if (req.files?.length > 0) {
      uploadedFiles = req.files.map(f => f.filename);
      await deleteCloudinaryImages(uploadedFiles);
    }
    
    res.status(400).json({ message: err.message });
  }
});

// Admin: Cập nhật tin tức (multiple images)
router.put('/:id', isAdmin, upload.array('images', 10), async (req, res) => {
  let uploadedFiles = [];
  
  try {
    console.log('Update news - ID:', req.params.id);
    console.log('Update news - Body:', req.body);
    console.log('Update news - New files:', req.files?.length);

    const news = await News.findById(req.params.id);
    if (!news) {
      // Nếu không tìm thấy, xóa ảnh vừa upload
      if (req.files?.length > 0) {
        uploadedFiles = req.files.map(f => f.filename);
        await deleteCloudinaryImages(uploadedFiles);
      }
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

    // Lưu cloudinary IDs của ảnh cũ để xóa sau
    const oldCloudinaryIds = news.getCloudinaryDeleteInfo();

    // Nếu có ảnh mới, thay thế tất cả
    if (req.files && req.files.length > 0) {
      const newImages = req.files.map((file, index) => ({
        url: file.path,
        cloudinaryId: file.filename,
        order: index,
      }));
      
      updateData.images = newImages;
      // imageUrl và imageUrls sẽ auto-sync bởi pre-update middleware
    }

    const updated = await News.findByIdAndUpdate(
      req.params.id,
      updateData,
      { new: true, runValidators: true }
    );

    // Xóa ảnh cũ sau khi cập nhật thành công
    if (req.files && req.files.length > 0 && oldCloudinaryIds.length > 0) {
      await deleteCloudinaryImages(oldCloudinaryIds);
      console.log('Old images deleted from Cloudinary:', oldCloudinaryIds.length);
    }

    console.log('News updated successfully:', updated._id);
    res.json(updated);
  } catch (err) {
    console.error('Update news error:', err);
    
    // Nếu lỗi, xóa ảnh mới vừa upload
    if (req.files?.length > 0) {
      uploadedFiles = req.files.map(f => f.filename);
      await deleteCloudinaryImages(uploadedFiles);
    }
    
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

    // Lấy cloudinary IDs để xóa
    const cloudinaryIds = news.getCloudinaryDeleteInfo();

    // Xóa document từ database
    await News.findByIdAndDelete(req.params.id);

    // Xóa ảnh trên Cloudinary
    if (cloudinaryIds.length > 0) {
      await deleteCloudinaryImages(cloudinaryIds);
      console.log('Images deleted from Cloudinary:', cloudinaryIds.length);
    }
    
    console.log('News deleted successfully:', req.params.id);
    res.json({ message: 'Xóa tin tức thành công' });
  } catch (err) {
    console.error('Delete news error:', err);
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;