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
    final uri = Uri.parse('${ApiRoutes.news}?page=$page&limit=$limit');
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
    final uri = Uri.parse('${ApiRoutes.featuredNews}?limit=$limit');
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
    final uri = Uri.parse(ApiRoutes.newsById(newsId));
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

  // ====================== SAVED ARTICLES APIs ======================

  /// Lưu tin tức
  Future<void> saveArticle(String newsId) async {
    try {
      final uri = Uri.parse(ApiRoutes.saveArticle(newsId));
      print('Saving article: $uri');

      final headers = await _headers(requireAuth: true);
      final response = await http
          .post(
        uri,
        headers: headers,
      )
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Timeout'),
      );

      print('Save response status: ${response.statusCode}');

      if (response.statusCode == 201) {
        return;
      } else if (response.statusCode == 400) {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Bạn đã lưu tin tức này');
      } else if (response.statusCode == 401) {
        throw Exception('Token hết hạn, vui lòng đăng nhập lại');
      } else if (response.statusCode == 404) {
        throw Exception('Tin tức không tồn tại');
      }
      throw Exception('Không thể lưu tin tức (${response.statusCode})');
    } catch (e) {
      print('Error in saveArticle: $e');
      rethrow;
    }
  }

  /// Bỏ lưu tin tức
  Future<void> unsaveArticle(String newsId) async {
    try {
      final uri = Uri.parse(ApiRoutes.unsaveArticle(newsId));
      print('Unsaving article: $uri');

      final headers = await _headers(requireAuth: true);
      final response = await http
          .delete(
        uri,
        headers: headers,
      )
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Timeout'),
      );

      if (response.statusCode == 200) {
        return;
      } else if (response.statusCode == 401) {
        throw Exception('Token hết hạn');
      } else if (response.statusCode == 404) {
        throw Exception('Tin tức không tồn tại');
      }
      throw Exception('Không thể bỏ lưu tin tức (${response.statusCode})');
    } catch (e) {
      print('Error in unsaveArticle: $e');
      rethrow;
    }
  }

  /// Kiểm tra tin tức có được lưu không
  Future<bool> checkIsSaved(String newsId) async {
    try {
      final uri = Uri.parse(ApiRoutes.checkIsSaved(newsId));
      final headers = await _headers(requireAuth: true);
      final response = await http
          .get(
        uri,
        headers: headers,
      )
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Timeout'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['isSaved'] ?? false;
      }
      return false;
    } catch (e) {
      print('Error in checkIsSaved: $e');
      return false;
    }
  }

  /// Lấy tất cả tin tức đã lưu của user (có phân trang)
  Future<Map<String, dynamic>> fetchSavedArticles({
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final uri =
      Uri.parse('${ApiRoutes.savedArticles}?page=$page&limit=$limit');
      print('Fetching saved articles: $uri');

      final headers = await _headers(requireAuth: true);
      final response = await http
          .get(
        uri,
        headers: headers,
      )
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Timeout'),
      );

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else if (response.statusCode == 401) {
        throw Exception('Token hết hạn, vui lòng đăng nhập lại');
      }
      throw Exception('Tải tin tức đã lưu thất bại (${response.statusCode})');
    } catch (e) {
      print('Error in fetchSavedArticles: $e');
      rethrow;
    }
  }

  // ====================== ADMIN APIs ======================

  /// Admin: Lấy tất cả tin tức
  Future<Map<String, dynamic>> fetchAllNewsAdmin({
    int page = 1,
    int limit = 20,
  }) async {
    final uri = Uri.parse('${ApiRoutes.adminNews}?page=$page&limit=$limit');
    final response = await http
        .get(
      uri,
      headers: await _headers(requireAuth: true),
    )
        .timeout(
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

  /// Admin: Tạo tin tức mới (multiple images)
  Future<Map<String, dynamic>> createNews({
    required String title,
    required String content,
    required String summary,
    required List<File> imageFiles, // Thay đổi: danh sách file
    String author = 'Admin',
    String category = 'Tin tức',
    bool featured = false,
  }) async {
    if (imageFiles.isEmpty) {
      throw Exception('Vui lòng chọn ít nhất 1 ảnh');
    }

    // Validate tất cả file
    for (var file in imageFiles) {
      await _validateImageFile(file);
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse(ApiRoutes.news),
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

    // Thêm tất cả ảnh
    for (var imageFile in imageFiles) {
      final mimeType = _determineMimeType(imageFile.path);
      request.files.add(await http.MultipartFile.fromPath(
        'images', // Thay đổi: 'images' (plural)
        imageFile.path,
        contentType: MediaType.parse(mimeType),
      ));
    }

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

  /// Admin: Cập nhật tin tức (multiple images)
  Future<Map<String, dynamic>> updateNews({
    required String newsId,
    required String title,
    required String content,
    required String summary,
    String author = 'Admin',
    String category = 'Tin tức',
    required bool featured,
    required bool isActive,
    List<File>? imageFiles, // Thay đổi: danh sách file
  }) async {
    if (imageFiles != null && imageFiles.isNotEmpty) {
      for (var file in imageFiles) {
        await _validateImageFile(file);
      }
    }

    final request = http.MultipartRequest(
      'PUT',
      Uri.parse(ApiRoutes.newsById(newsId)),
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

    // Thêm ảnh nếu có
    if (imageFiles != null && imageFiles.isNotEmpty) {
      for (var imageFile in imageFiles) {
        final mimeType = _determineMimeType(imageFile.path);
        request.files.add(await http.MultipartFile.fromPath(
          'images',
          imageFile.path,
          contentType: MediaType.parse(mimeType),
        ));
      }
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
    final uri = Uri.parse(ApiRoutes.newsById(newsId));
    final response = await http
        .delete(
      uri,
      headers: await _headers(requireAuth: true),
    )
        .timeout(
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