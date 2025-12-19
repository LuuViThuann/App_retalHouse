import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter/foundation.dart';
import '../models/rental.dart';
import '../config/api_routes.dart';

// 🔥 CUSTOM EXCEPTION CHO PAYMENT REQUIRED
class PaymentRequiredException implements Exception {
  final String message;
  final Map<String, dynamic>? paymentInfo;

  PaymentRequiredException({
    required this.message,
    this.paymentInfo,
  });

  @override
  String toString() => message;
}

class ApiService {
  final auth.FirebaseAuth _auth = auth.FirebaseAuth.instance;

  Future<String?> _getIdToken() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return await user.getIdToken();
  }

  Future<List<Rental>> getRentals() async {
    final token = await _getIdToken();
    if (token == null) {
      throw Exception('Không tìm thấy token. Vui lòng đăng nhập lại.');
    }
    final headers = {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    };
    debugPrint('📤 Get rentals headers: $headers');
    final response = await http.get(
      Uri.parse(ApiRoutes.rentals),
      headers: headers,
    );
    debugPrint('📥 Get rentals response: status=${response.statusCode}');

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Rental.fromJson(json)).toList();
    } else {
      throw Exception('Không thể tải danh sách bài đăng: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> searchRentals({
    String? search,
    double? minPrice,
    double? maxPrice,
    List<String>? propertyTypes,
    String? status,
    int page = 1,
    int limit = 10,
  }) async {
    final token = await _getIdToken();
    if (token == null) {
      throw Exception('Không tìm thấy token. Vui lòng đăng nhập lại.');
    }

    final queryParameters = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (search != null && search.isNotEmpty) queryParameters['search'] = search;
    if (minPrice != null) queryParameters['minPrice'] = minPrice.toString();
    if (maxPrice != null) queryParameters['maxPrice'] = maxPrice.toString();
    if (propertyTypes != null && propertyTypes.isNotEmpty) {
      queryParameters['propertyType'] = propertyTypes.join(',');
    }
    if (status != null && status.isNotEmpty) queryParameters['status'] = status;

    final uri = Uri.parse('${ApiRoutes.rentals}/search')
        .replace(queryParameters: queryParameters);
    final headers = {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    };
    debugPrint('📤 Search rentals headers: $headers');
    final response = await http.get(uri, headers: headers);
    debugPrint('📥 Search rentals response: status=${response.statusCode}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map && data.containsKey('rentals')) {
        return {
          'rentals': (data['rentals'] as List)
              .map((json) => Rental.fromJson(json))
              .toList(),
          'total': data['total'] as int,
          'page': data['page'] as int,
          'pages': data['pages'] as int,
        };
      } else {
        throw Exception('Unexpected response format: ${response.body}');
      }
    } else {
      throw Exception('Không thể tải danh sách bài đăng: ${response.body}');
    }
  }

  Future<List<String>> getSearchHistory() async {
    final token = await _getIdToken();
    if (token == null) {
      throw Exception('Không tìm thấy token. Vui lòng đăng nhập lại.');
    }

    final headers = {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    };
    debugPrint('📤 Search history headers: $headers');
    final response = await http.get(
      Uri.parse('${ApiRoutes.baseUrl}/search-history'),
      headers: headers,
    );
    debugPrint('📥 Search history response: status=${response.statusCode}');

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<String>();
    } else {
      throw Exception('Không thể tải lịch sử tìm kiếm: ${response.body}');
    }
  }

  Future<void> deleteSearchHistoryItem(String query) async {
    final token = await _getIdToken();
    if (token == null) {
      throw Exception('Không tìm thấy token. Vui lòng đăng nhập lại.');
    }

    final headers = {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    debugPrint('📤 Delete search history item headers: $headers');
    final response = await http.delete(
      Uri.parse('${ApiRoutes.baseUrl}/search-history'),
      headers: headers,
      body: jsonEncode({'query': query}),
    );
    debugPrint('📥 Delete search history item response: status=${response.statusCode}');

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Không thể xóa mục lịch sử tìm kiếm: ${response.body}');
    }
  }

  Future<void> clearSearchHistory() async {
    final token = await _getIdToken();
    if (token == null) {
      throw Exception('Không tìm thấy token. Vui lòng đăng nhập lại.');
    }

    final headers = {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    };
    debugPrint('📤 Clear search history headers: $headers');
    final response = await http.delete(
      Uri.parse('${ApiRoutes.baseUrl}/search-history/all'),
      headers: headers,
    );
    debugPrint('📥 Clear search history response: status=${response.statusCode}');

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(
          'Không thể xóa toàn bộ lịch sử tìm kiếm: ${response.body}');
    }
  }

  // ============================================
  // 🔥 CREATE RENTAL WITH PAYMENT INTEGRATION
  // ============================================
  Future<Rental> createRental(
      Rental rental,
      List<String> imagePaths, {
        List<String> videoPaths = const [],
      }) async {
    try {
      final token = await _getIdToken();
      if (token == null) {
        throw Exception('Không tìm thấy token. Vui lòng đăng nhập lại.');
      }

      var request = http.MultipartRequest('POST', Uri.parse(ApiRoutes.rentals));
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      debugPrint('📤 Create rental headers: ${request.headers}');

      // Add text fields
      request.fields['title'] = rental.title;
      request.fields['price'] = rental.price.toString();
      request.fields['areaTotal'] = rental.area['total'].toString();
      request.fields['areaLivingRoom'] = rental.area['livingRoom'].toString();
      request.fields['areaBedrooms'] = rental.area['bedrooms'].toString();
      request.fields['areaBathrooms'] = rental.area['bathrooms'].toString();
      request.fields['locationShort'] = rental.location['short'];
      request.fields['locationFullAddress'] = rental.location['fullAddress'];

      // Add coordinates if available
      if (rental.location['latitude'] != null) {
        request.fields['latitude'] = rental.location['latitude'].toString();
      }
      if (rental.location['longitude'] != null) {
        request.fields['longitude'] = rental.location['longitude'].toString();
      }

      request.fields['propertyType'] = rental.propertyType;
      request.fields['furniture'] = rental.furniture.join(',');
      request.fields['amenities'] = rental.amenities.join(',');
      request.fields['surroundings'] = rental.surroundings.join(',');
      request.fields['rentalTermsMinimumLease'] =
      rental.rentalTerms['minimumLease'];
      request.fields['rentalTermsDeposit'] =
          rental.rentalTerms['deposit'].toString();
      request.fields['rentalTermsPaymentMethod'] =
      rental.rentalTerms['paymentMethod'];
      request.fields['rentalTermsRenewalTerms'] =
      rental.rentalTerms['renewalTerms'];
      request.fields['contactInfoName'] = rental.contactInfo['name'];
      request.fields['contactInfoPhone'] = rental.contactInfo['phone'];
      request.fields['contactInfoAvailableHours'] =
      rental.contactInfo['availableHours'];
      request.fields['status'] = rental.status;

      // 🔥 THÊM PAYMENT TRANSACTION CODE
      if (rental.paymentTransactionCode != null &&
          rental.paymentTransactionCode!.isNotEmpty) {
        request.fields['paymentTransactionCode'] = rental.paymentTransactionCode!;
        debugPrint('💳 Payment transaction code: ${rental.paymentTransactionCode}');
      } else {
        debugPrint('⚠️ Warning: No payment transaction code provided');
      }

      // Upload images
      for (var imagePath in imagePaths) {
        try {
          request.files.add(await http.MultipartFile.fromPath(
            'media',
            imagePath,
            contentType: MediaType('image', 'jpeg'),
          ));
          debugPrint('📤 Added image: $imagePath');
        } catch (e) {
          debugPrint('❌ Error adding image: $e');
          throw Exception('Không thể tải ảnh: $e');
        }
      }

      // Upload videos
      for (var path in videoPaths) {
        if (path.isNotEmpty) {
          try {
            request.files.add(await http.MultipartFile.fromPath(
              'media',
              path,
              contentType: MediaType('video', 'mp4'),
            ));
            debugPrint('📹 Added video: $path');
          } catch (e) {
            debugPrint('❌ Error adding video: $e');
            throw Exception('Không thể tải video: $e');
          }
        }
      }

      debugPrint('📤 Total files to upload: ${request.files.length}');
      debugPrint('📤 File fields: ${request.files.map((f) => f.field).toList()}');

      final response = await request.send();
      final responseBody = await http.Response.fromStream(response);

      debugPrint('📥 Response status: ${response.statusCode}');
      debugPrint('📥 Response body: ${responseBody.body}');

      if (response.statusCode == 201) {
        // ✅ Success - Rental created
        final responseData = jsonDecode(responseBody.body);
        final createdRental = Rental.fromJson(responseData['rental']);

        debugPrint('✅ Rental created successfully');
        debugPrint('✅ Rental ID: ${createdRental.id}');

        if (responseData.containsKey('paymentInfo')) {
          debugPrint('✅ Payment info: ${responseData['paymentInfo']}');
        }

        return createdRental;
      }
      else if (response.statusCode == 402) {
        // 🔥 Payment Required - Backend yêu cầu thanh toán
        debugPrint('⚠️ Payment required (402)');
        final errorData = jsonDecode(responseBody.body);
        throw PaymentRequiredException(
          message: errorData['message'] ?? 'Vui lòng thanh toán phí đăng bài trước khi đăng bài',
          paymentInfo: errorData['paymentRequired'],
        );
      }
      else if (response.statusCode == 400) {
        // ❌ Bad Request
        final errorData = jsonDecode(responseBody.body);
        final errorMessage = errorData['message'] ?? 'Dữ liệu không hợp lệ';
        debugPrint('❌ Bad request: $errorMessage');
        throw Exception(errorMessage);
      }
      else if (response.statusCode == 401 || response.statusCode == 403) {
        // ❌ Unauthorized
        debugPrint('❌ Unauthorized: ${response.statusCode}');
        throw Exception('Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.');
      }
      else {
        // ❌ Other errors
        final errorData = jsonDecode(responseBody.body);
        final errorMessage = errorData['message'] ?? 'Không thể tạo bài đăng';
        debugPrint('❌ Error: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      debugPrint('❌ Exception in createRental: $e');

      // Re-throw PaymentRequiredException as-is
      if (e is PaymentRequiredException) {
        rethrow;
      }

      // Wrap other exceptions
      if (e.toString().contains('Failed to geocode address')) {
        throw Exception('Địa chỉ không hợp lệ. Vui lòng kiểm tra lại hoặc chọn từ bản đồ.');
      }

      rethrow;
    }
  }
}