import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/config/api_routes.dart';
import 'package:flutter_rentalhouse/services/auth_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AdminViewModel extends ChangeNotifier {
  List<Map<String, dynamic>> _users = [];
  Map<String, dynamic>? _currentUserDetail;
  bool _isLoading = false;
  String? _error;

  // ✅ Cache ảnh để tránh load lại
  final Map<String, String> _avatarCache = {};

  List<Map<String, dynamic>> get users => _users;
  Map<String, dynamic>? get currentUserDetail => _currentUserDetail;
  bool get isLoading => _isLoading;
  String? get error => _error;

  final AuthService _authService = AuthService();

  // ✅ Lấy ảnh từ cache hoặc null
  String? getAvatarFromCache(String userId) {
    return _avatarCache[userId];
  }

  // ✅ THÊM: Reset danh sách người dùng (xóa dữ liệu cũ)
  void resetUsersList() {
    _users = [];
    _currentUserDetail = null;
    _error = null;
    notifyListeners();
  }

  // ✅ Fetch danh sách người dùng (kèm ảnh nhỏ từ API)
  Future<void> fetchUsers({int page = 1}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final token = await _authService.getIdToken();
      final response = await http.get(
        Uri.parse('${ApiRoutes.baseUrl}/auth/admin/users?page=$page&limit=20'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // ✅ FIX: Nếu page 1, ghi đè; nếu page > 1, append
        if (page == 1) {
          _users = List<Map<String, dynamic>>.from(data['users']);
        } else {
          _users.addAll(List<Map<String, dynamic>>.from(data['users']));
        }

        // ✅ Cache ảnh từ API nếu có
        for (var user in _users) {
          if (user['avatarBase64'] != null && user['avatarBase64'].isNotEmpty) {
            _avatarCache[user['id']] = user['avatarBase64'];
          }
        }

        _error = null;
      } else {
        _error = 'Lỗi tải danh sách người dùng (${response.statusCode})';
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('Lỗi fetch users: $_error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ✅ Fetch ảnh riêng lẻ cho các ảnh lớn
  Future<void> fetchAvatarForUser(String userId) async {
    // Nếu đã có trong cache, bỏ qua
    if (_avatarCache.containsKey(userId)) {
      return;
    }

    try {
      final token = await _authService.getIdToken();
      final response = await http.get(
        Uri.parse('${ApiRoutes.baseUrl}/auth/admin/users/$userId/avatar'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['avatarBase64'] != null) {
          _avatarCache[userId] = data['avatarBase64'];
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Lỗi fetch ảnh cho user $userId: $e');
    }
  }

  // ✅ Fetch chi tiết người dùng (có ảnh đầy đủ)
  Future<void> fetchUserDetail(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final token = await _authService.getIdToken();
      final response = await http.get(
        Uri.parse('${ApiRoutes.baseUrl}/auth/admin/users/$userId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        _currentUserDetail = jsonDecode(response.body);

        // ✅ Cache ảnh nếu có
        if (_currentUserDetail!['avatarBase64'] != null) {
          _avatarCache[userId] = _currentUserDetail!['avatarBase64'];
        }
      } else {
        _error = 'Không tải được chi tiết người dùng';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ✅ Cập nhật avatar
  Future<bool> updateUserAvatar(String userId, String base64Image) async {
    try {
      final token = await _authService.getIdToken();
      final response = await http.put(
        Uri.parse('${ApiRoutes.baseUrl}/auth/admin/users/$userId/avatar'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'avatarBase64': base64Image}),
      );

      if (response.statusCode == 200) {
        // ✅ Cập nhật cache ngay
        _avatarCache[userId] = base64Image;

        // ✅ Cập nhật trong danh sách (real-time)
        _updateUserInList(userId, {'avatarBase64': base64Image});

        // Cập nhật lại chi tiết người dùng
        await fetchUserDetail(userId);
        return true;
      } else {
        _error = 'Lỗi đổi ảnh: ${response.statusCode}';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ✅ Cập nhật thông tin người dùng
  Future<bool> updateUser(String userId, Map<String, dynamic> data) async {
    try {
      final token = await _authService.getIdToken();
      final response = await http.put(
        Uri.parse('${ApiRoutes.baseUrl}/auth/admin/users/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        // ✅ Cập nhật trực tiếp trong danh sách (real-time)
        _updateUserInList(userId, data);
        return true;
      } else {
        _error = 'Cập nhật thất bại: ${response.statusCode}';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ✅ HELPER: Cập nhật user trong danh sách (real-time)
  void _updateUserInList(String userId, Map<String, dynamic> updates) {
    final index = _users.indexWhere((u) => u['id'] == userId);
    if (index != -1) {
      _users[index] = {
        ..._users[index],
        ...updates,
      };
      notifyListeners();
    }
  }

  // ✅ Xóa người dùng
  Future<void> deleteUser(String userId) async {
    try {
      final token = await _authService.getIdToken();
      final response = await http.delete(
        Uri.parse('${ApiRoutes.baseUrl}/auth/admin/users/$userId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        _users.removeWhere((u) => u['id'] == userId);
        _avatarCache.remove(userId);
        notifyListeners();
      } else {
        _error = 'Xóa thất bại (${response.statusCode})';
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // ✅ Xóa cache ảnh (dùng khi refresh)
  void clearAvatarCache() {
    _avatarCache.clear();
  }

  // ✅ Xóa toàn bộ dữ liệu (cache + users + detail)
  void clearAllCache() {
    _users = [];
    _currentUserDetail = null;
    _avatarCache.clear();
    _error = null;
    notifyListeners();
  }
}
