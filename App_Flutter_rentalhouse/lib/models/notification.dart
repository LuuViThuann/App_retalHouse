import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

class NotificationModel {
  final String id;
  final String userId;
  final String type;
  final String title;
  final String message;
  final String? rentalId;
  final Map<String, dynamic>? details;
  final bool read;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    this.rentalId,
    this.details,
    required this.read,
    required this.createdAt,
  });

  // Lấy icon theo type
  String get icon {
    switch (type) {
      case 'rental_approved':
        return '✓';
      case 'rental_rejected':
        return '✗';
      case 'rental_deleted':
        return '🗑️';
      case 'comment':
        return '💬';
      case 'message':
        return '📧';
      default:
        return 'ℹ️';
    }
  }

  // Lấy màu theo type
  Color getColorByType() {
    switch (type) {
      case 'rental_approved':
        return const Color(0xFF4CAF50); // Green
      case 'rental_rejected':
        return const Color(0xFFF44336); // Red
      case 'rental_deleted':
        return const Color(0xFFFF9800); // Orange
      case 'comment':
        return const Color(0xFF2196F3); // Blue
      case 'message':
        return const Color(0xFF9C27B0); // Purple
      default:
        return const Color(0xFF757575); // Grey
    }
  }

  NotificationModel copyWith({
    String? id,
    String? userId,
    String? type,
    String? title,
    String? message,
    String? rentalId,
    Map<String, dynamic>? details,
    bool? read,
    DateTime? createdAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      rentalId: rentalId ?? this.rentalId,
      details: details ?? this.details,
      read: read ?? this.read,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    try {
      return NotificationModel(
        id: json['_id'] as String? ?? '',
        userId: json['userId'] as String? ?? '',
        type: json['type'] as String? ?? 'message',
        title: json['title'] as String? ?? '',
        message: json['message'] as String? ?? '',
        rentalId: json['rentalId'] as String?,
        details: json['details'] as Map<String, dynamic>?,
        read: json['read'] as bool? ?? false,
        createdAt: DateTime.parse(
          json['createdAt'] as String? ?? DateTime.now().toIso8601String(),
        ),
      );
    } catch (e) {
      debugPrint('Error parsing notification: $e');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() => {
        '_id': id,
        'userId': userId,
        'type': type,
        'title': title,
        'message': message,
        'rentalId': rentalId,
        'details': details,
        'read': read,
        'createdAt': createdAt.toIso8601String(),
      };
}
