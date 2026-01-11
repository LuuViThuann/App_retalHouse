import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter_rentalhouse/models/comments.dart';
import 'package:flutter_rentalhouse/models/notification.dart';
import 'package:flutter_rentalhouse/models/rental.dart';
import 'package:flutter_rentalhouse/services/TokenExpirationManager.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../config/api_routes.dart';
import '../models/user.dart';
import 'dart:async';

class AuthService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FacebookAuth _facebookAuth = FacebookAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: '616377322079-eb0grhlmn2lbnifatbduclltcur9t3g4.apps.googleusercontent.com',
    scopes: ['email', 'profile', 'https://www.googleapis.com/auth/userinfo.profile'],
  );
  //  HTTP Client với connection pooling
  static final http.Client _httpClient = http.Client();

  //  Timeout configurations
  static const Duration _defaultTimeout = Duration(seconds: 30);
  static const Duration _shortTimeout = Duration(seconds: 15);
  static const Duration _lightTimeout = Duration(seconds: 10);

  //  Retry configuration
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);
  // Validation functions
  bool _isValidEmail(String email) => RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email);
  bool _isValidPhoneNumber(String phoneNumber) => RegExp(r'^\d{10}$').hasMatch(phoneNumber);
  bool _isValidPassword(String password) => password.length >= 6;
  bool _isValidUsername(String username) => username.length >= 3;
  bool _isValidAddress(String address) => address.isNotEmpty;
  //  HELPER: Make HTTP request with retry logic
  Future<http.Response> _makeRequestWithRetry(
      Future<http.Response> Function() requestFn, {
        Duration timeout = _defaultTimeout,
        int maxRetries = _maxRetries,
        bool throwOnError = true,
      }) async {
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final response = await requestFn().timeout(
          timeout,
          onTimeout: () {
            throw TimeoutException(
              'Request timeout after ${timeout.inSeconds}s',
              timeout,
            );
          },
        );
        return response;
      } on SocketException catch (e) {
        print('⚠️ Network error (attempt ${attempt + 1}/$maxRetries): ${e.message}');
        if (attempt == maxRetries - 1) {
          if (throwOnError) {
            throw Exception('Lỗi kết nối mạng. Vui lòng kiểm tra internet.');
          }
          return http.Response('{"error": "Network error"}', 503);
        }
        await Future.delayed(_retryDelay * (attempt + 1));
      } on TimeoutException catch (e) {
        print('⚠️ Timeout (attempt ${attempt + 1}/$maxRetries): ${e.message}');
        if (attempt == maxRetries - 1) {
          if (throwOnError) {
            throw Exception('Kết nối quá chậm. Vui lòng thử lại.');
          }
          return http.Response('{"error": "Timeout"}', 408);
        }
        await Future.delayed(_retryDelay * (attempt + 1));
      } on http.ClientException catch (e) {
        print('⚠️ Client error (attempt ${attempt + 1}/$maxRetries): ${e.message}');
        if (attempt == maxRetries - 1) {
          if (throwOnError) {
            throw Exception('Lỗi kết nối: ${e.message}');
          }
          return http.Response('{"error": "Client error"}', 500);
        }
        await Future.delayed(_retryDelay * (attempt + 1));
      }
    }
    throw Exception('Request failed after $maxRetries attempts');
  }
  // ============================================
  // REGISTER
  // ============================================
  Future<AppUser?> register({
    required String email,
    required String password,
    required String phoneNumber,
    required String address,
    required String username,
    required String imagePath,
  }) async {
    if (!_isValidEmail(email)) throw Exception('Email không hợp lệ');
    if (!_isValidPhoneNumber(phoneNumber)) throw Exception('Số điện thoại phải có 10 chữ số');
    if (!_isValidPassword(password)) throw Exception('Mật khẩu phải có ít nhất 6 ký tự');
    if (!_isValidUsername(username)) throw Exception('Tên người dùng phải có ít nhất 3 ký tự');
    if (!_isValidAddress(address)) throw Exception('Vui lòng nhập địa chỉ');
    if (imagePath.isEmpty) throw Exception('Vui lòng chọn ảnh');

    try {
      print('═══════════════════════════════════════════');
      print('📝 REGISTER USER');
      print('═══════════════════════════════════════════');

      // Step 1: Create Firebase auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) throw Exception('Tạo tài khoản Firebase thất bại');

      print('✅ Firebase user created: ${user.uid}');

      // Step 2: Get ID token
      final idToken = await user.getIdToken();
      if (idToken == null) throw Exception('Không lấy được ID token');

      print('✅ ID token obtained');

      // Step 3: Upload with file
      var request = http.MultipartRequest('POST', Uri.parse(ApiRoutes.register));
      request.fields['idToken'] = idToken;
      request.fields['phoneNumber'] = phoneNumber;
      request.fields['address'] = address;
      request.fields['username'] = username;

      request.files.add(await http.MultipartFile.fromPath('avatar', imagePath));

      print('📤 Sending multipart request...');
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      print('📊 Response: ${response.statusCode}');

      if (response.statusCode == 201) {
        final data = jsonDecode(responseBody);

        return AppUser(
          id: user.uid,
          email: user.email ?? email,
          phoneNumber: phoneNumber,
          address: address,
          username: username,
          createdAt: DateTime.now(),
          token: idToken,
          avatarUrl: data['avatarUrl'] as String?,
          role: data['role'] ?? 'user',
        );
      } else {
        // ✅ Xóa user Firebase nếu đăng ký backend thất bại
        await user.delete();
        final error = jsonDecode(responseBody);
        throw Exception(error['message'] ?? 'Đăng ký thất bại');
      }
    } on FirebaseAuthException catch (e) {
      // ✅ Xử lý lỗi Firebase Auth với thông báo thân thiện
      print('❌ FirebaseAuthException: ${e.code}');

      switch (e.code) {
        case 'email-already-in-use':
          throw Exception('Email đã được sử dụng');

        case 'invalid-email':
          throw Exception('Email không hợp lệ');

        case 'weak-password':
          throw Exception('Mật khẩu quá yếu. Vui lòng chọn mật khẩu mạnh hơn');

        case 'operation-not-allowed':
          throw Exception('Đăng ký không được phép');

        case 'network-request-failed':
          throw Exception('Lỗi kết nối mạng. Vui lòng kiểm tra internet');

        default:
          throw Exception('Đăng ký thất bại. Vui lòng thử lại');
      }
    } on SocketException catch (_) {
      throw Exception('Không có kết nối internet');
    } on TimeoutException catch (_) {
      throw Exception('Kết nối quá chậm. Vui lòng thử lại');
    } catch (e) {
      print('❌ Registration error: $e');
      if (e.toString().contains('Exception: ')) {
        rethrow;
      }
      throw Exception('Đăng ký thất bại. Vui lòng thử lại');
    }
  }

  // ============================================
  // LOGIN
  // ============================================
  Future<AppUser?> login({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) throw Exception('Đăng nhập thất bại');

      final idToken = await user.getIdToken();
      if (idToken == null) throw Exception('Không lấy được token');

      final response = await http.post(
        Uri.parse(ApiRoutes.login),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'idToken': idToken}),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        String? avatarUrl = data['avatarUrl'] as String?;
        if (avatarUrl == null || avatarUrl.isEmpty) {
          avatarUrl = await fetchAvatarUrl(user.uid, idToken);
        }

        final String userRole = data['role'] as String? ?? 'user';

        return AppUser(
          id: data['id'] as String,
          email: data['email'] as String,
          phoneNumber: data['phoneNumber'] as String? ?? '',
          address: data['address'] as String? ?? '',
          username: data['username'] as String? ?? '',
          createdAt: DateTime.parse(
            data['createdAt'] as String? ?? DateTime.now().toIso8601String(),
          ),
          token: idToken,
          avatarUrl: avatarUrl,
          role: userRole,
        );
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Đăng nhập thất bại');
      }
    } on FirebaseAuthException catch (e) {
      // ✅ Xử lý lỗi Firebase Auth với thông báo thân thiện
      print('❌ FirebaseAuthException: ${e.code}');

      switch (e.code) {
        case 'invalid-credential':
        case 'wrong-password':
        case 'user-not-found':
          throw Exception('Email hoặc mật khẩu không chính xác');

        case 'invalid-email':
          throw Exception('Email không hợp lệ');

        case 'user-disabled':
          throw Exception('Tài khoản đã bị vô hiệu hóa');

        case 'too-many-requests':
          throw Exception('Quá nhiều lần thử. Vui lòng thử lại sau');

        case 'network-request-failed':
          throw Exception('Lỗi kết nối mạng. Vui lòng kiểm tra internet');

        case 'operation-not-allowed':
          throw Exception('Phương thức đăng nhập không được phép');

        default:
          throw Exception('Đăng nhập thất bại. Vui lòng thử lại');
      }
    } on SocketException catch (_) {
      throw Exception('Không có kết nối internet');
    } on TimeoutException catch (_) {
      throw Exception('Kết nối quá chậm. Vui lòng thử lại');
    } catch (e) {
      print('❌ Login error: $e');
      // ✅ Nếu lỗi đã có message rõ ràng thì giữ nguyên
      if (e.toString().contains('Exception: ')) {
        rethrow;
      }
      throw Exception('Đăng nhập thất bại. Vui lòng thử lại');
    }
  }

  // ============================================
  // SIGN IN WITH GOOGLE
  // ============================================
  Future<AppUser?> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        print('❌ Google Sign-In cancelled by user');
        throw Exception('Đăng nhập Google đã bị hủy');
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null || idToken.isEmpty) {
        throw Exception('Không lấy được token từ Google');
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: accessToken,
        idToken: idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) throw Exception('Đăng nhập Google thất bại');

      final firebaseIdToken = await user.getIdToken(true);
      if (firebaseIdToken == null || firebaseIdToken.isEmpty) {
        throw Exception('Không lấy được Firebase token');
      }

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
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final avatarUrl = await fetchAvatarUrl(user.uid, firebaseIdToken);

        return AppUser(
          id: data['id'] as String,
          email: data['email'] as String,
          username: data['username'] as String? ?? googleUser.displayName ?? '',
          phoneNumber: data['phoneNumber'] as String? ?? '',
          address: data['address'] as String? ?? '',
          createdAt: DateTime.parse(
            data['createdAt'] as String? ?? DateTime.now().toIso8601String(),
          ),
          token: firebaseIdToken,
          avatarUrl: avatarUrl,
        );
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Đăng nhập Google thất bại');
      }
    } on FirebaseAuthException catch (e) {
      print('❌ FirebaseAuthException: ${e.code}');

      switch (e.code) {
        case 'account-exists-with-different-credential':
          throw Exception('Email đã được sử dụng với phương thức đăng nhập khác');

        case 'invalid-credential':
          throw Exception('Thông tin đăng nhập Google không hợp lệ');

        case 'operation-not-allowed':
          throw Exception('Đăng nhập Google không được phép');

        case 'user-disabled':
          throw Exception('Tài khoản đã bị vô hiệu hóa');

        case 'network-request-failed':
          throw Exception('Lỗi kết nối mạng. Vui lòng kiểm tra internet');

        default:
          throw Exception('Đăng nhập Google thất bại. Vui lòng thử lại');
      }
    } on SocketException catch (_) {
      throw Exception('Không có kết nối internet');
    } on TimeoutException catch (_) {
      throw Exception('Kết nối quá chậm. Vui lòng thử lại');
    } catch (e) {
      print('❌ Google sign in error: $e');
      if (e.toString().contains('Exception: ')) {
        rethrow;
      }
      throw Exception('Đăng nhập Google thất bại. Vui lòng thử lại');
    }
  }

  // ============================================
  // PASSWORD RESET
  // ============================================
  Future<String> sendPasswordResetEmail(String email) async {
    try {
      final response = await http.post(
        Uri.parse(ApiRoutes.sendResetEmail),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      if (response.statusCode == 200) {
        return 'Email đặt lại mật khẩu đã được gửi thành công';
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception('Gửi email thất bại: ${errorData['message'] ?? response.body}');
      }
    } catch (e) {
      print('❌ Send reset email error: $e');
      throw Exception('Gửi email thất bại: $e');
    }
  }

  Future<void> resetPassword(String oobCode, String newPassword) async {
    try {
      final response = await http.post(
        Uri.parse(ApiRoutes.resetPassword),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'oobCode': oobCode, 'newPassword': newPassword}),
      );

      if (response.statusCode != 200) {
        final errorData = jsonDecode(response.body);
        throw Exception('Đặt lại mật khẩu thất bại: ${errorData['message'] ?? response.body}');
      }
    } catch (e) {
      print('❌ Reset password error: $e');
      throw Exception('Đặt lại mật khẩu thất bại: $e');
    }
  }

  // ============================================
  // CHANGE PASSWORD
  // ============================================
  Future<bool> changePassword({required String newPassword}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final idToken = await user.getIdToken(true);
      if (idToken == null) return false;

      final response = await http.post(
        Uri.parse(ApiRoutes.changePassword),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'idToken': idToken, 'newPassword': newPassword}),
      );

      if (response.statusCode == 200) {
        await user.updatePassword(newPassword);
        return true;
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception('Thay đổi mật khẩu thất bại: ${errorData['message'] ?? response.body}');
      }
    } catch (e) {
      print('❌ Change password error: $e');
      throw Exception('Thay đổi mật khẩu thất bại: $e');
    }
  }

  // ============================================
  // UPDATE PROFILE
  // ============================================
  Future<AppUser?> updateProfile({
    required String phoneNumber,
    required String address,
    required String username,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final idToken = await user.getIdToken(true);
      if (idToken == null) return null;

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

      checkTokenExpiration(response.statusCode);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final avatarUrl = await fetchAvatarUrl(user.uid, idToken);

        return AppUser(
          id: data['id'] as String,
          email: data['email'] as String,
          phoneNumber: data['phoneNumber'] as String,
          address: data['address'] as String,
          createdAt: DateTime.parse(
            data['createdAt'] as String? ?? DateTime.now().toIso8601String(),
          ),
          username: data['username'] as String? ?? '',
          token: idToken,
          avatarUrl: avatarUrl,
        );
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception('Cập nhật hồ sơ thất bại: ${errorData['message'] ?? response.body}');
      }
    } catch (e) {
      print('❌ Update profile error: $e');
      throw Exception('Cập nhật hồ sơ thất bại: $e');
    }
  }

  // ============================================
  // UPLOAD PROFILE IMAGE
  // ============================================
  Future<String?> uploadProfileImage({required String imagePath}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final idToken = await user.getIdToken(true);
      if (idToken == null) return null;

      var request = http.MultipartRequest('POST', Uri.parse(ApiRoutes.uploadImage));
      request.fields['idToken'] = idToken;

      //  Upload with field 'avatar'
      request.files.add(await http.MultipartFile.fromPath('avatar', imagePath));


      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      checkTokenExpiration(response.statusCode);

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody);
        final avatarUrl = data['avatarUrl'] as String?;

        if (avatarUrl == null || avatarUrl.isEmpty) {
          throw Exception('No avatarUrl in response');
        }

        return avatarUrl;
      } else {
        final errorData = jsonDecode(responseBody);
        throw Exception('Tải ảnh lên thất bại: ${errorData['message'] ?? responseBody}');
      }
    } catch (e) {
      print(' Upload image error: $e');
      throw Exception('Tải ảnh lên thất bại: $e');
    }
  }

  // ============================================
  // FETCH AVATAR URL
  // ============================================
  Future<String?> fetchAvatarUrl(String userId, String idToken) async {
    try {
      final response = await http.get(
        Uri.parse(ApiRoutes.getAvatar(userId)),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['avatarUrl'] as String?;
      } else {
        print('❌ Failed to fetch avatarUrl: ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ Error fetching avatarUrl: $e');
      return null;
    }
  }

  // ============================================
  // LOGOUT
  // ============================================
  Future<bool> logout() async {
    try {
      await _googleSignIn.signOut();
      await _googleSignIn.disconnect().catchError((e) => print('❌ Error: $e'));
      await _facebookAuth.logOut().catchError((e) => print('❌ Error: $e'));
      await _auth.signOut();
      await _auth.setPersistence(Persistence.NONE).catchError((e) => print('❌ Error: $e'));

      print('✅ User logged out');
      return true;
    } catch (e) {
      print('❌ Logout error: $e');
      throw Exception('Đăng xuất thất bại: $e');
    }
  }

  // ============================================
  // GET ID TOKEN
  // ============================================
  Future<String?> getIdToken() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('❌ No user for ID token');
        return null;
      }
      final idToken = await user.getIdToken(true);
      print('✅ Got ID token');
      return idToken;
    } catch (e) {
      print('❌ Error getting ID token: $e');
      return null;
    }
  }

  // ============================================
  // FETCH MY POSTS
  // ============================================
  Future<Map<String, dynamic>> fetchMyPosts({int page = 1, int limit = 10}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return {'rentals': [], 'total': 0, 'page': page, 'pages': 1};

      final idToken = await user.getIdToken(true);
      if (idToken == null) return {'rentals': [], 'total': 0, 'page': page, 'pages': 1};

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
        throw Exception('Lấy bài đăng thất bại: ${errorData['message'] ?? response.body}');
      }
    } catch (e) {
      print('❌ Fetch posts error: $e');
      throw Exception('Lấy bài đăng thất bại: $e');
    }
  }

  // ============================================
  // FETCH RECENT COMMENTS
  // ============================================
  Future<Map<String, dynamic>> fetchRecentComments({int page = 1, int limit = 10}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return {'comments': [], 'total': 0, 'page': page, 'pages': 1};

      final idToken = await user.getIdToken(true);
      if (idToken == null) return {'comments': [], 'total': 0, 'page': page, 'pages': 1};

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
              'avatarBytes': userId['avatarBase64'] != null ? base64Decode(userId['avatarBase64']) : null,
            };
          }
          if (commentMap['replies'] != null) {
            commentMap['replies'] = (commentMap['replies'] as List).map((reply) {
              final replyMap = Map<String, dynamic>.from(reply);
              if (replyMap['userId'] != null) {
                final replyUserId = Map<String, dynamic>.from(replyMap['userId']);
                replyMap['userId'] = {
                  ...replyUserId,
                  'avatarBytes': replyUserId['avatarBase64'] != null ? base64Decode(replyUserId['avatarBase64']) : null,
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
        throw Exception('Lấy bình luận thất bại: ${errorData['message'] ?? response.body}');
      }
    } catch (e) {
      print('❌ Fetch comments error: $e');
      throw Exception('Lấy bình luận thất bại: $e');
    }
  }
  // ============================================
  // CHECK THÔNG BÁO PHIÊN ĐĂNG NHẬP HẾT HẠN
  Future<void> _handleTokenExpiration(int statusCode) async {
    if (statusCode == 401) {
      print(' Token expired or invalid - Showing global dialog');

      try {
        await _auth.signOut();
      } catch (e) {
        print('Error signing out: $e');
      }

      //  Trigger dialog toàn cục
      throw Exception('SESSION_EXPIRED');
    }
  }

  void checkTokenExpiration(int statusCode) {
    if (statusCode == 401) {
      print('❌ Token expired (401 Unauthorized)');
      TokenExpirationManager().markTokenAsExpired();
      throw Exception('SESSION_EXPIRED');
    }
  }
  // ============================================
  // FETCH NOTIFICATIONS
  // ============================================
  Future<Map<String, dynamic>> fetchNotifications({int page = 1, int limit = 10}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return {'notifications': [], 'total': 0, 'page': page, 'pages': 1};

      final idToken = await user.getIdToken(true);
      if (idToken == null) return {'notifications': [], 'total': 0, 'page': page, 'pages': 1};

      print('🔵 [FETCH NOTIFICATIONS]');

      final response = await http.get(
        Uri.parse('${ApiRoutes.baseUrl}/notifications?page=$page&limit=$limit'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      ).timeout(const Duration(seconds: 15));

      checkTokenExpiration(response.statusCode);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final notifications = (data['notifications'] as List?)
            ?.map((notification) {
          try {
            return NotificationModel.fromJson(notification);
          } catch (e) {
            print('⚠️ Error parsing notification: $e');
            return null;
          }
        })
            .whereType<NotificationModel>()
            .toList() ?? [];

        print('✅ [FETCH NOTIFICATIONS] Parsed ${notifications.length} notifications');

        return {
          'notifications': notifications,
          'total': data['pagination']?['total'] ?? 0,
          'page': data['pagination']?['page'] ?? page,
          'pages': data['pagination']?['pages'] ?? 1,
        };
      } else if (response.statusCode == 401) {
        print('⚠️ [FETCH NOTIFICATIONS] Unauthorized');
        return {'notifications': [], 'total': 0, 'page': page, 'pages': 1};
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception('Lấy thông báo thất bại: ${errorData['message'] ?? response.body}');
      }
    } on TimeoutException {
      print('❌ [FETCH NOTIFICATIONS] Timeout');
      throw Exception('Kết nối server quá lâu');
    } catch (e) {
      print('❌ [FETCH NOTIFICATIONS] Error: $e');
      throw Exception('Lấy thông báo thất bại: $e');
    }
  }

  // ============================================
  // MARK NOTIFICATION AS READ
  // ============================================
  Future<bool> markNotificationAsRead(String notificationId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final idToken = await user.getIdToken(true);
      if (idToken == null) return false;

      final response = await http.patch(
        Uri.parse('${ApiRoutes.baseUrl}/notifications/$notificationId/read'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      ).timeout(const Duration(seconds: 10));
      checkTokenExpiration(response.statusCode);

      return response.statusCode == 200;
    } catch (e) {
      print('❌ Mark as read error: $e');
      return false;
    }
  }

  // ============================================
  // MARK ALL NOTIFICATIONS AS READ
  // ============================================
  Future<bool> markAllNotificationsAsRead() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final idToken = await user.getIdToken(true);
      if (idToken == null) return false;

      final response = await http.patch(
        Uri.parse('${ApiRoutes.baseUrl}/notifications/read-all'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      print('❌ Mark all as read error: $e');
      return false;
    }
  }

  // ============================================
  // DELETE NOTIFICATION
  // ============================================
  Future<bool> deleteNotification(String notificationId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final idToken = await user.getIdToken(true);
      if (idToken == null) return false;

      final response = await http.delete(
        Uri.parse('${ApiRoutes.baseUrl}/notifications/$notificationId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      print('❌ Delete notification error: $e');
      return false;
    }
  }

  // ============================================
  // GET UNREAD COUNT
  // ============================================
  Future<int> getUnreadNotificationCount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 0;

      final idToken = await user.getIdToken(true);
      if (idToken == null) return 0;

      final response = await http.get(
        Uri.parse('${ApiRoutes.baseUrl}/notifications/unread/count'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['unreadCount'] as int? ?? 0;
      }
      return 0;
    } catch (e) {
      print('❌ Get unread count error: $e');
      return 0;
    }
  }

  // ============================================
  // GET DELETED NOTIFICATIONS
  // ============================================
  Future<Map<String, dynamic>> getDeletedNotifications() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return {'count': 0, 'data': []};

      final idToken = await user.getIdToken(true);
      if (idToken == null) return {'count': 0, 'data': []};

      final response = await http.get(
        Uri.parse('${ApiRoutes.baseUrl}/notifications/deleted/list'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'count': data['count'] as int? ?? 0, 'data': data['data'] as List? ?? []};
      }
      return {'count': 0, 'data': []};
    } catch (e) {
      print('❌ Get deleted notifications error: $e');
      return {'count': 0, 'data': []};
    }
  }
  Future<bool> undoDeleteNotificationSingle(String notificationId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final idToken = await user.getIdToken(true);
      if (idToken == null) return false;

      print('🔵 [UNDO DELETE SINGLE]');
      print('   notificationId: $notificationId');

      final response = await http.post(
        Uri.parse('${ApiRoutes.baseUrl}/notifications/$notificationId/restore'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      ).timeout(const Duration(seconds: 10));

      print('✅ [UNDO DELETE SINGLE] Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ [UNDO DELETE SINGLE] Restored: ${data['data']['_id']}');
        return true;
      } else if (response.statusCode == 404) {
        print('⚠️ [UNDO DELETE SINGLE] Not found');
        return false;
      } else {
        final errorData = jsonDecode(response.body);
        print('❌ [UNDO DELETE SINGLE] Error: ${errorData['message']}');
        throw Exception(
          'Hoàn tác thất bại: ${errorData['message'] ?? response.body}',
        );
      }
    } on TimeoutException catch (_) {
      print('❌ [UNDO DELETE SINGLE] Timeout');
      throw Exception('Kết nối server quá lâu. Vui lòng kiểm tra mạng.');
    } catch (e) {
      print('❌ [UNDO DELETE SINGLE] Error: $e');
      throw Exception('Hoàn tác thất bại: $e');
    }
  }
  // ============================================
  // UNDO DELETE NOTIFICATION SINGLE
  // ============================================
  Future<bool> undoDeleteNotifications() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final idToken = await user.getIdToken(true);
      if (idToken == null) return false;

      final response = await http.post(
        Uri.parse('${ApiRoutes.baseUrl}/notifications/restore'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      print('❌ Undo delete all error: $e');
      throw Exception('Hoàn tác thất bại: $e');
    }
  }

  // ============================================
  // PERMANENT DELETE FROM UNDO
  // ============================================
  Future<bool> permanentDeleteFromUndo(String notificationId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final idToken = await user.getIdToken(true);
      if (idToken == null) return false;

      final response = await http.delete(
        Uri.parse('${ApiRoutes.baseUrl}/notifications/$notificationId/permanent'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      print('❌ Permanent delete error: $e');
      throw Exception('Xóa vĩnh viễn thất bại: $e');
    }
  }

  // ============================================
  // CHECK UNDO STATUS
  // ============================================
  Future<Map<String, dynamic>> checkUndoStatus() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return {'hasUndo': false, 'undoCount': 0};

      final idToken = await user.getIdToken(true);
      if (idToken == null) return {'hasUndo': false, 'undoCount': 0};

      final response = await http.get(
        Uri.parse('${ApiRoutes.baseUrl}/notifications/undo/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'hasUndo': data['hasUndo'] ?? false,
          'undoCount': data['undoCount'] ?? 0,
          'expiresIn': data['expiresIn'] ?? 0,
        };
      }
      return {'hasUndo': false, 'undoCount': 0};
    } catch (e) {
      print('❌ Check undo status error: $e');
      return {'hasUndo': false, 'undoCount': 0};
    }
  }

  // ============================================
  // FETCH RENTAL
  // ============================================
  Future<Rental> fetchRental(String rentalId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not found');

      final idToken = await user.getIdToken(true);
      if (idToken == null) throw Exception('Failed to obtain token');

      final response = await http.get(
        Uri.parse('${ApiRoutes.baseUrl}/rentals/$rentalId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Rental.fromJson(data);
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception('Failed to fetch rental: ${errorData['message'] ?? response.body}');
      }
    } catch (e) {
      print('❌ Fetch rental error: $e');
      throw Exception('Failed to fetch rental: $e');
    }
  }

  // ============================================
  // DELETE RENTAL
  // ============================================
  Future<void> deleteRental(String rentalId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final idToken = await user.getIdToken(true);
      if (idToken == null) return;

      final response = await http.delete(
        Uri.parse('${ApiRoutes.baseUrl}/rentals/$rentalId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (response.statusCode != 200) {
        final errorData = jsonDecode(response.body);
        throw Exception('Failed to delete rental: ${errorData['message'] ?? response.body}');
      }
    } catch (e) {
      print('❌ Delete rental error: $e');
      throw Exception('Failed to delete rental: $e');
    }
  }

  // ============================================
  // UPDATE RENTAL
  // ============================================
  Future<Rental> updateRental({
    required String rentalId,
    required Map<String, dynamic> updatedData,
    List<String>? imagePaths,
    List<String>? videoPaths,
    List<String>? removedImages,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Không tìm thấy người dùng');

      final idToken = await user.getIdToken(true);
      if (idToken == null) throw Exception('Không lấy được token');

      final currentRental = await fetchRental(rentalId);

      final validRemovedImages = (removedImages ?? [])
          .where((url) =>
      url.isNotEmpty &&
          (url.startsWith('http') || url.startsWith('/uploads/')) &&
          currentRental.images.contains(url))
          .toList();


      var request = http.MultipartRequest(
        'PATCH',
        Uri.parse('${ApiRoutes.baseUrl}/rentals/$rentalId'),
      );
      request.headers['Authorization'] = 'Bearer $idToken';
      request.headers['Accept'] = 'application/json';

      updatedData.forEach((key, value) {
        if (value != null) {
          request.fields[key] = value.toString();
        }
      });

      if (validRemovedImages.isNotEmpty) {
        request.fields['removedMedia'] = jsonEncode(validRemovedImages);
        print('📤 Added removedMedia with ${validRemovedImages.length} URLs');
      }

      int addedFiles = 0;
      if (imagePaths != null && imagePaths.isNotEmpty) {
        for (var path in imagePaths) {
          if (path.isNotEmpty && path.contains('/')) {
            try {
              request.files.add(await http.MultipartFile.fromPath(
                'media',
                path,
                filename: path.split('/').last,
              ));
              addedFiles++;
              print('📤 Added file: ${path.split('/').last}');
            } catch (e) {
              print('⚠️ Error adding file: $e');
            }
          }
        }
      }
      if (videoPaths != null && videoPaths.isNotEmpty) {
        for (final videoPath in videoPaths) {
          final videoFile = File(videoPath);
          if (await videoFile.exists()) {
            // Kiểm tra kích thước file
            final fileSize = await videoFile.length();
            if (fileSize > 100 * 1024 * 1024) {
              throw Exception('Video $videoPath vượt quá 100MB');
            }
            request.files.add(
              await http.MultipartFile.fromPath(
                'media',
                videoPath,
                contentType: MediaType('video', 'mp4'),
              ),
            );
            print('🎥 Added video: $videoPath (${(fileSize / 1024 / 1024).toStringAsFixed(2)}MB)');
          }
        }
      }

      final response = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );

      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody);

        final rentalData = data['rental'] ?? data['data'] ?? data;

        if (rentalData == null) {
          throw Exception('Không nhận được dữ liệu bài đăng');
        }

        if (rentalData['_id'] != null && rentalData['id'] == null) {
          rentalData['id'] = rentalData['_id'];
        }

        final updatedRental = Rental.fromJson(rentalData);

        if (updatedRental.id == null || updatedRental.id!.isEmpty) {
          throw Exception('RentalID is missing');
        }
        print('✅ Rental updated: ${updatedRental.id}');
        return updatedRental;
      } else {
        final errorData = jsonDecode(responseBody);
        print('❌ Update failed: ${response.statusCode}');
        throw Exception('Cập nhật thất bại: ${errorData['message'] ?? responseBody}');
      }
    } on TimeoutException {
      print('❌ Request timeout');
      throw Exception('Kết nối server quá lâu');
    } catch (e) {
      print('❌ Update rental error: $e');
      throw Exception('Cập nhật bài đăng thất bại: $e');
    }
  }
}

// ============================================
// APP USER EXTENSION
// ============================================
extension AppUserExtension on AppUser {
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
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
    );
  }
}