const mongoose = require('mongoose');
const bcrypt = require('bcrypt');

const userSchema = new mongoose.Schema({
  username: {
    type: String,
    required: true,
    unique: true,
  },
  password: {
    type: String,
    required: true,
  },
  email: {
    type: String,
    required: true,
    unique: true,
  },
  phoneNumber: {
    type: String,
    required: true,
  },
});

userSchema.pre('save', async function (next) {
    if (this.isModified('password')) {
       // const salt = await bcrypt.genSalt(10);
        this.password = await bcrypt.hash(this.password, 10);
    }
    next();
});

// so sánh mật khẩu
userSchema.methods.comparePassword = async function (candidatePassword) {
    return await bcrypt.compare(candidatePassword, this.password);
};

// Tạo model từ schema và xuất nó
module.exports = mongoose.model('User', userSchema);