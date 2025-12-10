// models/aboutUs.js
const mongoose = require('mongoose');

const aboutUsSchema = new mongoose.Schema({
  title: {
    type: String,
    required: [true, 'Tiêu đề không được để trống'],
  },
  description: {
    type: String,
    required: [true, 'Mô tả không được để trống'],
  },
  // Mảng ảnh mới (Cloudinary)
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
  createdBy: {
    type: String,
    required: true,
  },
  createdAt: {
    type: Date,
    default: Date.now,
  },
  updatedAt: {
    type: Date,
    default: Date.now,
  },
  isActive: {
    type: Boolean,
    default: true,
  },
});

// Index
aboutUsSchema.index({ isActive: 1, createdAt: -1 });

// Middleware: tự động cập nhật updatedAt
aboutUsSchema.pre('save', function(next) {
  this.updatedAt = Date.now();
  next();
});

aboutUsSchema.pre('findOneAndUpdate', function(next) {
  this.set({ updatedAt: Date.now() });
  next();
});

// Virtual: Kiểm tra có phải ảnh Cloudinary không
aboutUsSchema.virtual('hasCloudinaryImages').get(function() {
  return this.images && this.images.length > 0 && 
         this.images[0].url && this.images[0].url.includes('cloudinary.com');
});

// Virtual: Lấy tất cả URLs
aboutUsSchema.virtual('imageUrls').get(function() {
  if (this.images && this.images.length > 0) {
    return this.images
      .sort((a, b) => (a.order || 0) - (b.order || 0))
      .map(img => img.url);
  }
  return [];
});

// Method: Lấy cloudinary IDs để xóa
aboutUsSchema.methods.getCloudinaryDeleteInfo = function() {
  const deleteInfo = [];
  
  if (this.images && this.images.length > 0) {
    this.images.forEach(img => {
      if (img.cloudinaryId) {
        deleteInfo.push(img.cloudinaryId);
      } else if (img.url && img.url.includes('cloudinary.com')) {
        try {
          const urlParts = img.url.split('/');
          const publicIdWithExt = urlParts[urlParts.length - 1];
          const publicId = `aboutus/${publicIdWithExt.split('.')[0]}`;
          deleteInfo.push(publicId);
        } catch (error) {
          console.error('Error extracting cloudinary ID:', error);
        }
      }
    });
  }
  
  return deleteInfo;
};

// Method: Thêm ảnh
aboutUsSchema.methods.addImage = function(url, cloudinaryId) {
  if (!this.images) {
    this.images = [];
  }
  
  const order = this.images.length;
  this.images.push({ url, cloudinaryId, order });
};

// Method: Xóa ảnh theo URL
aboutUsSchema.methods.removeImageByUrl = function(url) {
  if (this.images) {
    this.images = this.images.filter(img => img.url !== url);
    
    // Re-order
    this.images.forEach((img, i) => {
      img.order = i;
    });
  }
};

// Static method: Lấy active AboutUs
aboutUsSchema.statics.getActive = function() {
  return this.findOne({ isActive: true })
    .select('-__v')
    .lean();
};

// Đảm bảo virtual fields được include khi convert to JSON
aboutUsSchema.set('toJSON', {
  virtuals: true,
  transform: function(doc, ret) {
    delete ret.__v;
    return ret;
  }
});

module.exports = mongoose.model('AboutUs', aboutUsSchema);