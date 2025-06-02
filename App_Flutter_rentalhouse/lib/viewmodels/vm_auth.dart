import 'package:flutter/foundation.dart';
import 'package:flutter_rentalhouse/models/comments.dart';
import 'package:flutter_rentalhouse/models/notification.dart';
import 'package:flutter_rentalhouse/models/rental.dart';
import '../services/auth_service.dart';
import '../models/user.dart';

class AuthViewModel extends ChangeNotifier {
  final AuthService _authService = AuthService();
  AppUser? _currentUser;
  List<Rental> _myPosts = [];
  List<Comment> _recentComments = [];
  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  String? _errorMessage;
  int _postsPage = 1;
  int _commentsPage = 1;
  int _notificationsPage = 1;
  int _postsTotalPages = 1;
  int _commentsTotalPages = 1;
  int _notificationsTotalPages = 1;

  AppUser? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<Rental> get myPosts => _myPosts;
  List<Comment> get recentComments => _recentComments;
  List<NotificationModel> get notifications => _notifications;
  int get postsPage => _postsPage;
  int get commentsPage => _commentsPage;
  int get notificationsPage => _notificationsPage;
  int get postsTotalPages => _postsTotalPages;
  int get commentsTotalPages => _commentsTotalPages;
  int get notificationsTotalPages => _notificationsTotalPages;

  // Đăng ký
  Future<void> register({
    required String email,
    required String password,
    required String phoneNumber,
    required String address,
    required String username,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      AppUser? user = await _authService.register(
        email: email,
        password: password,
        phoneNumber: phoneNumber,
        address: address,
        username: username,
      );
      if (user != null) {
        _currentUser = user;
      } else {
        _errorMessage = 'Đăng ký thất bại. Vui lòng thử lại.';
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Đăng nhập
  Future<void> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      AppUser? user = await _authService.login(
        email: email,
        password: password,
      );
      if (user != null) {
        _currentUser = user;
      } else {
        _errorMessage =
        'Đăng nhập thất bại. Vui lòng kiểm tra email hoặc mật khẩu.';
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Đăng nhập bằng Google
  Future<void> signInWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      AppUser? user = await _authService.signInWithGoogle();
      if (user != null) {
        _currentUser = user;
      } else {
        _errorMessage = 'Đăng nhập Google thất bại. Vui lòng thử lại.';
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Gửi email đặt lại mật khẩu
  Future<void> sendPasswordResetEmail(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.sendPasswordResetEmail(email);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Đặt lại mật khẩu
  Future<void> resetPassword(String oobCode, String newPassword) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.resetPassword(oobCode, newPassword);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Thay đổi mật khẩu
  Future<void> changePassword({
    required String newPassword,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      bool success = await _authService.changePassword(
        newPassword: newPassword,
      );
      if (success) {
        _errorMessage = null;
      } else {
        _errorMessage = 'Thay đổi mật khẩu thất bại. Vui lòng thử lại.';
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Cập nhật thông tin người dùng
  Future<void> updateUserProfile({
    required String phoneNumber,
    required String address,
    required String username,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      AppUser? updatedUser = await _authService.updateProfile(
        phoneNumber: phoneNumber,
        address: address,
        username: username,
      );
      if (updatedUser != null) {
        _currentUser = _currentUser?.copyWith(
          phoneNumber: phoneNumber,
          address: address,
          username: username,
        );
        await fetchCurrentUser();
        _errorMessage = null;
      } else {
        _errorMessage = 'Cập nhật hồ sơ thất bại. Vui lòng thử lại.';
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Upload profile image
  Future<void> uploadProfileImage({
    required String imageBase64,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final avatarBase64 =
      await _authService.uploadProfileImage(imageBase64: imageBase64);
      if (avatarBase64 != null && _currentUser != null) {
        _currentUser = _currentUser!.copyWith(avatarBase64: avatarBase64);
      } else {
        _errorMessage = 'Tải ảnh lên thất bại. Vui lòng thử lại.';
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Đăng xuất
  Future<void> logout() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      bool success = await _authService.logout();
      if (success) {
        _currentUser = null;
      } else {
        _errorMessage = 'Đăng xuất thất bại. Vui lòng thử lại.';
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Lấy thông tin user hiện tại
  Future<void> fetchCurrentUser() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      AppUser? user = await _authService.getCurrentUser();
      _currentUser = user;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchMyPosts({int page = 1, int limit = 10}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await _authService.fetchMyPosts(page: page, limit: limit);
      if (page == 1) {
        _myPosts = data['rentals'] as List<Rental>;
      } else {
        _myPosts.addAll(data['rentals'] as List<Rental>);
      }
      _postsPage = data['page'] as int;
      _postsTotalPages = data['pages'] as int;
    } catch (e) {
      _errorMessage = 'Failed to fetch posts: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Fetch recent comments
  Future<void> fetchRecentComments({int page = 1, int limit = 10}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data =
      await _authService.fetchRecentComments(page: page, limit: limit);
      final comments =
      (data['comments'] as List).map((e) => Comment.fromJson(e)).toList();
      if (page == 1) {
        _recentComments = comments;
      } else {
        _recentComments.addAll(comments);
      }
      _commentsPage = data['page'] as int;
      _commentsTotalPages = data['pages'] as int;
      if (comments.isEmpty && page == 1) {
        _errorMessage = 'Chưa có bình luận nào';
      }
    } catch (e) {
      _errorMessage = 'Lấy bình luận thất bại: $e';
      _recentComments = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Fetch notifications
  Future<void> fetchNotifications({int page = 1, int limit = 10}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data =
      await _authService.fetchNotifications(page: page, limit: limit);
      _notifications = data['notifications'] as List<NotificationModel>;
      _notificationsPage = data['page'] as int;
      _notificationsTotalPages = data['pages'] as int;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}