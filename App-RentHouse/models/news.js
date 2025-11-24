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
  imageUrl: {
    type: String,
    required: true,
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

// Indexes
newsSchema.index({ createdAt: -1 });
newsSchema.index({ isActive: 1, featured: -1, createdAt: -1 });

module.exports = mongoose.model('News', newsSchema);