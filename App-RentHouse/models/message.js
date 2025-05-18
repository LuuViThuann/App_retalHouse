const mongoose = require('mongoose');

const messageSchema = new mongoose.Schema({
  conversationId: { type: String, ref: 'Conversation', required: true },
  senderId: { type: String, ref: 'User', required: true },
  content: { type: String, required: true },
  createdAt: { type: Date, default: Date.now },
  read: { type: Boolean, default: false }, // Track if the message has been read
});

// Create indexes for efficient querying
messageSchema.index({ conversationId: 1, createdAt: -1 });

module.exports = mongoose.model('Message', messageSchema);