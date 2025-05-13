import 'package:flutter_rentalhouse/models/rental.dart';

class Favorite {
  final String userId;
  final String rentalId;
  final Rental? rental;
  final DateTime createdAt;

  Favorite({
    required this.userId,
    required this.rentalId,
    this.rental,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Favorite.fromJson(Map<String, dynamic> json) {
    return Favorite(
      userId: json['userId'] ?? '',
      rentalId: json['rentalId']?.toString() ?? '',
      rental: json['rentalId'] != null && json['rentalId'] is Map
          ? Rental.fromJson(json['rentalId'] as Map<String, dynamic>)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'rentalId': rentalId,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}