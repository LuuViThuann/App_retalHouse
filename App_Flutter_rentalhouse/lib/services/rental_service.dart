import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/api_routes.dart';
import '../models/rental.dart';
import '../services/auth_service.dart';
import '../viewmodels/vm_auth.dart';

class RentalService {
  Future<List<Rental>> fetchRentals({
    int page = 1,
    int limit = 10,
    String? token,
  }) async {
    try {
      final uri =
          Uri.parse('${ApiRoutes.baseUrl}/rentals?page=$page&limit=$limit');
      final headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> rentalsData = data['rentals'] ?? [];
        return rentalsData.map((json) => Rental.fromJson(json)).toList();
      } else {
        throw Exception(
            'Failed to fetch rentals: Status ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error fetching rentals: $e');
      throw Exception('Lỗi khi tải danh sách nhà trọ: $e');
    }
  }

  Future<Rental?> fetchRentalById({
    required String rentalId,
    String? token,
  }) async {
    try {
      final uri = Uri.parse('${ApiRoutes.baseUrl}/rentals/$rentalId');
      final headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        return Rental.fromJson(jsonDecode(response.body));
      } else {
        debugPrint(
            'Error fetching rental $rentalId: Status ${response.statusCode}, Body: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Exception fetching rental $rentalId: $e');
      return null;
    }
  }

  Future<void> fetchRentalDetails({
    required Rental rental,
    required Function(double, int) onSuccess,
    required Function(String) onError,
    required BuildContext context,
    String? token,
  }) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final response = await http.get(
        Uri.parse('${ApiRoutes.baseUrl}/rentals/${rental.id}'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final averageRating =
            (data['averageRating'] as num?)?.toDouble() ?? 0.0;
        final reviewCount = (data['comments'] as List<dynamic>?)?.length ?? 0;
        onSuccess(averageRating, reviewCount);
      } else {
        onError('Không thể tải thông tin chi tiết: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching rental details: $e');
      onError('Lỗi khi tải thông tin chi tiết: $e');
    }
  }

  Future<void> checkFavoriteStatus({
    required Rental rental,
    required Function(bool) onSuccess,
    required Function(String) onError,
    required BuildContext context,
  }) async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    if (authViewModel.currentUser == null) {
      onSuccess(false);
      return;
    }

    try {
      final token = await AuthService().getIdToken();
      if (token == null) {
        onSuccess(false);
        return;
      }

      final response = await http.get(
        Uri.parse('${ApiRoutes.baseUrl}/favorites'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> favorites = jsonDecode(response.body);
        final isFavorited = favorites
            .any((favorite) => favorite['rentalId']['_id'] == rental.id);
        onSuccess(isFavorited);
      } else {
        onError(
            'Không thể kiểm tra trạng thái yêu thích: ${response.statusCode}');
        onSuccess(false);
      }
    } catch (e) {
      debugPrint('Error checking favorite status: $e');
      onError('Lỗi khi kiểm tra trạng thái yêu thích: $e');
      onSuccess(false);
    }
  }

  Future<void> toggleFavorite({
    required Rental rental,
    required bool isFavorite,
    required Function(bool) onSuccess,
    required Function(String) onError,
    required BuildContext context,
  }) async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    if (authViewModel.currentUser == null) {
      onError('Vui lòng đăng nhập để thêm vào yêu thích');
      return;
    }

    try {
      final token = await AuthService().getIdToken();
      if (token == null) {
        throw Exception('Không tìm thấy token xác thực');
      }

      final url = isFavorite
          ? '${ApiRoutes.baseUrl}/favorites/${rental.id}'
          : '${ApiRoutes.baseUrl}/favorites';
      final response = isFavorite
          ? await http.delete(
              Uri.parse(url),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
            )
          : await http.post(
              Uri.parse(url),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
              body: jsonEncode({'rentalId': rental.id}),
            );

      if (response.statusCode == 200 || response.statusCode == 201) {
        onSuccess(!isFavorite);
      } else {
        throw Exception(
            'Không thể cập nhật yêu thích: ${response.statusCode}, ${response.body}');
      }
    } catch (e) {
      debugPrint('Error toggling favorite: $e');
      onError('Lỗi khi cập nhật yêu thích: $e');
    }
  }

  Future<void> createRental({
    required Rental rental,
    required List<String> imagePaths,
    required String token,
    required Function(Rental) onSuccess,
    required Function(String) onError,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiRoutes.baseUrl}/rentals'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          ...rental.toJson(),
          'images': imagePaths,
          'latitude': rental.location['latitude'],
          'longitude': rental.location['longitude'],
        }),
      );

      if (response.statusCode == 201) {
        final createdRental = Rental.fromJson(jsonDecode(response.body));
        onSuccess(createdRental);
      } else {
        throw Exception(
            'Không thể tạo nhà trọ: ${response.statusCode}, ${response.body}');
      }
    } catch (e) {
      debugPrint('Error creating rental: $e');
      onError('Lỗi khi tạo nhà trọ: $e');
    }
  }

  Future<void> updateRental({
    required Rental rental,
    required String token,
    required Function(Rental) onSuccess,
    required Function(String) onError,
  }) async {
    try {
      final response = await http.patch(
        Uri.parse('${ApiRoutes.baseUrl}/rentals/${rental.id}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          ...rental.toJson(),
          'latitude': rental.location['latitude'],
          'longitude': rental.location['longitude'],
        }),
      );

      if (response.statusCode == 200) {
        final updatedRental = Rental.fromJson(jsonDecode(response.body));
        onSuccess(updatedRental);
      } else {
        throw Exception(
            'Không thể cập nhật nhà trọ: ${response.statusCode}, ${response.body}');
      }
    } catch (e) {
      debugPrint('Error updating rental: $e');
      onError('Lỗi khi cập nhật nhà trọ: $e');
    }
  }

  // Cập nhật method fetchNearbyRentals trong RentalService
  Future<Map<String, dynamic>> fetchNearbyRentals({
    required String rentalId,
    double radius = 10.0,
    String? token,
  }) async {
    try {
      final uri = Uri.parse(
          '${ApiRoutes.baseUrl}/rentals/nearby/$rentalId?radius=$radius&limit=10');
      final headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Log response để debug
        debugPrint('Nearby rentals API response: ${response.body}');

        final List<dynamic> rentalsData = data['rentals'] ?? [];
        final String? warning = data['warning'];
        final String? searchMethod = data['searchMethod'];

        if (warning != null) {
          debugPrint('Warning from server: $warning');
        }

        // Xử lý dữ liệu rentals an toàn hơn
        final List<Rental> rentals = rentalsData
            .map((json) {
              try {
                // Đảm bảo coordinates được xử lý đúng
                if (json['coordinates'] != null &&
                    json['coordinates'] is List) {
                  final coords = json['coordinates'] as List;
                  if (coords.length >= 2) {
                    // Cập nhật location với coordinates
                    json['location'] = json['location'] ?? {};
                    json['location']['longitude'] = coords[0];
                    json['location']['latitude'] = coords[1];
                  }
                }

                return Rental.fromJson(json);
              } catch (e) {
                debugPrint('Error parsing rental: $e, JSON: $json');
                return null;
              }
            })
            .where((rental) => rental != null)
            .cast<Rental>()
            .toList();

        return {
          'rentals': rentals,
          'warning': warning,
          'searchMethod': searchMethod,
          'total': data['total'] ?? rentals.length,
          'radiusKm': data['radiusKm'] ?? radius,
        };
      } else {
        throw Exception(
            'Failed to fetch nearby rentals: ${response.statusCode}, ${response.body}');
      }
    } catch (e) {
      debugPrint('Error fetching nearby rentals: $e');
      throw Exception('Lỗi khi tải nhà trọ gần đây: $e');
    }
  }
}
