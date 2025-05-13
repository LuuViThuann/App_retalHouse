const express = require('express');
const router = express.Router();
const admin = require('firebase-admin');
const mongoose = require('mongoose');
const User = require('../models/usermodel'); // Import your Mongoose User model

// Đăng ký người dùng
router.post('/register', async (req, res) => {
  const { email, password, phoneNumber, address } = req.body;
  if (!email || !password || !phoneNumber || !address) {
    return res.status(400).json({ message: 'Missing required fields' });
  }

  try {
    const userRecord = await admin.auth().createUser({
      email,
      password,
    });

    await admin.firestore().collection('Users').doc(userRecord.uid).set({
      email,
      phoneNumber,
      address,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    res.status(201).json({
      id: userRecord.uid,
      email: userRecord.email,
      phoneNumber,
      address,
      createdAt: new Date().toISOString(),
    });
  } catch (err) {
    res.status(400).json({ message: err.message });
  }
});

// Đăng nhập
router.post('/login', async (req, res) => {
  const { idToken } = req.body;
  if (!idToken) {
    return res.status(400).json({ message: 'Missing ID token' });
  }

  try {
    const decodedToken = await admin.auth().verifyIdToken(idToken);
    const user = await admin.auth().getUser(decodedToken.uid);

    const userDoc = await admin.firestore().collection('Users').doc(user.uid).get();
    if (!userDoc.exists) {
      return res.status(404).json({ message: 'User not found in Firestore' });
    }

    const userData = userDoc.data();
    res.json({
      id: user.uid,
      email: user.email,
      phoneNumber: userData.phoneNumber,
      address: userData.address,
      createdAt: userData.createdAt.toDate().toISOString(),
    });
  } catch (err) {
    res.status(401).json({ message: 'Invalid token' });
  }
});

// Thay đổi mật khẩu
router.post('/change-password', async (req, res) => {
  const { idToken, newPassword } = req.body;
  if (!idToken || !newPassword) {
    return res.status(400).json({ message: 'Missing required fields' });
  }

  try {
    const decodedToken = await admin.auth().verifyIdToken(idToken);
    await admin.auth().updateUser(decodedToken.uid, {
      password: newPassword,
    });
    res.json({ message: 'Password updated successfully' });
  } catch (err) {
    res.status(400).json({ message: err.message });
  }
});

// Cập nhật thông tin người dùng
router.post('/update-profile', async (req, res) => {
  const { idToken, phoneNumber, address } = req.body;
  if (!idToken || !phoneNumber || !address) {
    return res.status(400).json({ message: 'Missing required fields' });
  }

  try {
    const decodedToken = await admin.auth().verifyIdToken(idToken);
    const userId = decodedToken.uid;

    await admin.firestore().collection('Users').doc(userId).update({
      phoneNumber,
      address,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const userDoc = await admin.firestore().collection('Users').doc(userId).get();
    const userData = userDoc.data();

    res.json({
      id: userId,
      email: decodedToken.email,
      phoneNumber: userData.phoneNumber,
      address: userData.address,
      updatedAt: userData.updatedAt?.toDate().toISOString(),
    });
  } catch (err) {
    res.status(400).json({ message: err.message });
  }
});

// Upload profile image to MongoDB
router.post('/upload-image', async (req, res) => {
  const { idToken, imageBase64 } = req.body;
  if (!idToken || !imageBase64) {
    return res.status(400).json({ message: 'Missing required fields' });
  }

  try {
    const decodedToken = await admin.auth().verifyIdToken(idToken);
    const userId = decodedToken.uid;

    console.log(`Attempting to update user ${userId} with image`);

    let user = await User.findOne({ _id: userId });
    if (!user) {
      console.log(`User ${userId} not found, creating new user`);
      const userDoc = await admin.firestore().collection('Users').doc(userId).get();
      if (!userDoc.exists) {
        return res.status(404).json({ message: 'User not found in Firestore' });
      }
      const userData = userDoc.data();

      user = new User({
        _id: userId,
        username: decodedToken.email.split('@')[0],
        email: decodedToken.email,
        password: 'firebase-managed',
        phoneNumber: userData.phoneNumber || '',
      });
      await user.save();
      console.log(`New user ${userId} created with phoneNumber: ${user.phoneNumber}`);
    }

    console.log(`Updating avatarBase64 for user ${userId}`);
    user.avatarBase64 = imageBase64;
    await user.save();
    console.log(`Successfully saved image for user ${userId}, avatarBase64 length: ${user.avatarBase64?.length}`);

    res.json({ message: 'Image uploaded successfully', avatarBase64: imageBase64 });
  } catch (err) {
    console.error(`Error uploading image for user: ${err.message}`);
    res.status(400).json({ message: err.message });
  }
});

// Fetch avatarBase64 for a user
router.get('/user/:id/avatar', async (req, res) => {
  const { id } = req.params;
  const idToken = req.headers.authorization?.split('Bearer ')[1];

  if (!idToken) {
    return res.status(400).json({ message: 'Missing ID token' });
  }

  try {
    const decodedToken = await admin.auth().verifyIdToken(idToken);
    if (decodedToken.uid !== id) {
      return res.status(403).json({ message: 'Unauthorized access' });
    }

    const user = await User.findOne({ _id: id });
    if (!user) {
      return res.status(404).json({ message: 'User not found in MongoDB' });
    }

    res.json({ avatarBase64: user.avatarBase64 });
  } catch (err) {
    console.error(`Error fetching avatarBase64 for user ${id}: ${err.message}`);
    res.status(400).json({ message: err.message });
  }
});

module.exports = router;