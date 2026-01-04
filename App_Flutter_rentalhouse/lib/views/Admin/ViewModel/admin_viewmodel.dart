import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/config/api_routes.dart';
import 'package:flutter_rentalhouse/models/rental.dart';
import 'package:flutter_rentalhouse/services/auth_service.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
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

  /// Get token with refresh
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

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final userList = List<Map<String, dynamic>>.from(data['users'] ?? []);

        debugPrint('✅ Users fetched: ${userList.length}');

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
        _error = '🚫 Bạn không có quyền admin để truy cập';
        debugPrint('❌ Forbidden (403)');
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

      debugPrint('═══════════════════════════════════════════');
      debugPrint('🔍 FETCH USER DETAIL');
      debugPrint('═══════════════════════════════════════════');
      debugPrint('User ID: $userId');

      final url = ApiRoutes.adminUserDetail(userId);
      debugPrint('🔗 URL: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint('📊 Response Status: ${response.statusCode}');
      debugPrint('📋 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        debugPrint('✅ Parsed response successfully');

        _currentUserDetail = responseData;
        _error = null;
        debugPrint('✅ User detail loaded');
      } else if (response.statusCode == 401) {
        _error = 'Token hết hạn - vui lòng đăng nhập lại';
        debugPrint('❌ 401 Unauthorized');
      } else if (response.statusCode == 404) {
        _error = 'Không tìm thấy người dùng';
        debugPrint('❌ 404 Not Found');
      } else {
        _error = 'Không tải được chi tiết người dùng (${response.statusCode})';
        debugPrint('❌ Error: ${response.body}');
      }
    } catch (e) {
      _error = 'Lỗi: $e';
      debugPrint('❌ Exception: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Cập nhật avatar người dùng (Upload multipart file)
  Future<bool> updateUserAvatar(String userId, String imagePath) async {
    try {
      final token = await _getValidToken();
      if (token == null) {
        _error = 'Không lấy được token';
        return false;
      }

      debugPrint('═══════════════════════════════════════════');
      debugPrint('📤 UPDATE USER AVATAR');
      debugPrint('═══════════════════════════════════════════');
      debugPrint('User ID: $userId');
      debugPrint('Image Path: $imagePath');

      var request = http.MultipartRequest(
        'PUT',
        Uri.parse(ApiRoutes.adminUserAvatarUpdate(userId)),
      );

      request.headers['Authorization'] = 'Bearer $token';

      // Thêm file với key 'avatar'
      request.files.add(
        await http.MultipartFile.fromPath(
          'avatar',
          imagePath,
          contentType: MediaType('image', 'jpeg'),
        ),
      );

      debugPrint('📤 Sending multipart request...');
      final response = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Upload timeout');
        },
      );

      final responseBody = await response.stream.bytesToString();
      debugPrint('📊 Response Status: ${response.statusCode}');
      debugPrint('📋 Response Body: $responseBody');

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody);
        debugPrint('✅ Upload successful');

        // Cập nhật detail
        if (_currentUserDetail != null) {
          _currentUserDetail!['avatarUrl'] = data['user']?['avatarUrl'] ??
              data['avatarUrl'] ??
              data['user']?['avatarUrl'];
        }

        _error = null;
        notifyListeners();
        return true;
      } else if (response.statusCode == 401) {
        _error = 'Token hết hạn';
        debugPrint('❌ 401 Unauthorized');
        return false;
      } else {
        final errorData = jsonDecode(responseBody);
        _error = errorData['message'] ?? 'Lỗi đổi ảnh';
        debugPrint('❌ Error: $errorData');
        return false;
      }
    } catch (e) {
      _error = 'Lỗi upload: $e';
      debugPrint('❌ Exception: $e');
      return false;
    }
  }

  /// Cập nhật thông tin người dùng
  Future<bool> updateUser(String userId, Map<String, dynamic> data) async {
    try {
      final token = await _getValidToken();
      if (token == null) {
        _error = 'Không lấy được token';
        return false;
      }

      debugPrint('═══════════════════════════════════════════');
      debugPrint('✏️ UPDATE USER INFO');
      debugPrint('═══════════════════════════════════════════');
      debugPrint('User ID: $userId');
      debugPrint('Data: $data');

      final url = ApiRoutes.adminUserUpdate(userId);
      debugPrint('🔗 URL: $url');

      final response = await http.put(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(data),
      ).timeout(const Duration(seconds: 15));

      debugPrint('📊 Response Status: ${response.statusCode}');
      debugPrint('📋 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        // Cập nhật currentUserDetail
        if (responseData['user'] != null) {
          _currentUserDetail = responseData['user'];
        }

        _updateUserInList(userId, data);
        _error = null;
        notifyListeners();
        debugPrint('✅ User updated successfully');
        return true;
      } else if (response.statusCode == 401) {
        _error = 'Token hết hạn';
        debugPrint('❌ 401 Unauthorized');
        return false;
      } else if (response.statusCode == 400) {
        final errorData = jsonDecode(response.body);
        _error = errorData['message'] ?? 'Dữ liệu không hợp lệ';
        debugPrint('❌ 400 Bad Request: $_error');
        return false;
      } else {
        final errorData = jsonDecode(response.body);
        _error = errorData['message'] ?? 'Cập nhật thất bại';
        debugPrint('❌ Error: $errorData');
        return false;
      }
    } catch (e) {
      _error = 'Lỗi: $e';
      debugPrint('❌ Exception: $e');
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

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final userList = List<Map<String, dynamic>>.from(data['users'] ?? []);

        if (page == 1) {
          _users = userList;
        } else {
          _users.addAll(userList);
        }

        _error = null;
      } else if (response.statusCode == 401) {
        _error = '⚠️ Token hết hạn';
      } else if (response.statusCode == 403) {
        _error = '🚫 Bạn không có quyền admin';
      } else {
        _error = 'Lỗi tải danh sách (${response.statusCode})';
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

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rentalList = (data['rentals'] as List?)
            ?.map((rental) => Rental.fromJson(rental))
            .toList() ??
            [];

        if (page == 1) {
          _userPosts = rentalList;
        } else {
          _userPosts.addAll(rentalList);
        }

        _postsPage = data['page'] ?? page;
        _postsTotalPages = data['pages'] ?? 1;
        _error = null;
      } else if (response.statusCode == 401) {
        _error = 'Token hết hạn';
      } else {
        _error = 'Lỗi tải bài đăng: ${response.statusCode}';
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
      if (token == null) return false;

      final url = '${ApiRoutes.baseUrl}/admin/rentals/$rentalId';

      final response = await http.delete(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        _userPosts.removeWhere((post) => post.id == rentalId);
        _error = null;
        notifyListeners();
        return true;
      } else if (response.statusCode == 401) {
        _error = 'Token hết hạn';
        return false;
      } else if (response.statusCode == 403) {
        _error = 'Bạn không có quyền xóa bài viết';
        return false;
      } else {
        _error = 'Lỗi xóa bài đăng: ${response.statusCode}';
        return false;
      }
    } catch (e) {
      _error = 'Lỗi: $e';
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

  /// Cập nhật bài đăng
  Future<bool> adminEditRental(
      String rentalId,
      Map<String, dynamic> updateData,
      ) async {
    try {
      final token = await _getValidToken();
      if (token == null) return false;

      final url = '${ApiRoutes.baseUrl}/admin/rentals/$rentalId';

      final response = await http.patch(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(updateData),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final index = _userPosts.indexWhere((post) => post.id == rentalId);
        if (index != -1) {
          _userPosts[index] = Rental.fromJson(data['rental']);
        }
        _error = null;
        notifyListeners();
        return true;
      } else {
        _error = 'Lỗi cập nhật: ${response.statusCode}';
        return false;
      }
    } catch (e) {
      _error = 'Lỗi: $e';
      return false;
    }
  }

  /// Xóa bài đăng người dùng (chỉ admin)
  Future<bool> adminDeleteRental(String rentalId) async {
    try {
      final token = await _getValidToken();
      if (token == null) return false;

      final response = await http.delete(
        Uri.parse('${ApiRoutes.baseUrl}/admin/rentals/$rentalId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        _userPosts.removeWhere((post) => post.id == rentalId);
        _error = null;
        notifyListeners();
        return true;
      } else {
        _error = 'Lỗi xóa bài viết: ${response.statusCode}';
        return false;
      }
    } catch (e) {
      _error = 'Lỗi mạng: $e';
      return false;
    }
  }

  /// Lấy bài đăng để chỉnh sửa
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
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }
}