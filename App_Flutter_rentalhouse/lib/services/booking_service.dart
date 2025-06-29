import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_routes.dart';
import '../models/booking.dart';
import '../models/rental.dart';
import '../services/auth_service.dart';

class BookingService {
  final AuthService _authService = AuthService();

  Future<String?> _getIdToken() async {
    return await _authService.getIdToken();
  }

  // Tạo booking mới
  Future<Booking> createBooking({
    required String rentalId,
    required Map<String, dynamic> customerInfo,
    required String preferredViewingTime,
    required Function(String) onError,
  }) async {
    try {
      final token = await _getIdToken();
      if (token == null) {
        throw Exception('Không tìm thấy token. Vui lòng đăng nhập lại.');
      }

      final response = await http.post(
        Uri.parse('${ApiRoutes.baseUrl}/bookings'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'rentalId': rentalId,
          'customerInfo': customerInfo,
          'preferredViewingTime': preferredViewingTime,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return Booking.fromJson(data['booking']);
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Tạo đặt chỗ thất bại');
      }
    } catch (e) {
      onError('Lỗi khi tạo đặt chỗ: $e');
      rethrow;
    }
  }

  // Lấy danh sách booking của người dùng
  Future<Map<String, dynamic>> getMyBookings({
    int page = 1,
    int limit = 10,
    String? status,
    required Function(String) onError,
  }) async {
    try {
      final token = await _getIdToken();
      if (token == null) {
        throw Exception('Không tìm thấy token. Vui lòng đăng nhập lại.');
      }

      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };
      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }

      final uri = Uri.parse('${ApiRoutes.baseUrl}/bookings/my-bookings')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final bookings = (data['bookings'] as List)
            .map((json) => Booking.fromJson(json))
            .toList();
        return {
          'bookings': bookings,
          'total': data['total'] ?? 0,
          'page': data['page'] ?? page,
          'pages': data['pages'] ?? 1,
        };
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(
            errorData['message'] ?? 'Lấy danh sách đặt chỗ thất bại');
      }
    } catch (e) {
      onError('Lỗi khi lấy danh sách đặt chỗ: $e');
      rethrow;
    }
  }

  // Lấy danh sách booking cho chủ nhà
  Future<Map<String, dynamic>> getRentalBookings({
    required String rentalId,
    int page = 1,
    int limit = 10,
    String? status,
    required Function(String) onError,
  }) async {
    try {
      final token = await _getIdToken();
      if (token == null) {
        throw Exception('Không tìm thấy token. Vui lòng đăng nhập lại.');
      }

      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };
      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }

      final uri = Uri.parse('${ApiRoutes.baseUrl}/bookings/rental/$rentalId')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final bookings = (data['bookings'] as List)
            .map((json) => Booking.fromJson(json))
            .toList();
        return {
          'bookings': bookings,
          'total': data['total'] ?? 0,
          'page': data['page'] ?? page,
          'pages': data['pages'] ?? 1,
        };
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(
            errorData['message'] ?? 'Lấy danh sách đặt chỗ thất bại');
      }
    } catch (e) {
      onError('Lỗi khi lấy danh sách đặt chỗ: $e');
      rethrow;
    }
  }

  // Cập nhật trạng thái booking (cho chủ nhà)
  Future<Booking> updateBookingStatus({
    required String bookingId,
    required String status,
    String? ownerNotes,
    required Function(String) onError,
  }) async {
    try {
      final token = await _getIdToken();
      if (token == null) {
        throw Exception('Không tìm thấy token. Vui lòng đăng nhập lại.');
      }

      final body = <String, dynamic>{
        'status': status,
      };
      if (ownerNotes != null) {
        body['ownerNotes'] = ownerNotes;
      }

      final response = await http.patch(
        Uri.parse('${ApiRoutes.baseUrl}/bookings/$bookingId/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Booking.fromJson(data['booking']);
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Cập nhật trạng thái thất bại');
      }
    } catch (e) {
      onError('Lỗi khi cập nhật trạng thái: $e');
      rethrow;
    }
  }

  // Hủy booking (cho khách hàng)
  Future<Booking> cancelBooking({
    required String bookingId,
    required Function(String) onError,
  }) async {
    try {
      final token = await _getIdToken();
      if (token == null) {
        throw Exception('Không tìm thấy token. Vui lòng đăng nhập lại.');
      }

      final response = await http.patch(
        Uri.parse('${ApiRoutes.baseUrl}/bookings/$bookingId/cancel'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Booking.fromJson(data['booking']);
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Hủy đặt chỗ thất bại');
      }
    } catch (e) {
      onError('Lỗi khi hủy đặt chỗ: $e');
      rethrow;
    }
  }

  // Lấy chi tiết booking
  Future<Booking> getBookingDetail({
    required String bookingId,
    required Function(String) onError,
  }) async {
    try {
      final token = await _getIdToken();
      if (token == null) {
        throw Exception('Không tìm thấy token. Vui lòng đăng nhập lại.');
      }

      final response = await http.get(
        Uri.parse('${ApiRoutes.baseUrl}/bookings/$bookingId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Booking.fromJson(data);
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(
            errorData['message'] ?? 'Lấy chi tiết đặt chỗ thất bại');
      }
    } catch (e) {
      onError('Lỗi khi lấy chi tiết đặt chỗ: $e');
      rethrow;
    }
  }

  // Xóa booking (chỉ cho booking đã hủy)
  Future<void> deleteBooking({
    required String bookingId,
    required Function(String) onError,
  }) async {
    try {
      final token = await _getIdToken();
      if (token == null) {
        throw Exception('Không tìm thấy token. Vui lòng đăng nhập lại.');
      }

      final response = await http.delete(
        Uri.parse('${ApiRoutes.baseUrl}/bookings/$bookingId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Xóa đặt chỗ thất bại');
      }
    } catch (e) {
      onError('Lỗi khi xóa đặt chỗ: $e');
      rethrow;
    }
  }
}
