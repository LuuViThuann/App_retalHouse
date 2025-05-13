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
          token: data['token'] ?? '', // Xử lý null
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
      final idToken = await userCredential.user?.getIdToken();
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
          token: data['token'] ?? idToken, // Sử dụng idToken nếu API không trả về token
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

      final idToken = await user.getIdToken();
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
      if (user != null) {
        final idToken = await user.getIdToken();
        final doc = await _firestore.collection('Users').doc(user.uid).get();
        if (doc.exists) {
          return AppUser.fromFirestore(doc.data(), doc.id).copyWith(token: idToken);
        }
        throw Exception('Không tìm thấy thông tin người dùng trong Firestore');
      }
      return null;
    } catch (e) {
      print('Error getting current user: $e');
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
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      address: address ?? this.address,
      createdAt: createdAt ?? this.createdAt,
      token: token ?? this.token,
    );
  }
}