// lib/services/news_service.dart

import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_rentalhouse/config/api_routes.dart';

class NewsService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ====================== HỖ TRỢ ======================

  /// Tự động lấy Firebase ID Token
  Future<String?> _getIdToken() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    try {
      return await user.getIdToken();
    } catch (e) {
      print('Lỗi lấy Firebase ID Token: $e');
      return null;
    }
  }

  /// Tạo header có Authorization (nếu có token)
  Future<Map<String, String>> _headers({bool requireAuth = false}) async {
    final token = await _getIdToken();
    final headers = {
      'Content-Type': 'application/json',
    };

    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    } else if (requireAuth) {
      throw Exception('Chưa đăng nhập');
    }

    return headers;
  }

  /// Xác định MIME type từ đường dẫn file
  String _determineMimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    return 'image/jpeg';
  }

  /// Kiểm tra kích thước file (max 10MB)
  Future<void> _validateImageFile(File file) async {
    if (!await file.exists()) {
      throw Exception('File ảnh không tồn tại');
    }
    final size = await file.length();
    const maxSize = 10 * 1024 * 1024; // 10MB
    if (size > maxSize) {
      throw Exception(
          'Ảnh quá lớn (tối đa 10MB, hiện tại ${(size / 1024 / 1024).toStringAsFixed(1)}MB)');
    }
  }

  // ====================== PUBLIC APIs ======================

  /// Lấy tin tức công khai (có phân trang)
  Future<Map<String, dynamic>> fetchAllNews({
    int page = 1,
    int limit = 10,
  }) async {
    final uri = Uri.parse('${ApiRoutes.baseUrl}/news?page=$page&limit=$limit');
    final response = await http.get(uri, headers: await _headers()).timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw Exception('Timeout'),
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    }
    throw Exception('Tải tin tức thất bại (${response.statusCode})');
  }

  /// Lấy tin tức nổi bật
  Future<List<dynamic>> fetchFeaturedNews({int limit = 3}) async {
    final uri = Uri.parse('${ApiRoutes.baseUrl}/news/featured?limit=$limit');
    final response = await http.get(uri, headers: await _headers()).timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw Exception('Timeout'),
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes)) as List;
    }
    throw Exception('Tải tin tức nổi bật thất bại');
  }

  /// Lấy chi tiết 1 tin tức (tăng view)
  Future<Map<String, dynamic>> fetchNewsDetail(String newsId) async {
    final uri = Uri.parse('${ApiRoutes.baseUrl}/news/$newsId');
    final response = await http.get(uri, headers: await _headers()).timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw Exception('Timeout'),
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else if (response.statusCode == 404) {
      throw Exception('Tin tức không tồn tại');
    }
    throw Exception('Lấy chi tiết thất bại');
  }

  // ====================== ADMIN APIs (yêu cầu đăng nhập + quyền admin) ======================

  /// Admin: Lấy tất cả tin tức (kể cả chưa active)
  Future<Map<String, dynamic>> fetchAllNewsAdmin({
    int page = 1,
    int limit = 20,
  }) async {
    final uri = Uri.parse(
        '${ApiRoutes.baseUrl}/news/admin/all?page=$page&limit=$limit');
    final response = await http.get(uri, headers: await _headers(requireAuth: true)).timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw Exception('Timeout'),
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else if (response.statusCode == 401) {
      throw Exception('Token hết hạn, vui lòng đăng nhập lại');
    } else if (response.statusCode == 403) {
      throw Exception('Bạn không có quyền Admin');
    }
    throw Exception('Tải danh sách tin tức thất bại');
  }

  /// Admin: Tạo tin tức mới
  Future<Map<String, dynamic>> createNews({
    required String title,
    required String content,
    required String summary,
    required File imageFile,
    String author = 'Admin',
    String category = 'Tin tức',
    bool featured = false,
  }) async {
    await _validateImageFile(imageFile);

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiRoutes.baseUrl}/news'),
    );

    // Header + token
    final headers = await _headers(requireAuth: true);
    request.headers.addAll(headers);

    // Fields
    request.fields.addAll({
      'title': title.trim(),
      'content': content,
      'summary': summary.trim(),
      'author': author.trim(),
      'category': category.trim(),
      'featured': featured.toString(),
    });

    // File ảnh
    final mimeType = _determineMimeType(imageFile.path);
    request.files.add(await http.MultipartFile.fromPath(
      'image',
      imageFile.path,
      contentType: MediaType.parse(mimeType),
    ));

    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 60),
      onTimeout: () => throw Exception('Upload timeout'),
    );
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 401) {
      throw Exception('Token hết hạn, vui lòng đăng nhập lại');
    } else if (response.statusCode == 403) {
      throw Exception('Bạn không có quyền Admin');
    } else if (response.statusCode == 400) {
      final err = jsonDecode(response.body);
      throw Exception(err['message'] ?? 'Dữ liệu không hợp lệ');
    }
    throw Exception('Tạo tin tức thất bại (${response.statusCode})');
  }

  /// Admin: Cập nhật tin tức
  Future<Map<String, dynamic>> updateNews({
    required String newsId,
    required String title,
    required String content,
    required String summary,
    String author = 'Admin',
    String category = 'Tin tức',
    required bool featured,
    required bool isActive,
    File? imageFile,
  }) async {
    if (imageFile != null) await _validateImageFile(imageFile);

    final request = http.MultipartRequest(
      'PUT',
      Uri.parse('${ApiRoutes.baseUrl}/news/$newsId'),
    );

    request.headers.addAll(await _headers(requireAuth: true));

    request.fields.addAll({
      'title': title.trim(),
      'content': content,
      'summary': summary.trim(),
      'author': author.trim(),
      'category': category.trim(),
      'featured': featured.toString(),
      'isActive': isActive.toString(),
    });

    if (imageFile != null) {
      final mimeType = _determineMimeType(imageFile.path);
      request.files.add(await http.MultipartFile.fromPath(
        'image',
        imageFile.path,
        contentType: MediaType.parse(mimeType),
      ));
    }

    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 60),
      onTimeout: () => throw Exception('Upload timeout'),
    );
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 401) {
      throw Exception('Token hết hạn');
    } else if (response.statusCode == 403) {
      throw Exception('Không có quyền Admin');
    } else if (response.statusCode == 404) {
      throw Exception('Tin tức không tồn tại');
    }
    throw Exception('Cập nhật thất bại (${response.statusCode})');
  }

  /// Admin: Xóa tin tức
  Future<void> deleteNews(String newsId) async {
    final uri = Uri.parse('${ApiRoutes.baseUrl}/news/$newsId');
    final response = await http.delete(
      uri,
      headers: await _headers(requireAuth: true),
    ).timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw Exception('Timeout'),
    );

    if (response.statusCode == 200) {
      return;
    } else if (response.statusCode == 401) {
      throw Exception('Token hết hạn, vui lòng đăng nhập lại');
    } else if (response.statusCode == 403) {
      throw Exception('Bạn không có quyền Admin');
    } else if (response.statusCode == 404) {
      throw Exception('Tin tức không tồn tại');
    }
    final err = jsonDecode(response.body);
    throw Exception(err['message'] ?? 'Xóa thất bại');
  }
}