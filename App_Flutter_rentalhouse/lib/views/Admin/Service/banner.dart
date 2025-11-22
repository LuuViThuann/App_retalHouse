import 'dart:io';
import 'package:flutter_rentalhouse/views/Admin/model/banner.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_rentalhouse/config/api_routes.dart';
import 'dart:convert';
import 'package:http_parser/http_parser.dart';

class BannerService {
  /// Helper function để parse MIME type từ string
  MediaType _getMimeType(String mimeType) {
    try {
      final parts = mimeType.split('/');
      if (parts.length == 2) {
        return MediaType(parts[0], parts[1]);
      }
      return MediaType('image', 'jpeg'); // Default
    } catch (e) {
      return MediaType('image', 'jpeg'); // Fallback
    }
  }

  /// Xác định MIME type dựa trên đuôi file
  String _determineMimeType(String filePath) {
    final lowerPath = filePath.toLowerCase();
    if (lowerPath.endsWith('.png')) {
      return 'image/png';
    } else if (lowerPath.endsWith('.webp')) {
      return 'image/webp';
    } else if (lowerPath.endsWith('.gif')) {
      return 'image/gif';
    } else if (lowerPath.endsWith('.jpg') || lowerPath.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    return 'image/jpeg'; // Default
  }

  // ==================== PUBLIC METHODS ====================

  /// Lấy tất cả banner (công khai - chỉ active)
  Future<List<BannerModel>> fetchActiveBanners() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiRoutes.banners}'),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Kết nối timeout'),
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(utf8.decode(response.bodyBytes)) as List;
        return jsonData
            .map((item) => BannerModel.fromJson(item as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('Tải banner thất bại: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Lỗi kết nối: $e');
    }
  }

  /// Lấy tất cả banner (admin - kể cả không active)
  Future<List<BannerModel>> fetchAllBanners(String token) async {
    try {
      if (token.isEmpty) {
        throw Exception('Token không hợp lệ');
      }

      final response = await http.get(
        Uri.parse('${ApiRoutes.baseUrl}/banners/admin'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Kết nối timeout'),
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(utf8.decode(response.bodyBytes)) as List;
        return jsonData
            .map((item) => BannerModel.fromJson(item as Map<String, dynamic>))
            .toList();
      } else if (response.statusCode == 401) {
        throw Exception('Token hết hạn, vui lòng đăng nhập lại');
      } else if (response.statusCode == 403) {
        throw Exception('Bạn không có quyền admin');
      } else {
        throw Exception('Tải banner thất bại: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Lỗi kết nối: $e');
    }
  }

  /// Tạo banner mới
  Future<BannerModel> createBanner({
    required String title,
    required String description,
    required String link,
    required int position,
    required File imageFile,
    required String token,
  }) async {
    try {
      // Validate inputs
      if (token.isEmpty) {
        throw Exception('Token không hợp lệ');
      }

      if (!imageFile.existsSync()) {
        throw Exception('File ảnh không tồn tại');
      }

      // Check file size (max 5MB)
      final fileSizeInBytes = await imageFile.length();
      const maxSizeInBytes = 5 * 1024 * 1024; // 5MB
      if (fileSizeInBytes > maxSizeInBytes) {
        throw Exception(
            'File quá lớn (tối đa 5MB, file hiện tại ${(fileSizeInBytes / 1024 / 1024).toStringAsFixed(2)}MB)');
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiRoutes.baseUrl}/banners'),
      );

      // Set headers
      request.headers['Authorization'] = 'Bearer $token';

      // Set fields
      request.fields['title'] = title.trim();
      request.fields['description'] = description.trim();
      request.fields['link'] = link.trim();
      request.fields['position'] = position.toString();
      request.fields['isActive'] = 'true';

      // Determine and set MIME type
      final mimeType = _determineMimeType(imageFile.path);

      // Add file
      request.files.add(
        await http.MultipartFile.fromPath(
          'image',
          imageFile.path,
          contentType: _getMimeType(mimeType),
        ),
      );

      // Send request with timeout
      final streamResponse = await request.send().timeout(
            const Duration(seconds: 60),
            onTimeout: () => throw Exception('Upload timeout'),
          );

      final response = await http.Response.fromStream(streamResponse);

      if (response.statusCode == 201) {
        final jsonData = jsonDecode(response.body);
        return BannerModel.fromJson(jsonData as Map<String, dynamic>);
      } else if (response.statusCode == 401) {
        throw Exception('Token hết hạn, vui lòng đăng nhập lại');
      } else if (response.statusCode == 403) {
        throw Exception('Bạn không có quyền admin');
      } else if (response.statusCode == 400) {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Lỗi yêu cầu không hợp lệ');
      } else {
        throw Exception(
            'Tạo banner thất bại (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      throw Exception('Lỗi tạo banner: $e');
    }
  }

  /// Cập nhật banner
  Future<BannerModel> updateBanner({
    required String bannerId,
    required String title,
    required String description,
    required String link,
    required int position,
    required bool isActive,
    File? imageFile,
    required String token,
  }) async {
    try {
      // Validate inputs
      if (token.isEmpty) {
        throw Exception('Token không hợp lệ');
      }

      // Check file size if provided
      if (imageFile != null) {
        if (!imageFile.existsSync()) {
          throw Exception('File ảnh không tồn tại');
        }
        final fileSizeInBytes = await imageFile.length();
        const maxSizeInBytes = 5 * 1024 * 1024;
        if (fileSizeInBytes > maxSizeInBytes) {
          throw Exception(
              'File quá lớn (tối đa 5MB, file hiện tại ${(fileSizeInBytes / 1024 / 1024).toStringAsFixed(2)}MB)');
        }
      }

      final request = http.MultipartRequest(
        'PUT',
        Uri.parse('${ApiRoutes.baseUrl}/banners/$bannerId'),
      );

      // Set headers
      request.headers['Authorization'] = 'Bearer $token';

      // Set fields
      request.fields['title'] = title.trim();
      request.fields['description'] = description.trim();
      request.fields['link'] = link.trim();
      request.fields['position'] = position.toString();
      request.fields['isActive'] = isActive.toString();

      // Add file if provided
      if (imageFile != null) {
        final mimeType = _determineMimeType(imageFile.path);
        request.files.add(
          await http.MultipartFile.fromPath(
            'image',
            imageFile.path,
            contentType: _getMimeType(mimeType),
          ),
        );
      }

      // Send request with timeout
      final streamResponse = await request.send().timeout(
            const Duration(seconds: 60),
            onTimeout: () => throw Exception('Upload timeout'),
          );

      final response = await http.Response.fromStream(streamResponse);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        return BannerModel.fromJson(jsonData as Map<String, dynamic>);
      } else if (response.statusCode == 401) {
        throw Exception('Token hết hạn, vui lòng đăng nhập lại');
      } else if (response.statusCode == 403) {
        throw Exception('Bạn không có quyền admin');
      } else if (response.statusCode == 404) {
        throw Exception('Banner không tồn tại');
      } else if (response.statusCode == 400) {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Lỗi yêu cầu không hợp lệ');
      } else {
        throw Exception(
            'Cập nhật banner thất bại (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      throw Exception('Lỗi cập nhật banner: $e');
    }
  }

  /// Xóa banner
  Future<void> deleteBanner(String bannerId, String token) async {
    try {
      if (token.isEmpty) {
        throw Exception('Token không hợp lệ');
      }

      final response = await http.delete(
        Uri.parse('${ApiRoutes.baseUrl}/banners/$bannerId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Kết nối timeout'),
      );

      if (response.statusCode == 200) {
        // Success
        return;
      } else if (response.statusCode == 401) {
        throw Exception('Token hết hạn, vui lòng đăng nhập lại');
      } else if (response.statusCode == 403) {
        throw Exception('Bạn không có quyền admin');
      } else if (response.statusCode == 404) {
        throw Exception('Banner không tồn tại');
      } else {
        final error = jsonDecode(response.body);
        throw Exception(
            error['message'] ?? 'Xóa banner thất bại: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Lỗi xóa banner: $e');
    }
  }
}
