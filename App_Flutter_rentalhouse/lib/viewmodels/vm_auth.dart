import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import '../models/user.dart';

class AuthViewModel extends ChangeNotifier {
  final AuthService _authService = AuthService();
  AppUser? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  AppUser? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

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
        _errorMessage = 'Đăng nhập thất bại. Vui lòng kiểm tra email hoặc mật khẩu.';
      }
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
        username: username, // Update to 'username' as per API consistency
      );
      if (updatedUser != null) {
        _currentUser = _currentUser?.copyWith(
          phoneNumber: phoneNumber,
          address: address,
          username: username,
        ); // Immediate update
        await fetchCurrentUser(); // Refresh with server data
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
      final avatarBase64 = await _authService.uploadProfileImage(imageBase64: imageBase64);
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
}