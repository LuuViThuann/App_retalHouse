const express = require('express');
const router = express.Router();
const admin = require('firebase-admin');

// Đăng ký người dùng
router.post('/register', async (req, res) => {
  const { email, password, phoneNumber, address } = req.body;
  if (!email || !password || !phoneNumber || !address) {
    return res.status(400).json({ message: 'Missing required fields' });
  }

  try {
    // Tạo người dùng trong Firebase Auth
    const userRecord = await admin.auth().createUser({
      email,
      password,
    });

    // Lưu thông tin người dùng vào Firestore
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

// Đăng nhập (trả về thông tin người dùng)
router.post('/login', async (req, res) => {
  const { idToken } = req.body;
  if (!idToken) {
    return res.status(400).json({ message: 'Missing ID token' });
  }

  try {
    // Xác minh token
    const decodedToken = await admin.auth().verifyIdToken(idToken);
    const user = await admin.auth().getUser(decodedToken.uid);

    // Lấy thông tin người dùng từ Firestore
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

module.exports = router;