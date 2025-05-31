require('dotenv').config();
const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const admin = require('firebase-admin');
const Rental = require('../models/Rental');
const Favorite = require('../models/favorite');


const authMiddleware = async (req, res, next) => {
  const token = req.header('Authorization')?.replace('Bearer ', '');
  if (!token) return res.status(401).json({ message: 'No token provided' });
  try {
    const decodedToken = await admin.auth().verifyIdToken(token);
    req.userId = decodedToken.uid;
    next();
  } catch (err) {
    res.status(401).json({ message: 'Invalid token' });
  }
};

router.post('/favorites', authMiddleware, async (req, res) => {
  try {
    const { rentalId } = req.body;
    const rental = await Rental.findById(rentalId);
    if (!rental) return res.status(404).json({ message: 'Rental not found' });
    const existingFavorite = await Favorite.findOne({ userId: req.userId, rentalId });
    if (existingFavorite) return res.status(400).json({ message: 'Rental already in favorites' });
    const favorite = new Favorite({ userId: req.userId, rentalId });
    await favorite.save();
    res.status(201).json({ message: 'Added to favorites', favorite });
  } catch (err) {
    res.status(400).json({ message: err.message });
  }
});

router.delete('/favorites/:rentalId', authMiddleware, async (req, res) => {
  try {
    const rentalId = req.params.rentalId;

    const rental = await Rental.findById(rentalId);
    if (!rental) {
      return res.status(404).json({ message: 'Rental not found' });
    }

    const result = await Favorite.findOneAndDelete({ userId: req.userId, rentalId });
    if (!result) {
      return res.status(404).json({ message: 'Favorite not found' });
    }

    res.json({ message: 'Removed from favorites' });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});


router.get('/favorites', authMiddleware, async (req, res) => {
  try {
    const favorites = await Favorite.find({ userId: req.userId }).populate('rentalId');
    res.json(favorites);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;
