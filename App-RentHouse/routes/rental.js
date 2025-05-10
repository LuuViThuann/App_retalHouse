const express = require('express');
const router = express.Router();
const Rental = require('../models/Rental');
const jwt = require('jsonwebtoken');
const multer = require('multer');
const path = require('path');

const JWT_SECRET = 'Z4fR!@c8vX3m$Lp9sWq#J2eYb%N7Tk0R'; 

// Cấu hình multer để upload ảnh
const storage = multer.diskStorage({
  destination: './uploads/',
  filename: (req, file, cb) => {
    cb(null, `${Date.now()}-${file.originalname}`);
  },
});
const upload = multer({ storage });

// Middleware xác thực JWT
const authMiddleware = (req, res, next) => {
  const token = req.header('Authorization')?.replace('Bearer ', '');
  if (!token) {
    return res.status(401).json({ message: 'No token provided' });
  }
  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    req.userId = decoded.userId;
    next();
  } catch (err) {
    res.status(401).json({ message: 'Invalid token' });
  }
};

// Get all rentals
router.get('/', async (req, res) => {
  try {
    const rentals = await Rental.find();
    res.json(rentals);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// Create a rental with multiple images
router.post('/', authMiddleware, upload.array('images', 5), async (req, res) => {
  try {
    const imageUrls = req.files.map(file => `/uploads/${file.filename}`);
    const rental = new Rental({
      title: req.body.title,
      description: req.body.description,
      price: req.body.price,
      location: req.body.location,
      userId: req.userId,
      images: imageUrls,
    });
    const newRental = await rental.save();
    res.status(201).json(newRental);
  } catch (err) {
    res.status(400).json({ message: err.message });
  }
});

module.exports = router;