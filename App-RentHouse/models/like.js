const mongoose = require('mongoose');

const likeSchema = new mongoose.Schema({
  commentId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Comment',
  },
  replyId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Reply',
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

module.exports = mongoose.model('Like', likeSchema);