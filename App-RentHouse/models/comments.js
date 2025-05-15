const mongoose = require('mongoose');

const commentSchema = new mongoose.Schema({
  rentalId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Rental',
    required: true,
  },
  userId: {
    type: String,
    ref: 'User',
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
    default: 0,
  },
  images: [{
    type: String,
  }],
  createdAt: {
    type: Date,
    default: Date.now,
  },
  replies: [{
    userId: { type: String, ref: 'User', required: true },
    content: { type: String, required: true },
    createdAt: { type: Date, default: Date.now },
  }],
  likes: [{
    userId: { type: String, ref: 'User', required: true },
    createdAt: { type: Date, default: Date.now },
  }],
});

module.exports = mongoose.model('Comment', commentSchema);