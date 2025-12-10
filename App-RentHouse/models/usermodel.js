const mongoose = require('mongoose');

const userSchema = new mongoose.Schema({
  _id: {
    type: String, 
    required: true,
  },
  username: {
    type: String,
    required: true,
  }, 
  password: {
    type: String,
    required: false, 
  },  
  email: {
    type: String,
    required: false, 
    unique: true,
    sparse: true,
  },
  phoneNumber: {
    type: String,
    required: true,
  },
  address: {
    type: String,
    default: '',
  },
  // ✅ Thay đổi: Lưu URL Cloudinary thay vì base64
  avatarUrl: {
    type: String,
    default: null,
  },
  // ✅ Thêm: Lưu publicId để có thể xóa ảnh sau này
  avatarPublicId: {
    type: String,
    default: null,
  },
  role: {
    type: String,
    enum: ['user', 'admin'],
    default: 'user',
    index: true,
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

// Middleware để cập nhật updatedAt
userSchema.pre('save', function(next) {
  this.updatedAt = Date.now();
  next();
});

module.exports = mongoose.model('User', userSchema);