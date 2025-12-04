// ==================== NOTIFICATIONS ROUTES ====================

require('dotenv').config();
const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const admin = require('firebase-admin');

const Notification = require('../models/notification');

// ==================== MIDDLEWARE ====================

const authMiddleware = async (req, res, next) => {
  try {
    const token = req.header('Authorization')?.replace('Bearer ', '');
    if (!token) return res.status(401).json({ message: 'Không có token' });

    const decodedToken = await admin.auth().verifyIdToken(token);
    req.userId = decodedToken.uid;
    next();
  } catch (err) {
    res.status(401).json({ message: 'Token không hợp lệ' });
  }
};

const verifyAdmin = async (req, res, next) => {
  try {
    const token = req.header('Authorization')?.replace('Bearer ', '');
    if (!token) return res.status(401).json({ message: 'Không có token' });

    const decodedToken = await admin.auth().verifyIdToken(token);
    const uid = decodedToken.uid;

    const User = require('../models/usermodel');
    const mongoUser = await User.findOne({ _id: uid });
    if (!mongoUser || mongoUser.role !== 'admin') {
      return res.status(403).json({ message: 'Chỉ admin mới có quyền' });
    }

    req.userId = uid;
    req.isAdmin = true;
    next();
  } catch (err) {
    res.status(401).json({ message: 'Token không hợp lệ' });
  }
};

// ==================== REDIS HELPER FUNCTIONS ====================

let redisClient = null;

// Hàm khởi tạo Redis client từ server.js
const setRedisClient = (client) => {
  redisClient = client;
};

// ✅ Lưu từng thông báo vào Redis (mỗi cái riêng biệt)
const saveNotificationToUndoStack = async (userId, notification) => {
  try {
    if (!redisClient) {
      console.warn('⚠️ [SAVE UNDO] Redis client not available');
      return;
    }

    // Mỗi notification được lưu riêng với key unique
    const undoKey = `undo:notification:${userId}:${notification._id.toString()}`;
    const undoData = JSON.stringify({
      timestamp: Date.now(),
      notification: {
        _id: notification._id?.toString(),
        userId: notification.userId,
        type: notification.type,
        title: notification.title,
        message: notification.message,
        rentalId: notification.rentalId,
        details: notification.details,
        read: notification.read,
        createdAt: notification.createdAt,
      },
    });

    // Lưu vào Redis với TTL 30 phút
    await redisClient.setEx(undoKey, 1800, undoData);
    console.log(`✅ [SAVE UNDO] Saved notification ${notification._id} for user ${userId}`);
  } catch (err) {
    console.error('⚠️ [SAVE UNDO] Redis error:', err.message);
  }
};

// ✅ Lấy tất cả thông báo đã xóa từ Redis
const getDeletedNotifications = async (userId) => {
  try {
    if (!redisClient) {
      console.warn('⚠️ [GET DELETED] Redis client not available');
      return [];
    }

    // Tìm tất cả key có pattern undo:notification:userId:*
    const pattern = `undo:notification:${userId}:*`;
    const keys = await redisClient.keys(pattern);

    if (!keys || keys.length === 0) {
      console.log(`⚠️ [GET DELETED] No deleted notifications found for user ${userId}`);
      return [];
    }

    const deletedNotifications = [];
    for (const key of keys) {
      const data = await redisClient.get(key);
      if (data) {
        try {
          const parsed = JSON.parse(data);
          deletedNotifications.push({
            key: key,
            ...parsed,
          });
        } catch (e) {
          console.warn(`⚠️ [GET DELETED] Failed to parse key ${key}:`, e.message);
        }
      }
    }

    console.log(`✅ [GET DELETED] Found ${deletedNotifications.length} deleted notifications for user ${userId}`);
    return deletedNotifications;
  } catch (err) {
    console.error('⚠️ [GET DELETED] Redis error:', err.message);
    return [];
  }
};

// ✅ Xóa 1 notification khỏi undo stack
const deleteFromUndoStack = async (userId, notificationId) => {
  try {
    if (!redisClient) return;

    const undoKey = `undo:notification:${userId}:${notificationId}`;
    await redisClient.del(undoKey);
    console.log(`✅ [CLEAR UNDO] Cleared undo stack for notification ${notificationId}`);
  } catch (err) {
    console.error('⚠️ [CLEAR UNDO] Redis error:', err.message);
  }
};

// ==================== USER ROUTES ====================

// ✅ GET: Lấy thông báo của user hiện tại (có phân trang)
router.get('/notifications', authMiddleware, async (req, res) => {
  try {
    const { page = 1, limit = 20 } = req.query;
    const skip = (parseInt(page) - 1) * parseInt(limit);

    console.log('🔵 [GET NOTIFICATIONS]');
    console.log('   userId:', req.userId);
    console.log('   page:', page);
    console.log('   limit:', limit);

    const [notifications, total] = await Promise.all([
      Notification.find({ userId: req.userId })
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(parseInt(limit))
        .lean(),
      Notification.countDocuments({ userId: req.userId }),
    ]);

    console.log('✅ [GET NOTIFICATIONS] Found', notifications.length, 'notifications');
    console.log('   Total:', total);

    res.json({
      message: 'Lấy danh sách thông báo thành công',
      notifications: notifications.map(n => ({
        _id: n._id.toString(),
        userId: n.userId,
        type: n.type,
        title: n.title,
        message: n.message,
        rentalId: n.rentalId,
        details: n.details,
        read: n.read,
        createdAt: n.createdAt,
      })),
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
        pages: Math.ceil(total / parseInt(limit)),
      },
    });
  } catch (err) {
    console.error('❌ [GET NOTIFICATIONS] ERROR:', err);
    res.status(500).json({ 
      message: 'Lỗi server', 
      error: err.message 
    });
  }
});

// ✅ GET: Lấy một thông báo cụ thể
router.get('/notifications/:id', authMiddleware, async (req, res) => {
  try {
    const notification = await Notification.findById(req.params.id).lean();

    if (!notification) {
      return res.status(404).json({ message: 'Không tìm thấy thông báo' });
    }

    if (notification.userId !== req.userId) {
      return res.status(403).json({ message: 'Bạn không có quyền xem thông báo này' });
    }

    res.json({
      message: 'Thành công',
      data: {
        _id: notification._id.toString(),
        userId: notification.userId,
        type: notification.type,
        title: notification.title,
        message: notification.message,
        rentalId: notification.rentalId,
        details: notification.details,
        read: notification.read,
        createdAt: notification.createdAt,
      },
    });
  } catch (err) {
    console.error('❌ [GET NOTIFICATION] ERROR:', err);
    res.status(500).json({ 
      message: 'Lỗi server', 
      error: err.message 
    });
  }
});

// ✅ PATCH: Đánh dấu thông báo là đã đọc
router.patch('/notifications/:id/read', authMiddleware, async (req, res) => {
  try {
    const notification = await Notification.findById(req.params.id);

    if (!notification) {
      return res.status(404).json({ message: 'Không tìm thấy thông báo' });
    }

    if (notification.userId !== req.userId) {
      return res.status(403).json({ message: 'Bạn không có quyền cập nhật thông báo này' });
    }

    notification.read = true;
    await notification.save();

    console.log('✅ [MARK AS READ]');
    console.log('   notificationId:', req.params.id);
    console.log('   userId:', req.userId);

    res.json({
      message: 'Đã đánh dấu là đã đọc',
      data: {
        _id: notification._id.toString(),
        userId: notification.userId,
        type: notification.type,
        title: notification.title,
        message: notification.message,
        read: notification.read,
        createdAt: notification.createdAt,
      },
    });
  } catch (err) {
    console.error('❌ [MARK AS READ] ERROR:', err);
    res.status(500).json({ 
      message: 'Lỗi server', 
      error: err.message 
    });
  }
});

// ✅ PATCH: Đánh dấu tất cả thông báo là đã đọc
router.patch('/notifications/read-all', authMiddleware, async (req, res) => {
  try {
    console.log('🔵 [MARK ALL AS READ]');
    console.log('   userId:', req.userId);

    const result = await Notification.updateMany(
      { userId: req.userId, read: false },
      { read: true }
    );

    console.log('✅ [MARK ALL AS READ] Updated', result.modifiedCount, 'notifications');

    res.json({
      message: 'Đã đánh dấu tất cả thông báo là đã đọc',
      updatedCount: result.modifiedCount,
    });
  } catch (err) {
    console.error('❌ [MARK ALL AS READ] ERROR:', err);
    res.status(500).json({ 
      message: 'Lỗi server', 
      error: err.message 
    });
  }
});

// ✅ DELETE: Xóa một thông báo (CÓ BACKUP)
router.delete('/notifications/:id', authMiddleware, async (req, res) => {
  try {
    const notification = await Notification.findById(req.params.id);

    if (!notification) {
      return res.status(404).json({ message: 'Không tìm thấy thông báo' });
    }

    if (notification.userId !== req.userId) {
      return res.status(403).json({ message: 'Bạn không có quyền xóa thông báo này' });
    }

    await Notification.findByIdAndDelete(req.params.id);

    // Lưu vào undo stack - TỪNG cái riêng biệt
    await saveNotificationToUndoStack(req.userId, notification);

    console.log('✅ [DELETE NOTIFICATION]');
    console.log('   notificationId:', req.params.id);
    console.log('   userId:', req.userId);

    res.json({ 
      message: 'Xóa thông báo thành công. Bạn có thể hoàn tác trong 30 phút.',
      notificationId: req.params.id,
      canRestore: true
    });
  } catch (err) {
    console.error('❌ [DELETE NOTIFICATION] ERROR:', err);
    res.status(500).json({ 
      message: 'Lỗi server', 
      error: err.message 
    });
  }
});

// ✅ DELETE: Xóa tất cả thông báo (CÓ BACKUP)
router.delete('/notifications', authMiddleware, async (req, res) => {
  try {
    console.log('🔵 [DELETE ALL NOTIFICATIONS]');
    console.log('   userId:', req.userId);

    // Lấy thông báo trước khi xóa để lưu undo
    const deletedNotifications = await Notification.find({ userId: req.userId });
    
    const result = await Notification.deleteMany({ userId: req.userId });

    // Lưu vào undo stack - TỪNG cái riêng biệt
    if (deletedNotifications.length > 0) {
      for (const notification of deletedNotifications) {
        await saveNotificationToUndoStack(req.userId, notification);
      }
    }

    console.log('✅ [DELETE ALL NOTIFICATIONS] Deleted', result.deletedCount, 'notifications');

    res.json({
      message: 'Xóa tất cả thông báo thành công. Bạn có thể hoàn tác trong 30 phút.',
      deletedCount: result.deletedCount,
      canRestore: true
    });
  } catch (err) {
    console.error('❌ [DELETE ALL NOTIFICATIONS] ERROR:', err);
    res.status(500).json({ 
      message: 'Lỗi server', 
      error: err.message 
    });
  }
});

// ✅ GET: Lấy danh sách thông báo đã xóa (THÙNG RÁC)
router.get('/notifications/deleted/list', authMiddleware, async (req, res) => {
  try {
    console.log('🔵 [GET DELETED NOTIFICATIONS]');
    console.log('   userId:', req.userId);

    const deletedNotifications = await getDeletedNotifications(req.userId);

    res.json({
      message: 'Lấy danh sách thông báo đã xóa thành công',
      count: deletedNotifications.length,
      data: deletedNotifications.map(item => ({
        _id: item.notification._id,
        title: item.notification.title,
        message: item.notification.message,
        type: item.notification.type,
        timestamp: item.timestamp,
        createdAt: item.notification.createdAt,
      }))
    });
  } catch (err) {
    console.error('❌ [GET DELETED NOTIFICATIONS] ERROR:', err);
    res.status(500).json({ 
      message: 'Lỗi server', 
      error: err.message 
    });
  }
});

// ✅ POST: Hoàn tác xóa thông báo RIÊNG LẺ
router.post('/notifications/:id/restore', authMiddleware, async (req, res) => {
  try {
    const notificationId = req.params.id;

    console.log('🔵 [UNDO SINGLE NOTIFICATION]');
    console.log('   userId:', req.userId);
    console.log('   notificationId:', notificationId);

    const undoKey = `undo:notification:${req.userId}:${notificationId}`;

    // Lấy từng notification từ Redis
    const data = await redisClient.get(undoKey);

    if (!data) {
      console.log('⚠️ [UNDO SINGLE NOTIFICATION] No notification found in undo stack');
      return res.status(404).json({ 
        message: 'Không tìm thấy thông báo để hoàn tác hoặc hết thời gian (30 phút)' 
      });
    }

    const parsed = JSON.parse(data);
    const notifData = parsed.notification;

    // Khôi phục thông báo
    const restored = await Notification.create({
      _id: notifData._id,
      userId: notifData.userId,
      type: notifData.type,
      title: notifData.title,
      message: notifData.message,
      rentalId: notifData.rentalId,
      details: notifData.details,
      read: notifData.read,
      createdAt: notifData.createdAt,
    });

    // Xóa từ undo stack
    await deleteFromUndoStack(req.userId, notificationId);

    console.log('✅ [UNDO SINGLE NOTIFICATION] Restored notification', notificationId);

    res.json({
      message: 'Hoàn tác thành công',
      data: {
        _id: restored._id.toString(),
        userId: restored.userId,
        type: restored.type,
        title: restored.title,
        message: restored.message,
        rentalId: restored.rentalId,
        details: restored.details,
        read: restored.read,
        createdAt: restored.createdAt,
      },
    });
  } catch (err) {
    console.error('❌ [UNDO SINGLE NOTIFICATION] ERROR:', err);
    res.status(500).json({ 
      message: 'Lỗi server', 
      error: err.message 
    });
  }
});

// ✅ POST: Hoàn tác xóa tất cả thông báo
router.post('/notifications/restore', authMiddleware, async (req, res) => {
  try {
    console.log('🔵 [UNDO ALL NOTIFICATIONS]');
    console.log('   userId:', req.userId);

    const deletedNotifications = await getDeletedNotifications(req.userId);

    if (deletedNotifications.length === 0) {
      console.log('⚠️ [UNDO ALL NOTIFICATIONS] No deleted notifications');
      return res.status(404).json({ 
        message: 'Không có thông báo để hoàn tác' 
      });
    }

    console.log('   Restoring', deletedNotifications.length, 'notifications');

    // Khôi phục tất cả thông báo
    const restoredNotifications = [];
    for (const item of deletedNotifications) {
      const notifData = item.notification;
      
      const restored = await Notification.create({
        _id: notifData._id,
        userId: notifData.userId,
        type: notifData.type,
        title: notifData.title,
        message: notifData.message,
        rentalId: notifData.rentalId,
        details: notifData.details,
        read: notifData.read,
        createdAt: notifData.createdAt,
      });
      
      restoredNotifications.push(restored);

      // Xóa từ undo stack
      await deleteFromUndoStack(req.userId, notifData._id);
    }

    console.log('✅ [UNDO ALL NOTIFICATIONS] Restored', restoredNotifications.length, 'notifications');

    res.json({
      message: 'Hoàn tác thành công',
      restoredCount: restoredNotifications.length,
      notifications: restoredNotifications.map(n => ({
        _id: n._id.toString(),
        userId: n.userId,
        type: n.type,
        title: n.title,
        message: n.message,
        rentalId: n.rentalId,
        details: n.details,
        read: n.read,
        createdAt: n.createdAt,
      })),
    });
  } catch (err) {
    console.error('❌ [UNDO ALL NOTIFICATIONS] ERROR:', err);
    res.status(500).json({ 
      message: 'Lỗi server', 
      error: err.message 
    });
  }
});

// ✅ DELETE: Xóa vĩnh viễn notification từ undo stack
router.delete('/notifications/:id/permanent', authMiddleware, async (req, res) => {
  try {
    const notificationId = req.params.id;

    console.log('🔵 [PERMANENT DELETE UNDO]');
    console.log('   userId:', req.userId);
    console.log('   notificationId:', notificationId);

    const undoKey = `undo:notification:${req.userId}:${notificationId}`;

    // Kiểm tra notification tồn tại
    const data = await redisClient.get(undoKey);

    if (!data) {
      console.log('⚠️ [PERMANENT DELETE UNDO] No notification found');
      return res.status(404).json({ 
        message: 'Không tìm thấy thông báo để xóa' 
      });
    }

    // Xóa vĩnh viễn
    await redisClient.del(undoKey);

    console.log('✅ [PERMANENT DELETE UNDO] Permanently deleted', notificationId);

    res.json({
      message: 'Đã xóa vĩnh viễn thông báo',
      notificationId: notificationId,
    });
  } catch (err) {
    console.error('❌ [PERMANENT DELETE UNDO] ERROR:', err);
    res.status(500).json({ 
      message: 'Lỗi server', 
      error: err.message 
    });
  }
});

// ✅ GET: Lấy số lượng thông báo chưa đọc
router.get('/notifications/unread/count', authMiddleware, async (req, res) => {
  try {
    const unreadCount = await Notification.countDocuments({
      userId: req.userId,
      read: false,
    });

    console.log('✅ [GET UNREAD COUNT]');
    console.log('   userId:', req.userId);
    console.log('   unreadCount:', unreadCount);

    res.json({
      message: 'Thành công',
      unreadCount,
    });
  } catch (err) {
    console.error('❌ [GET UNREAD COUNT] ERROR:', err);
    res.status(500).json({ 
      message: 'Lỗi server', 
      error: err.message 
    });
  }
});

// ✅ GET: Thống kê thông báo
router.get('/notifications/stats/overview', authMiddleware, async (req, res) => {
  try {
    const stats = await Notification.aggregate([
      { $match: { userId: req.userId } },
      {
        $facet: {
          totalCount: [{ $count: 'count' }],
          unreadCount: [
            { $match: { read: false } },
            { $count: 'count' },
          ],
          byType: [
            { $group: { _id: '$type', count: { $sum: 1 } } },
          ],
          recent: [
            { $sort: { createdAt: -1 } },
            { $limit: 5 },
            { $project: { title: 1, type: 1, read: 1, createdAt: 1 } },
          ],
        },
      },
    ]);

    const data = stats[0];

    res.json({
      message: 'Lấy thống kê thành công',
      data: {
        totalCount: data.totalCount[0]?.count || 0,
        unreadCount: data.unreadCount[0]?.count || 0,
        byType: data.byType,
        recentNotifications: data.recent,
      },
    });
  } catch (err) {
    console.error('❌ [GET STATS] ERROR:', err);
    res.status(500).json({ 
      message: 'Lỗi server', 
      error: err.message 
    });
  }
});

// Export hàm để gọi từ server.js
module.exports = router;
module.exports.setRedisClient = setRedisClient;