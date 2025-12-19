// models/payment.dart - UPDATED
import 'package:flutter/material.dart';

class Payment {
  final String transactionCode;
  final String userId;
  final String? rentalId;
  final int amount;
  final String description;
  final String status; // pending, processing, completed, failed, cancelled
  final String? paymentUrl;
  final String? vnpayTransactionId;
  final String? responseCode;
  final String? responseMessage;
  final String? bankCode;
  final String? bankTranNo; // ✅ THÊM: Bank transaction number
  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime expiresAt;

  Payment({
    required this.transactionCode,
    required this.userId,
    this.rentalId,
    required this.amount,
    required this.description,
    required this.status,
    this.paymentUrl,
    this.vnpayTransactionId,
    this.responseCode,
    this.responseMessage,
    this.bankCode,
    this.bankTranNo, // ✅ THÊM
    required this.createdAt,
    this.completedAt,
    required this.expiresAt,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      transactionCode: json['transactionCode'] ?? '',
      userId: json['userId'] ?? '',
      rentalId: json['rentalId'],
      amount: json['amount'] ?? 10000,
      description: json['description'] ?? '',
      status: json['status'] ?? 'pending',
      paymentUrl: json['paymentUrl'],
      vnpayTransactionId: json['vnpayTransactionId'],
      responseCode: json['responseCode'],
      responseMessage: json['responseMessage'],
      bankCode: json['bankCode'],
      bankTranNo: json['bankTranNo'], // ✅ THÊM
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'])
          : null,
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'])
          : DateTime.now().add(const Duration(minutes: 15)),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'transactionCode': transactionCode,
      'userId': userId,
      'rentalId': rentalId,
      'amount': amount,
      'description': description,
      'status': status,
      'paymentUrl': paymentUrl,
      'vnpayTransactionId': vnpayTransactionId,
      'responseCode': responseCode,
      'responseMessage': responseMessage,
      'bankCode': bankCode,
      'bankTranNo': bankTranNo, // ✅ THÊM
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
    };
  }

  bool get isCompleted => status == 'completed';
  bool get isPending => status == 'pending' || status == 'processing';
  bool get isFailed => status == 'failed' || status == 'cancelled';
  bool get isExpired => DateTime.now().isAfter(expiresAt) && !isCompleted;

  // ✅ THÊM: Helper để format amount
  String get formattedAmount {
    return '${amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
    )} đ';
  }

  // ✅ THÊM: Get status display text
  String get statusDisplay {
    switch (status) {
      case 'pending':
        return 'Chờ thanh toán';
      case 'processing':
        return 'Đang xử lý';
      case 'completed':
        return 'Thành công';
      case 'failed':
        return 'Thất bại';
      case 'cancelled':
        return 'Đã hủy';
      default:
        return 'Không xác định';
    }
  }

  // ✅ THÊM: Get status color
  Color get statusColor {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'processing':
        return Colors.orange;
      case 'failed':
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Payment copyWith({
    String? status,
    String? vnpayTransactionId,
    String? responseCode,
    String? responseMessage,
    String? bankCode,
    String? bankTranNo,
    DateTime? completedAt,
  }) {
    return Payment(
      transactionCode: transactionCode,
      userId: userId,
      rentalId: rentalId,
      amount: amount,
      description: description,
      status: status ?? this.status,
      paymentUrl: paymentUrl,
      vnpayTransactionId: vnpayTransactionId ?? this.vnpayTransactionId,
      responseCode: responseCode ?? this.responseCode,
      responseMessage: responseMessage ?? this.responseMessage,
      bankCode: bankCode ?? this.bankCode,
      bankTranNo: bankTranNo ?? this.bankTranNo, // ✅ THÊM
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
      expiresAt: expiresAt,
    );
  }
}