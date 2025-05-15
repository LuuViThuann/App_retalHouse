const mongoose = require('mongoose');

// *---------------------------------------------------------------------------------------
// Đây là cấu trúc trước khi lưu vào trong cơ sở dữ liệu MongoDB
// Mongoose là một thư viện giúp kết nối và tương tác với MongoDB
// Mongoose.Schema là một lớp trong Mongoose dùng để định nghĩa cấu trúc của một document trong MongoDB
// rentalSchema là một đối tượng schema được tạo ra từ Mongoose.Schema
// rentalSchema định nghĩa các trường dữ liệu mà một tài sản cho thuê sẽ có
// rentalSchema sẽ được sử dụng để tạo ra một model (Rental) mà chúng ta có thể sử dụng để tương tác với MongoDB
// rentalSchema sẽ định nghĩa các trường dữ liệu mà một tài sản cho thuê sẽ có
// rentalSchema sẽ định nghĩa các kiểu dữ liệu cho từng trường
// rentalSchema sẽ định nghĩa các thuộc tính cho từng trường
// rentalSchema sẽ định nghĩa các trường bắt buộc và không bắt buộc
// rentalSchema sẽ định nghĩa các kiểu dữ liệu cho từng trường
// *---------------------------------------------------------------------------------------
const rentalSchema = new mongoose.Schema({
  
  // *  thông tin tiêu đề 
  title: {
    type: String,
    required: true,
  },
  // *  thông tin giá thuê
  price: {
    type: Number,
    required: true,
  },
  // *  thông tin diện tích
  area: {
    total: { type: Number, required: true }, // tổng diện tích
    livingRoom: { type: Number }, // diện tích phòng khách
    bedrooms: { type: Number }, // diện tích phòng ngủ
    bathrooms: { type: Number }, // diện tích phòng tắm
  },

  // * thông tin vị trí
  location: {
    short: { type: String, required: true }, // e.g., "Quận 7, TP. HCM"
    fullAddress: { type: String, required: true }, // e.g., "123 Đường ABC, Phường XYZ, Quận 7, TP. HCM"
  },
  // *  thông tin mô tả
  propertyType: {
    type: String, 
  },
  // *  thông tin mô tả các thiết bị trong nhà
  furniture: {
    type: [String], // ví dụ : ["Giường", "Tủ lạnh", "Máy giặt"]
  },
  // *  thông tin các tiện ích thuê nhà 
  amenities: {
    type: [String], // ví dụ : ["Hồ bơi", "Gym", "Hầm gửi xe"]
  },
  // *  thông tin các tiện ích xung quanh
  surroundings: {
    type: [String], // ví dụ : ["Gần Lotte Mart", "Yên tĩnh, an ninh cao"]
  },
  // *  thông tin mô tả chi tiết điều khoản hợp đồng thuê 
  rentalTerms: {
    minimumLease: { type: String }, // ví dụ : "Thời gian thuê tối thiểu 6 tháng"
    deposit: { type: String }, // ví dụ : "Cọc 1 tháng tiền thuê"
    paymentMethod: { type: String }, // ví dụ : "Chuyển khoản qua ngân hàng"
    renewalTerms: { type: String }, // ví dụ : "Có thể gia hạn hợp đồng"
  },
  // *  thông tin liên hệ của người cho thuê
  contactInfo: {
    name: { type: String }, // ví dụ : "Anh Minh"
    phone: { type: String }, // ví dụ : "0909 xxx xxx"
    availableHours: { type: String }, // ví dụ :"9:00–20:00"
  },
  // *  thông tin người cho thuê
  userId: {
    type: String,
    ref: 'User',
    required: true,
  },
  // *  thông tin danh sách hình ảnh của nhà cho thuê
  images: {
    type: [String],
    default: [],
  },
  // *  thông tin trạng thái của nhà cho thuê
    status: {
    type: String,
    enum: ['available', 'rented'], // Chỉ cho phép 2 giá trị: "available" hoặc "rented"
    default: 'available', // Mặc định là "available"
  },
  // *  thông tin thời gian tạo
  createdAt: {
    type: Date,
    default: Date.now,
  },
});

module.exports = mongoose.model('Rental', rentalSchema);