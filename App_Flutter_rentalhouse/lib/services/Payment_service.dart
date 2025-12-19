// services/payment_service.dart - FIXED VERSION
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';
import '../config/api_routes.dart';
import '../models/payment.dart';
import '../services/auth_service.dart';

class PaymentService {
  final AuthService _authService = AuthService();

  /// Tạo giao dịch thanh toán qua backend
  Future<Payment> createPaymentTransaction({
    required int amount,
    String? description,
  }) async {
    try {
      final token = await _authService.getIdToken();
      if (token == null) {
        throw Exception('Vui lòng đăng nhập để thanh toán');
      }

      debugPrint('🔵 Creating VNPay payment transaction via backend...');

      final response = await http
          .post(
        Uri.parse(ApiRoutes.vnpayCreatePayment),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'amount': amount,
        }),
      )
          .timeout(const Duration(seconds: 15));

      debugPrint('📡 VNPay create-payment status: ${response.statusCode}');
      debugPrint('📄 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          final txnRef = data['transactionCode'] as String? ?? '';
          final paymentUrl = data['paymentUrl'] as String?;

          if (txnRef.isEmpty || paymentUrl == null || paymentUrl.isEmpty) {
            throw Exception('Phản hồi tạo thanh toán không hợp lệ');
          }

          final expiresIn = (data['expiresIn'] as int?) ?? 15 * 60;

          debugPrint('✅ Payment transaction created: $txnRef');
          debugPrint('🌐 Payment URL: $paymentUrl');

          final now = DateTime.now();
          return Payment(
            transactionCode: txnRef,
            userId: '',
            rentalId: null,
            amount: data['amount'] is int ? data['amount'] as int : amount,
            description: description ?? 'Thanh toán phí đăng bài bất động sản',
            status: 'processing',
            paymentUrl: paymentUrl,
            vnpayTransactionId: null,
            responseCode: null,
            responseMessage: null,
            bankCode: null,
            bankTranNo: null,
            createdAt: now,
            completedAt: null,
            expiresAt: now.add(Duration(seconds: expiresIn)),
          );
        } else {
          throw Exception(
              data['message'] ?? 'Không tạo được yêu cầu thanh toán');
        }
      }

      throw Exception('Lỗi tạo link thanh toán (${response.statusCode})');
    } catch (e) {
      debugPrint('❌ Error creating payment transaction: $e');
      rethrow;
    }
  }

  /// Kiểm tra trạng thái thanh toán với retry logic
  Future<Map<String, dynamic>> checkPaymentStatus({
    required String transactionCode,
    int maxRetries = 3,
  }) async {
    try {
      final token = await _authService.getIdToken();
      if (token == null) {
        throw Exception('Vui lòng đăng nhập');
      }

      debugPrint('\n🔍 Checking payment status: $transactionCode');

      int attempt = 0;
      Exception? lastError;

      while (attempt < maxRetries) {
        try {
          attempt++;
          debugPrint('   Attempt $attempt/$maxRetries');

          final response = await http
              .get(
            Uri.parse(ApiRoutes.vnpayCheckPayment(transactionCode)),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
              .timeout(const Duration(seconds: 10));

          debugPrint('   Status code: ${response.statusCode}');
          debugPrint('   Response body: ${response.body}');

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body) as Map<String, dynamic>;

            if (data['success'] == true) {
              final paymentStatus = data['paymentStatus'] as Map<String, dynamic>?;

              if (paymentStatus != null) {
                debugPrint('   ✅ Got payment status: ${paymentStatus['status']}');
                debugPrint('   - Response code: ${paymentStatus['responseCode']}');
                debugPrint('   - Confirmed via: ${paymentStatus['confirmedVia']}');
                debugPrint('   - Confirmed at: ${paymentStatus['confirmedAt']}');
                debugPrint('   - Transaction No: ${paymentStatus['transactionNo']}');
                debugPrint('   - Bank code: ${paymentStatus['bankCode']}');

                return paymentStatus;
              }
            }

            // Nếu success = false, throw error với message
            throw Exception(data['message'] ?? 'Không lấy được trạng thái thanh toán');
          } else if (response.statusCode == 404) {
            throw Exception('Không tìm thấy giao dịch');
          } else if (response.statusCode == 403) {
            throw Exception('Bạn không có quyền xem giao dịch này');
          } else {
            throw Exception('Lỗi server (${response.statusCode})');
          }
        } catch (e) {
          lastError = e is Exception ? e : Exception(e.toString());
          debugPrint('   ⚠️ Attempt $attempt failed: $e');

          if (attempt < maxRetries) {
            // Đợi trước khi retry
            await Future.delayed(Duration(seconds: 2 * attempt));
          }
        }
      }

      // Hết retries
      throw lastError ?? Exception('Không thể kiểm tra trạng thái thanh toán');
    } catch (e) {
      debugPrint('❌ Error checking VNPay payment status: $e');
      rethrow;
    }
  }

  /// Kiểm tra trạng thái với polling (gọi nhiều lần cho đến khi có kết quả)
  Future<Map<String, dynamic>> pollPaymentStatus({
    required String transactionCode,
    int maxAttempts = 15,
    Duration delayBetweenAttempts = const Duration(seconds: 3),
  }) async {
    debugPrint('\n🔄 Starting payment status polling');
    debugPrint('   Transaction: $transactionCode');
    debugPrint('   Max attempts: $maxAttempts');
    debugPrint('   Delay: ${delayBetweenAttempts.inSeconds}s');

    for (int i = 0; i < maxAttempts; i++) {
      try {
        debugPrint('\n📡 Poll attempt ${i + 1}/$maxAttempts');

        final status = await checkPaymentStatus(
          transactionCode: transactionCode,
          maxRetries: 2, // Mỗi poll có 2 retries
        );

        final paymentStatus = status['status'] as String? ?? '';
        final isCompleted = status['isCompleted'] as bool? ?? false;

        debugPrint('   Current status: $paymentStatus');
        debugPrint('   Is completed: $isCompleted');

        // Nếu đã completed hoặc failed, return ngay
        if (paymentStatus == 'completed' || isCompleted == true) {
          debugPrint('✅ Payment completed!');
          return status;
        } else if (paymentStatus == 'failed' || paymentStatus == 'cancelled') {
          debugPrint('❌ Payment failed or cancelled');
          return status;
        }

        // Nếu vẫn processing, đợi rồi thử lại
        if (i < maxAttempts - 1) {
          debugPrint('   ⏳ Still processing, waiting ${delayBetweenAttempts.inSeconds}s...');
          await Future.delayed(delayBetweenAttempts);
        }
      } catch (e) {
        debugPrint('   ⚠️ Poll attempt ${i + 1} error: $e');

        // Nếu là lỗi không tìm thấy hoặc không có quyền, throw ngay
        if (e.toString().contains('Không tìm thấy') ||
            e.toString().contains('không có quyền')) {
          rethrow;
        }

        // Các lỗi khác, retry
        if (i < maxAttempts - 1) {
          await Future.delayed(delayBetweenAttempts);
        } else {
          rethrow; // Lỗi ở attempt cuối cùng
        }
      }
    }

    throw Exception(
        'Timeout: Không thể xác nhận trạng thái thanh toán sau ${maxAttempts * delayBetweenAttempts.inSeconds} giây'
    );
  }

  /// Lấy lịch sử thanh toán từ backend VNPay
  Future<List<Payment>> getPaymentHistory({
    int page = 1,
    int limit = 10,
    String? status,
  }) async {
    try {
      final token = await _authService.getIdToken();
      if (token == null) {
        throw Exception('Vui lòng đăng nhập');
      }

      final uri = Uri.parse(
        ApiRoutes.vnpayPaymentHistory(
          page: page,
          limit: limit,
          status: status,
        ),
      );

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          final List<dynamic> paymentsData = data['payments'] ?? [];
          return paymentsData
              .map((json) => Payment.fromJson(json as Map<String, dynamic>))
              .toList();
        }
      }

      throw Exception('Không lấy được lịch sử thanh toán');
    } catch (e) {
      debugPrint('❌ Error getting VNPay payment history: $e');
      rethrow;
    }
  }

  /// Format amount VND
  String formatAmount(int amount) {
    return '${amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
    )} đ';
  }
}