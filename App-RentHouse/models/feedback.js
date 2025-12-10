
const mongoose = require('mongoose');

const feedbackSchema = new mongoose.Schema({
  userId: {
    type: String,
    required: true,
  },
  userName: {
    type: String,
    required: true,
  },
  userEmail: {
    type: String,
    required: true,
  },
  feedbackType: {
    type: String,
    enum: ['bug', 'suggestion', 'complaint', 'other'],
    default: 'suggestion',
  },
  title: {
    type: String,
    required: true,
  },
  content: {
    type: String,
    required: true,
  },
  rating: {
    type: Number,
    min: 1,
    max: 5,
    default: 3,
  },
  // Mảng attachments mới (Cloudinary)
  attachments: [{
    url: {
      type: String,
      required: true,
    },
    cloudinaryId: {
      type: String,
    },
    filename: {
      type: String,
    },
    uploadedAt: {
      type: Date,
      default: Date.now,
    },
  }],
  status: {
    type: String,
    enum: ['pending', 'reviewing', 'resolved', 'closed'],
    default: 'pending',
  },
  adminResponse: {
    type: String,
  },
  respondedBy: {
    type: String,
  },
  respondedAt: {
    type: Date,
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
feedbackSchema.index({ userId: 1, createdAt: -1 });
feedbackSchema.index({ status: 1, createdAt: -1 });
feedbackSchema.index({ feedbackType: 1, createdAt: -1 });

// Middleware: tự động cập nhật updatedAt
feedbackSchema.pre('save', function(next) {
  this.updatedAt = Date.now();
  next();
});

feedbackSchema.pre('findOneAndUpdate', function(next) {
  this.set({ updatedAt: Date.now() });
  next();
});

// Virtual: Kiểm tra có phải ảnh Cloudinary không
feedbackSchema.virtual('hasCloudinaryAttachments').get(function() {
  return this.attachments && this.attachments.length > 0 && 
         this.attachments[0].url && this.attachments[0].url.includes('cloudinary.com');
});

// Virtual: Lấy tất cả attachment URLs
feedbackSchema.virtual('attachmentUrls').get(function() {
  if (this.attachments && this.attachments.length > 0) {
    return this.attachments.map(att => att.url);
  }
  return [];
});

// Method: Lấy cloudinary IDs để xóa
feedbackSchema.methods.getCloudinaryDeleteInfo = function() {
  const deleteInfo = [];
  
  if (this.attachments && this.attachments.length > 0) {
    this.attachments.forEach(att => {
      if (att.cloudinaryId) {
        deleteInfo.push(att.cloudinaryId);
      } else if (att.url && att.url.includes('cloudinary.com')) {
        try {
          const urlParts = att.url.split('/');
          const publicIdWithExt = urlParts[urlParts.length - 1];
          const publicId = `feedback/${publicIdWithExt.split('.')[0]}`;
          deleteInfo.push(publicId);
        } catch (error) {
          console.error('Error extracting cloudinary ID:', error);
        }
      }
    });
  }
  
  return deleteInfo;
};

// Static method: Lấy feedback theo user
feedbackSchema.statics.findByUser = function(userId) {
  return this.find({ userId })
    .select('-__v')
    .sort({ createdAt: -1 });
};

// Static method: Lấy feedback theo status
feedbackSchema.statics.findByStatus = function(status) {
  return this.find({ status })
    .select('-__v')
    .sort({ createdAt: -1 });
};

// Static method: Thống kê
feedbackSchema.statics.getStats = function() {
  return this.aggregate([
    {
      $facet: {
        byStatus: [
          { $group: { _id: '$status', count: { $sum: 1 } } },
        ],
        byType: [
          { $group: { _id: '$feedbackType', count: { $sum: 1 } } },
        ],
        averageRating: [
          { $group: { _id: null, avg: { $avg: '$rating' } } },
        ],
        totalFeedbacks: [{ $count: 'total' }],
      },
    },
  ]);
};

// Đảm bảo virtual fields được include khi convert to JSON
feedbackSchema.set('toJSON', {
  virtuals: true,
  transform: function(doc, ret) {
    delete ret.__v;
    return ret;
  }
});

module.exports = mongoose.model('Feedback', feedbackSchema);