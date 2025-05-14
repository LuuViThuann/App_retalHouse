const mongoose = require('mongoose');
const commentSchema = new mongoose.Schema({

    // * thông tin bài viết 
  rentalId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Rental', // Lây từ model Rental
    required: true,
  },

  // * thông tin người dùng
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User', // Lây từ model User
    required: true,
  },

  // * thông tin nội dung bình luận
  content: {
    type: String,
    required: true,
  },

  // * thông tin thời gian tạo bình luận
  createdAt: {
    type: Date,
    default: Date.now,
  },

  // * Thông tin lưu trữ các bình luận trả lời
  replies: [{
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    content: { type: String, required: true },
    createdAt: { type: Date, default: Date.now },
  }],
  // * Thông tin lưu trữ các bình luận thích
  likes: [{
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    createdAt: { type: Date, default: Date.now },
  }],
});

module.exports = mongoose.model('Comment', commentSchema);