import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../config/api_routes.dart';
import '../models/user.dart';

class AuthService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Đăng ký
  Future<AppUser?> register({
    required String email,
    required String password,
    required String phoneNumber,
    required String address,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(ApiRoutes.register),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'phoneNumber': phoneNumber,
          'address': address,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return AppUser(
          id: data['id'] as String,
          email: data['email'] as String,
          phoneNumber: data['phoneNumber'] as String,
          address: data['address'] as String,
          createdAt: DateTime.parse(data['createdAt'] as String),
          token: data['token'] ?? '',
        );
      } else {
        throw Exception('Đăng ký thất bại: ${response.body}');
      }
    } catch (e) {
      print('Error during registration: $e');
      throw Exception('Đăng ký thất bại: $e');
    }
  }

  // Đăng nhập
  Future<AppUser?> login({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final idToken = await userCredential.user?.getIdToken(true);
      if (idToken == null) throw Exception('Không thể lấy ID token');

      final response = await http.post(
        Uri.parse(ApiRoutes.login),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'idToken': idToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return AppUser(
          id: data['id'] as String,
          email: data['email'] as String,
          phoneNumber: data['phoneNumber'] as String,
          address: data['address'] as String,
          createdAt: DateTime.parse(data['createdAt'] as String),
          token: data['token'] ?? idToken,
        );
      } else {
        throw Exception('Đăng nhập thất bại: ${response.body}');
      }
    } catch (e) {
      print('Error during login: $e');
      throw Exception('Đăng nhập thất bại: $e');
    }
  }

  // Thay đổi mật khẩu
  Future<bool> changePassword({
    required String newPassword,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Không tìm thấy người dùng');

      final idToken = await user.getIdToken(true);
      final response = await http.post(
        Uri.parse(ApiRoutes.changePassword),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'idToken': idToken,
          'newPassword': newPassword,
        }),
      );

      if (response.statusCode == 200) {
        await user.updatePassword(newPassword);
        return true;
      } else {
        throw Exception('Thay đổi mật khẩu thất bại: ${response.body}');
      }
    } catch (e) {
      print('Error during password change: $e');
      throw Exception('Thay đổi mật khẩu thất bại: $e');
    }
  }

  // Cập nhật thông tin người dùng
  Future<AppUser?> updateProfile({
    required String phoneNumber,
    required String address,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Không tìm thấy người dùng');

      final idToken = await user.getIdToken(true);
      final response = await http.post(
        Uri.parse(ApiRoutes.updateProfile),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'idToken': idToken,
          'phoneNumber': phoneNumber,
          'address': address,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return AppUser(
          id: data['id'] as String,
          email: data['email'] as String,
          phoneNumber: data['phoneNumber'] as String,
          address: data['address'] as String,
          createdAt: DateTime.parse(data['createdAt'] as String? ?? DateTime.now().toIso8601String()),
          token: idToken,
        );
      } else {
        throw Exception('Cập nhật hồ sơ thất bại: ${response.body}');
      }
    } catch (e) {
      print('Error during profile update: $e');
      throw Exception('Cập nhật hồ sơ thất bại: $e');
    }
  }

  // Upload profile image
  Future<String?> uploadProfileImage({
    required String imageBase64,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Không tìm thấy người dùng');

      final idToken = await user.getIdToken(true);
      final response = await http.post(
        Uri.parse(ApiRoutes.uploadImage),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'idToken': idToken,
          'imageBase64': imageBase64,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['avatarBase64'] as String?;
      } else {
        throw Exception('Tải ảnh lên thất bại: ${response.body}');
      }
    } catch (e) {
      print('Error during image upload: $e');
      throw Exception('Tải ảnh lên thất bại: $e');
    }
  }

  // Fetch avatarBase64 from MongoDB
  Future<String?> fetchAvatarBase64(String userId, String idToken) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiRoutes.baseUrl}/user/$userId/avatar'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['avatarBase64'] as String?;
      } else {
        throw Exception('Không thể lấy avatarBase64: ${response.body}');
      }
    } catch (e) {
      print('Error fetching avatarBase64: $e');
      return null; // Return null if fetch fails, we'll handle it gracefully
    }
  }

  // Đăng xuất
  Future<bool> logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      return true;
    } catch (e) {
      print('Error during logout: $e');
      throw Exception('Đăng xuất thất bại: $e');
    }
  }

  // Lấy thông tin user hiện tại
  Future<AppUser?> getCurrentUser() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final idToken = await user.getIdToken(true);
      final doc = await _firestore.collection('Users').doc(user.uid).get();
      if (doc.exists) {
        // Fetch avatarBase64 from MongoDB
        final avatarBase64 = await fetchAvatarBase64(user.uid, idToken!);
        return AppUser.fromFirestore(doc.data(), doc.id).copyWith(
          token: idToken,
          avatarBase64: avatarBase64, // Include avatarBase64
        );
      }
      // If document doesn't exist, create it with basic data
      await _firestore.collection('Users').doc(user.uid).set({
        'email': user.email ?? '',
        'phoneNumber': '',
        'address': '',
        'createdAt': FieldValue.serverTimestamp(),
      });
      return AppUser(
        id: user.uid,
        email: user.email ?? '',
        phoneNumber: '',
        address: '',
        createdAt: DateTime.now(),
        token: idToken,
      );
    } catch (e) {
      print('Error getting current user: $e');
      if (e.toString().contains('permission-denied')) {
        throw Exception('Lỗi quyền truy cập Firestore. Vui lòng kiểm tra quy tắc bảo mật.');
      }
      throw Exception('Lỗi khi lấy thông tin người dùng: $e');
    }
  }
}

// Thêm extension để hỗ trợ copyWith cho AppUser
extension AppUserExtension on AppUser {
  AppUser copyWith({
    String? id,
    String? email,
    String? phoneNumber,
    String? address,
    DateTime? createdAt,
    String? token,
    String? avatarBase64,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      address: address ?? this.address,
      createdAt: createdAt ?? this.createdAt,
      token: token ?? this.token,
      avatarBase64: avatarBase64 ?? this.avatarBase64,
    );
  }
}