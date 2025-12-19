// models/Payment.js - UPDATED for RETURN URL + IPN
const mongoose = require('mongoose');

const paymentSchema = new mongoose.Schema(
  {
    // ==================== UNIQUE IDENTIFIERS ====================
    transactionCode: {
      type: String,
      required: true,
      unique: true,
      index: true,
    },

    vnpayTransactionId: {
      type: String,
      sparse: true,
      index: true,
    },

    // ==================== USER & RENTAL INFO ====================
    userId: {
      type: String,
      required: true,
      index: true,
    },

    rentalId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Rental',
      sparse: true,
      index: true,
    },

    // ==================== PAYMENT DETAILS ====================
    amount: {
      type: Number,
      required: true,
      min: 1000,
      default: 10000,
    },

    description: {
      type: String,
      default: 'Thanh toán phí đăng bài bất động sản',
      maxlength: 200,
    },

    // ==================== PAYMENT STATUS ====================
    // ✅ UPDATED: Added 'pending_confirmation' for RETURN URL state
    status: {
      type: String,
      enum: ['processing', 'pending_confirmation', 'completed', 'failed', 'cancelled', 'expired'],
      default: 'processing',
      index: true,
    },

    // ==================== RETURN URL DATA (from user's browser) ====================
    vnpResponseCode: {
      type: String,
      sparse: true,
    },

    responseMessage: {
      type: String,
      sparse: true,
    },

    // ==================== IPN DATA (from VNPay server) ====================
    // ✅ UPDATED: Added fields for IPN tracking
    transactionNo: {
      type: String,
      sparse: true,
      index: true,
    },

    bankCode: {
      type: String,
      sparse: true,
    },

    bankTranNo: {
      type: String,
      sparse: true,
    },

    payDate: {
      type: String,
      sparse: true,
    },

    cardType: {
      type: String,
      sparse: true,
    },

    // ==================== CONFIRMATION TRACKING ====================
    // ✅ UPDATED: Track which callback confirmed the payment
    confirmedAt: {
      type: Date,
      sparse: true,
    },

    confirmedVia: {
      type: String,
      enum: ['return', 'ipn'],
      sparse: true,
    },

    failedAt: {
      type: Date,
      sparse: true,
    },

    // ==================== URLS & METADATA ====================
    paymentUrl: {
      type: String,
      sparse: true,
    },

    ipAddress: {
      type: String,
      sparse: true,
    },

    userAgent: {
      type: String,
      sparse: true,
    },

    // ==================== TIMESTAMPS ====================
    createdAt: {
      type: Date,
      default: Date.now,
      index: true,
    },

    // ✅ UPDATED: Renamed from completedAt to be more explicit
    completedAt: {
      type: Date,
      sparse: true,
    },

    // ⚠️ FIXED: TTL index only (no duplicate indexes)
    expiresAt: {
      type: Date,
      default: () => new Date(Date.now() + 15 * 60 * 1000),
    },

    retryCount: {
      type: Number,
      default: 0,
    },

    notes: {
      type: String,
      sparse: true,
    },
  },
  {
    timestamps: true,
    toJSON: { virtuals: true },
    toObject: { virtuals: true },
  }
);

// ==================== INDEXES ====================
// ✅ FIXED: TTL Index only - removed duplicates
paymentSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 900 });

// Compound indexes for common queries
paymentSchema.index({ userId: 1, createdAt: -1 });
paymentSchema.index({ status: 1, createdAt: -1 });

// ==================== VIRTUALS ====================
paymentSchema.virtual('isExpired').get(function () {
  return this.expiresAt < new Date() && this.status !== 'completed';
});

paymentSchema.virtual('isPending').get(function () {
  return this.status === 'processing' || this.status === 'pending_confirmation';
});

paymentSchema.virtual('isCompleted').get(function () {
  return this.status === 'completed';
});

paymentSchema.virtual('isFailed').get(function () {
  return this.status === 'failed' || this.status === 'cancelled';
});

paymentSchema.virtual('durationMinutes').get(function () {
  const diff = new Date() - this.createdAt;
  return Math.floor(diff / (1000 * 60));
});

// ==================== METHODS ====================

/**
 * Mark payment as completed
 * Called from both RETURN URL and IPN
 */
paymentSchema.methods.markAsCompleted = function (data = {}) {
  this.status = 'completed';
  this.completedAt = new Date();
  this.vnpayTransactionId = data.transactionNo;
  this.vnpResponseCode = data.responseCode || '00';
  this.responseMessage = data.responseMessage || 'Giao dịch thành công';
  this.transactionNo = data.transactionNo;
  this.bankCode = data.bankCode;
  this.bankTranNo = data.bankTranNo;
  this.payDate = data.payDate;
  this.cardType = data.cardType;
  this.confirmedAt = new Date();
  this.confirmedVia = data.confirmedVia || 'return';

  console.log(`✅ Payment marked as completed: ${this.transactionCode} (via ${this.confirmedVia})`);
  return this.save();
};

/**
 * Mark payment as failed
 * Called from both RETURN URL and IPN
 */
paymentSchema.methods.markAsFailed = function (responseCode, responseMessage) {
  this.status = 'failed';
  this.vnpResponseCode = responseCode;
  this.responseMessage = responseMessage;
  this.failedAt = new Date();

  console.log(`❌ Payment marked as failed: ${this.transactionCode} (Code: ${responseCode})`);
  return this.save();
};

/**
 * Mark as pending confirmation (after RETURN URL, waiting for IPN)
 */
paymentSchema.methods.markAsPendingConfirmation = function (data = {}) {
  this.status = 'pending_confirmation';
  this.vnpResponseCode = data.responseCode || '00';
  this.responseMessage = data.responseMessage || 'Chờ xác nhận từ VNPay';
  this.transactionNo = data.transactionNo;
  this.bankCode = data.bankCode;
  this.bankTranNo = data.bankTranNo;
  this.payDate = data.payDate;

  console.log(`⏳ Payment marked as pending_confirmation: ${this.transactionCode}`);
  return this.save();
};

/**
 * Check if payment is still valid
 */
paymentSchema.methods.isValid = function () {
  return !this.isExpired && !this.isCompleted && !this.isFailed;
};

/**
 * Get payment status info
 */
paymentSchema.methods.getStatusInfo = function () {
  return {
    transactionCode: this.transactionCode,
    status: this.status,
    amount: this.amount,
    description: this.description,
    isPending: this.isPending,
    isCompleted: this.isCompleted,
    isFailed: this.isFailed,
    isExpired: this.isExpired,
    createdAt: this.createdAt,
    completedAt: this.completedAt,
    expiresAt: this.expiresAt,
    durationMinutes: this.durationMinutes,
    responseCode: this.vnpResponseCode,
    responseMessage: this.responseMessage,
    transactionNo: this.transactionNo,
    bankCode: this.bankCode,
    bankTranNo: this.bankTranNo,
    confirmedAt: this.confirmedAt,
    confirmedVia: this.confirmedVia,
  };
};

/**
 * Get formatted amount
 */
paymentSchema.methods.getFormattedAmount = function () {
  return new Intl.NumberFormat('vi-VN', {
    style: 'currency',
    currency: 'VND',
  }).format(this.amount);
};

/**
 * Copy with updated fields
 */
paymentSchema.methods.copyWith = function (updates = {}) {
  const updated = { ...this.toObject(), ...updates };
  return updated;
};

// ==================== STATICS ====================

/**
 * Create new payment transaction
 */
paymentSchema.statics.createTransaction = async function (
  userId,
  amount = 10000,
  description = null
) {
  const transactionCode = `TXN${Date.now()}`;

  const payment = new this({
    transactionCode,
    userId,
    amount,
    description: description || 'Thanh toán phí đăng bài bất động sản',
    status: 'processing',
  });

  await payment.save();
  console.log(`📝 Payment transaction created: ${transactionCode}`);
  return payment;
};

/**
 * Find by transaction code
 */
paymentSchema.statics.findByTransactionCode = async function (transactionCode) {
  const payment = await this.findOne({ transactionCode });

  if (!payment) {
    throw new Error('Payment not found');
  }

  return payment;
};

/**
 * Find by transaction code and verify ownership
 */
paymentSchema.statics.findByTransactionCodeAndUser = async function (transactionCode, userId) {
  const payment = await this.findOne({ transactionCode });

  if (!payment) {
    throw new Error('Payment not found');
  }

  if (payment.userId !== userId) {
    throw new Error('Unauthorized: Payment does not belong to user');
  }

  return payment;
};

/**
 * Get user's payment history
 */
paymentSchema.statics.getUserHistory = async function (userId, options = {}) {
  const { page = 1, limit = 10, status = null } = options;

  const skip = (page - 1) * limit;

  const query = { userId };
  if (status) {
    query.status = status;
  }

  const payments = await this.find(query)
    .sort({ createdAt: -1 })
    .skip(skip)
    .limit(limit)
    .lean();

  const total = await this.countDocuments(query);

  return {
    payments,
    pagination: {
      page,
      limit,
      total,
      pages: Math.ceil(total / limit),
    },
  };
};

/**
 * Get payment statistics for admin
 */
paymentSchema.statics.getStatistics = async function (options = {}) {
  const {
    startDate = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000),
    endDate = new Date(),
  } = options;

  const stats = await this.aggregate([
    {
      $match: {
        createdAt: {
          $gte: startDate,
          $lte: endDate,
        },
      },
    },
    {
      $group: {
        _id: '$status',
        count: { $sum: 1 },
        totalAmount: { $sum: '$amount' },
      },
    },
    {
      $sort: { count: -1 },
    },
  ]);

  return {
    period: { startDate, endDate },
    stats,
  };
};

/**
 * Find payments pending IPN confirmation (older than 2 minutes)
 */
paymentSchema.statics.findPendingIPN = async function () {
  const twoMinutesAgo = new Date(Date.now() - 2 * 60 * 1000);

  const pending = await this.find({
    status: 'pending_confirmation',
    createdAt: { $lt: twoMinutesAgo },
  });

  return pending;
};

/**
 * Cleanup expired payments
 */
paymentSchema.statics.cleanupExpired = async function () {
  const now = new Date();

  const result = await this.deleteMany({
    status: { $in: ['processing', 'pending_confirmation'] },
    expiresAt: { $lt: now },
  });

  console.log(`🧹 Cleaned up ${result.deletedCount} expired payments`);
  return result;
};

// ==================== MIDDLEWARE ====================

// Auto-update updatedAt
paymentSchema.pre('save', function (next) {
  this.updatedAt = new Date();
  next();
});

// Log payment status changes
paymentSchema.post('save', function (doc) {
  console.log(`📝 Payment ${doc.transactionCode} updated: status=${doc.status}`);
});

module.exports = mongoose.model('Payment', paymentSchema);