const mongoose = require('mongoose');

const feedbackSchema = new mongoose.Schema({
  userId: { type: String, required: true },
  userName: { type: String, required: true },
  userEmail: { type: String, required: true },
  feedbackType: {
    type: String,
    enum: ['bug', 'suggestion', 'complaint', 'other'],
    default: 'suggestion',
  },
  title: { type: String, required: true },
  content: { type: String, required: true },
  rating: { type: Number, min: 1, max: 5, default: 3 },
  attachments: [{ type: String }],
  status: {
    type: String,
    enum: ['pending', 'reviewing', 'resolved', 'closed'],
    default: 'pending',
  },
  adminResponse: { type: String },
  respondedBy: { type: String },
  respondedAt: { type: Date },
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now },
});

module.exports = mongoose.model('Feedback', feedbackSchema);