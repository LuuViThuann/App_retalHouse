const mongoose = require('mongoose');

const notificationSchema = new mongoose.Schema({
  userId: {
    type: String,
    ref: 'User',
    required: true,
    index: true,
  },
  type: {
    type: String,
    enum: ['rental_approved', 'rental_rejected', 'rental_deleted', 'Comment', 'Reply', 'Comment_Reply', 'message', 'feedback_response'],
    required: true,
    index: true,
  },
  title: {
    type: String,
    required: true,
  },
  message: {
    type: String,
    required: true,
  },
  rentalId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Rental',
    default: null,
  },
  // ✅ New fields for comment/reply notifications
  commentId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Comment',
    default: null,
  },
  replyId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Reply',
    default: null,
  },
  // Detailed information for UI display
  details: {
    type: mongoose.Schema.Types.Mixed,
    default: null,
  },
  read: {
    type: Boolean,
    default: false,
    index: true,
  },
  // For soft delete (trash functionality)
  isDeleted: {
    type: Boolean,
    default: false,
    index: true,
  },
  deletedAt: {
    type: Date,
    default: null,
  },
  createdAt: {
    type: Date,
    default: Date.now,
    index: true,
  },
  updatedAt: {
    type: Date,
    default: Date.now,
  },
});

// ✅ Compound indexes for efficient queries
notificationSchema.index({ userId: 1, createdAt: -1 });
notificationSchema.index({ userId: 1, read: 1, createdAt: -1 });
notificationSchema.index({ userId: 1, isDeleted: 1, createdAt: -1 });
notificationSchema.index({ userId: 1, type: 1, createdAt: -1 });

// TTL Index - xóa thông báo cũ hơn 30 ngày
notificationSchema.index({ createdAt: 1 }, { expireAfterSeconds: 2592000 });

module.exports = mongoose.model('Notification', notificationSchema);