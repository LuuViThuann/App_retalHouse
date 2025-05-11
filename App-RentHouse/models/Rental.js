const mongoose = require('mongoose');

const rentalSchema = new mongoose.Schema({
  title: {
    type: String,
    required: true,
  },
  price: {
    type: Number,
    required: true,
  },
  area: {
    total: { type: Number, required: true },
    livingRoom: { type: Number },
    bedrooms: { type: Number },
    bathrooms: { type: Number },
  },
  location: {
    short: { type: String, required: true }, // e.g., "Đường Nguyễn Lương Bằng, Phường Tân Phú, Quận 7"
    fullAddress: { type: String, required: true }, // e.g., "Số 123 Nguyễn Lương Bằng, Phường Tân Phú, Quận 7, TP. HCM"
  },
  propertyType: {
    type: String, // e.g., "Căn hộ chung cư (Block B, tầng 5)"
  },
  furniture: {
    type: [String], // e.g., ["Sofa", "Tủ lạnh", "Máy giặt"]
  },
  amenities: {
    type: [String], // e.g., ["Hồ bơi", "Gym", "Hầm gửi xe"]
  },
  surroundings: {
    type: [String], // e.g., ["Gần Lotte Mart", "Yên tĩnh, an ninh cao"]
  },
  rentalTerms: {
    minimumLease: { type: String }, // e.g., "6 tháng"
    deposit: { type: String }, // e.g., "2 tháng"
    paymentMethod: { type: String }, // e.g., "Chuyển khoản hoặc tiền mặt"
    renewalTerms: { type: String }, // e.g., "Thương lượng lại sau mỗi 12 tháng, tối đa +5% giá thuê"
  },
  contactInfo: {
    name: { type: String }, // e.g., "Anh Minh"
    phone: { type: String }, // e.g., "0909 xxx xxx"
    availableHours: { type: String }, // e.g., "9:00–20:00"
  },
  userId: {
    type: String,
    required: true,
  },
  images: {
    type: [String],
    default: [],
  },
  createdAt: {
    type: Date,
    default: Date.now,
  },
});

module.exports = mongoose.model('Rental', rentalSchema);