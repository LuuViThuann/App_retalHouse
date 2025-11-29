import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/config/api_routes.dart';
import 'package:flutter_rentalhouse/models/rental.dart';
import 'package:flutter_rentalhouse/services/auth_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AdminViewModel extends ChangeNotifier {
  // ============ USER MANAGEMENT ============
  List<Map<String, dynamic>> _users = [];
  Map<String, dynamic>? _currentUserDetail;
  final Map<String, String> _avatarCache = {};

  // ============ POSTS MANAGEMENT ============
  List<Rental> _userPosts = [];
  int _postsPage = 1;
  int _postsTotalPages = 1;

  // ============ STATE ============
  bool _isLoading = false;
  String? _error;

  // ============ GETTERS ============
  List<Map<String, dynamic>> get users => _users;
  Map<String, dynamic>? get currentUserDetail => _currentUserDetail;
  List<Rental> get userPosts => _userPosts;
  int get postsPage => _postsPage;
  int get postsTotalPages => _postsTotalPages;
  bool get isLoading => _isLoading;
  String? get error => _error;

  final AuthService _authService = AuthService();

  // ============ HELPER METHODS ============
  String? getAvatarFromCache(String userId) => _avatarCache[userId];

  void resetUsersList() {
    _users = [];
    _currentUserDetail = null;
    _userPosts = [];
    _postsPage = 1;
    _postsTotalPages = 1;
    _error = null;
    notifyListeners();
  }

  void clearAllCache() {
    _users = [];
    _currentUserDetail = null;
    _userPosts = [];
    _avatarCache.clear();
    _postsPage = 1;
    _postsTotalPages = 1;
    _error = null;
    notifyListeners();
  }

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

  /// ✅ Helper: Get token with refresh
  Future<String?> _getValidToken() async {
    try {
      final token = await _authService.getIdToken();
      if (token == null) {
        _error = 'Không lấy được token - vui lòng đăng nhập lại';
        debugPrint('❌ Token is null');
        return null;
      }
      debugPrint('✅ Token obtained: ${token.substring(0, 20)}...');
      return token;
    } catch (e) {
      _error = 'Lỗi lấy token: $e';
      debugPrint('❌ Error getting token: $e');
      return null;
    }
  }

  // ============ USER MANAGEMENT METHODS ============

  /// Lấy danh sách người dùng
  Future<void> fetchUsers({int page = 1, int limit = 20}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final token = await _getValidToken();
      if (token == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      final url = ApiRoutes.adminUserList(page: page, limit: limit);
      debugPrint('🔗 Fetching users from: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint('📡 Response status: ${response.statusCode}');
      debugPrint('📄 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final userList = List<Map<String, dynamic>>.from(data['users'] ?? []);

        debugPrint('✅ Users fetched: ${userList.length}');

        if (page == 1) {
          _users = userList;
        } else {
          _users.addAll(userList);
        }

        // Cache avatars
        for (var user in userList) {
          if (user['avatarBase64'] != null && user['avatarBase64'].isNotEmpty) {
            _avatarCache[user['id']] = user['avatarBase64'];
          }
        }

        _error = null;
      } else if (response.statusCode == 401) {
        _error = '⚠️ Token hết hạn - vui lòng đăng nhập lại';
        debugPrint('❌ Unauthorized (401): Token expired or invalid');
      } else if (response.statusCode == 403) {
        _error = '🚫 Bạn không có quyền admin để truy cập';
        debugPrint('❌ Forbidden (403): Not admin');
      } else {
        _error = 'Lỗi tải danh sách người dùng (${response.statusCode})';
        debugPrint('❌ Error: ${response.body}');
      }
    } catch (e) {
      _error = 'Lỗi mạng: $e';
      debugPrint('❌ Exception: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Lấy ảnh đại diện riêng lẻ (cho ảnh lớn)
  Future<void> fetchAvatarForUser(String userId) async {
    if (_avatarCache.containsKey(userId)) {
      return;
    }

    try {
      final token = await _getValidToken();
      if (token == null) return;

      final response = await http.get(
        Uri.parse(ApiRoutes.adminUserAvatar(userId)),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['avatarBase64'] != null) {
          _avatarCache[userId] = data['avatarBase64'];
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('❌ Error fetch avatar for user $userId: $e');
    }
  }

  /// Lấy chi tiết người dùng
  Future<void> fetchUserDetail(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final token = await _getValidToken();
      if (token == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      final response = await http.get(
        Uri.parse(ApiRoutes.adminUserDetail(userId)),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        _currentUserDetail = jsonDecode(response.body);

        if (_currentUserDetail!['avatarBase64'] != null) {
          _avatarCache[userId] = _currentUserDetail!['avatarBase64'];
        }
        _error = null;
      } else if (response.statusCode == 401) {
        _error = 'Token hết hạn - vui lòng đăng nhập lại';
      } else {
        _error = 'Không tải được chi tiết người dùng (${response.statusCode})';
      }
    } catch (e) {
      _error = 'Lỗi: $e';
      debugPrint('❌ Error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Cập nhật avatar người dùng
  Future<bool> updateUserAvatar(String userId, String base64Image) async {
    try {
      final token = await _getValidToken();
      if (token == null) return false;

      final response = await http
          .put(
            Uri.parse(ApiRoutes.adminUserAvatarUpdate(userId)),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'avatarBase64': base64Image}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        _avatarCache[userId] = base64Image;
        _updateUserInList(userId, {'avatarBase64': base64Image});
        await fetchUserDetail(userId);
        return true;
      } else if (response.statusCode == 401) {
        _error = 'Token hết hạn';
        return false;
      } else {
        _error = 'Lỗi đổi ảnh: ${response.statusCode}';
        return false;
      }
    } catch (e) {
      _error = 'Lỗi: $e';
      return false;
    }
  }

  /// Cập nhật thông tin người dùng
  Future<bool> updateUser(String userId, Map<String, dynamic> data) async {
    try {
      final token = await _getValidToken();
      if (token == null) return false;

      final response = await http
          .put(
            Uri.parse(ApiRoutes.adminUserUpdate(userId)),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        _updateUserInList(userId, data);
        _error = null;
        return true;
      } else if (response.statusCode == 401) {
        _error = 'Token hết hạn';
        return false;
      } else {
        _error = 'Cập nhật thất bại: ${response.statusCode}';
        return false;
      }
    } catch (e) {
      _error = 'Lỗi: $e';
      return false;
    }
  }

  /// Xóa người dùng
  Future<bool> deleteUser(String userId) async {
    try {
      final token = await _getValidToken();
      if (token == null) return false;

      final response = await http.delete(
        Uri.parse(ApiRoutes.adminUserDelete(userId)),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        _users.removeWhere((u) => u['id'] == userId);
        _avatarCache.remove(userId);
        _error = null;
        notifyListeners();
        return true;
      } else if (response.statusCode == 401) {
        _error = 'Token hết hạn';
        return false;
      } else {
        _error = 'Xóa thất bại (${response.statusCode})';
        return false;
      }
    } catch (e) {
      _error = 'Lỗi: $e';
      return false;
    }
  }

  // ============ POSTS MANAGEMENT METHODS ============

  /// Lấy danh sách user cùng số bài đăng
  Future<void> fetchUsersWithPostCount({int page = 1, int limit = 20}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final token = await _getValidToken();
      if (token == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      final url =
          ApiRoutes.adminUsersWithPostsPaginated(page: page, limit: limit);
      debugPrint('🔗 Fetching users with posts from: $url');
      debugPrint('🔑 Token: ${token.substring(0, 20)}...');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint('📡 Response status: ${response.statusCode}');
      debugPrint('📄 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final userList = List<Map<String, dynamic>>.from(data['users'] ?? []);

        debugPrint('✅ Users with posts fetched: ${userList.length}');

        if (page == 1) {
          _users = userList;
        } else {
          _users.addAll(userList);
        }

        _error = null;
      } else if (response.statusCode == 401) {
        _error = '⚠️ Token hết hạn - vui lòng đăng nhập lại';
        debugPrint('❌ Unauthorized (401)');
      } else if (response.statusCode == 403) {
        _error = '🚫 Bạn không có quyền admin';
        debugPrint('❌ Forbidden (403)');
      } else {
        _error = 'Lỗi tải danh sách (${response.statusCode})';
        debugPrint('❌ Error: ${response.body}');
      }
    } catch (e) {
      _error = 'Lỗi mạng: $e';
      debugPrint('❌ Exception: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Lấy bài đăng của một user cụ thể
  Future<void> fetchUserPosts(
    String userId, {
    int page = 1,
    int limit = 10,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final token = await _getValidToken();
      if (token == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      final url = ApiRoutes.adminUserPosts(userId, page: page, limit: limit);
      debugPrint('🔗 Fetching user posts from: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint('📡 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rentalList = (data['rentals'] as List?)
                ?.map((rental) => Rental.fromJson(rental))
                .toList() ??
            [];

        debugPrint('✅ Posts fetched: ${rentalList.length}');

        if (page == 1) {
          _userPosts = rentalList;
        } else {
          _userPosts.addAll(rentalList);
        }

        _postsPage = data['page'] ?? page;
        _postsTotalPages = data['pages'] ?? 1;
        _error = null;
      } else if (response.statusCode == 401) {
        _error = 'Token hết hạn - vui lòng đăng nhập lại';
        debugPrint('❌ Unauthorized (401)');
      } else {
        _error = 'Lỗi tải bài đăng: ${response.statusCode}';
        debugPrint('❌ Error: ${response.body}');
      }
    } catch (e) {
      _error = 'Lỗi mạng: $e';
      debugPrint('❌ Exception: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Xóa bài đăng
  Future<bool> deleteUserPost(String rentalId) async {
    try {
      final token = await _getValidToken();
      if (token == null) {
        _error = 'Token is null - không lấy được token';
        debugPrint('❌ Token is null');
        return false;
      }

      debugPrint('═══════════════════════════════════════════');
      debugPrint('🗑️ DELETE POST REQUEST');
      debugPrint('═══════════════════════════════════════════');

      // ✅ ĐÚNG - Gọi route /admin/rentals/:rentalId
      final url = '${ApiRoutes.baseUrl}/admin/rentals/$rentalId';

      debugPrint('🔗 DELETE URL: $url');
      debugPrint('🔑 Token (first 50): ${token.substring(0, 50)}...');

      final response = await http.delete(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint('📊 Response Status: ${response.statusCode}');
      debugPrint('📋 Response Body: ${response.body}');
      debugPrint('═══════════════════════════════════════════');

      if (response.statusCode == 200) {
        // ✅ FIX: Xóa từ danh sách bài đăng
        _userPosts.removeWhere((post) => post.id == rentalId);
        _error = null;

        // ✅ FIX: Notify listeners để cập nhật UI
        notifyListeners();

        debugPrint('✅ SUCCESS: Rental deleted and UI updated');
        return true;
      } else if (response.statusCode == 401) {
        _error = 'Token hết hạn - vui lòng đăng nhập lại';
        debugPrint('❌ 401 Unauthorized: Token expired');
        return false;
      } else if (response.statusCode == 403) {
        _error = 'Bạn không có quyền admin để xóa bài viết';
        debugPrint('❌ 403 Forbidden');
        return false;
      } else if (response.statusCode == 404) {
        _error = 'Bài viết không tồn tại';
        debugPrint('❌ 404: Rental not found');
        return false;
      } else {
        _error = 'Lỗi xóa bài đăng: ${response.statusCode}';
        debugPrint('❌ ERROR ${response.statusCode}');
        return false;
      }
    } catch (e) {
      _error = 'Lỗi: $e';
      debugPrint('❌ EXCEPTION: $e');
      return false;
    }
  }

  void clearAvatarCache() {
    _avatarCache.clear();
  }

  /// Tải thêm bài đăng (pagination)
  Future<void> loadMoreUserPosts(String userId, {int limit = 10}) async {
    if (_postsPage >= _postsTotalPages) {
      return;
    }
    await fetchUserPosts(userId, page: _postsPage + 1, limit: limit);
  }

  // ============ CHỈNH SỬA - XÓA BÀI VIẾT
  /// ========== EDIT RENTAL METHODS ==========

  /// Cập nhật bài đăng (chỉ admin mới có quyền)
  Future<bool> adminEditRental(
    String rentalId,
    Map<String, dynamic> updateData, {
    List<String>? imagesToRemove,
  }) async {
    try {
      final token = await _getValidToken();
      if (token == null) return false;

      final request = http.MultipartRequest(
        'PATCH',
        Uri.parse('${ApiRoutes.rentals}/$rentalId'),
      );

      // Thêm headers
      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Content-Type': 'multipart/form-data',
      });

      // Thêm các trường dữ liệu
      updateData.forEach((key, value) {
        if (value != null && value is! List) {
          request.fields[key] = value.toString();
        } else if (value is List) {
          request.fields[key] = value.join(',');
        }
      });

      // Thêm danh sách ảnh cần xóa
      if (imagesToRemove != null && imagesToRemove.isNotEmpty) {
        request.fields['removedImages'] = jsonEncode(imagesToRemove);
      }

      debugPrint('📤 Sending PATCH request to edit rental: $rentalId');

      final response =
          await request.send().timeout(const Duration(seconds: 30));

      final responseBody = await response.stream.bytesToString();
      debugPrint('📡 Response status: ${response.statusCode}');
      debugPrint('📄 Response body: $responseBody');

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody);
        _error = null;
        debugPrint('✅ Rental updated successfully');
        return true;
      } else if (response.statusCode == 401) {
        _error = 'Token hết hạn - vui lòng đăng nhập lại';
        return false;
      } else if (response.statusCode == 403) {
        _error = 'Bạn không có quyền chỉnh sửa bài viết này';
        return false;
      } else {
        _error = 'Lỗi cập nhật bài viết: ${response.statusCode}';
        return false;
      }
    } catch (e) {
      _error = 'Lỗi mạng: $e';
      debugPrint('❌ Exception: $e');
      return false;
    }
  }

  /// ========== DELETE RENTAL METHODS ==========

  /// Xóa bài đăng người dùng (chỉ admin)
  Future<bool> adminDeleteRental(String rentalId) async {
    try {
      final token = await _getValidToken();
      if (token == null) return false;

      debugPrint('🗑️ Attempting to delete rental: $rentalId');

      final response = await http.delete(
        Uri.parse('${ApiRoutes.baseUrl}/admin/rentals/$rentalId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint('📡 Delete response status: ${response.statusCode}');
      debugPrint('📄 Delete response body: ${response.body}');

      if (response.statusCode == 200) {
        // Xóa từ danh sách bài đăng
        _userPosts.removeWhere((post) => post.id == rentalId);
        _error = null;
        notifyListeners();
        debugPrint('✅ Rental deleted successfully');
        return true;
      } else if (response.statusCode == 401) {
        _error = 'Token hết hạn - vui lòng đăng nhập lại';
        return false;
      } else if (response.statusCode == 403) {
        _error = 'Bạn không có quyền xóa bài viết này';
        return false;
      } else if (response.statusCode == 404) {
        _error = 'Bài viết không tồn tại';
        return false;
      } else {
        _error = 'Lỗi xóa bài viết: ${response.statusCode}';
        return false;
      }
    } catch (e) {
      _error = 'Lỗi mạng: $e';
      debugPrint('❌ Exception: $e');
      return false;
    }
  }

  /// ========== GET SINGLE RENTAL FOR EDITING ==========

  /// Lấy chi tiết một bài viết để chỉnh sửa
  Future<Rental?> fetchRentalForEdit(String rentalId) async {
    try {
      _isLoading = true;
      notifyListeners();

      final response = await http.get(
        Uri.parse('${ApiRoutes.rentals}/$rentalId'),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint('📡 Fetch rental response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rental = Rental.fromJson(data);
        _error = null;
        _isLoading = false;
        notifyListeners();
        return rental;
      } else {
        _error = 'Không tải được bài viết: ${response.statusCode}';
        _isLoading = false;
        notifyListeners();
        return null;
      }
    } catch (e) {
      _error = 'Lỗi: $e';
      debugPrint('❌ Exception: $e');
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }
}
