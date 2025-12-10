import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
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

  // ✅ Cập nhật createRental để gửi ảnh và video
  Future<void> createRental({
    required Rental rental,
    required List<String> imagePaths,
    required List<String> videoPaths, // ✅ Add video paths
    required String token,
    required Function(Rental) onSuccess,
    required Function(String) onError,
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiRoutes.baseUrl}/rentals'),
      );

      // Add headers
      request.headers['Authorization'] = 'Bearer $token';

      // Add text fields
      request.fields['title'] = rental.title;
      request.fields['price'] = rental.price.toString();
      request.fields['areaTotal'] = rental.area['total'].toString();
      request.fields['areaLivingRoom'] = (rental.area['livingRoom'] ?? 0).toString();
      request.fields['areaBedrooms'] = (rental.area['bedrooms'] ?? 0).toString();
      request.fields['areaBathrooms'] = (rental.area['bathrooms'] ?? 0).toString();
      request.fields['locationShort'] = rental.location['short'] ?? '';
      request.fields['locationFullAddress'] = rental.location['fullAddress'] ?? '';
      request.fields['latitude'] = (rental.location['latitude'] ?? 0.0).toString();
      request.fields['longitude'] = (rental.location['longitude'] ?? 0.0).toString();
      request.fields['propertyType'] = rental.propertyType;
      request.fields['furniture'] = rental.furniture.join(',');
      request.fields['amenities'] = rental.amenities.join(',');
      request.fields['surroundings'] = rental.surroundings.join(',');
      request.fields['rentalTermsMinimumLease'] = rental.rentalTerms['minimumLease'] ?? '';
      request.fields['rentalTermsDeposit'] = rental.rentalTerms['deposit'] ?? '';
      request.fields['rentalTermsPaymentMethod'] = rental.rentalTerms['paymentMethod'] ?? '';
      request.fields['rentalTermsRenewalTerms'] = rental.rentalTerms['renewalTerms'] ?? '';
      request.fields['contactInfoName'] = rental.contactInfo['name'] ?? '';
      request.fields['contactInfoPhone'] = rental.contactInfo['phone'] ?? '';
      request.fields['contactInfoAvailableHours'] = rental.contactInfo['availableHours'] ?? '';
      request.fields['status'] = rental.status;

      // ✅ Upload images
      for (var imagePath in imagePaths) {
        var file = await http.MultipartFile.fromPath('media', imagePath);
        request.files.add(file);
      }

      // ✅ Upload videos
      for (var videoPath in videoPaths) {
        var file = await http.MultipartFile.fromPath('media', videoPath);
        request.files.add(file);
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        final createdRental = Rental.fromJson(responseData['rental']);
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

  // ✅ Cập nhật updateRental để gửi ảnh và video
  Future<void> updateRental({
    required Rental rental,
    required String token,
    List<String>? newImagePaths, // ✅ New images to upload
    List<String>? newVideoPaths, // ✅ New videos to upload
    List<String>? removedMediaUrls, // ✅ URLs to remove
    required Function(Rental) onSuccess,
    required Function(String) onError,
  }) async {
    try {
      var request = http.MultipartRequest(
        'PATCH',
        Uri.parse('${ApiRoutes.baseUrl}/rentals/${rental.id}'),
      );

      request.headers['Authorization'] = 'Bearer $token';

      // Add text fields
      request.fields['title'] = rental.title;
      request.fields['price'] = rental.price.toString();
      request.fields['areaTotal'] = rental.area['total'].toString();
      request.fields['areaLivingRoom'] = (rental.area['livingRoom'] ?? 0).toString();
      request.fields['areaBedrooms'] = (rental.area['bedrooms'] ?? 0).toString();
      request.fields['areaBathrooms'] = (rental.area['bathrooms'] ?? 0).toString();
      request.fields['locationShort'] = rental.location['short'] ?? '';
      request.fields['locationFullAddress'] = rental.location['fullAddress'] ?? '';
      request.fields['latitude'] = (rental.location['latitude'] ?? 0.0).toString();
      request.fields['longitude'] = (rental.location['longitude'] ?? 0.0).toString();
      request.fields['propertyType'] = rental.propertyType;
      request.fields['furniture'] = rental.furniture.join(',');
      request.fields['amenities'] = rental.amenities.join(',');
      request.fields['surroundings'] = rental.surroundings.join(',');
      request.fields['rentalTermsMinimumLease'] = rental.rentalTerms['minimumLease'] ?? '';
      request.fields['rentalTermsDeposit'] = rental.rentalTerms['deposit'] ?? '';
      request.fields['rentalTermsPaymentMethod'] = rental.rentalTerms['paymentMethod'] ?? '';
      request.fields['rentalTermsRenewalTerms'] = rental.rentalTerms['renewalTerms'] ?? '';
      request.fields['contactInfoName'] = rental.contactInfo['name'] ?? '';
      request.fields['contactInfoPhone'] = rental.contactInfo['phone'] ?? '';
      request.fields['contactInfoAvailableHours'] = rental.contactInfo['availableHours'] ?? '';
      request.fields['status'] = rental.status;

      // ✅ Add removed media URLs
      if (removedMediaUrls != null && removedMediaUrls.isNotEmpty) {
        request.fields['removedMedia'] = jsonEncode(removedMediaUrls);
      }

      // ✅ Upload new images
      if (newImagePaths != null) {
        for (var imagePath in newImagePaths) {
          var file = await http.MultipartFile.fromPath('media', imagePath);
          request.files.add(file);
        }
      }

      // ✅ Upload new videos
      if (newVideoPaths != null) {
        for (var videoPath in newVideoPaths) {
          var file = await http.MultipartFile.fromPath('media', videoPath);
          request.files.add(file);
        }
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final updatedRental = Rental.fromJson(responseData['rental']);
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

  Future<Map<String, dynamic>> fetchNearbyRentals({
    required String rentalId,
    double radius = 10.0,
    double? minPrice,
    double? maxPrice,
    String? token,
  }) async {
    try {
      final queryParams = {
        'radius': radius.toString(),
        'limit': '10',
      };
      if (minPrice != null) queryParams['minPrice'] = minPrice.toString();
      if (maxPrice != null) queryParams['maxPrice'] = maxPrice.toString();

      final uri = Uri.parse('${ApiRoutes.baseUrl}/rentals/nearby/$rentalId')
          .replace(queryParameters: queryParams);
      final headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final List<dynamic> rentalsData = data['rentals'] ?? [];
        final String? warning = data['warning'];
        final String? searchMethod = data['searchMethod'];

        if (warning != null) {
          debugPrint('Warning from server: $warning');
        }

        final List<Rental> rentals = rentalsData
            .map((json) {
          try {
            if (json['coordinates'] != null &&
                json['coordinates'] is List) {
              final coords = json['coordinates'] as List;
              if (coords.length >= 2) {
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