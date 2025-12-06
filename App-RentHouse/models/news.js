// models/news.js
const mongoose = require('mongoose');

const newsSchema = new mongoose.Schema({
  title: {
    type: String,
    required: true,
    trim: true,
  },
  content: {
    type: String, // JSON từ flutter_quill (Delta format)
    required: true,
  },
  summary: {
    type: String,
    trim: true,
  },
  // Thay đổi: Hỗ trợ nhiều ảnh
  imageUrls: {
    type: [String], // Mảng URLs
    default: [],
  },
  // Giữ lại imageUrl để tương thích (ảnh đầu tiên)
  imageUrl: {
    type: String,
  },
  author: {
    type: String,
    default: 'Admin',
    trim: true,
  },
  category: {
    type: String,
    default: 'Tin tức', 
    trim: true,
  },
  isActive: {
    type: Boolean,
    default: true,
  },
  views: {
    type: Number,
    default: 0,
  },
  featured: {
    type: Boolean,
    default: false,
  },
  createdAt: {
    type: Date,
    default: Date.now,
  },
  updatedAt: {
    type: Date,
    default: Date.now,
  },
});

// Middleware: Tự động set imageUrl từ imageUrls[0]
newsSchema.pre('save', function(next) {
  if (this.imageUrls && this.imageUrls.length > 0) {
    this.imageUrl = this.imageUrls[0];
  }
  next();
});

newsSchema.pre('findByIdAndUpdate', function(next) {
  const update = this.getUpdate();
  if (update.imageUrls && update.imageUrls.length > 0) {
    update.imageUrl = update.imageUrls[0];
  }
  next();
});

// Indexes
newsSchema.index({ createdAt: -1 });
newsSchema.index({ isActive: 1, featured: -1, createdAt: -1 });

module.exports = mongoose.model('News', newsSchema);