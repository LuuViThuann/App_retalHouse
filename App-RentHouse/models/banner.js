// models/banner.js
const mongoose = require('mongoose');

const bannerSchema = new mongoose.Schema({
  title: {
    type: String,
    trim: true,
  },
  description: {
    type: String,
    trim: true,
    default: '',
  },
  imageUrl: {
    type: String,
    required: [true, 'URL ảnh không được để trống'],
  },
  cloudinaryId: {
    type: String,
    // Public ID của ảnh trên Cloudinary (để xóa ảnh sau này)
  },
  rentalId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Rental',
    default: null,
    sparse: true,
  },
  newsId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'News',
    default: null,
    sparse: true,
  },
  link: {
    type: String,
    trim: true,
    default: '',
  },
  isActive: {
    type: Boolean,
    default: true,
  },
  position: {
    type: Number,
    default: 0,
    min: [0, 'Vị trí phải >= 0'],
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
bannerSchema.index({ isActive: 1, position: 1 });
bannerSchema.index({ position: 1 });

// Middleware: tự động cập nhật updatedAt trước khi save
bannerSchema.pre('save', function(next) {
  this.updatedAt = Date.now();
  next();
});

// Middleware: tự động cập nhật updatedAt trước khi update
bannerSchema.pre('findOneAndUpdate', function(next) {
  this.set({ updatedAt: Date.now() });
  next();
});

// Sắp xếp theo position khi query
bannerSchema.pre('find', function() {
  this.sort({ position: 1 });
});

// Virtual field: Kiểm tra xem có phải ảnh Cloudinary không
bannerSchema.virtual('isCloudinaryImage').get(function() {
  return this.imageUrl && this.imageUrl.includes('cloudinary.com');
});

// Method: Lấy thông tin để xóa ảnh Cloudinary
bannerSchema.methods.getCloudinaryDeleteInfo = function() {
  if (!this.isCloudinaryImage) {
    return null;
  }
  
  // Nếu có cloudinaryId, dùng nó
  if (this.cloudinaryId) {
    return this.cloudinaryId;
  }
  
  // Nếu không, extract từ URL
  try {
    const urlParts = this.imageUrl.split('/');
    const publicIdWithExt = urlParts[urlParts.length - 1];
    const publicId = `banners/${publicIdWithExt.split('.')[0]}`;
    return publicId;
  } catch (error) {
    console.error('Error extracting cloudinary ID:', error);
    return null;
  }
};

// Static method: Tìm banner active
bannerSchema.statics.findActive = function() {
  return this.find({ isActive: true }).sort({ position: 1 });
};

// Static method: Lấy vị trí cao nhất hiện tại
bannerSchema.statics.getMaxPosition = async function() {
  const banner = await this.findOne().sort({ position: -1 }).select('position');
  return banner ? banner.position : 0;
};

// Đảm bảo virtual fields được include khi convert to JSON
bannerSchema.set('toJSON', {
  virtuals: true,
  transform: function(doc, ret) {
    // Xóa các field không cần thiết khi trả về JSON
    delete ret.__v;
    return ret;
  }
});

module.exports = mongoose.model('Banner', bannerSchema);