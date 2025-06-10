import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter_rentalhouse/config/loading.dart';
import 'package:flutter_rentalhouse/models/comments.dart';
import 'package:flutter_rentalhouse/models/notification.dart';
import 'package:flutter_rentalhouse/models/rental.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import '../config/api_routes.dart';
import '../models/user.dart';

class AuthService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FacebookAuth _facebookAuth = FacebookAuth.instance;

  // Đăng ký
  Future<AppUser?> register({
    required String email,
    required String password,
    required String phoneNumber,
    required String address,
    required String username,
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
          'username': username,
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
          username: data['username'] as String,
          token: '', // Không lưu token
        );
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(
            'Đăng ký thất bại: ${errorData['message'] ?? response.body}');
      }
    } catch (e) {
      print('Error during registration: $e');
      throw Exception('Đăng ký thất bại: ${e.toString()}');
    }
  }

  // Đăng nhập
  Future<AppUser?> login({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
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
        final avatarBase64 =
            await fetchAvatarBase64(userCredential.user!.uid, idToken);
        return AppUser(
          id: data['id'] as String,
          email: data['email'] as String,
          phoneNumber: data['phoneNumber'] as String,
          address: data['address'] as String,
          createdAt: DateTime.parse(data['createdAt'] as String),
          token: data['token'] ?? idToken,
          avatarBase64: avatarBase64,
          username: data['username'] as String? ?? '',
        );
      } else {
        throw Exception('Đăng nhập thất bại: ${response.body}');
      }
    } catch (e) {
      print('Error during login: $e');
      throw Exception('Đăng nhập thất bại: $e');
    }
  }

  // Đăng nhập bằng Google
  Future<AppUser?> signInWithGoogle() async {
    try {
      // Đăng xuất và ngắt kết nối Google trước để buộc chọn tài khoản
      await _googleSignIn.signOut();
      await _googleSignIn.disconnect().catchError((e) {
        print('Error disconnecting Google before login: $e');
      });

      // Buộc chọn tài khoản Google
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        print('Google Sign-In cancelled by user');
        return null; // Người dùng hủy
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) throw Exception('Firebase user is null');

      final idToken = await user.getIdToken(true);
      if (idToken == null) throw Exception('Không thể lấy ID token');

      // Đặt Persistence.NONE sau khi đăng nhập
      await _auth.setPersistence(Persistence.NONE).catchError((e) {
        print('Error setting persistence after Google sign-in: $e');
      });

      // Kiểm tra và tạo tài liệu Firestore
      final docRef = _firestore.collection('Users').doc(user.uid);
      final docSnapshot = await docRef.get();
      if (!docSnapshot.exists) {
        await docRef.set({
          'email': user.email ?? '',
          'phoneNumber': '',
          'address': '',
          'username': user.displayName ?? '',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      final response = await http.post(
        Uri.parse(ApiRoutes.login),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'idToken': idToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final avatarBase64 = await fetchAvatarBase64(user.uid, idToken);
        return AppUser(
          id: data['id'] as String,
          email: data['email'] as String,
          phoneNumber: data['phoneNumber'] as String,
          address: data['address'] as String,
          createdAt: DateTime.parse(data['createdAt'] as String),
          username: data['username'] as String? ?? user.displayName ?? '',
          avatarBase64: avatarBase64,
          token: '', // Không lưu token
        );
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(
            'Đăng nhập Google thất bại: ${errorData['message'] ?? response.body}');
      }
    } catch (e) {
      print('Error during Google sign-in: $e');
      throw Exception('Đăng nhập Google thất bại: ${e.toString()}');
    }
  }

  // Đăng nhập bằng Facebook
  Future<AppUser?> signInWithFacebook() async {
    try {
      // Đăng xuất và xóa token Facebook trước để buộc chọn tài khoản
      await _facebookAuth.logOut().catchError((e) {
        print('Error logging out Facebook before login: $e');
      });

      final LoginResult result = await _facebookAuth.login(
        permissions: ['email', 'public_profile'],
        loginBehavior: LoginBehavior.dialogOnly,
      );

      if (result.status != LoginStatus.success) {
        print('Facebook login failed: ${result.message}');
        return null;
      }

      final AccessToken? accessToken = result.accessToken;
      if (accessToken == null) {
        print('Facebook access token is null');
        return null;
      }

      final facebookAuthCredential =
          FacebookAuthProvider.credential(accessToken.token);
      final userCredential =
          await _auth.signInWithCredential(facebookAuthCredential);
      final user = userCredential.user;
      if (user == null) {
        print('Firebase user is null');
        return null;
      }

      final idToken = await user.getIdToken(true);
      if (idToken == null) {
        throw Exception('Không thể lấy ID token');
      }

      // Đặt Persistence.NONE sau khi đăng nhập
      await _auth.setPersistence(Persistence.NONE).catchError((e) {
        print('Error setting persistence after Facebook sign-in: $e');
      });

      // Kiểm tra và tạo tài liệu Firestore
      final docRef = _firestore.collection('Users').doc(user.uid);
      final docSnapshot = await docRef.get();
      if (!docSnapshot.exists) {
        await docRef.set({
          'email': user.email ?? '',
          'phoneNumber': '',
          'address': '',
          'username': user.displayName ?? '',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      final response = await http.post(
        Uri.parse(ApiRoutes.login),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'idToken': idToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final avatarBase64 = await fetchAvatarBase64(user.uid, idToken);
        return AppUser(
          id: data['id'] as String,
          email: data['email'] as String,
          phoneNumber: data['phoneNumber'] as String,
          address: data['address'] as String,
          createdAt: DateTime.parse(data['createdAt'] as String),
          username: data['username'] as String? ?? user.displayName ?? '',
          avatarBase64: avatarBase64,
          token: '', // Không lưu token
        );
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(
            'Đăng nhập Facebook thất bại: ${errorData['message'] ?? response.body}');
      }
    } catch (e) {
      print('Error during Facebook sign-in: $e');
      throw Exception('Đăng nhập Facebook thất bại: ${e.toString()}');
    }
  }

  // Gửi email đặt lại mật khẩu
  Future<String> sendPasswordResetEmail(String email) async {
    try {
      final response = await http.post(
        Uri.parse(ApiRoutes.sendResetEmail),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      if (response.statusCode == 200) {
        print('Password reset email sent to: $email');
        return 'Email đặt lại mật khẩu đã được gửi thành công';
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(
            'Gửi email thất bại: ${errorData['message'] ?? response.body}');
      }
    } catch (e) {
      print('Error sending password reset email: $e');
      throw Exception('Gửi email thất bại: ${e.toString()}');
    }
  }

  // Đặt lại mật khẩu với mã OOB
  Future<void> resetPassword(String oobCode, String newPassword) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiRoutes.baseUrl}/auth/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'oobCode': oobCode,
          'newPassword': newPassword,
        }),
      );

      if (response.statusCode != 200) {
        final errorData = jsonDecode(response.body);
        throw Exception(
            'Đặt lại mật khẩu thất bại: ${errorData['message'] ?? response.body}');
      }
    } catch (e) {
      print('Error resetting password: $e');
      throw Exception('Đặt lại mật khẩu thất bại: ${e.toString()}');
    }
  }

  // Thay đổi mật khẩu
  Future<bool> changePassword({
    required String newPassword,
  }) async {
    try {
      final user = _auth.currentUser;
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
        final errorData = jsonDecode(response.body);
        throw Exception(
            'Thay đổi mật khẩu thất bại: ${errorData['message'] ?? response.body}');
      }
    } catch (e) {
      print('Error during password change: $e');
      throw Exception('Thay đổi mật khẩu thất bại: ${e.toString()}');
    }
  }

  // Cập nhật thông tin người dùng
  Future<AppUser?> updateProfile({
    required String phoneNumber,
    required String address,
    required String username,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Không tìm thấy người dùng');

      final idToken = await user.getIdToken(true);
      final response = await http.post(
        Uri.parse(ApiRoutes.updateProfile),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'idToken': idToken,
          'phoneNumber': phoneNumber,
          'address': address,
          'username': username,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return AppUser(
          id: data['id'] as String,
          email: data['email'] as String,
          phoneNumber: data['phoneNumber'] as String,
          address: data['address'] as String,
          createdAt: DateTime.parse(
              data['createdAt'] as String? ?? DateTime.now().toIso8601String()),
          username: data['username'] as String? ?? '',
          token: '', // Không lưu token
        );
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(
            'Cập nhật hồ sơ thất bại: ${errorData['message'] ?? response.body}');
      }
    } catch (e) {
      print('Error during profile update: $e');
      throw Exception('Cập nhật hồ sơ thất bại: ${e.toString()}');
    }
  }

  // Upload profile image
  Future<String?> uploadProfileImage({
    required String imageBase64,
  }) async {
    try {
      final user = _auth.currentUser;
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
        final errorData = jsonDecode(response.body);
        throw Exception(
            'Tải ảnh lên thất bại: ${errorData['message'] ?? response.body}');
      }
    } catch (e) {
      print('Error during image upload: $e');
      throw Exception('Tải ảnh lên thất bại: ${e.toString()}');
    }
  }

  // Fetch avatarBase64 from MongoDB
  Future<String?> fetchAvatarBase64(String userId, String idToken) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiRoutes.baseUrl}/auth/user/$userId/avatar'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['avatarBase64'] as String?;
      } else {
        print('Failed to fetch avatarBase64: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error fetching avatarBase64: $e');
      return null;
    }
  }

  Future<bool> logout() async {
    try {
      // Đăng xuất khỏi Google và ngắt kết nối hoàn toàn
      await _googleSignIn.signOut();
      await _googleSignIn.disconnect().catchError((e) {
        print('Error disconnecting Google: $e');
      });

      // Đăng xuất khỏi Facebook
      await _facebookAuth.logOut().catchError((e) {
        print('Error logging out Facebook: $e');
      });

      // Đăng xuất khỏi Firebase
      await _auth.signOut();

      // Đảm bảo xóa cache phiên
      await _auth.setPersistence(Persistence.NONE).catchError((e) {
        print('Error setting persistence after logout: $e');
      });

      // Xác minh không còn người dùng hiện tại
      print('Firebase user after logout: ${_auth.currentUser}');

      return true;
    } catch (e) {
      print('Error during logout: $e');
      throw Exception('Đăng xuất thất bại: ${e.toString()}');
    }
  }

  // Lấy ID token của người dùng hiện tại
  Future<String?> getIdToken() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;
      final idToken = await user.getIdToken(true);
      return idToken;
    } catch (e) {
      print('Error getting ID token: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> fetchMyPosts({
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Không tìm thấy người dùng');

      final idToken = await user.getIdToken(true);
      final response = await http.get(
        Uri.parse('${ApiRoutes.myPosts}?page=$page&limit=$limit'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rentals = (data['rentals'] as List)
            .map((rental) => Rental.fromJson(rental))
            .toList();
        return {
          'rentals': rentals,
          'total': data['total'] ?? 0,
          'page': data['page'] ?? page,
          'pages': data['pages'] ?? 1,
        };
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(
            'Lấy bài đăng thất bại: ${errorData['message'] ?? response.body}');
      }
    } catch (e) {
      print('Error fetching posts: $e');
      throw Exception('Lấy bài đăng thất bại: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> fetchRecentComments({
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Không tìm thấy người dùng');

      final idToken = await user.getIdToken(true);
      final response = await http.get(
        Uri.parse('${ApiRoutes.recentComments}?page=$page&limit=$limit'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final comments = (data['comments'] as List)
            .map((comment) => Comment.fromJson(comment))
            .toList();
        return {
          'comments': comments,
          'total': data['total'] ?? 0,
          'page': data['page'] ?? page,
          'pages': data['pages'] ?? 1,
        };
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(
            'Lấy bình luận thất bại: ${errorData['message'] ?? response.body}');
      }
    } catch (e) {
      print('Error fetching recent comments: $e');
      throw Exception('Lấy bình luận thất bại: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> fetchNotifications({
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Không tìm thấy người dùng');

      final idToken = await user.getIdToken(true);
      final response = await http.get(
        Uri.parse('${ApiRoutes.notifications}?page=$page&limit=$limit'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final notifications = (data['notifications'] as List)
            .map((notification) => NotificationModel.fromJson(notification))
            .toList();
        return {
          'notifications': notifications,
          'total': data['total'] ?? 0,
          'page': data['page'] ?? page,
          'pages': data['pages'] ?? 1,
        };
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(
            'Lấy thông báo thất bại: ${errorData['message'] ?? response.body}');
      }
    } catch (e) {
      print('Error fetching notifications: $e');
      throw Exception('Lấy thông báo thất bại: ${e.toString()}');
    }
  }
}

extension AppUserExtension on AppUser {
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
