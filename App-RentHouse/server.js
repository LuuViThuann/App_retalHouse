// File này là file chính của server, nơi khởi tạo server và kết nối với MongoDB
require('dotenv').config();

// Import các thư viện cần thiết ---------------
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const path = require('path');
const admin = require('firebase-admin');

// Import các route để xử lý yêu cầu trong server - API ---------------
const rentalRoutes = require('./routes/rental');
const authRoutes = require('./routes/auth');

// Khởi tạo Firebase Admin SDK
const serviceAccount = require('./app-rentalhouse-firebase-admin.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

// Khởi tạo Express app và cấu hình các middleware
const app = express();
const PORT = process.env.PORT || 3000;
const MONGODB_URI = process.env.MONGODB_URI;

// Middleware cần thiết cho server 
app.use(cors());
app.use(express.json());
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// Kết nối đến MongoDB 
mongoose.connect(MONGODB_URI)
  .then(() => {
    console.log('Connected to MongoDB');
  })
  .catch((err) => {
    console.error('Error connecting to MongoDB:', err);
  });

// Sử dụng các route đã import chạy hiển thị các dữ liệu trong API 
 // app.use('/api/rentals', rentalRoutes);
 
app.use('/api/auth', authRoutes);
app.use('/api', rentalRoutes);

// Route chính để kiểm tra server hoạt động 
app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});