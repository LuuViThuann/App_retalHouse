require('dotenv').config();
const express = require('express');
const router = express.Router();
const Rental = require('../models/Rental');
const admin = require('firebase-admin');
const multer = require('multer');
const path = require('path');

// Cấu hình multer để upload ảnh
const storage = multer.diskStorage({
  destination: './uploads/',
  filename: (req, file, cb) => {
    cb(null, `${Date.now()}-${file.originalname}`);
  },
});
const upload = multer({ storage });

// Middleware xác thực Firebase token
const authMiddleware = async (req, res, next) => {
  const token = req.header('Authorization')?.replace('Bearer ', '');
  if (!token) {
    return res.status(401).json({ message: 'No token provided' });
  }
  try {
    const decodedToken = await admin.auth().verifyIdToken(token);
    req.userId = decodedToken.uid;
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
router.post('/', authMiddleware, upload.array('images'), async (req, res) => {
  try {
    const imageUrls = req.files.map(file => `/uploads/${file.filename}`);
    const rental = new Rental({
      title: req.body.title,
      price: req.body.price,
      area: {
        total: req.body.areaTotal,
        livingRoom: req.body.areaLivingRoom,
        bedrooms: req.body.areaBedrooms,
        bathrooms: req.body.areaBathrooms,
      },
      location: {
        short: req.body.locationShort,
        fullAddress: req.body.locationFullAddress,
      },
      propertyType: req.body.propertyType,
      furniture: req.body.furniture.split(',').map(item => item.trim()),
      amenities: req.body.amenities.split(',').map(item => item.trim()),
      surroundings: req.body.surroundings.split(',').map(item => item.trim()),
      rentalTerms: {
        minimumLease: req.body.rentalTermsMinimumLease,
        deposit: req.body.rentalTermsDeposit,
        paymentMethod: req.body.rentalTermsPaymentMethod,
        renewalTerms: req.body.rentalTermsRenewalTerms,
      },
      contactInfo: {
        name: req.body.contactInfoName,
        phone: req.body.contactInfoPhone,
        availableHours: req.body.contactInfoAvailableHours,
      },
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