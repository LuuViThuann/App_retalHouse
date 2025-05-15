const mongoose = require('mongoose');

const commentSchema = new mongoose.Schema({
  // * Thông tin bài viết
  rentalId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Rental', // Lấy từ model Rental
    required: true,
  },

  // * Thông tin người dùng
  userId: {
    type: String, // Change to String to match User _id (Firebase UID)
    ref: 'User', // Lấy từ model User
    required: true,
  },

  // * Thông tin nội dung bình luận
  content: {
    type: String,
    required: true,
  },

  // * Thông tin thời gian tạo bình luận
  createdAt: {
    type: Date,
    default: Date.now,
  },

  // * Thông tin lưu trữ các bình luận trả lời
  replies: [{
    userId: { type: String, ref: 'User', required: true }, // Change to String
    content: { type: String, required: true },
    createdAt: { type: Date, default: Date.now },
  }],

  // * Thông tin lưu trữ các lượt thích
  likes: [{
    userId: { type: String, ref: 'User', required: true }, // Change to String
    createdAt: { type: Date, default: Date.now },
  }],
});

module.exports = mongoose.model('Comment', commentSchema);