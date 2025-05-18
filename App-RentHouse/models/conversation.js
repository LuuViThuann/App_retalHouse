const mongoose = require('mongoose');

const conversationSchema = new mongoose.Schema({
  participants: [{ type: String, ref: 'User', required: true }], // Array of user IDs
  rentalId: { type: String, ref: 'Rental', required: true }, // Reference to the rental post
  lastMessage: { type: String, ref: 'Message' }, // Reference to the last message
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now },
});

// Create an index on createdAt for efficient sorting
conversationSchema.index({ createdAt: -1 });

// Update the updatedAt field on save
conversationSchema.pre('save', function(next) {
  this.updatedAt = Date.now();
  next();
});

module.exports = mongoose.model('Conversation', conversationSchema);