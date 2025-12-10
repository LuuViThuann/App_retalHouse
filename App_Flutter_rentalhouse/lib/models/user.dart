import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String id;
  final String email;
  final String phoneNumber;
  final String address;
  final DateTime createdAt;
  final String? token;
  final String? avatarUrl;
  final String username;
  final String role;

  AppUser({
    required this.id,
    required this.email,
    required this.phoneNumber,
    required this.address,
    required this.createdAt,
    this.token,
    this.avatarUrl,
    required this.username,
    this.role = 'user',
  });

  factory AppUser.fromJson(Map<String, dynamic> data) {
    return AppUser(
      id: data['id'] as String,
      email: data['email'] as String? ?? '',
      phoneNumber: data['phoneNumber'] as String? ?? '',
      address: data['address'] as String? ?? '',
      createdAt: DateTime.parse(
          data['createdAt'] as String? ?? DateTime.now().toIso8601String()),
      token: data['token'] as String?,
      avatarUrl: data['avatarUrl'] as String?,
      username: data['username'] as String? ?? '',
      role: data['role'] as String? ?? 'user',
    );
  }

  factory AppUser.fromFirestore(Map<String, dynamic>? data, String id) {
    if (data == null) {
      throw Exception('Dữ liệu người dùng không tồn tại');
    }
    return AppUser(
      id: id,
      email: data['email'] as String? ?? '',
      phoneNumber: data['phoneNumber'] as String? ?? '',
      address: data['address'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      token: data['token'] as String?,
      avatarUrl: data['avatarUrl'] as String?,
      username: data['username'] as String? ?? '',
      role: data['role'] as String? ?? 'user',
    );
  }

  // ✅ Không cần getter avatarUrl nữa vì đã là URL sẵn

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'phoneNumber': phoneNumber,
      'address': address,
      'createdAt': Timestamp.fromDate(createdAt),
      'token': token,
      'avatarUrl': avatarUrl,
      'username': username,
      'role': role,
    };
  }

  AppUser copyWith({
    String? id,
    String? email,
    String? phoneNumber,
    String? address,
    DateTime? createdAt,
    String? token,
    String? avatarUrl,
    String? username,
    String? role,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      address: address ?? this.address,
      createdAt: createdAt ?? this.createdAt,
      token: token ?? this.token,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      username: username ?? this.username,
      role: role ?? this.role,
    );
  }
}