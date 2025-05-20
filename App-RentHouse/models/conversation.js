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
  createdAt: {
    type: Date,
    default: Date.now,
  },
  updatedAt: {
    type: Date,
    default: Date.now,
  },
});

conversationSchema.pre('save', function(next) {
  this.updatedAt = Date.now();
  next();
});

conversationSchema.index({ participants: 1, rentalId: 1 });
conversationSchema.index({ updatedAt: -1 });

module.exports = mongoose.model('Conversation', conversationSchema);