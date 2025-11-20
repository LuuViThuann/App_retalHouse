import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter_rentalhouse/models/comments.dart';
import 'package:flutter_rentalhouse/models/notification.dart';
import 'package:flutter_rentalhouse/models/rental.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import '../config/api_routes.dart';
import '../models/user.dart';
import 'dart:async';
class AuthService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FacebookAuth _facebookAuth = FacebookAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId:
        '616377322079-eb0grhlmn2lbnifatbduclltcur9t3g4.apps.googleusercontent.com',
    scopes: [
      'email',
      'profile',
      'https://www.googleapis.com/auth/userinfo.profile'
    ],
  );
  final Dio _dio = Dio(BaseOptions(
    baseUrl: ApiRoutes.baseUrl,
    headers: {'Content-Type': 'multipart/form-data'},
  ));
  // Hàm kiểm tra định dạng đầu vào
  bool _isValidEmail(String email) =>
      RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email);
  bool _isValidPhoneNumber(String phoneNumber) =>
      RegExp(r'^\d{10}$').hasMatch(phoneNumber);
  bool _isValidPassword(String password) => password.length >= 6;
  bool _isValidAvatarBase64(String? avatarBase64) {
    if (avatarBase64 == null) return false;
    final regex = RegExp(r'^(data:image/(jpeg|png);base64,)?[A-Za-z0-9+/=]+$');
    return regex.hasMatch(avatarBase64);
  }

  bool _isValidUsername(String username) => username.length >= 3;
  bool _isValidAddress(String address) => address.isNotEmpty;
  // Hàm loại bỏ tiền tố MIME
  String _stripMimePrefix(String base64) {
    return base64.replaceAll(RegExp(r'^data:image/(jpeg|png);base64,'), '');
  }

  // Hàm thêm tiền tố MIME khi cần hiển thị
  String _addMimePrefix(String base64, {String mimeType = 'image/png'}) {
    return 'data:$mimeType;base64,$base64';
  }

  Future<AppUser?> register({
    required String email,
    required String password,
    required String phoneNumber,
    required String address,
    required String username,
    required String avatarBase64,
  }) async {
    // Kiểm tra định dạng đầu vào
    if (!_isValidEmail(email)) {
      throw Exception('Email không hợp lệ');
    }
    if (!_isValidPhoneNumber(phoneNumber)) {
      throw Exception('Số điện thoại phải có 10 chữ số');
    }
    if (!_isValidPassword(password)) {
      throw Exception('Mật khẩu phải có ít nhất 6 ký tự');
    }
    if (!_isValidAvatarBase64(avatarBase64)) {
      print('AuthService: Invalid avatarBase64: $avatarBase64');
      throw Exception('Ảnh đại diện không hợp lệ');
    }
    if (!_isValidUsername(username)) {
      throw Exception('Tên người dùng phải có ít nhất 3 ký tự');
    }
    if (!_isValidAddress(address)) {
      throw Exception('Vui lòng nhập địa chỉ');
    }

    try {
      // Loại bỏ tiền tố MIME trước khi gửi
      final rawBase64 = _stripMimePrefix(avatarBase64);

      // Gửi request tới backend
      final response = await http.post(
        Uri.parse(ApiRoutes.register),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'phoneNumber': phoneNumber,
          'address': address,
          'username': username,
          'avatarBase64': rawBase64,
        }),
      );

      print(
          'AuthService: Register response: ${response.statusCode}, body: ${response.body}');

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final idToken = await _auth.currentUser?.getIdToken(true);
        return AppUser(
          id: data['id'] as String,
          email: data['email'] as String,
          phoneNumber: data['phoneNumber'] as String,
          address: data['address'] as String,
          createdAt: DateTime.parse(data['createdAt'] as String),
          username: data['username'] as String,
          token: idToken,
          avatarBase64: data['avatarBase64'] as String?,
        );
      } else {
        final errorData = jsonDecode(response.body);
        print('AuthService: Register error: ${errorData['message']}');
        throw Exception(errorData['message'] ?? 'Đăng ký thất bại');
      }
    } catch (e) {
      print('AuthService: Registration error: $e');
      throw Exception('Đăng ký thất bại: $e');
    }
  }

  Future<AppUser?> login({
    required String email,
    required String password,
  }) async {
    try {
      // 1. Đăng nhập Firebase trước (đã ok)
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) throw Exception('Đăng nhập thất bại');

      // 2. Lấy ID token
      final idToken = await user.getIdToken();
      if (idToken == null) throw Exception('Không lấy được token');

      // 3. GỌI BACKEND CHỈ GỬI idToken THÔI (QUAN TRỌNG NHẤT)
      final response = await http
          .post(
            Uri.parse(ApiRoutes.login),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'idToken': idToken}), // ← CHỈ GỬI CÁI NÀY
          )
          .timeout(
              const Duration(seconds: 20)); // tăng timeout lên 20s cho chắc

      print('Login API Response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        String? avatarBase64 = data['avatarBase64'] as String?;
        if (avatarBase64 == null || avatarBase64.isEmpty) {
          avatarBase64 = await fetchAvatarBase64(user.uid, idToken);
        }

        return AppUser(
          id: data['id'] as String,
          email: data['email'] as String,
          phoneNumber: data['phoneNumber'] as String? ?? '',
          address: data['address'] as String? ?? '',
          username: data['username'] as String? ?? '',
          createdAt: DateTime.parse(
              data['createdAt'] as String? ?? DateTime.now().toIso8601String()),
          token: idToken,
          avatarBase64: avatarBase64,
        );
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Đăng nhập thất bại');
      }
    } on FirebaseAuthException catch (e) {
      String msg = 'Đăng nhập thất bại';
      if (e.code == 'user-not-found') msg = 'Email không tồn tại';
      if (e.code == 'wrong-password' || e.code == 'invalid-credential')
        msg = 'Mật khẩu sai';
      throw Exception(msg);
    } on TimeoutException catch (_) {
      throw Exception(
          'Kết nối server quá lâu. Vui lòng kiểm tra mạng và thử lại.');
    } catch (e) {
      print('AuthService: Login error: $e');
      rethrow;
    }
  }

  Future<AppUser?> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        print('AuthService: Google Sign-In cancelled by user');
        return null;
      }
      print(
          'AuthService: Google user: ${googleUser.email}, ID: ${googleUser.id}');
      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;
      if (idToken == null || idToken.isEmpty) {
        print(
            'AuthService: No ID token from Google Sign-In, accessToken: ${accessToken?.substring(0, 10)}...');
        throw Exception('Failed to obtain ID token');
      }
      print('AuthService: Google ID token: ${idToken.substring(0, 10)}...');
      final credential = GoogleAuthProvider.credential(
        accessToken: accessToken,
        idToken: idToken,
      );
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) {
        print('AuthService: No Firebase user from Google Sign-In');
        throw Exception('Failed to sign in with Google');
      }
      print('AuthService: Firebase user: ${user.uid}, email: ${user.email}');
      final firebaseIdToken = await user.getIdToken(true);
      if (firebaseIdToken == null || firebaseIdToken.isEmpty) {
        print('AuthService: No Firebase ID token for user: ${user.uid}');
        throw Exception('Failed to obtain Firebase ID token');
      }
      print(
          'AuthService: Firebase ID token: ${firebaseIdToken.substring(0, 10)}...');
      final response = await http.post(
        Uri.parse(ApiRoutes.login),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': googleUser.email,
          'googleId': googleUser.id,
          'username': googleUser.displayName,
          'avatar': googleUser.photoUrl,
          'idToken': firebaseIdToken,
        }),
      );
      print(
          'AuthService: Google Sign-In API response: ${response.statusCode}, body: ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final avatarBase64 = await fetchAvatarBase64(user.uid, firebaseIdToken);
        return AppUser(
          id: data['id'] as String,
          email: data['email'] as String,
          username: data['username'] as String? ?? googleUser.displayName ?? '',
          phoneNumber: data['phoneNumber'] as String? ?? '',
          address: data['address'] as String? ?? '',
          createdAt: DateTime.parse(
              data['createdAt'] as String? ?? DateTime.now().toIso8601String()),
          token: firebaseIdToken,
          avatarBase64: avatarBase64,
        );
      } else {
        final errorData = jsonDecode(response.body);
        print(
            'AuthService: Google Sign-In API error: ${errorData['message'] ?? response.body}');
        throw Exception(
            'Đăng nhập Google thất bại: ${errorData['message'] ?? response.body}');
      }
    } catch (e) {
      print('AuthService: Error signing in with Google: $e');
      throw Exception('Đăng nhập Google thất bại: $e');
    }
  }

  Future<AppUser?> signInWithFacebook() async {
    try {
      await _facebookAuth.logOut().catchError((e) {
        print('AuthService: Error logging out Facebook before login: $e');
      });
      final LoginResult result = await _facebookAuth.login(
        permissions: ['email', 'public_profile'],
        loginBehavior: LoginBehavior.dialogOnly,
      );
      if (result.status != LoginStatus.success) {
        print('AuthService: Facebook login failed: ${result.message}');
        return null;
      }
      final AccessToken? accessToken = result.accessToken;
      if (accessToken == null) {
        print('AuthService: Facebook access token is null');
        throw Exception('Failed to obtain access token');
      }
      final facebookAuthCredential =
          FacebookAuthProvider.credential(accessToken.token);
      final userCredential =
          await _auth.signInWithCredential(facebookAuthCredential);
      final user = userCredential.user;
      if (user == null) {
        print('AuthService: No user from Facebook Sign-In');
        throw Exception('Failed to sign in with Facebook');
      }
      final idToken = await user.getIdToken(true);
      if (idToken == null) {
        print('AuthService: No ID token from Facebook Sign-In');
        throw Exception('Failed to obtain ID token');
      }
      await _auth.setPersistence(Persistence.NONE).catchError((e) {
        print(
            'AuthService: Error setting persistence after Facebook sign-in: $e');
      });
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
      final userData = await _facebookAuth.getUserData();
      final response = await http.post(
        Uri.parse(ApiRoutes.login),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': userData['email'] ?? user.email,
          'facebookId': userData['id'],
          'username': userData['name'] ?? user.displayName,
          'avatar': userData['picture']['data']['url'],
          'idToken': idToken,
        }),
      );
      print(
          'AuthService: Facebook Sign-In response: ${response.statusCode}, body: ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final avatarBase64 = await fetchAvatarBase64(user.uid, idToken);
        return AppUser(
          id: data['id'] as String,
          email: data['email'] as String,
          phoneNumber: data['phoneNumber'] as String? ?? '',
          address: data['address'] as String? ?? '',
          createdAt: DateTime.parse(
              data['createdAt'] as String? ?? DateTime.now().toIso8601String()),
          username: data['username'] as String? ?? user.displayName ?? '',
          token: idToken,
          avatarBase64: avatarBase64,
        );
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(
            'Đăng nhập Facebook thất bại: ${errorData['message'] ?? response.body}');
      }
    } catch (e) {
      print('AuthService: Error during Facebook sign-in: $e');
      throw Exception('Đăng nhập Facebook thất bại: $e');
    }
  }

  Future<String> sendPasswordResetEmail(String email) async {
    try {
      final response = await http.post(
        Uri.parse(ApiRoutes.sendResetEmail),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );
      print(
          'AuthService: Send reset email response: ${response.statusCode}, body: ${response.body}');
      if (response.statusCode == 200) {
        return 'Email đặt lại mật khẩu đã được gửi thành công';
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(
            'Gửi email thất bại: ${errorData['message'] ?? response.body}');
      }
    } catch (e) {
      print('AuthService: Error sending password reset email: $e');
      throw Exception('Gửi email thất bại: $e');
    }
  }

  Future<void> resetPassword(String oobCode, String newPassword) async {
    try {
      final response = await http.post(
        Uri.parse(ApiRoutes.resetPassword),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'oobCode': oobCode,
          'newPassword': newPassword,
        }),
      );
      print(
          'AuthService: Reset password response: ${response.statusCode}, body: ${response.body}');
      if (response.statusCode != 200) {
        final errorData = jsonDecode(response.body);
        throw Exception(
            'Đặt lại mật khẩu thất bại: ${errorData['message'] ?? response.body}');
      }
    } catch (e) {
      print('AuthService: Error resetting password: $e');
      throw Exception('Đặt lại mật khẩu thất bại: $e');
    }
  }

  Future<bool> changePassword({required String newPassword}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return false;
      }
      final idToken = await user.getIdToken(true);
      if (idToken == null) {
        return false;
      }
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
      print('AuthService: Error during password change: $e');
      throw Exception('Thay đổi mật khẩu thất bại: $e');
    }
  }

  Future<AppUser?> updateProfile({
    required String phoneNumber,
    required String address,
    required String username,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return null;
      }
      final idToken = await user.getIdToken(true);
      if (idToken == null) {
        return null;
      }
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
        final avatarBase64 = await fetchAvatarBase64(user.uid, idToken);
        return AppUser(
          id: data['id'] as String,
          email: data['email'] as String,
          phoneNumber: data['phoneNumber'] as String,
          address: data['address'] as String,
          createdAt: DateTime.parse(
              data['createdAt'] as String? ?? DateTime.now().toIso8601String()),
          username: data['username'] as String? ?? '',
          token: idToken,
          avatarBase64: avatarBase64,
        );
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(
            'Cập nhật hồ sơ thất bại: ${errorData['message'] ?? response.body}');
      }
    } catch (e) {
      print('AuthService: Error during profile update: $e');
      throw Exception('Cập nhật hồ sơ thất bại: $e');
    }
  }

  Future<String?> uploadProfileImage({required String imageBase64}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return null;
      }
      final idToken = await user.getIdToken(true);
      if (idToken == null) {
        return null;
      }
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
      print('AuthService: Error during image upload: $e');
      throw Exception('Tải ảnh lên thất bại: $e');
    }
  }

  Future<String?> fetchAvatarBase64(String userId, String idToken) async {
    try {
      final response = await http.get(
        Uri.parse(ApiRoutes.getAvatar(userId)),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );
      print(
          'AuthService: Fetch avatar response: ${response.statusCode}, body: ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['avatarBase64'] as String?;
      } else {
        print('AuthService: Failed to fetch avatarBase64: ${response.body}');
        return null;
      }
    } catch (e) {
      print('AuthService: Error fetching avatarBase64: $e');
      return null;
    }
  }

  Future<bool> logout() async {
    try {
      await _googleSignIn.signOut();
      await _googleSignIn.disconnect().catchError((e) {
        print('AuthService: Error disconnecting Google: $e');
      });
      await _facebookAuth.logOut().catchError((e) {
        print('AuthService: Error logging out Facebook: $e');
      });
      await _auth.signOut();
      await _auth.setPersistence(Persistence.NONE).catchError((e) {
        print('AuthService: Error setting persistence after logout: $e');
      });
      print('AuthService: User logged out, currentUser: ${_auth.currentUser}');
      return true;
    } catch (e) {
      print('AuthService: Error during logout: $e');
      throw Exception('Đăng xuất thất bại: $e');
    }
  }

  Future<String?> getIdToken() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('AuthService: No user for ID token');
        return null;
      }
      final idToken = await user.getIdToken(true);
      print('AuthService: Got ID token: ${idToken?.substring(0, 10)}...');
      return idToken;
    } catch (e) {
      print('AuthService: Error getting ID token: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> fetchMyPosts(
      {int page = 1, int limit = 10}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {'rentals': [], 'total': 0, 'page': page, 'pages': 1};
      }
      final idToken = await user.getIdToken(true);
      if (idToken == null) {
        return {'rentals': [], 'total': 0, 'page': page, 'pages': 1};
      }
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
      print('AuthService: Error fetching posts: $e');
      throw Exception('Lấy bài đăng thất bại: $e');
    }
  }

  Future<Map<String, dynamic>> fetchRecentComments(
      {int page = 1, int limit = 10}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {'comments': [], 'total': 0, 'page': page, 'pages': 1};
      }
      final idToken = await user.getIdToken(true);
      if (idToken == null) {
        return {'comments': [], 'total': 0, 'page': page, 'pages': 1};
      }
      final response = await http.get(
        Uri.parse('${ApiRoutes.recentComments}?page=$page&limit=$limit'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final comments = (data['comments'] as List).map((comment) {
          final commentMap = Map<String, dynamic>.from(comment);
          if (commentMap['userId'] != null) {
            final userId = Map<String, dynamic>.from(commentMap['userId']);
            commentMap['userId'] = {
              ...userId,
              'avatarBytes': userId['avatarBase64'] != null
                  ? base64Decode(userId['avatarBase64'])
                  : null,
            };
          }
          if (commentMap['replies'] != null) {
            commentMap['replies'] =
                (commentMap['replies'] as List).map((reply) {
              final replyMap = Map<String, dynamic>.from(reply);
              if (replyMap['userId'] != null) {
                final replyUserId =
                    Map<String, dynamic>.from(replyMap['userId']);
                replyMap['userId'] = {
                  ...replyUserId,
                  'avatarBytes': replyUserId['avatarBase64'] != null
                      ? base64Decode(replyUserId['avatarBase64'])
                      : null,
                };
              }
              return replyMap;
            }).toList();
          }
          return Comment.fromJson(commentMap);
        }).toList();
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
      print('AuthService: Error fetching recent comments: $e');
      throw Exception('Lấy bình luận thất bại: $e');
    }
  }

  Future<Map<String, dynamic>> fetchNotifications(
      {int page = 1, int limit = 10}) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiRoutes.baseUrl}/notifications?page=$page&limit=$limit'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${_auth.currentUser?.uid}',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to fetch notifications');
      }
    } catch (e) {
      throw Exception('Error fetching notifications: $e');
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiRoutes.baseUrl}/notifications/$notificationId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${_auth.currentUser?.uid}',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to delete notification');
      }
    } catch (e) {
      throw Exception('Error deleting notification: $e');
    }
  }

  Future<Rental> fetchRental(String rentalId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print(
            'AuthService: No user found for fetching rental (rentalId: $rentalId)');
        throw Exception('User not found');
      }
      final idToken = await user.getIdToken(true);
      if (idToken == null) {
        print(
            'AuthService: No ID token for fetching rental (rentalId: $rentalId)');
        throw Exception('Failed to obtain token');
      }
      final response = await http.get(
        Uri.parse('${ApiRoutes.baseUrl}/rentals/$rentalId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );
      print(
          'AuthService: Fetch rental response (rentalId: $rentalId): ${response.statusCode}, body: ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Rental.fromJson(data);
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(
            'Failed to fetch rental: ${errorData['message'] ?? response.body}');
      }
    } catch (e) {
      print('AuthService: Error fetching rental (rentalId: $rentalId): $e');
      throw Exception('Failed to fetch rental: $e');
    }
  }

  Future<void> deleteRental(String rentalId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return;
      }
      final idToken = await user.getIdToken(true);
      if (idToken == null) {
        return;
      }
      final response = await http.delete(
        Uri.parse('${ApiRoutes.baseUrl}/rentals/$rentalId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );
      if (response.statusCode != 200) {
        final errorData = jsonDecode(response.body);
        throw Exception(
            'Failed to delete rental: ${errorData['message'] ?? response.body}');
      }
    } catch (e) {
      print('AuthService: Error deleting rental (rentalId: $rentalId): $e');
      throw Exception('Failed to delete rental: $e');
    }
  }

  Future<Rental> updateRental({
    required String rentalId,
    required Map<String, dynamic> updatedData,
    List<String>? imagePaths,
    List<String>? removedImages,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('Không tìm thấy người dùng');
      }
      final idToken = await user.getIdToken(true);
      if (idToken == null) {
        throw Exception('Không lấy được token xác thực');
      }

      // Lấy thông tin bài đăng hiện tại để xác thực ảnh cần xóa
      final currentRental = await fetchRental(rentalId);

      // Lọc ra các ảnh thực sự hợp lệ để xóa
      final validRemovedImages = (removedImages ?? [])
          .where((url) =>
              url.isNotEmpty &&
              url.startsWith('/uploads/') &&
              currentRental.images.contains(url))
          .toList();

      // Tạo request PATCH dạng multipart
      var request = http.MultipartRequest(
        'PATCH',
        Uri.parse('${ApiRoutes.baseUrl}/rentals/$rentalId'),
      );
      request.headers['Authorization'] = 'Bearer $idToken';

      // Thêm các trường dữ liệu cập nhật
      updatedData.forEach((key, value) {
        if (value != null) {
          request.fields[key] = value.toString();
        }
      });

      // Thêm danh sách ảnh cần xóa (nếu có)
      if (validRemovedImages.isNotEmpty) {
        request.fields['removedImages'] = jsonEncode(validRemovedImages);
      }

      // Thêm các file ảnh mới (nếu có)
      if (imagePaths != null && imagePaths.isNotEmpty) {
        for (var path in imagePaths) {
          if (path.isNotEmpty) {
            request.files.add(await http.MultipartFile.fromPath(
              'images',
              path,
              filename: path.split('/').last,
            ));
          }
        }
      }

      print(
          'AuthService: PATCH rental $rentalId, fields: ${request.fields}, files: ${request.files.length}');

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      print(
          'AuthService: Update rental response ($rentalId): ${response.statusCode}, body: $responseBody');

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody);
        return Rental.fromJson(data);
      } else {
        final errorData = jsonDecode(responseBody);
        throw Exception(
            'Cập nhật bài đăng thất bại: ${errorData['message'] ?? responseBody}');
      }
    } catch (e) {
      print('AuthService: Lỗi cập nhật bài đăng ($rentalId): $e');
      throw Exception('Cập nhật bài đăng thất bại: $e');
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
