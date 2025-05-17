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
  isHidden: {
    type: Boolean,
    default: false,
  },
});

const replySchema = new mongoose.Schema({
  commentId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Comment',
    required: true,
  },
  parentReplyId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Reply',
    default: null,
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
  images: [{
    type: String,
  }],
  icon: {
    type: String,
    default: '/assets/img/arr.jpg',
  },
  createdAt: {
    type: Date,
    default: Date.now,
  },
});

const likeCommentSchema = new mongoose.Schema({
  targetId: {
    type: mongoose.Schema.Types.ObjectId,
    required: true,
    refPath: 'targetType',
  },
  targetType: {
    type: String,
    enum: ['Comment', 'Reply'],
    required: true,
  },
  userId: {
    type: String,
    ref: 'User',
    required: true,
  },
  createdAt: {
    type: Date,
    default: Date.now,
  },
});

module.exports = {
  Comment: mongoose.model('Comment', commentSchema),
  Reply: mongoose.model('Reply', replySchema),
  LikeComment: mongoose.model('LikeComment', likeCommentSchema),
};