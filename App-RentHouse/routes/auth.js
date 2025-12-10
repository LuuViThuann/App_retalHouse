const express = require('express');
const router = express.Router();
const admin = require('firebase-admin');
const User = require('../models/usermodel');
const axios = require('axios');
const cloudinary = require('../config/cloudinary');
const { CloudinaryStorage } = require('multer-storage-cloudinary');
const multer = require('multer');

const storage = new CloudinaryStorage({
  cloudinary: cloudinary,
  params: {
    folder: 'avatarUser', // Thư mục trong Cloudinary
    allowed_formats: ['jpg', 'jpeg', 'png', 'webp'],
    transformation: [{ width: 1920, height: 600, crop: 'limit' }], // Tùy chọn: resize ảnh
  },
});

const upload = multer({
  storage,
  limits: { fileSize: 50 * 1024 * 1024 }, // 5MB
  fileFilter: (req, file, cb) => {
    // Kiểm tra extension file
    const allowedExtensions = /\.(jpeg|jpg|png|webp)$/i;
    const extname = allowedExtensions.test(file.originalname); 
    
    // Kiểm tra MIME type
    const allowedMimeTypes = /^image\/(jpeg|jpg|png|webp|octet-stream)/i;
    const mimetype = allowedMimeTypes.test(file.mimetype);
    
    console.log('File:', file.originalname, 'Extension:', extname, 'MIME:', file.mimetype, 'MIMEValid:', mimetype);
    
    if (extname) {
      return cb(null, true);
    }
    cb(new Error('Chỉ chấp nhận file ảnh (JPEG, JPG, PNG, WebP)'));
  },
});

const deleteImage = async (publicId) => {
  try {
    if (!publicId) return;
    const result = await cloudinary.uploader.destroy(publicId);
    console.log(`✅ Đã xóa ảnh: ${publicId}`, result);
  } catch (error) {
    console.error(`❌ Lỗi khi xóa ảnh Cloudinary: ${publicId}`, error);
  }
};

// ============================== ADMIN MIDDLEWARE ========================================= //
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

// ============================== ADMIN USER MANAGEMENT ========================================= //

// ✅ Lấy danh sách người dùng
router.get('/admin/users', verifyAdmin, async (req, res) => {
  try {
    const page = Math.max(1, parseInt(req.query.page) || 1);
    const limit = Math.min(50, Math.max(10, parseInt(req.query.limit) || 20));
    const skip = (page - 1) * limit;

    const [users, total] = await Promise.all([
      User.find({})
        .select('username email phoneNumber role createdAt _id avatarUrl')
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit)
        .lean(),
      User.countDocuments()
    ]);

    const formattedUsers = users.map(u => ({
      id: u._id.toString(),
      username: u.username || 'Chưa đặt tên',
      email: u.email || 'Chưa có email',
      phoneNumber: u.phoneNumber || 'Chưa có số điện thoại',
      role: u.role || 'user',
      createdAt: u.createdAt,
      avatarUrl: u.avatarUrl || null,
      hasAvatar: !!u.avatarUrl
    }));

    res.json({
      users: formattedUsers,
      pagination: { page, limit, total, totalPages: Math.ceil(total / limit) }
    });
  } catch (err) {
    console.error('Lỗi lấy danh sách:', err);
    res.status(500).json({ message: 'Lỗi server' });
  }
});

// ✅ Lấy chi tiết người dùng
router.get('/admin/users/:id', verifyAdmin, async (req, res) => {
  try {
    const user = await User.findById(req.params.id)
      .select('username email phoneNumber role createdAt address avatarUrl')
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
      avatarUrl: user.avatarUrl || null,
      hasAvatar: !!u.avatarUrl
    });
  } catch (err) {
    res.status(500).json({ message: 'Lỗi server' });
  }
});

// ✅ Cập nhật AVATAR - Upload file từ form-data
router.put('/admin/users/:id/avatar', verifyAdmin, upload.single('avatar'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ message: 'Vui lòng upload ảnh' });
    }

    const currentUser = await User.findById(req.params.id);
    if (!currentUser) {
      return res.status(404).json({ message: 'Không tìm thấy người dùng' });
    }

    // Xóa ảnh cũ nếu có
    if (currentUser.avatarPublicId) {
      await deleteImage(currentUser.avatarPublicId);
    }

    // Avatar URL từ Cloudinary (từ multer-storage-cloudinary)
    const avatarUrl = req.file.path;
    const avatarPublicId = req.file.filename;

    // Cập nhật MongoDB
    const updatedUser = await User.findByIdAndUpdate(
      req.params.id,
      { 
        avatarUrl,
        avatarPublicId,
      },
      { new: true }
    ).select('username avatarUrl');

    // Cập nhật Firestore
    await admin.firestore()
      .collection('Users')
      .doc(req.params.id)
      .update({
        avatarUrl,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      })
      .catch(err => {
        console.log(`Firestore user không tồn tại: ${req.params.id}`, err.message);
      });

    res.json({
      message: 'Đổi ảnh đại diện thành công',
      user: {
        id: updatedUser._id.toString(),
        username: updatedUser.username,
        avatarUrl: updatedUser.avatarUrl
      }
    });
  } catch (err) {
    console.error('Lỗi đổi ảnh admin:', err.message);
    res.status(500).json({ message: 'Không thể cập nhật ảnh' });
  }
});

// ✅ Cập nhật thông tin người dùng
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

    const updatedUser = await User.findByIdAndUpdate(
      req.params.id,
      updateFields,
      { new: true, runValidators: true }
    ).select('-avatarPublicId');

    if (!updatedUser) {
      return res.status(404).json({ message: 'Không tìm thấy người dùng' });
    }

    // Cập nhật Firestore
    const firestoreUpdateData = { ...updateFields };
    firestoreUpdateData.updatedAt = admin.firestore.FieldValue.serverTimestamp();

    await admin.firestore()
      .collection('Users')
      .doc(req.params.id)
      .update(firestoreUpdateData)
      .catch(err => {
        console.log(`Firestore user không tồn tại: ${req.params.id}`, err.message);
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

// ✅ Xóa người dùng
router.delete('/admin/users/:id', verifyAdmin, async (req, res) => {
  try {
    const userId = req.params.id;

    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({ message: 'Người dùng không tồn tại' });
    }

    // Xóa ảnh trên Cloudinary
    if (user.avatarPublicId) {
      await deleteImage(user.avatarPublicId);
    }

    // Xóa trong MongoDB
    await User.findByIdAndDelete(userId);

    // Xóa trong Firestore
    await admin.firestore()
      .collection('Users')
      .doc(userId)
      .delete()
      .catch(err => {
        console.log(`Firestore user không tồn tại: ${userId}`, err.message);
      });

    // Xóa trong Firebase Auth
    await admin.auth()
      .deleteUser(userId)
      .catch(err => {
        console.log(`Firebase Auth user đã bị xóa: ${userId}`, err.message);
      });

    res.json({ message: 'Xóa người dùng thành công' });
  } catch (err) {
    console.error('Lỗi xóa người dùng:', err.message);
    res.status(500).json({ message: 'Xóa người dùng thất bại' });
  }
});

// ============================== USER AUTHENTICATION ========================================= //

// ✅ ĐĂNG KÝ - Upload avatar (form-data)
router.post('/register', upload.single('avatar'), async (req, res) => {
  const { idToken, phoneNumber, address, username } = req.body;

  if (!idToken) {
    return res.status(400).json({ message: 'Thiếu ID token' });
  }
  if (!phoneNumber || !address || !username) {
    return res.status(400).json({ message: 'Vui lòng điền đầy đủ thông tin' });
  }
  if (!req.file) {
    return res.status(400).json({ message: 'Vui lòng upload ảnh đại diện' });
  }

  const phoneRegex = /^\d{10}$/;
  if (!phoneRegex.test(phoneNumber)) {
    return res.status(400).json({ message: 'Số điện thoại phải có đúng 10 chữ số' });
  }

  try {
    // Xác thực token
    const decodedToken = await admin.auth().verifyIdToken(idToken);
    const uid = decodedToken.uid;
    const email = decodedToken.email;

    if (!email) {
      return res.status(400).json({ message: 'Token không chứa email' });
    }

    // Kiểm tra trùng số điện thoại
    const [firestoreCheck, mongoCheck] = await Promise.all([
      admin.firestore().collection('Users').where('phoneNumber', '==', phoneNumber).get(),
      User.findOne({ phoneNumber })
    ]);

    if (!firestoreCheck.empty || mongoCheck) {
      // Xóa ảnh đã upload nếu số điện thoại trùng
      if (req.file.filename) await deleteImage(req.file.filename);
      return res.status(400).json({ message: 'Số điện thoại đã được sử dụng' });
    }

    // Kiểm tra user đã tồn tại
    const existingMongoUser = await User.findOne({ _id: uid });
    if (existingMongoUser) {
      if (req.file.filename) await deleteImage(req.file.filename);
      return res.status(400).json({ message: 'Tài khoản đã được đăng ký trước đó' });
    }

    // Avatar URL từ Cloudinary
    const avatarUrl = req.file.path;
    const avatarPublicId = req.file.filename;

    // Lưu vào Firestore
    await admin.firestore().collection('Users').doc(uid).set({
      email,
      phoneNumber,
      address,
      username,
      role: 'user',
      avatarUrl,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    // Lưu vào MongoDB
    const newUser = new User({
      _id: uid,
      email,
      phoneNumber,
      address,
      username,
      avatarUrl,
      avatarPublicId,
      role: 'user',
    });

    await newUser.save();

    res.status(201).json({
      id: uid,
      email,
      phoneNumber,
      address,
      username,
      avatarUrl,
      role: 'user',
      createdAt: new Date().toISOString(),
      message: 'Đăng ký thành công',
    });

  } catch (err) {
    console.error('Registration error:', err);
    
    // Xóa ảnh nếu có lỗi
    if (req.file?.filename) {
      await deleteImage(req.file.filename).catch(e => console.log('Cleanup failed:', e));
    }

    if (err.code === 'auth/id-token-expired' || err.code === 'auth/argument-error') {
      return res.status(401).json({ message: 'Token không hợp lệ hoặc đã hết hạn' });
    }

    res.status(400).json({
      message: err.message || 'Đăng ký thất bại, vui lòng thử lại',
    });
  }
});

// ✅ ĐĂNG NHẬP
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
        avatarUrl: user.photoURL || '',
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

    let role = 'user';
    if (mongoUser && mongoUser.role === 'admin') {
      role = 'admin';
    } else if (decodedToken.email === 'admin@yourapp.com') {
      role = 'admin';
      await User.updateOne({ _id: user.uid }, { role: 'admin' }, { upsert: true });
    }

    res.json({
      id: user.uid,
      email: user.email || userData.email,
      phoneNumber: userData.phoneNumber || '',
      address: userData.address || '',
      username: userData.username || '',
      avatarUrl: mongoUser?.avatarUrl || userData.avatarUrl || '',
      createdAt: userData.createdAt ? userData.createdAt.toDate().toISOString() : new Date().toISOString(),
      role: role,
    });
  } catch (err) {
    console.error('Login error:', err);
    res.status(401).json({ message: 'Invalid token or authentication failure' });
  }
});

// ✅ Upload profile image - Form-data
router.post('/upload-image', upload.single('avatar'), async (req, res) => {
  const { idToken } = req.body;
  
  if (!idToken) {
    if (req.file?.filename) await deleteImage(req.file.filename);
    return res.status(400).json({ message: 'Missing ID token' });
  }
  
  if (!req.file) {
    return res.status(400).json({ message: 'Missing avatar file' });
  }

  try {
    const decodedToken = await admin.auth().verifyIdToken(idToken);
    const userId = decodedToken.uid;

    let user = await User.findOne({ _id: userId });
    if (!user) {
      const userDoc = await admin.firestore().collection('Users').doc(userId).get();
      if (!userDoc.exists) {
        if (req.file?.filename) await deleteImage(req.file.filename);
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

    // Xóa ảnh cũ nếu có
    if (user.avatarPublicId) {
      await deleteImage(user.avatarPublicId);
    }

    // Cập nhật với avatar mới từ Cloudinary
    const avatarUrl = req.file.path;
    const avatarPublicId = req.file.filename;

    user.avatarUrl = avatarUrl;
    user.avatarPublicId = avatarPublicId;
    await user.save();

    // Cập nhật Firestore
    await admin.firestore()
      .collection('Users')
      .doc(userId)
      .update({
        avatarUrl,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      })
      .catch(err => console.log(`Firestore update failed: ${err.message}`));

    res.json({ 
      message: 'Image uploaded successfully', 
      avatarUrl
    });
  } catch (err) {
    console.error(`Error uploading image: ${err.message}`);
    if (req.file?.filename) await deleteImage(req.file.filename);
    res.status(400).json({ message: err.message });
  }
});

// ✅ Fetch avatar URL
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

    res.json({ avatarUrl: user.avatarUrl });
  } catch (err) {
    console.error(`Error fetching avatar for user ${id}: ${err.message}`);
    res.status(400).json({ message: err.message });
  }
});

// ============================== OTHER ROUTES ========================================= //

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

    const continueUrl = 'https://flutterrentalhouse.page.link/reset-password';
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

router.post('/reset-password', async (req, res) => {
  const { oobCode, newPassword } = req.body;
  if (!oobCode || !newPassword) {
    return res.status(400).json({ message: 'Missing oobCode or newPassword' });
  }

  try {
    const response = await admin.auth().verifyPasswordResetCode(oobCode);
    const email = response;
    const user = await admin.auth().getUserByEmail(email);
    await admin.auth().updateUser(user.uid, { password: newPassword });

    res.json({ message: 'Mật khẩu đã được đặt lại thành công' });
  } catch (err) {
    console.error('Error resetting password:', err);
    res.status(400).json({ message: 'Đặt lại mật khẩu thất bại: ' + err.message });
  }
});

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

router.post('/update-profile', async (req, res) => {
  const { idToken, phoneNumber, address, username } = req.body;
  if (!idToken || !address) {
    return res.status(400).json({ message: 'Missing required fields' });
  }

  try {
    const decodedToken = await admin.auth().verifyIdToken(idToken);
    const userId = decodedToken.uid;

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

module.exports = router;