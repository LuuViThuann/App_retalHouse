require('dotenv').config();
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const path = require('path');
// const authRoutes = require('./routes/auth');
// const rentalRoutes = require('./routes/rentalRoutes');  
const e = require('express');

const app = express();
const PORT = process.env.PORT || 3000;
const MONGODB_URI = process.env.MONGODB_URI;

app.use(cors());
app.use(express.json());
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

mongoose.connect(MONGODB_URI)

    .then(() => {
      console.log('Connected to MongoDB');
    })
    .catch((err) => {
      console.error('Error connecting to MongoDB:', err);
    });

// Gọi các route
// app.use('/api/auth', authRoutes);
// app.use('/api/rentals', rentalRoutes); 
// Định nghĩa route chính
app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});