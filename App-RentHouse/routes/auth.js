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


// ============================== THÔNG TIN XỬ LÝ QUẢN LÝ NGƯỜI DÙNG BÊN ADMIN ========================================= // 
const verifyAdmin = async (req, res, next) => {
  try {
    const idToken = req.headers.authorization?.split('Bearer ')[1];
    if (!idToken) return res.status(401).json({ message: 'Thiếu token' });

    const decodedToken = await admin.auth().verifyIdToken(idToken);
    const uid = decodedToken.uid;

    const mongoUser = await User.findOne({ _id: uid });
    if (!mongoUser || mongoUser.role !== 'admin') {
      return res.status(403).json({ message: 'Chỉ admin mới có quyền truy cập' });
    }

    req.adminId = uid;
    next();
  } catch (err) {
    res.status(401).json({ message: 'Token không hợp lệ' });
  }
};

// ✅ CẬP NHẬT: Trả về avatarBase64 trong danh sách (nhưng kiểm soát kích thước)
router.get('/admin/users', verifyAdmin, async (req, res) => {
  try {
    const page = Math.max(1, parseInt(req.query.page) || 1);
    const limit = Math.min(50, Math.max(10, parseInt(req.query.limit) || 20));
    const skip = (page - 1) * limit;

    const [users, total] = await Promise.all([
      User.find({})
        .select('username email phoneNumber role createdAt _id avatarBase64')
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit)
        .lean(),
      User.countDocuments()
    ]);

    // Xử lý ảnh: nếu quá lớn thì tạm thời không trả (sẽ fetch riêng sau)
    const formattedUsers = users.map(u => {
      let avatar = null;
      if (u.avatarBase64 && u.avatarBase64.length > 0) {
        // Nếu ảnh < 500KB thì trả luôn, nếu > thì để null (sẽ fetch riêng)
        if (u.avatarBase64.length < 500000) {
          avatar = u.avatarBase64;
        }
      }
      return {
        id: u._id.toString(),
        username: u.username || 'Chưa đặt tên',
        email: u.email || 'Chưa có email',
        phoneNumber: u.phoneNumber || 'Chưa có số điện thoại',
        role: u.role || 'user',
        createdAt: u.createdAt,
        avatarBase64: avatar, // ✅ Trả về ảnh nếu nhỏ
        hasAvatar: !!u.avatarBase64 && u.avatarBase64.length > 100
      };
    });

    res.json({
      users: formattedUsers,
      pagination: { page, limit, total, totalPages: Math.ceil(total / limit) }
    });
  } catch (err) {
    console.error('Lỗi lấy danh sách:', err);
    res.status(500).json({ message: 'Lỗi server' });
  }
});

// ✅ CẬP NHẬT: Lấy chi tiết người dùng + ảnh đầy đủ
router.get('/admin/users/:id', verifyAdmin, async (req, res) => {
  try {
    const user = await User.findById(req.params.id)
      .select('username email phoneNumber role createdAt address avatarBase64')
      .lean();

    if (!user) return res.status(404).json({ message: 'Không tìm thấy' });

    res.json({
      id: user._id.toString(),
      username: user.username || 'Chưa đặt tên',
      email: user.email || 'Chưa có email',
      phoneNumber: user.phoneNumber || 'Chưa có số điện thoại',
      address: user.address || 'Chưa cập nhật',
      role: user.role || 'user',
      createdAt: user.createdAt,
      avatarBase64: user.avatarBase64 || null, // ✅ Trả ảnh đầy đủ
      hasAvatar: !!user.avatarBase64 && user.avatarBase64.length > 100
    });
  } catch (err) {
    res.status(500).json({ message: 'Lỗi server' });
  }
});

// ✅ GIỮ NGUYÊN: Endpoint riêng để fetch ảnh (dự phòng cho ảnh lớn)
router.get('/admin/users/:id/avatar', verifyAdmin, async (req, res) => {
  try {
    const user = await User.findById(req.params.id).select('avatarBase64').lean();
    if (!user || !user.avatarBase64) {
      return res.status(404).json({ avatarBase64: null });
    }
    res.json({ avatarBase64: user.avatarBase64 });
  } catch (err) {
    res.status(500).json({ message: 'Lỗi tải ảnh' });
  }
});

// ✅ Cập nhật AVATAR - SYNC CẢ MONGODB VÀ FIRESTORE
router.put('/admin/users/:id/avatar', verifyAdmin, async (req, res) => {
  try {
    const { avatarBase64 } = req.body;

    if (!avatarBase64 || typeof avatarBase64 !== 'string') {
      return res.status(400).json({ message: 'Thiếu hoặc sai định dạng ảnh base64' });
    }

    if (avatarBase64.length > 6_000_000) {
      return res.status(400).json({ message: 'Ảnh quá lớn, vui lòng chọn ảnh nhỏ hơn 4MB' });
    }

    // ✅ Cập nhật MongoDB
    const updatedUser = await User.findByIdAndUpdate(
      req.params.id,
      { avatarBase64 },
      { new: true }
    ).select('username avatarBase64');

    if (!updatedUser) {
      return res.status(404).json({ message: 'Không tìm thấy người dùng' });
    }

    // ✅ Cập nhật Firestore đồng thời
    await admin.firestore()
      .collection('Users')
      .doc(req.params.id)
      .update({
        avatarBase64: avatarBase64,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      })
      .catch(err => {
        console.log(`Firestore user không tồn tại hoặc lỗi cập nhật: ${req.params.id}`, err.message);
      });

    res.json({
      message: 'Đổi ảnh đại diện thành công',
      user: {
        id: updatedUser._id.toString(),
        username: updatedUser.username,
        avatarBase64: updatedUser.avatarBase64
      }
    });
  } catch (err) {
    console.error('Lỗi đổi ảnh admin:', err.message);
    res.status(500).json({ message: 'Không thể cập nhật ảnh' });
  }
});

// ✅ Cập nhật thông tin người dùng (admin) - CẬP NHẬT CẢ MONGODB VÀ FIRESTORE
router.put('/admin/users/:id', verifyAdmin, async (req, res) => {
  try {
    const { username, email, phoneNumber, role } = req.body;

    const updateFields = {};
    if (username !== undefined) updateFields.username = username;
    if (email !== undefined) updateFields.email = email;
    if (phoneNumber !== undefined) updateFields.phoneNumber = phoneNumber;
    if (role && ['user', 'admin'].includes(role)) {
      updateFields.role = role;
    }

    if (Object.keys(updateFields).length === 0) {
      return res.status(400).json({ message: 'Không có dữ liệu để cập nhật' });
    }

    // ✅ Cập nhật MongoDB
    const updatedUser = await User.findByIdAndUpdate(
      req.params.id,
      updateFields,
      { new: true, runValidators: true }
    ).select('-avatarBase64');

    if (!updatedUser) {
      return res.status(404).json({ message: 'Không tìm thấy người dùng' });
    }

    // ✅ Cập nhật Firestore đồng thời
    const firestoreUpdateData = {};
    if (username !== undefined) firestoreUpdateData.username = username;
    if (email !== undefined) firestoreUpdateData.email = email;
    if (phoneNumber !== undefined) firestoreUpdateData.phoneNumber = phoneNumber;
    if (role !== undefined) firestoreUpdateData.role = role;
    
    // Thêm timestamp
    firestoreUpdateData.updatedAt = admin.firestore.FieldValue.serverTimestamp();

    await admin.firestore()
      .collection('Users')
      .doc(req.params.id)
      .update(firestoreUpdateData)
      .catch(err => {
        console.log(`Firestore user không tồn tại hoặc lỗi cập nhật: ${req.params.id}`, err.message);
      });

    res.json({
      message: 'Cập nhật thành công',
      user: {
        id: updatedUser._id.toString(),
        username: updatedUser.username,
        email: updatedUser.email,
        phoneNumber: updatedUser.phoneNumber,
        role: updatedUser.role
      }
    });
  } catch (err) {
    console.error('Lỗi cập nhật người dùng:', err.message);
    res.status(500).json({ message: 'Cập nhật thất bại' });
  }
});

// ✅ Xóa người dùng - XÓA CẢ MONGODB, FIRESTORE, FIREBASE AUTH
router.delete('/admin/users/:id', verifyAdmin, async (req, res) => {
  try {
    const userId = req.params.id;

    // ✅ Xóa trong MongoDB
    const deletedUser = await User.findByIdAndDelete(userId);
    if (!deletedUser) {
      return res.status(404).json({ message: 'Người dùng không tồn tại' });
    }

    // ✅ Xóa trong Firestore
    await admin.firestore()
      .collection('Users')
      .doc(userId)
      .delete()
      .catch(err => {
        console.log(`Firestore user không tồn tại hoặc lỗi xóa: ${userId}`, err.message);
      });

    // ✅ Xóa trong Firebase Auth
    await admin.auth()
      .deleteUser(userId)
      .catch(err => {
        console.log(`Firebase Auth user đã bị xóa trước đó hoặc lỗi: ${userId}`, err.message);
      });

    res.json({ message: 'Xóa người dùng thành công' });
  } catch (err) {
    console.error('Lỗi xóa người dùng:', err.message);
    res.status(500).json({ message: 'Xóa người dùng thất bại' });
  }
});


// =======================================================

// Đăng ký người dùng
// POST /register - Đăng ký người dùng mới
router.post('/register', async (req, res) => {
  const { idToken, phoneNumber, address, username, avatarBase64 } = req.body;

  // === 1. KIỂM TRA BẮT BUỘC ===
  if (!idToken) {
    return res.status(400).json({ message: 'Thiếu ID token' });
  }
  if (!phoneNumber || !address || !username || !avatarBase64) {
    return res.status(400).json({ message: 'Vui lòng điền đầy đủ thông tin' });
  }

  // Kiểm tra định dạng số điện thoại
  const phoneRegex = /^\d{10}$/;
  if (!phoneRegex.test(phoneNumber)) {
    return res.status(400).json({ message: 'Số điện thoại phải có đúng 10 chữ số' });
  }

  // Kiểm tra avatarBase64 hợp lệ
  const avatarRegex = /^(data:image\/(jpeg|png);base64,)?[A-Za-z0-9+/=]+$/;
  if (!avatarRegex.test(avatarBase64)) {
    return res.status(400).json({ message: 'Ảnh đại diện không hợp lệ (chỉ hỗ trợ JPEG/PNG)' });
  }

  // Loại bỏ tiền tố MIME
  let base64Data = avatarBase64.replace(/^data:image\/(jpeg|png);base64,/, '');

  // Kiểm tra kích thước (< 5MB)
  try {
    const buffer = Buffer.from(base64Data, 'base64');
    if (buffer.length > 5 * 1024 * 1024) {
      return res.status(400).json({ message: 'Ảnh đại diện quá lớn (tối đa 5MB)' });
    }
  } catch (err) {
    return res.status(400).json({ message: 'Dữ liệu base64 không hợp lệ' });
  }

  try {
    // === 2. XÁC THỰC ID TOKEN TỪ FIREBASE ===
    const decodedToken = await admin.auth().verifyIdToken(idToken);
    const uid = decodedToken.uid;
    const email = decodedToken.email;

    if (!email) {
      return res.status(400).json({ message: 'Token không chứa email' });
    }

    // === 3. KIỂM TRA TRÙNG SỐ ĐIỆN THOẠI ===
    const [firestoreCheck, mongoCheck] = await Promise.all([
      admin.firestore().collection('Users').where('phoneNumber', '==', phoneNumber).get(),
      User.findOne({ phoneNumber })
    ]);

    if (!firestoreCheck.empty || mongoCheck) {
      return res.status(400).json({ message: 'Số điện thoại đã được sử dụng' });
    }

    // === 4. KIỂM TRA USER ĐÃ TỒN TẠI TRONG MONGODB CHƯA? ===
    const existingMongoUser = await User.findOne({ _id: uid });

    if (existingMongoUser) {
      return res.status(400).json({ message: 'Tài khoản đã được đăng ký trước đó' });
    }

    // === 5. LƯU VÀO FIRESTORE ===
    await admin.firestore().collection('Users').doc(uid).set({
      email,
      phoneNumber,
      address,
      username,
      role: 'user', // ✅ THÊM role vào Firestore
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    // === 6. LƯU VÀO MONGODB ===
    const newUser = new User({
      _id: uid,
      email,
      phoneNumber,
      address,
      username,
      avatarBase64: base64Data,
      role: 'user',
    });

    await newUser.save();

    // === 7. TRẢ VỀ KẾT QUẢ ===
    res.status(201).json({
      id: uid,
      email,
      phoneNumber,
      address,
      username,
      avatarBase64: base64Data,
      role: 'user',
      createdAt: new Date().toISOString(),
      message: 'Đăng ký thành công',
    });

  } catch (err) {
    console.error('Registration error:', err);

    // Nếu lỗi nghiêm trọng (ví dụ token giả mạo, lỗi server)
    if (err.code === 'auth/id-token-expired' || err.code === 'auth/argument-error') {
      return res.status(401).json({ message: 'Token không hợp lệ hoặc đã hết hạn' });
    }

    res.status(400).json({
      message: err.message || 'Đăng ký thất bại, vui lòng thử lại',
    });
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
      const email = user.email || `user_${user.uid}@noemail.com`;
      const userData = {
        email,
        phoneNumber: '',
        address: '',
        username: user.displayName || '',
        avatarBase64: user.photoURL || '',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      await admin.firestore().collection('Users').doc(user.uid).set(userData);

      await User.findOneAndUpdate(
        { _id: user.uid },
        { ...userData, _id: user.uid },
        { upsert: true, new: true }
      ).exec();
    }

    const userData = userDoc.data();
    const mongoUser = await User.findOne({ _id: user.uid });

    // XÁC ĐỊNH ROLE
    let role = 'user';
    if (mongoUser && mongoUser.role === 'admin') {
      role = 'admin';
    } else if (decodedToken.email === 'admin@yourapp.com') { // hoặc kiểm tra custom claim
      role = 'admin';
      // Tự động cập nhật role nếu là admin email
      await User.updateOne({ _id: uid }, { role: 'admin' }, { upsert: true });
    }

    res.json({
      id: user.uid,
      email: user.email || userData.email,
      phoneNumber: userData.phoneNumber || '',
      address: userData.address || '',
      username: userData.username || '',
      avatarBase64: mongoUser?.avatarBase64 || userData.avatarBase64 || '',
      createdAt: userData.createdAt ? userData.createdAt.toDate().toISOString() : new Date().toISOString(),
      role: role,
    });
  } catch (err) {
    console.error('Login error:', err);
    res.status(401).json({ message: 'Invalid token or authentication failure' });
  }
});


// Gửi email đặt lại mật khẩu
router.post('/send-reset-email', async (req, res) => {
  const { email } = req.body;
  if (!email) {
    return res.status(400).json({ message: 'Missing email' });
  }

  try {
    const user = await admin.auth().getUserByEmail(email).catch(() => null);
    if (!user) {
      return res.status(404).json({ message: 'Email chưa được đăng ký' });
    }

    const continueUrl = 'https://flutterrentalhouse.page.link/reset-password'; // Kiểm tra giá trị
    if (!continueUrl || !continueUrl.startsWith('http')) {
      throw new Error('Invalid continue URL: ' + continueUrl);
    }
    console.log('Continue URL:', continueUrl);

    const link = await admin.auth().generatePasswordResetLink(email, {
      url: continueUrl,
      handleCodeInApp: true,
    });

    console.log('Password reset link:', link);
    res.json({ message: 'Email đặt lại mật khẩu đã được gửi thành công' });
  } catch (err) {
    console.error('Full error:', JSON.stringify(err, null, 2));
    res.status(400).json({ message: 'Gửi email thất bại: ' + err.message });
  }
});

// Xác minh nhận mã OOB và đặt lại mật khẩu
router.post('/reset-password', async (req, res) => {
  const { oobCode, newPassword } = req.body;
  if (!oobCode || !newPassword) {
    return res.status(400).json({ message: 'Missing oobCode or newPassword' });
  }

  try {
    // Xác minh mã OOB
    const response = await admin.auth().verifyPasswordResetCode(oobCode);
    const email = response;

    // Cập nhật mật khẩu
    const user = await admin.auth().getUserByEmail(email);
    await admin.auth().updateUser(user.uid, { password: newPassword });

    res.json({ message: 'Mật khẩu đã được đặt lại thành công' });
  } catch (err) {
    console.error('Error resetting password:', err);
    res.status(400).json({ message: 'Đặt lại mật khẩu thất bại: ' + err.message });
  }
});

// Gửi mã OTP
router.post('/send-otp', async (req, res) => {
  const { email } = req.body;
  if (!email) {
    return res.status(400).json({ message: 'Missing required fields' });
  }

  try {
    // Kiểm tra xem email đã đăng ký
    const user = await admin.auth().getUserByEmail(email).catch(() => null);
    if (!user) {
      return res.status(404).json({ message: 'Email chưa được đăng ký' });
    }

    // Tạo mã OTP
    const otp = Math.floor(1000000 + Math.random() * 1000).toString();
    const expiryTime = new Date(Date.now() + 10 * 60 * 1000); // Hết hạn sau 10 phút

    // Lưu OTP lưu trữ
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
    return res.status(400).json({ message: 'Missing required fields' });
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
  if (!idToken  || !address) {
    return res.status(400).json({ message: 'Missing required fields' });
  }

  try {
    const decodedToken = await admin.auth().verifyIdToken(idToken);
    const userId = decodedToken.uid;

    // Fetch user data from Firebase Auth or Firestore to ensure email is included
    const user = await admin.auth().getUser(userId);
    const userDoc = await admin.firestore().collection('Users').doc(userId).get();
    const userData = userDoc.data();
    const email = user.email || userData?.email || `user_${userId}@noemail.com`;

    const updateData = {
      phoneNumber,
      address,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (username !== undefined) {
      updateData.username = username;
    }

    await admin.firestore().collection('Users').doc(userId).update(updateData);

    // Update MongoDB, ensuring email is always set
    await User.findOneAndUpdate(
      { _id: userId },
      { email, phoneNumber, address, username: username !== undefined ? username : userData?.username },
      { upsert: true, new: true }
    ).exec();

    const updatedUserDoc = await admin.firestore().collection('Users').doc(userId).get();
    const updatedUserData = updatedUserDoc.data();

    res.json({
      id: userId,
      email: email,
      phoneNumber: updatedUserData.phoneNumber,
      address: updatedUserData.address,
      username: updatedUserData.username ?? '',
      updatedAt: updatedUserData.updatedAt?.toDate().toISOString(),
    });
  } catch (err) {
    console.error('Update profile error:', err);
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
      const authUser = await admin.auth().getUser(userId);
      user = new User({
        _id: userId,
        username: userData.username || '',
        email: authUser.email || userData.email || `user_${userId}@noemail.com`,
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