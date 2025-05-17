const mongoose = require('mongoose');

const replySchema = new mongoose.Schema({
  commentId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Comment',
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
  images: [{
    type: String,
  }],
  createdAt: {
    type: Date,
    default: Date.now,
  },
  replyToUserId: {
    type: String,
    ref: 'User',
  },
  parentReplyId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Reply',
  },
});

module.exports = mongoose.model('Reply', replySchema);