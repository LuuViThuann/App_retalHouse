import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
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

  Future<AppUser?> register({
    required String email,
    required String password,
    required String phoneNumber,
    required String address,
    required String username,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      final user = userCredential.user;
      if (user == null) {
        print('AuthService: No user created during registration');
        throw Exception('Failed to create user');
      }
      final idToken = await user.getIdToken(true);
      if (idToken == null) {
        print('AuthService: No ID token for registered user');
        throw Exception('Failed to obtain ID token');
      }
      final response = await http.post(
        Uri.parse(ApiRoutes.register),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'phoneNumber': phoneNumber,
          'address': address,
          'username': username,
          'idToken': idToken,
        }),
      );
      print(
          'AuthService: Register response: ${response.statusCode}, body: ${response.body}');
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final avatarBase64 = await fetchAvatarBase64(user.uid, idToken);
        return AppUser(
          id: data['id'] as String,
          email: data['email'] as String,
          phoneNumber: data['phoneNumber'] as String,
          address: data['address'] as String,
          createdAt: DateTime.parse(data['createdAt'] as String),
          username: data['username'] as String,
          token: idToken,
          avatarBase64: avatarBase64,
        );
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(
            'Đăng ký thất bại: ${errorData['message'] ?? response.body}');
      }
    } catch (e) {
      print('AuthService: Error during registration: $e');
      throw Exception('Đăng ký thất bại: $e');
    }
  }

  Future<AppUser?> login({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      final user = userCredential.user;
      if (user == null) {
        print('AuthService: No user found for login');
        throw Exception('Failed to login');
      }
      final idToken = await user.getIdToken(true);
      if (idToken == null) {
        print('AuthService: No ID token for logged-in user');
        throw Exception('Failed to obtain ID token');
      }
      final response = await http.post(
        Uri.parse(ApiRoutes.login),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'idToken': idToken,
        }),
      );
      print(
          'AuthService: Login response: ${response.statusCode}, body: ${response.body}');
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
          username: data['username'] as String? ?? '',
          token: idToken,
          avatarBase64: avatarBase64,
        );
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(
            'Đăng nhập thất bại: ${errorData['message'] ?? response.body}');
      }
    } catch (e) {
      print('AuthService: Error during login: $e');
      throw Exception('Đăng nhập thất bại: $e');
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
        print('AuthService: No user found for password change');
        throw Exception('Không tìm thấy người dùng');
      }
      final idToken = await user.getIdToken(true);
      if (idToken == null) {
        print('AuthService: No ID token for password change');
        throw Exception('Failed to obtain ID token');
      }
      final response = await http.post(
        Uri.parse(ApiRoutes.changePassword),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'idToken': idToken,
          'newPassword': newPassword,
        }),
      );
      print(
          'AuthService: Change password response: ${response.statusCode}, body: ${response.body}');
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
        print('AuthService: No user found for profile update');
        throw Exception('Không tìm thấy người dùng');
      }
      final idToken = await user.getIdToken(true);
      if (idToken == null) {
        print('AuthService: No ID token for profile update');
        throw Exception('Failed to obtain ID token');
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
      print(
          'AuthService: Update profile response: ${response.statusCode}, body: ${response.body}');
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
        print('AuthService: No user found for image upload');
        throw Exception('Không tìm thấy người dùng');
      }
      final idToken = await user.getIdToken(true);
      if (idToken == null) {
        print('AuthService: No ID token for image upload');
        throw Exception('Failed to obtain ID token');
      }
      final response = await http.post(
        Uri.parse(ApiRoutes.uploadImage),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'idToken': idToken,
          'imageBase64': imageBase64,
        }),
      );
      print(
          'AuthService: Upload image response: ${response.statusCode}, body: ${response.body}');
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
        print('AuthService: No user for fetching posts');
        throw Exception('Không tìm thấy người dùng');
      }
      final idToken = await user.getIdToken(true);
      if (idToken == null) {
        print('AuthService: No ID token for fetching posts');
        throw Exception('Failed to obtain ID token');
      }
      final response = await http.get(
        Uri.parse('${ApiRoutes.myPosts}?page=$page&limit=$limit'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );
      print(
          'AuthService: Fetch posts response: ${response.statusCode}, body: ${response.body}');
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
        print('AuthService: No user for fetching comments');
        throw Exception('Không tìm thấy người dùng');
      }
      final idToken = await user.getIdToken(true);
      if (idToken == null) {
        print('AuthService: No ID token for fetching comments');
        throw Exception('Failed to obtain ID token');
      }
      final response = await http.get(
        Uri.parse('${ApiRoutes.recentComments}?page=$page&limit=$limit'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );
      print(
          'AuthService: Fetch comments response: ${response.statusCode}, body: ${response.body}');
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
      print('AuthService: Error fetching recent comments: $e');
      throw Exception('Lấy bình luận thất bại: $e');
    }
  }

  Future<Map<String, dynamic>> fetchNotifications(
      {int page = 1, int limit = 10}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('AuthService: No user for fetching notifications');
        throw Exception('Không tìm thấy người dùng');
      }
      final idToken = await user.getIdToken(true);
      if (idToken == null) {
        print('AuthService: No ID token for fetching notifications');
        throw Exception('Failed to obtain ID token');
      }
      final response = await http.get(
        Uri.parse('${ApiRoutes.notifications}?page=$page&limit=$limit'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );
      print(
          'AuthService: Fetch notifications response: ${response.statusCode}, body: ${response.body}');
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
      print('AuthService: Error fetching notifications: $e');
      throw Exception('Lấy thông báo thất bại: $e');
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
