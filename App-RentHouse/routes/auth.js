const express = require('express');
const router = express.Router();
const admin = require('firebase-admin');
const mongoose = require('mongoose');
const User = require('../models/usermodel'); // Import your Mongoose User model

// Đăng ký người dùng
router.post('/register', async (req, res) => {
  const { email, password, phoneNumber, address, username } = req.body; // Add username
  if (!email || !password || !phoneNumber || !address || !username) {
    return res.status(400).json({ message: 'Missing required fields' });
  }

  try {
    // Kiểm tra số điện thoai đã tồn tại
    const usersSnapshot = await admin.firestore().collection('Users').where('phoneNumber', '==', phoneNumber).get();

    if (!usersSnapshot.empty) {
      return res.status(400).json({ message: 'Số điện thoại đã được sử dụng' });
    }

    // Kiểm tra email đã tồn tại
    const userRecord = await admin.auth().createUser({
      email,
      password,
    });

    // Kiểm tra xem người dùng đã tồn tại trong Firestore
    await admin.firestore().collection('Users').doc(userRecord.uid).set({
      email,
      phoneNumber,
      address,
      username, // Save username to Firestore
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Kiểm tra xem người dùng đã tồn tại trong MongoDB
    res.status(201).json({
      id: userRecord.uid,
      email: userRecord.email,
      phoneNumber,
      address,
      username, // Return username in response
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
    // Xác nhận ID token
    const decodedToken = await admin.auth().verifyIdToken(idToken);

    // Lấy thông tin người dùng từ Firebase Authentication
    const user = await admin.auth().getUser(decodedToken.uid);

    // Kiểm tra xem người dùng đã tồn tại trong Firestore
    const userDoc = await admin.firestore().collection('Users').doc(user.uid).get();

    // Nếu người dùng không tồn tại trong Firestore, trả về lỗi
    if (!userDoc.exists) {
      return res.status(404).json({ message: 'User not found in Firestore' });
    }

    // Nếu người dùng không tồn tại trong MongoDB, tạo mới
    const userData = userDoc.data();

    // Kiểm tra xem người dùng đã tồn tại trong MongoDB
    res.json({
      id: user.uid,
      email: user.email,
      phoneNumber: userData.phoneNumber,
      address: userData.address,
      username: userData.username, // Include username in login response
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
  const { idToken, phoneNumber, address, username } = req.body;
  if (!idToken || !phoneNumber || !address) {
    return res.status(400).json({ message: 'Missing required fields' });
  }

  try {
    const decodedToken = await admin.auth().verifyIdToken(idToken);
    const userId = decodedToken.uid;

    // Prepare the update object with all provided fields
    const updateData = {
      phoneNumber,
      address,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    // Add username to update if it’s provided
    if (username !== undefined) {
      updateData.username = username;
    }

    await admin.firestore().collection('Users').doc(userId).update(updateData);

    // Update MongoDB if username is provided
    if (username !== undefined) {
      await User.findOneAndUpdate(
        { _id: userId },
        { username, phoneNumber, address }, // Update username, phoneNumber, and address in MongoDB
        { upsert: true, new: true }
      ).exec();
    }

    const userDoc = await admin.firestore().collection('Users').doc(userId).get();
    const userData = userDoc.data();

    res.json({
      id: userId,
      email: decodedToken.email,
      phoneNumber: userData.phoneNumber,
      address: userData.address,
      username: userData.username ?? '', // Ensure username is returned
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
    console.log(`Decoded token email: ${decodedToken.email}`);

    let user = await User.findOne({ _id: userId });
    if (!user) {
      console.log(`User ${userId} not found, creating new user`);
      const userDoc = await admin.firestore().collection('Users').doc(userId).get();
      if (!userDoc.exists) {
        return res.status(404).json({ message: 'User not found in Firestore' });
      }
      const userData = userDoc.data();
      console.log(`Firestore user data: ${JSON.stringify(userData)}`);

      user = new User({
        _id: userId,
        username: userData.username || '',
        email: decodedToken.email || userData.email, // Fallback to Firestore email if decodedToken.email is undefined
        phoneNumber: userData.phoneNumber || '',
      });
      await user.save();
      console.log(`New user ${userId} created with email: ${user.email}, phoneNumber: ${user.phoneNumber}`);
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