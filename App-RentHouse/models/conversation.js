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
    default: true, // Marks if the conversation is pending (unanswered by landlord)
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

// Create an index on createdAt for efficient sorting
conversationSchema.index({ createdAt: -1 });
// Index on participants for quick lookup
conversationSchema.index({ participants: 1, rentalId: 1 });

conversationSchema.pre('save', function(next) {
  this.updatedAt = Date.now();
  next();
});

module.exports = mongoose.model('Conversation', conversationSchema);