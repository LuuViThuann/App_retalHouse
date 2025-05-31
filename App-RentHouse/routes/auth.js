const express = require('express');
const router = express.Router();
const admin = require('firebase-admin');
const mongoose = require('mongoose');
const User = require('../models/usermodel');
const axios = require('axios');

// Cấu hình EmailJS từ environment variables
const EMAILJS_API = process.env.EMAILJS_API || 'https://api.emailjs.com/api/v1.0/email/send';
const EMAILJS_SERVICE_ID = process.env.EMAILJS_SERVICE_ID || 'service_gz8v706';
const EMAILJS_TEMPLATE_ID = process.env.EMAILJS_TEMPLATE_ID || 'template_1k09fcg';
const EMAILJS_USER_ID = process.env.EMAILJS_USER_ID || 'bGlLdgP91zmfcVxzm';
const EMAILJS_API_TOKEN = process.env.EMAILJS_API_TOKEN; // Private Key from .env

// Đăng ký người dùng
router.post('/register', async (req, res) => {
  const { email, password, phoneNumber, address, username } = req.body;
  if (!email || !password || !phoneNumber || !address || !username) {
    return res.status(400).json({ message: 'Missing required fields' });
  }

  try {
    // Kiểm tra số điện thoại đã tồn tại
    const usersSnapshot = await admin.firestore().collection('Users').where('phoneNumber', '==', phoneNumber).get();
    if (!usersSnapshot.empty) {
      return res.status(400).json({ message: 'Số điện thoại đã được sử dụng' });
    }

    // Tạo người dùng trong Firebase Authentication
    const userRecord = await admin.auth().createUser({
      email,
      password,
    });

    // Lưu thông tin người dùng vào Firestore
    await admin.firestore().collection('Users').doc(userRecord.uid).set({
      email,
      phoneNumber,
      address,
      username,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Lưu thông tin người dùng vào MongoDB
    await User.findOneAndUpdate(
      { _id: userRecord.uid },
      { email, phoneNumber, address, username },
      { upsert: true, new: true }
    ).exec();

    res.status(201).json({
      id: userRecord.uid,
      email: userRecord.email,
      phoneNumber,
      address,
      username,
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
      username: userData.username,
      createdAt: userData.createdAt.toDate().toISOString(),
    });
  } catch (err) {
    res.status(401).json({ message: 'Invalid token' });
  }
});

// Gửi mã OTP
router.post('/send-otp', async (req, res) => {
  const { email } = req.body;
  if (!email) {
    return res.status(400).json({ message: 'Missing email' });
  }

  try {
    // Kiểm tra email đã đăng ký
    const user = await admin.auth().getUserByEmail(email).catch(() => null);
    if (!user) {
      return res.status(404).json({ message: 'Email chưa được đăng ký' });
    }

    // Tạo mã OTP
    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    const expiryTime = new Date(Date.now() + 10 * 60 * 1000); // Hết hạn sau 10 phút

    // Lưu OTP vào Firestore
    await admin.firestore().collection('otps').doc(email).set({
      otp,
      expiryTime: admin.firestore.Timestamp.fromDate(expiryTime),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Gửi email qua EmailJS
    const response = await axios.post(
      EMAILJS_API,
      {
        service_id: EMAILJS_SERVICE_ID,
        template_id: EMAILJS_TEMPLATE_ID,
        user_id: EMAILJS_USER_ID,
        accessToken: EMAILJS_API_TOKEN,
        template_params: {
          to_email: email,
          otp_code: otp,
          to_name: email.split('@')[0],
        },
      },
      {
        headers: {
          'Content-Type': 'application/json',
        },
      }
    );

    console.log('EmailJS response:', response.status, response.data);
    res.json({ message: 'Mã OTP đã được gửi thành công' });
  } catch (err) {
    console.error('EmailJS error:', err.response?.status, err.response?.data, err.message);
    res.status(400).json({ message: 'Gửi OTP thất bại: ' + err.message });
  }
});

// Xác minh OTP và đặt lại mật khẩu
router.post('/verify-otp', async (req, res) => {
  const { email, otp, newPassword } = req.body;
  if (!email || !otp) {
    return res.status(400).json({ message: 'Missing email or OTP' });
  }

  try {
    const doc = await admin.firestore().collection('otps').doc(email).get();
    if (!doc.exists) {
      return res.status(400).json({ message: 'Mã OTP không tồn tại' });
    }

    const data = doc.data();
    const storedOTP = data.otp;
    const expiryTime = data.expiryTime.toDate();

    if (new Date() > expiryTime) {
      return res.status(400).json({ message: 'Mã OTP đã hết hạn' });
    }

    if (storedOTP !== otp) {
      return res.status(400).json({ message: 'Mã OTP không đúng' });
    }

    if (newPassword) {
      const user = await admin.auth().getUserByEmail(email);
      await admin.auth().updateUser(user.uid, { password: newPassword });
    }

    // Xóa OTP sau khi xác minh
    await admin.firestore().collection('otps').doc(email).delete();
    res.json({ message: newPassword ? 'Mật khẩu đã được cập nhật thành công' : 'OTP xác minh thành công' });
  } catch (err) {
    console.error('Error verifying OTP:', err);
    res.status(400).json({ message: 'Xác minh OTP thất bại: ' + err.message });
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

    const updateData = {
      phoneNumber,
      address,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (username !== undefined) {
      updateData.username = username;
    }

    await admin.firestore().collection('Users').doc(userId).update(updateData);

    if (username !== undefined) {
      await User.findOneAndUpdate(
        { _id: userId },
        { username, phoneNumber, address },
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
      username: userData.username ?? '',
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

    let user = await User.findOne({ _id: userId });
    if (!user) {
      const userDoc = await admin.firestore().collection('Users').doc(userId).get();
      if (!userDoc.exists) {
        return res.status(404).json({ message: 'User not found in Firestore' });
      }
      const userData = userDoc.data();
      user = new User({
        _id: userId,
        username: userData.username || '',
        email: decodedToken.email || userData.email,
        phoneNumber: userData.phoneNumber || '',
      });
      await user.save();
    }

    user.avatarBase64 = imageBase64;
    await user.save();
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