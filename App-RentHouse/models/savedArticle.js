
const mongoose = require('mongoose');

const savedArticleSchema = new mongoose.Schema({
  userId: {
    type: String,  // Firebase UID là string, không phải ObjectId
    required: true,
  },
  newsId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'News',
    required: true,
  },
  savedAt: {
    type: Date,
    default: Date.now,
  },
});

// Tạo index để đảm bảo mỗi user chỉ save 1 bài một lần
savedArticleSchema.index({ userId: 1, newsId: 1 }, { unique: true });
savedArticleSchema.index({ userId: 1, savedAt: -1 });

module.exports = mongoose.model('SavedArticle', savedArticleSchema);