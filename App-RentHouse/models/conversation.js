const mongoose = require('mongoose');

const conversationSchema = new mongoose.Schema({
  participants: [{
    type: String,
    ref: 'User',
    required: true,
  }],
  rentalId: {
    type: String,
    ref: 'Rental',
    required: true,
  },
  lastMessage: {
    type: mongoose.Schema.Types.ObjectId, 
    ref: 'Message',
  },
  isPending: {
    type: Boolean,
    default: true,
  },
  unreadCounts: {
    type: Map,
    of: Number,
    default: () => new Map(), // Ensure default is a new Map
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

// Initialize unreadCounts for all participants on save
conversationSchema.pre('save', function(next) {
  if (!this.unreadCounts || !(this.unreadCounts instanceof Map)) {
    this.unreadCounts = new Map();
  }
  // Ensure all participants have an unread count
  this.participants.forEach(participant => {
    if (!this.unreadCounts.has(participant)) {
      this.unreadCounts.set(participant, 0);
    }
  });
  this.updatedAt = Date.now();
  next();
});

conversationSchema.pre('find', function(next) {
  this.populate('lastMessage');
  next();
});

conversationSchema.index({ participants: 1, rentalId: 1 });
conversationSchema.index({ updatedAt: -1 });

module.exports = mongoose.model('Conversation', conversationSchema);