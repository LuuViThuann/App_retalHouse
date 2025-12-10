// models/news.js
const mongoose = require('mongoose');

const newsSchema = new mongoose.Schema({
  title: {
    type: String,
    required: [true, 'Tiêu đề không được để trống'],
    trim: true,
  },
  content: {
    type: String, // JSON từ flutter_quill (Delta format)
    required: [true, 'Nội dung không được để trống'],
  },
  summary: {
    type: String,
    trim: true,
    default: '',
  },
  // Mảng ảnh mới (Cloudinary) - RECOMMENDED
  images: [{
    url: {
      type: String,
      required: true,
    },
    cloudinaryId: {
      type: String,
    },
    order: {
      type: Number,
      default: 0,
    },
  }],
  // Giữ lại imageUrls để backward compatibility với code cũ
  imageUrls: {
    type: [String],
    default: [],
  },
  // Giữ lại imageUrl để tương thích (ảnh đầu tiên)
  imageUrl: {
    type: String,
    required: [true, 'Ảnh đại diện không được để trống'],
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
    min: [0, 'Views không được âm'],
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

// Index để tăng tốc query
newsSchema.index({ isActive: 1, featured: -1, createdAt: -1 });
newsSchema.index({ category: 1, isActive: 1 });
newsSchema.index({ createdAt: -1 });
newsSchema.index({ featured: 1, isActive: 1 });

// Middleware: Tự động cập nhật updatedAt và sync imageUrl từ images/imageUrls
newsSchema.pre('save', function(next) {
  this.updatedAt = Date.now();
  
  // Sync imageUrl từ images (ưu tiên) hoặc imageUrls
  if (this.images && this.images.length > 0) {
    // Sort by order
    this.images.sort((a, b) => (a.order || 0) - (b.order || 0));
    this.imageUrl = this.images[0].url;
    
    // Sync imageUrls từ images để backward compatibility
    this.imageUrls = this.images.map(img => img.url);
  } else if (this.imageUrls && this.imageUrls.length > 0) {
    this.imageUrl = this.imageUrls[0];
  }
  
  next();
});

newsSchema.pre('findOneAndUpdate', function(next) {
  this.set({ updatedAt: Date.now() });
  
  const update = this.getUpdate();
  
  // Sync imageUrl từ images hoặc imageUrls trong update
  if (update.images && update.images.length > 0) {
    update.images.sort((a, b) => (a.order || 0) - (b.order || 0));
    update.imageUrl = update.images[0].url;
    update.imageUrls = update.images.map(img => img.url);
  } else if (update.imageUrls && update.imageUrls.length > 0) {
    update.imageUrl = update.imageUrls[0];
  }
  
  next();
});

// Virtual: Kiểm tra có phải ảnh Cloudinary không
newsSchema.virtual('hasCloudinaryImages').get(function() {
  return this.images && this.images.length > 0 && 
         this.images[0].url && this.images[0].url.includes('cloudinary.com');
});

// Virtual: Lấy tất cả URLs (để hiển thị)
newsSchema.virtual('allImageUrls').get(function() {
  if (this.images && this.images.length > 0) {
    return this.images
      .sort((a, b) => (a.order || 0) - (b.order || 0))
      .map(img => img.url);
  }
  return this.imageUrls || [this.imageUrl];
});

// Virtual: Đếm số ảnh
newsSchema.virtual('imageCount').get(function() {
  if (this.images && this.images.length > 0) {
    return this.images.length;
  }
  return this.imageUrls ? this.imageUrls.length : (this.imageUrl ? 1 : 0);
});

// Method: Lấy thông tin để xóa ảnh Cloudinary
newsSchema.methods.getCloudinaryDeleteInfo = function() {
  const deleteInfo = [];
  
  if (this.images && this.images.length > 0) {
    this.images.forEach(img => {
      if (img.cloudinaryId) {
        deleteInfo.push(img.cloudinaryId);
      } else if (img.url && img.url.includes('cloudinary.com')) {
        // Extract từ URL nếu không có cloudinaryId
        try {
          const urlParts = img.url.split('/');
          const publicIdWithExt = urlParts[urlParts.length - 1];
          const publicId = `news/${publicIdWithExt.split('.')[0]}`;
          deleteInfo.push(publicId);
        } catch (error) {
          console.error('Error extracting cloudinary ID:', error);
        }
      }
    });
  }
  
  return deleteInfo;
};

// Method: Thêm ảnh mới
newsSchema.methods.addImage = function(url, cloudinaryId) {
  if (!this.images) {
    this.images = [];
  }
  
  const order = this.images.length;
  this.images.push({ url, cloudinaryId, order });
  
  // Sync
  if (this.images.length === 1) {
    this.imageUrl = url;
  }
  this.imageUrls = this.images.map(img => img.url);
};

// Method: Xóa ảnh theo index
newsSchema.methods.removeImageAtIndex = function(index) {
  if (this.images && this.images.length > index) {
    this.images.splice(index, 1);
    
    // Re-order
    this.images.forEach((img, i) => {
      img.order = i;
    });
    
    // Sync
    if (this.images.length > 0) {
      this.imageUrl = this.images[0].url;
      this.imageUrls = this.images.map(img => img.url);
    } else {
      this.imageUrl = '';
      this.imageUrls = [];
    }
  }
};

// Static method: Tìm tin tức active
newsSchema.statics.findActive = function(options = {}) {
  const query = { isActive: true };
  if (options.featured !== undefined) {
    query.featured = options.featured;
  }
  if (options.category) {
    query.category = options.category;
  }
  return this.find(query).sort({ featured: -1, createdAt: -1 });
};

// Static method: Tìm tin tức featured
newsSchema.statics.findFeatured = function(limit = 3) {
  return this.find({ isActive: true, featured: true })
    .sort({ createdAt: -1 })
    .limit(limit);
};

// Static method: Tìm theo category
newsSchema.statics.findByCategory = function(category, limit = 10) {
  return this.find({ isActive: true, category })
    .sort({ createdAt: -1 })
    .limit(limit);
};

// Static method: Tìm tin tức liên quan (cùng category, trừ tin hiện tại)
newsSchema.statics.findRelated = function(newsId, category, limit = 5) {
  return this.find({ 
    _id: { $ne: newsId },
    category,
    isActive: true 
  })
    .sort({ createdAt: -1 })
    .limit(limit);
};

// Static method: Tăng views
newsSchema.statics.incrementViews = function(newsId) {
  return this.findByIdAndUpdate(
    newsId,
    { $inc: { views: 1 } },
    { new: true }
  );
};

// Static method: Tìm tin tức phổ biến
newsSchema.statics.findPopular = function(limit = 10, days = 30) {
  const date = new Date();
  date.setDate(date.getDate() - days);
  
  return this.find({ 
    isActive: true,
    createdAt: { $gte: date }
  })
    .sort({ views: -1, createdAt: -1 })
    .limit(limit);
};

// Đảm bảo virtual fields được include khi convert to JSON
newsSchema.set('toJSON', {
  virtuals: true,
  transform: function(doc, ret) {
    delete ret.__v;
    return ret;
  }
});

newsSchema.set('toObject', {
  virtuals: true,
});

module.exports = mongoose.model('News', newsSchema);