const mongoose = require('mongoose');
const bcrypt = require('bcrypt');

const userSchema = new mongoose.Schema({
  _id: { // sử dụng ObjectId tự động
    type: String, 
    required: true,
  },
  username: {
    type: String,
    required: true,
    unique: true,
  },
  password: {
    type: String,
    required: false, 
  },  
  email: {
    type: String,
    required: false, 
    unique: true,
    sparse: true, // cho phép nhiều bản ghi có giá trị null
  },
  phoneNumber: {
    type: String,
    required: true,
  },
  avatarBase64: {
    type: String,
    default: null, // lưu trữ ảnh đại diện dưới dạng base64
  },
});

// Không cần mã hóa mật khẩu vì Firebase đã xử lý điều đó
userSchema.pre('save', async function (next) {
  next();
});

// Remove comparePassword method since it's not needed with Firebase
// userSchema.methods.comparePassword = async function (candidatePassword) {
//   return await bcrypt.compare(candidatePassword, this.password);
// };

// Tạo model từ schema và xuất nó
module.exports = mongoose.model('User', userSchema);