import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String id;
  final String email;
  final String phoneNumber;
  final String address;
  final DateTime createdAt;
  final String? token;

  AppUser({
    required this.id,
    required this.email,
    required this.phoneNumber,
    required this.address,
    required this.createdAt,
    this.token,
  });

  factory AppUser.fromFirestore(Map<String, dynamic>? data, String id) {
    if (data == null) {
      throw Exception('User data is null');
    }
    return AppUser(
      id: id,
      email: data['email'] as String? ?? '',
      phoneNumber: data['phoneNumber'] as String? ?? '',
      address: data['address'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      token: data['token'] as String?,
    );
  }

  get avatarUrl => null;

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'phoneNumber': phoneNumber,
      'address': address,
      'createdAt': Timestamp.fromDate(createdAt),
      'token': token,
    };
  }
}