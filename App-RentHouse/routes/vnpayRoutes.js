// routes/vnpayRoutes.js - FIXED IPN HANDLER
require('dotenv').config();
const express = require('express');
const router = express.Router();
const admin = require('firebase-admin');
const Payment = require('../models/Payment');
const Rental = require('../models/Rental');
const vnpayService = require('../service/vnpayService');

// ==================== MIDDLEWARE ====================
const authMiddleware = async (req, res, next) => {
  const token = req.header('Authorization')?.replace('Bearer ', '');
  if (!token) return res.status(401).json({ message: 'No token provided' });
  try {
    const decodedToken = await admin.auth().verifyIdToken(token);
    req.userId = decodedToken.uid;
    next();
  } catch (err) {
    res.status(401).json({ message: 'Invalid token', error: err.message });
  }
};

// ==================== ENDPOINTS ====================

/**
 * POST /api/vnpay/create-payment
 */
router.post('/create-payment', authMiddleware, async (req, res) => {
  try {
    const { amount = 10000 } = req.body;
    
    if (!amount || amount < 1000) {
      return res.status(400).json({
        success: false,
        message: 'Số tiền thanh toán phải từ 1,000 VND trở lên',
      });
    }

    const payment = await Payment.createTransaction(
      req.userId,
      amount,
      'Thanh toán phí đăng bài bất động sản'
    );

    const ipAddress = req.headers['x-forwarded-for']?.split(',')[0].trim() ||
                     req.headers['x-real-ip'] ||
                     req.connection.remoteAddress ||
                     req.socket.remoteAddress ||
                     '127.0.0.1';

    console.log('📋 Creating payment for:', {
      transactionCode: payment.transactionCode,
      userId: req.userId,
      amount: payment.amount,
      ip: ipAddress,
    });

    const paymentUrl = vnpayService.createPaymentUrl({
      txnRef: payment.transactionCode,
      amount: payment.amount,
      orderInfo: `Thanh toan phi dang bai - ${payment.transactionCode}`,
      ipAddress: ipAddress,
      returnUrl: process.env.VNPAY_RETURN_URL,
    });

    payment.paymentUrl = paymentUrl;
    payment.status = 'processing';
    payment.ipAddress = ipAddress;
    payment.userAgent = req.get('user-agent');
    await payment.save();

    console.log(`✅ Payment created: ${payment.transactionCode}`);
    console.log(`🌐 Payment URL: ${paymentUrl}`);

    res.json({
      success: true,
      message: 'Tạo link thanh toán thành công',
      paymentUrl,
      transactionCode: payment.transactionCode,
      amount: payment.amount,
      expiresIn: 15 * 60,
    });
  } catch (err) {
    console.error('❌ Error creating payment:', err);
    res.status(500).json({
      success: false,
      message: 'Lỗi tạo link thanh toán',
      error: err.message,
    });
  }
});

/**
 * GET /api/vnpay/return
 * ✅ RETURN URL - User browser redirect callback
 */
router.get('/return', async (req, res) => {
  try {
    console.log('\n========== VNPAY RETURN CALLBACK (GET) ==========');
    console.log('Timestamp:', new Date().toISOString());
    console.log('Query params count:', Object.keys(req.query).length);

    // Verify checksum
    const isValidChecksum = vnpayService.verifyReturnUrl(req.query);

    if (!isValidChecksum) {
      console.error('❌ CHECKSUM INVALID');
      return res.json({
        success: false,
        message: 'Chữ ký không hợp lệ',
        transactionCode: req.query.vnp_TxnRef,
      });
    }

    const transactionCode = req.query.vnp_TxnRef;
    const responseCode = req.query.vnp_ResponseCode;

    console.log(`🔍 Return - TxnRef: ${transactionCode}, ResponseCode: ${responseCode}`);
    
    const payment = await Payment.findOne({ transactionCode });

    if (!payment) {
      console.error(`❌ Payment not found: ${transactionCode}`);
      return res.json({
        success: false,
        message: 'Không tìm thấy giao dịch',
        transactionCode,
      });
    }

    console.log(`✅ Found payment, current status: ${payment.status}`);

    if (responseCode === '00') {
      // ✅ SUCCESS
      payment.status = 'completed';
      payment.vnpResponseCode = responseCode;
      payment.responseMessage = vnpayService.getResponseMessage(responseCode);
      payment.transactionNo = req.query.vnp_TransactionNo;
      payment.bankTranNo = req.query.vnp_BankTranNo;
      payment.bankCode = req.query.vnp_BankCode;
      payment.payDate = req.query.vnp_PayDate;
      payment.confirmedAt = new Date();
      payment.confirmedVia = 'return';
      payment.completedAt = new Date();
      await payment.save();

      console.log(`\n🎉 PAYMENT COMPLETED VIA RETURN URL`);
      console.log(`TransactionCode: ${transactionCode}`);
      console.log(`TransactionNo: ${payment.transactionNo}`);

      return res.json({
        success: true,
        message: 'Thanh toán thành công',
        transactionCode,
        amount: payment.amount,
        status: 'completed',
      });
    } else {
      // ❌ FAILED
      payment.status = 'failed';
      payment.vnpResponseCode = responseCode;
      payment.responseMessage = vnpayService.getResponseMessage(responseCode);
      payment.failedAt = new Date();
      await payment.save();

      console.error(`❌ Payment failed: ${responseCode}`);

      return res.json({
        success: false,
        message: vnpayService.getResponseMessage(responseCode),
        transactionCode,
        status: 'failed',
      });
    }
  } catch (err) {
    console.error('❌ RETURN callback error:', err);
    return res.json({
      success: false,
      message: 'Lỗi xử lý thanh toán',
      error: err.message,
    });
  }
});

/**
 * 🔧 FIXED: GET /api/vnpay/ipn
 * VNPay sandbox GỬI QUA req.query (GET method), KHÔNG PHẢI req.body
 */
router.get('/ipn', async (req, res) => {
  try {
    console.log('\n========== VNPAY IPN CALLBACK (GET) ==========');
    console.log('Timestamp:', new Date().toISOString());
    console.log('Query keys count:', Object.keys(req.query).length);

    // ✅ FIX: Đọc từ req.query thay vì req.body
    const params = req.query;

    // Verify checksum
    const isValidChecksum = vnpayService.verifyReturnUrl(params);

    if (!isValidChecksum) {
      console.error('❌ IPN - Checksum invalid');
      return res.json({
        RspCode: '97',
        Message: 'Fail checksum',
      });
    }

    const transactionCode = params.vnp_TxnRef;
    const responseCode = params.vnp_ResponseCode;

    console.log(`🔍 IPN - TxnRef: ${transactionCode}, ResponseCode: ${responseCode}`);

    const payment = await Payment.findOne({ transactionCode });

    if (!payment) {
      console.warn(`⚠️ Payment not found in IPN: ${transactionCode}`);
      return res.json({
        RspCode: '01',
        Message: 'Order not found',
      });
    }

    // Check if already processed
    if (payment.status === 'completed') {
      console.log(`ℹ️ Payment already completed: ${transactionCode}`);
      return res.json({
        RspCode: '00',
        Message: 'Confirm Success',
      });
    }

    // ✅ FIX: Đọc từ params thay vì req.body
    if (responseCode === '00') {
      payment.status = 'completed';
      payment.vnpResponseCode = responseCode;
      payment.responseMessage = vnpayService.getResponseMessage(responseCode);
      payment.transactionNo = params.vnp_TransactionNo; // ✅ FIX
      payment.bankTranNo = params.vnp_BankTranNo;       // ✅ FIX
      payment.bankCode = params.vnp_BankCode;           // ✅ FIX
      payment.payDate = params.vnp_PayDate;             // ✅ FIX
      payment.confirmedAt = new Date();
      payment.confirmedVia = 'ipn';
      payment.completedAt = new Date();
      await payment.save();

      console.log(`\n🎉 PAYMENT CONFIRMED VIA IPN`);
      console.log(`TransactionCode: ${transactionCode}`);
      console.log(`TransactionNo: ${payment.transactionNo}`);
      console.log(`Bank: ${payment.bankCode}`);

      // Auto-mark rental as paid if linked
      if (payment.rentalId) {
        await Rental.findByIdAndUpdate(
          payment.rentalId,
          {
            paymentStatus: 'completed',
            isPaid: true,
            paidAt: new Date(),
            paymentTransactionCode: transactionCode,
          }
        );
        console.log(`✅ Rental auto-marked as paid: ${payment.rentalId}`);
      }

      return res.json({
        RspCode: '00',
        Message: 'Confirm Success',
      });
    } else {
      payment.status = 'failed';
      payment.vnpResponseCode = responseCode;
      payment.responseMessage = vnpayService.getResponseMessage(responseCode);
      payment.failedAt = new Date();
      await payment.save();

      console.error(`❌ Payment failed via IPN: ${responseCode}`);

      return res.json({
        RspCode: '00',
        Message: 'Confirm Success',
      });
    }
  } catch (err) {
    console.error('❌ IPN error:', err);
    console.error('Stack:', err.stack);
    return res.json({
      RspCode: '99',
      Message: 'Internal error',
    });
  }
});

/**
 * GET /api/vnpay/check-payment/:transactionCode
 */
router.get('/check-payment/:transactionCode', authMiddleware, async (req, res) => {
  try {
    const { transactionCode } = req.params;

    console.log(`\n🔍 CHECK PAYMENT: ${transactionCode}`);

    const payment = await Payment.findOne({ transactionCode });

    if (!payment) {
      return res.status(404).json({
        success: false,
        message: 'Không tìm thấy giao dịch',
      });
    }

    if (payment.userId !== req.userId) {
      return res.status(403).json({
        success: false,
        message: 'Bạn không có quyền kiểm tra giao dịch này',
      });
    }

    console.log(`   Status: ${payment.status}`);
    console.log(`   ConfirmedVia: ${payment.confirmedVia || 'NOT_CONFIRMED_YET'}`);
    console.log(`   ConfirmedAt: ${payment.confirmedAt || 'NOT_CONFIRMED_YET'}`);

    res.json({
      success: true,
      paymentStatus: {
        status: payment.status,
        amount: payment.amount,
        transactionCode: payment.transactionCode,
        responseCode: payment.vnpResponseCode,
        responseMessage: payment.responseMessage,
        transactionNo: payment.transactionNo,
        bankCode: payment.bankCode,
        bankTranNo: payment.bankTranNo,
        createdAt: payment.createdAt,
        confirmedAt: payment.confirmedAt,
        confirmedVia: payment.confirmedVia,
        isCompleted: payment.status === 'completed',
      },
    });
  } catch (err) {
    console.error('❌ Error checking payment:', err);
    res.status(500).json({
      success: false,
      message: 'Lỗi kiểm tra trạng thái',
      error: err.message,
    });
  }
});

/**
 * GET /api/vnpay/payment-history
 */
router.get('/payment-history', authMiddleware, async (req, res) => {
  try {
    const { page = 1, limit = 10, status } = req.query;

    const history = await Payment.getUserHistory(req.userId, {
      page: Number(page),
      limit: Number(limit),
      status: status || null,
    });

    res.json({
      success: true,
      ...history,
    });
  } catch (err) {
    console.error('❌ Error fetching payment history:', err);
    res.status(500).json({
      success: false,
      message: 'Lỗi lấy lịch sử thanh toán',
      error: err.message,
    });
  }
});

/**
 * POST /api/vnpay/verify-and-publish
 */
router.post('/verify-and-publish', authMiddleware, async (req, res) => {
  try {
    const { transactionCode, rentalId } = req.body;

    if (!transactionCode || !rentalId) {
      return res.status(400).json({
        success: false,
        message: 'transactionCode và rentalId là bắt buộc',
      });
    }

    const payment = await Payment.findOne({ transactionCode });

    if (!payment) {
      return res.status(404).json({
        success: false,
        message: 'Không tìm thấy giao dịch thanh toán',
      });
    }

    if (payment.userId !== req.userId) {
      return res.status(403).json({
        success: false,
        message: 'Giao dịch không thuộc về bạn',
      });
    }

    if (payment.status !== 'completed') {
      return res.status(402).json({
        success: false,
        message: 'Thanh toán chưa hoàn tất',
        paymentStatus: payment.status,
        hint: 'Vui lòng chờ VNPay xác nhận',
      });
    }

    const rental = await Rental.findById(rentalId);

    if (!rental) {
      return res.status(404).json({
        success: false,
        message: 'Không tìm thấy bài đăng',
      });
    }

    if (rental.userId !== req.userId) {
      return res.status(403).json({
        success: false,
        message: 'Bài đăng không thuộc về bạn',
      });
    }

    // Link and mark as paid
    await rental.markAsPaid(payment._id, transactionCode);
    payment.rentalId = rentalId;
    await payment.save();

    console.log(`✅ Rental published: ${rentalId} with payment ${transactionCode}`);

    res.json({
      success: true,
      message: 'Bài đăng đã được xuất bản thành công',
      rental: {
        id: rental._id,
        title: rental.title,
        paymentStatus: rental.getPaymentStatus(),
      },
    });
  } catch (err) {
    console.error('❌ Error verifying and publishing:', err);
    res.status(500).json({
      success: false,
      message: 'Lỗi xác thực và xuất bản',
      error: err.message,
    });
  }
});

module.exports = router;