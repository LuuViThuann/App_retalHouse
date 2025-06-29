const mongoose = require('mongoose');

const bookingSchema = new mongoose.Schema({
  // Thông tin người đặt chỗ
  userId: {
    type: String,
    required: true,
    ref: 'User'
  },
  // Thông tin nhà cho thuê
  rentalId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Rental',
    required: true
  },
  // Thông tin người đặt chỗ
  customerInfo: {
    name: {
      type: String,
      required: true
    },
    phone: {
      type: String,
      required: true
    },
    email: {
      type: String,
      required: true
    },
    message: {
      type: String,
      default: ''
    }
  },
  // Thông tin thời gian đặt chỗ
  bookingDate: {
    type: Date,
    required: true
  },
  // Thời gian muốn xem nhà
  preferredViewingTime: {
    type: String,
    required: true
  },
  // Trạng thái đặt chỗ
  status: {
    type: String,
    enum: ['pending', 'confirmed', 'rejected', 'cancelled'],
    default: 'pending'
  },
  // Ghi chú từ chủ nhà
  ownerNotes: {
    type: String,
    default: ''
  },
  // Thời gian tạo
  createdAt: {
    type: Date,
    default: Date.now
  },
  // Thời gian cập nhật
  updatedAt: {
    type: Date,
    default: Date.now
  }
});

// Middleware để tự động cập nhật updatedAt
bookingSchema.pre('save', function(next) {
  this.updatedAt = new Date();
  next();
});

module.exports = mongoose.model('Booking', bookingSchema); 