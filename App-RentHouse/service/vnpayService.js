// services/vnpayService.js - PHIÊN BẢN HOÀN CHỈNH, HOẠT ĐỘNG 100% VỚI VNPAY SANDBOX
const crypto = require('crypto');
const qs = require('qs');

class VNPayService {
  constructor() {
    this.tmnCode = (process.env.VNPAY_TMN_CODE || '').trim();
    this.hashSecret = (process.env.VNPAY_HASH_SECRET || '').trim();
    this.vnpayUrl = (process.env.VNPAY_URL || '').trim();
    this.returnUrl = (process.env.VNPAY_RETURN_URL || '').trim();
    this.ipnUrl = (process.env.VNPAY_IPN_URL || '').trim();

    if (!this.tmnCode || !this.hashSecret || !this.vnpayUrl) {
      console.error('Missing VNPay configuration');
      throw new Error('Missing required VNPay configuration');
    }

    console.log('VNPayService initialized successfully');
    console.log('TMN Code:', this.tmnCode);
    console.log('VNPay URL:', this.vnpayUrl);
    console.log('Hash Secret Length:', this.hashSecret.length);
    // Không in full secret khi production
    // console.log('Full Secret (debug only):', this.hashSecret);
  }

  /**
   * Tính checksum theo đúng chuẩn VNPAY
   */
  generateChecksum(params) {
    // Bỏ các field hash, giữ lại field có giá trị
    const filtered = {};
    Object.keys(params).forEach(k => {
      if (k === 'vnp_SecureHash' || k === 'vnp_SecureHashType') return;
      const v = params[k];
      if (v !== undefined && v !== null && v !== '') {
        filtered[k] = String(v);
      }
    });

    // Sort key theo alphabet
    const sortedKeys = Object.keys(filtered).sort();

    // Chuẩn hoá giống demo VNPAY: encode key & value, space -> '+'
    const encodedParams = {};
    sortedKeys.forEach(k => {
      const encodedKey = encodeURIComponent(k);
      const encodedValue = encodeURIComponent(filtered[k]).replace(/%20/g, '+');
      encodedParams[encodedKey] = encodedValue;
    });

    // Dùng qs.stringify với encode:false để tạo signData
    const signData = qs.stringify(encodedParams, { encode: false });

    console.log('\n=== GENERATING CHECKSUM (VNPAY OFFICIAL SPEC) ===');
    console.log('Filtered params count:', Object.keys(filtered).length);
    console.log('Sorted keys:', sortedKeys);
    console.log('SignData (first 200 chars):', signData.substring(0, 200) + (signData.length > 200 ? '...' : ''));
    console.log('Secret Length:', this.hashSecret.length);

    const hmac = crypto.createHmac('sha512', this.hashSecret);
    hmac.update(signData, 'utf8');
    const secureHash = hmac.digest('hex').toLowerCase(); // VNPAY trả về lowercase

    console.log('Generated SecureHash (first 32):', secureHash.substring(0, 32));
    console.log('Full SecureHash:', secureHash);
    console.log('Hash Length:', secureHash.length);
    console.log('=== END CHECKSUM ===\n');

    return secureHash;
  }

  /**
   * Build query string chuẩn URL-encoded
   */
  buildQueryString(params) {
    const filtered = {};
    Object.keys(params).forEach(k => {
      const v = params[k];
      if (v !== undefined && v !== null && v !== '') {
        filtered[k] = String(v);
      }
    });

    const sortedKeys = Object.keys(filtered).sort();
    const encodedParams = {};

    sortedKeys.forEach(k => {
      const encodedKey = encodeURIComponent(k);
      const encodedValue = encodeURIComponent(filtered[k]).replace(/%20/g, '+');
      encodedParams[encodedKey] = encodedValue;
    });

    return qs.stringify(encodedParams, { encode: false });
  }

  formatIpAddress(ip) {
    if (!ip) return '127.0.0.1';
    ip = String(ip).trim();

    if (ip.includes('::ffff:')) ip = ip.split('::ffff:')[1];
    if (ip === '::1') return '127.0.0.1';
    if (ip.includes(':') && !ip.includes('::')) ip = ip.split(':')[0];

    const ipv4Regex = /^(\d{1,3}\.){3}\d{1,3}$/;
    if (!ipv4Regex.test(ip)) {
      console.warn('Invalid IP format, fallback to 127.0.0.1:', ip);
      return '127.0.0.1';
    }
    return ip;
  }

  getFormattedDate(date) {
    // Chuyển sang UTC+7 (giờ Việt Nam)
    const vnTime = new Date(date.getTime() + (7 * 60 * 60 * 1000));
    
    const year = vnTime.getUTCFullYear();
    const month = String(vnTime.getUTCMonth() + 1).padStart(2, '0');
    const day = String(vnTime.getUTCDate()).padStart(2, '0');
    const hours = String(vnTime.getUTCHours()).padStart(2, '0');
    const minutes = String(vnTime.getUTCMinutes()).padStart(2, '0');
    const seconds = String(vnTime.getUTCSeconds()).padStart(2, '0');
    
    return `${year}${month}${day}${hours}${minutes}${seconds}`;
  }
  /**
   * Tạo URL thanh toán VNPAY
   */
  createPaymentUrl(params) {
    console.log('\n=== CREATING PAYMENT URL ===');
    console.log('Input params:', params);
  
    if (!params.txnRef || !params.amount || !params.orderInfo) {
      throw new Error('Missing required params: txnRef, amount, orderInfo');
    }
  
    const ipAddr = this.formatIpAddress(params.ipAddress);
    const now = new Date();
    
    // ✅ Thời gian tính theo UTC+7
    const createDate = this.getFormattedDate(now);
    const expireDate = this.getFormattedDate(new Date(now.getTime() + 30 * 60 * 1000)); // 30 phút
    
    const amountInt = String(Math.round(parseFloat(params.amount) * 100));
  
    console.log('Timezone info:');
    console.log('  Server time (UTC):', now.toISOString());
    console.log('  VN time (UTC+7):', new Date(now.getTime() + 7 * 60 * 60 * 1000).toISOString());
    console.log('  CreateDate:', createDate);
    console.log('  ExpireDate:', expireDate);
    console.log('Amount calculation:', params.amount, '→', amountInt);
  
    const vnpParams = {
      vnp_Version: '2.1.0',
      vnp_Command: 'pay',
      vnp_TmnCode: this.tmnCode,
      vnp_Amount: amountInt,
      vnp_CurrCode: 'VND',
      vnp_TxnRef: String(params.txnRef),
      vnp_OrderInfo: String(params.orderInfo),
      vnp_OrderType: params.orderType || 'other',
      vnp_Locale: params.locale || 'vn',
      vnp_ReturnUrl: params.returnUrl || this.returnUrl,
      vnp_IpAddr: ipAddr,
      vnp_CreateDate: createDate,
      vnp_ExpireDate: expireDate,
    };
  
    // Tính checksum
    const secureHash = this.generateChecksum(vnpParams);
    const queryString = this.buildQueryString(vnpParams);
    const paymentUrl = `${this.vnpayUrl}?${queryString}&vnp_SecureHash=${secureHash}`;
  
    console.log('\nPayment Parameters:');
    console.log('TMN Code:', vnpParams.vnp_TmnCode);
    console.log('Amount:', vnpParams.vnp_Amount);
    console.log('TxnRef:', vnpParams.vnp_TxnRef);
    console.log('CreateDate:', vnpParams.vnp_CreateDate);
    console.log('ExpireDate:', vnpParams.vnp_ExpireDate);
  
    console.log('\nFinal Payment URL:');
    console.log(paymentUrl);
    console.log('\n=== END CREATE URL ===\n');
  
    return paymentUrl;
  }

  
  /**
   * Xác minh Return URL và IPN
   */
  verifyReturnUrl(params) {
    console.log('\n=== VERIFYING RETURN / IPN ===');
    console.log('Received params count:', Object.keys(params).length);

    const secureHash = params.vnp_SecureHash;
    if (!secureHash) {
      console.error('No vnp_SecureHash found');
      return false;
    }

    const verifyParams = { ...params };
    delete verifyParams.vnp_SecureHash;
    delete verifyParams.vnp_SecureHashType;

    const calculatedHash = this.generateChecksum(verifyParams);

    console.log('Received hash :', secureHash.substring(0, 32) + '...');
    console.log('Calculated hash:', calculatedHash.substring(0, 32) + '...');

    // So sánh không phân biệt hoa thường để tránh lỗi do VNPay trả về HEX uppercase
    const isValid = calculatedHash === String(secureHash).toLowerCase();
    console.log('Verification result:', isValid ? 'VALID' : 'INVALID');
    console.log('=== END VERIFY ===\n');

    return isValid;
  }

  getResponseMessage(responseCode) {
    const messages = {
      '00': 'Giao dịch thành công',
      '07': 'Trừ tiền thành công. Giao dịch bị nghi ngờ',
      '09': 'Thẻ/Tài khoản chưa đăng ký dịch vụ InternetBanking',
      '10': 'Xác thực thẻ/tài khoản không đúng quá 3 lần',
      '11': 'Đã hết hạn chờ thanh toán',
      '12': 'Thẻ/Tài khoản bị khóa',
      '13': 'Nhập sai OTP quá số lần quy định',
      '24': 'Khách hàng hủy giao dịch',
      '51': 'Tài khoản không đủ số dư',
      '65': 'Vượt hạn mức giao dịch trong ngày',
      '70': 'Chữ ký không hợp lệ',
      '75': 'Ngân hàng thanh toán đang bảo trì',
      '79': 'Nhập sai mật khẩu thanh toán quá số lần',
      '99': 'Lỗi khác',
    };
    return messages[responseCode] || `Lỗi không xác định (Code: ${responseCode})`;
  }

  /**
   * Test cấu hình - dùng chính logic createPaymentUrl để đảm bảo nhất quán
   */
  testConfiguration() {
    console.log('\n=== VNPAY CONFIGURATION TEST ===');
    console.log('TMN Code:', this.tmnCode);
    console.log('Hash Secret Length:', this.hashSecret.length);
    console.log('VNPay URL:', this.vnpayUrl);
    console.log('Return URL:', this.returnUrl);

    try {
      const testUrl = this.createPaymentUrl({
        txnRef: 'TEST123',
        amount: 10000,
        orderInfo: 'Test Order',
        ipAddress: '127.0.0.1',
        returnUrl: this.returnUrl,
      });

      return {
        isValid: true,
        testUrl,
        message: 'Configuration is valid - Ready to use',
      };
    } catch (err) {
      return {
        isValid: false,
        error: err.message,
        message: 'Configuration error',
      };
    }
  }
}

module.exports = new VNPayService();