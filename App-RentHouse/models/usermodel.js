const mongoose = require('mongoose');
const bcrypt = require('bcrypt');

const userSchema = new mongoose.Schema({
  _id: {
    type: String, // Explicitly define _id as String to match Firebase UID
    required: true,
  },
  username: {
    type: String,
    required: true,
    unique: true,
  },
  password: {
    type: String,
    required: false, // Changed to optional since Firebase manages passwords
  },
  email: {
    type: String,
    required: false, // Changed to optional with a fallback in the endpoint
    unique: true,
    sparse: true, // Allows multiple documents with no email field
  },
  phoneNumber: {
    type: String,
    required: true,
  },
  avatarBase64: {
    type: String,
    default: null, // Store Base64 string of the profile image
  },
});

// Remove pre-save middleware for password hashing since Firebase manages authentication
userSchema.pre('save', async function (next) {
  next();
});

// Remove comparePassword method since it's not needed with Firebase
// userSchema.methods.comparePassword = async function (candidatePassword) {
//   return await bcrypt.compare(candidatePassword, this.password);
// };

// Tạo model từ schema và xuất nó
module.exports = mongoose.model('User', userSchema);