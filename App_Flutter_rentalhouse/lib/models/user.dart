import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String id;
  final String email;
  final String phoneNumber;
  final String address;
  final DateTime createdAt;
  final String? token;
  final String? avatarBase64;
  final String username;

  AppUser({
    required this.id,
    required this.email,
    required this.phoneNumber,
    required this.address,
    required this.createdAt,
    this.token,
    this.avatarBase64,
    required this.username,
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
      avatarBase64: data['avatarBase64'] as String?,
      username: data['username'] as String? ?? '',
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
      avatarBase64: data['avatarBase64'] as String?,
      username: data['username'] as String? ?? '',
    );
  }

  String? get avatarUrl {
    if (avatarBase64 != null && avatarBase64!.isNotEmpty) {
      return 'data:image/jpeg;base64,$avatarBase64';
    }
    return null;
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'phoneNumber': phoneNumber,
      'address': address,
      'createdAt': Timestamp.fromDate(createdAt),
      'token': token,
      // Không lưu avatarBase64 vào Firestore
    };
  }

  AppUser copyWith({
    String? id,
    String? email,
    String? phoneNumber,
    String? address,
    DateTime? createdAt,
    String? token,
    String? avatarBase64,
    String? username,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      address: address ?? this.address,
      createdAt: createdAt ?? this.createdAt,
      token: token ?? this.token,
      avatarBase64: avatarBase64 ?? this.avatarBase64,
      username: username ?? this.username,
    );
  }
}
