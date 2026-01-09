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

  // ✅ ĐĂNG KÝ - Thay đổi từ avatarBase64 → imagePath
  Future<void> register({
    required String email,
    required String password,
    required String phoneNumber,
    required String address,
    required String username,
    required String imagePath,
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
        imagePath: imagePath,
      );
      if (user != null) {
        _currentUser = user;
        _errorMessage = null; // Clear error on success
      } else {
        _errorMessage = 'Đăng ký thất bại. Vui lòng thử lại';
      }
    } catch (e) {
      // ✅ Extract clean error message
      String errorMsg = e.toString();
      if (errorMsg.startsWith('Exception: ')) {
        errorMsg = errorMsg.substring(11);
      }
      _errorMessage = errorMsg;
      print(' Register error in ViewModel: $_errorMessage');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

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
        _errorMessage = null; //  Clear error on success
      } else {
        _errorMessage = 'Đăng nhập thất bại. Vui lòng thử lại';
      }
    } catch (e) {
      //  Extract clean error message
      String errorMsg = e.toString();
      if (errorMsg.startsWith('Exception: ')) {
        errorMsg = errorMsg.substring(11); // Remove "Exception: " prefix
      }
      _errorMessage = errorMsg;
      print('❌ Login error in ViewModel: $_errorMessage');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signInWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      AppUser? user = await _authService.signInWithGoogle();
      if (user != null) {
        _currentUser = user;
        _errorMessage = null; //  Clear error on success
      } else {
        _errorMessage = 'Đăng nhập Google thất bại. Vui lòng thử lại';
      }
    } catch (e) {
      //  Extract clean error message
      String errorMsg = e.toString();
      if (errorMsg.startsWith('Exception: ')) {
        errorMsg = errorMsg.substring(11);
      }
      _errorMessage = errorMsg;
      print('❌ Google sign-in error in ViewModel: $_errorMessage');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

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
          avatarUrl: _currentUser?.avatarUrl,
          role: _currentUser?.role,
        );
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

  // ✅ UPLOAD PROFILE IMAGE - Thay đổi từ imageBase64 → imagePath
  Future<void> uploadProfileImage({
    required String imagePath,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final avatarUrl = await _authService.uploadProfileImage(imagePath: imagePath);
      if (avatarUrl != null && _currentUser != null) {
        _currentUser = _currentUser!.copyWith(avatarUrl: avatarUrl);
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

  Future<void> fetchRecentComments({int page = 1, int limit = 10}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data =
      await _authService.fetchRecentComments(page: page, limit: limit);
      final comments = data['comments'] as List<Comment>;
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

  Future<void> fetchNotifications({int page = 1, int limit = 10}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      print('🔵 [FETCH NOTIFICATIONS ViewModel]');
      print('   page: $page, limit: $limit');

      final data = await _authService.fetchNotifications(page: page, limit: limit);

      print('✅ [FETCH NOTIFICATIONS ViewModel] Success');
      print('   notifications: ${data['notifications'].length}');
      print('   total: ${data['total']}');

      final notifications = data['notifications'] as List<NotificationModel>;

      if (page == 1) {
        _notifications = notifications;
      } else {
        _notifications.addAll(notifications);
      }

      _notificationsPage = data['page'] as int;
      _notificationsTotalPages = data['pages'] as int;

      if (notifications.isEmpty && page == 1) {
        print('⚠️ [FETCH NOTIFICATIONS ViewModel] No notifications found');
        _errorMessage = null;
      }
    } catch (e) {
      print('❌ [FETCH NOTIFICATIONS ViewModel] Error: $e');
      _errorMessage = 'Lấy thông báo thất bại: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      print('🔵 [MARK AS READ ViewModel]');
      print('   notificationId: $notificationId');

      bool success = await _authService.markNotificationAsRead(notificationId);

      if (success) {
        final index = _notifications.indexWhere((n) => n.id == notificationId);
        if (index != -1) {
          _notifications[index] = _notifications[index].copyWith(read: true);
          print('✅ [MARK AS READ ViewModel] Updated local state');
          notifyListeners();
        }
      }
    } catch (e) {
      print('❌ [MARK AS READ ViewModel] Error: $e');
      _errorMessage = 'Không thể cập nhật thông báo: $e';
      notifyListeners();
    }
  }

  Future<void> markAllNotificationsAsRead() async {
    try {
      print('🔵 [MARK ALL AS READ ViewModel]');

      bool success = await _authService.markAllNotificationsAsRead();

      if (success) {
        for (var i = 0; i < _notifications.length; i++) {
          _notifications[i] = _notifications[i].copyWith(read: true);
        }
        print('✅ [MARK ALL AS READ ViewModel] Updated all notifications');
        notifyListeners();
      }
    } catch (e) {
      print('❌ [MARK ALL AS READ ViewModel] Error: $e');
      _errorMessage = 'Không thể cập nhật: $e';
      notifyListeners();
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      print('🔵 [DELETE NOTIFICATION ViewModel]');
      print('   notificationId: $notificationId');

      bool success = await _authService.deleteNotification(notificationId);

      if (success) {
        _notifications.removeWhere((n) => n.id == notificationId);
        print('✅ [DELETE NOTIFICATION ViewModel] Removed from list');
        notifyListeners();
      }
    } catch (e) {
      print('❌ [DELETE NOTIFICATION ViewModel] Error: $e');
      _errorMessage = 'Không thể xóa thông báo: $e';
      notifyListeners();
    }
  }

  Future<int> getUnreadCount() async {
    try {
      return await _authService.getUnreadNotificationCount();
    } catch (e) {
      print('❌ [GET UNREAD COUNT ViewModel] Error: $e');
      return 0;
    }
  }

  Future<Map<String, dynamic>> getDeletedNotifications() async {
    try {
      print('🔵 [GET DELETED NOTIFICATIONS ViewModel]');

      final result = await _authService.getDeletedNotifications();

      print('✅ [GET DELETED NOTIFICATIONS ViewModel] count: ${result['count']}');

      return result;
    } catch (e) {
      print('❌ [GET DELETED NOTIFICATIONS ViewModel] Error: $e');
      return {'count': 0, 'data': []};
    }
  }

  Future<bool> undoDeleteNotificationSingle(String notificationId) async {
    try {
      print('🔵 [UNDO DELETE SINGLE ViewModel]');
      print('   notificationId: $notificationId');

      bool success = await _authService.undoDeleteNotificationSingle(notificationId);

      if (success) {
        print('✅ [UNDO DELETE SINGLE ViewModel] Success');
        await fetchNotifications(page: 1);
        notifyListeners();
        return true;
      } else {
        print('⚠️ [UNDO DELETE SINGLE ViewModel] Failed');
        return false;
      }
    } catch (e) {
      print('❌ [UNDO DELETE SINGLE ViewModel] Error: $e');
      _errorMessage = 'Hoàn tác thất bại: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<bool> undoDeleteNotifications() async {
    try {
      print('🔵 [UNDO DELETE ALL NOTIFICATIONS ViewModel]');

      bool success = await _authService.undoDeleteNotifications();

      if (success) {
        print('✅ [UNDO DELETE ALL NOTIFICATIONS ViewModel] Success');
        await fetchNotifications(page: 1);
        notifyListeners();
        return true;
      } else {
        print('⚠️ [UNDO DELETE ALL NOTIFICATIONS ViewModel] Failed');
        return false;
      }
    } catch (e) {
      print('❌ [UNDO DELETE ALL NOTIFICATIONS ViewModel] Error: $e');
      _errorMessage = 'Hoàn tác thất bại: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<bool> permanentDeleteFromUndo(String notificationId) async {
    try {
      print('🔵 [PERMANENT DELETE UNDO ViewModel]');
      print('   notificationId: $notificationId');

      bool success = await _authService.permanentDeleteFromUndo(notificationId);

      if (success) {
        print('✅ [PERMANENT DELETE UNDO ViewModel] Success');
        await getDeletedNotifications();
        notifyListeners();
        return true;
      } else {
        print('⚠️ [PERMANENT DELETE UNDO ViewModel] Failed');
        return false;
      }
    } catch (e) {
      print('❌ [PERMANENT DELETE UNDO ViewModel] Error: $e');
      _errorMessage = 'Xóa vĩnh viễn thất bại: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> checkUndoStatus() async {
    try {
      print('🔵 [CHECK UNDO STATUS ViewModel]');

      final result = await _authService.checkUndoStatus();

      print('✅ [CHECK UNDO STATUS ViewModel] hasUndo: ${result['hasUndo']} - undoCount: ${result['undoCount']}');

      return result;
    } catch (e) {
      print('❌ [CHECK UNDO STATUS ViewModel] Error: $e');
      return {'hasUndo': false, 'undoCount': 0};
    }
  }

  Future<void> deleteRental(String rentalId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.deleteRental(rentalId);
      _myPosts.removeWhere((rental) => rental.id == rentalId);
      print('AuthViewModel: Successfully deleted rental (rentalId: $rentalId)');
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      print('AuthViewModel: Error deleting rental (rentalId: $rentalId): $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateRental({
    required String rentalId,
    required Map<String, dynamic> updatedData,
    List<String>? imagePaths,
    List<String>? videoPaths,
    List<String>? removedImages,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updatedRental = await _authService.updateRental(
        rentalId: rentalId,
        updatedData: updatedData,
        imagePaths: imagePaths,
        videoPaths: videoPaths,
        removedImages: removedImages,
      );
      final index = _myPosts.indexWhere((rental) => rental.id == rentalId);
      if (index != -1) {
        _myPosts[index] = updatedRental;
      }
      print('AuthViewModel: Successfully updated rental (rentalId: $rentalId)');
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      print('AuthViewModel: Error updating rental (rentalId: $rentalId): $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}