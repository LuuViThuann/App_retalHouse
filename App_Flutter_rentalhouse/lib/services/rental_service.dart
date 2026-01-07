import 'dart:async';

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
  // ✅ Timeout configuration
  static const Duration _defaultTimeout = Duration(seconds: 30);
  static const Duration _longTimeout = Duration(seconds: 60);
  static const int _maxRetries = 3;

  // ✅ HTTP Client với connection pooling
  static final http.Client _client = http.Client();

  // ✅ Circuit breaker pattern
  static DateTime? _lastFailure;
  static int _consecutiveFailures = 0;
  static const int _failureThreshold = 5;
  static const Duration _recoveryTime = Duration(minutes: 1);

  bool _isCircuitOpen() {
    if (_consecutiveFailures >= _failureThreshold && _lastFailure != null) {
      final timeSinceLastFailure = DateTime.now().difference(_lastFailure!);
      if (timeSinceLastFailure < _recoveryTime) {
        return true;
      } else {
        // Reset circuit breaker
        _consecutiveFailures = 0;
        _lastFailure = null;
      }
    }
    return false;
  }

  void _recordSuccess() {
    _consecutiveFailures = 0;
    _lastFailure = null;
  }

  void _recordFailure() {
    _consecutiveFailures++;
    _lastFailure = DateTime.now();
  }

  // ✅ Retry with exponential backoff
  Future<T> _retryRequest<T>(
      Future<T> Function() operation, {
        int maxRetries = _maxRetries,
        Duration initialDelay = const Duration(milliseconds: 500),
      }) async {
    int attempt = 0;
    Duration delay = initialDelay;

    while (attempt < maxRetries) {
      try {
        if (_isCircuitOpen()) {
          throw Exception('Service temporarily unavailable. Please try again later.');
        }

        final result = await operation();
        _recordSuccess();
        return result;
      } catch (e) {
        attempt++;
        _recordFailure();

        if (attempt >= maxRetries) {
          debugPrint('❌ Max retries ($maxRetries) reached: $e');
          rethrow;
        }

        // Exponential backoff
        debugPrint('⚠️ Retry attempt $attempt/$maxRetries after ${delay.inMilliseconds}ms');
        await Future.delayed(delay);
        delay *= 2; // Double the delay each time
      }
    }

    throw Exception('Max retries exceeded');
  }

  // ✅ Safe request wrapper with proper error handling
  Future<http.Response> _safeRequest(
      Future<http.Response> Function() request, {
        Duration? timeout,
      }) async {
    try {
      final response = await request().timeout(
        timeout ?? _defaultTimeout,
        onTimeout: () {
          throw TimeoutException('Request timeout after ${timeout?.inSeconds ?? _defaultTimeout.inSeconds}s');
        },
      );
      return response;
    } on SocketException catch (e) {
      throw Exception('Không có kết nối mạng: ${e.message}');
    } on TimeoutException catch (e) {
      throw Exception('Timeout: ${e.message}');
    } on http.ClientException catch (e) {
      throw Exception('Lỗi kết nối: ${e.message}');
    } catch (e) {
      throw Exception('Lỗi không xác định: $e');
    }
  }

  Future<List<Rental>> fetchRentals({
    int page = 1,
    int limit = 10,
    String? token,
  }) async {
    return _retryRequest(() async {
      final uri = Uri.parse('${ApiRoutes.baseUrl}/rentals?page=$page&limit=$limit');
      final headers = {
        'Content-Type': 'application/json',
        'Connection': 'keep-alive', // ✅ Keep connection alive
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final response = await _safeRequest(
            () => _client.get(uri, headers: headers),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> rentalsData = data['rentals'] ?? [];
        return rentalsData.map((json) => Rental.fromJson(json)).toList();
      } else {
        throw Exception('Failed to fetch rentals: Status ${response.statusCode}');
      }
    });
  }

  Future<Rental?> fetchRentalById({
    required String rentalId,
    String? token,
  }) async {
    try {
      return await _retryRequest(() async {
        final uri = Uri.parse('${ApiRoutes.baseUrl}/rentals/$rentalId');
        final headers = {
          'Content-Type': 'application/json',
          'Connection': 'keep-alive',
          if (token != null) 'Authorization': 'Bearer $token',
        };

        final response = await _safeRequest(
              () => _client.get(uri, headers: headers),
        );

        if (response.statusCode == 200) {
          return Rental.fromJson(jsonDecode(response.body));
        } else {
          debugPrint('⚠️ Error fetching rental $rentalId: Status ${response.statusCode}');
          return null;
        }
      });
    } catch (e) {
      debugPrint('❌ Exception fetching rental $rentalId: $e');
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
    int page = 1,
    int limit = 10,
  }) async {
    return _retryRequest(() async {
      // 🔥 BUILD QUERY PARAMETERS - CẬP NHẬT
      final queryParams = {
        'radius': radius.toString(),
        'limit': limit.toString(),
        'page': page.toString(),
      };

      // Chỉ thêm minPrice nếu nó khác null
      if (minPrice != null && minPrice > 0) {
        queryParams['minPrice'] = minPrice.toString();
        debugPrint('📌 Adding minPrice: $minPrice');
      }

      // Chỉ thêm maxPrice nếu nó khác null
      if (maxPrice != null && maxPrice > 0) {
        queryParams['maxPrice'] = maxPrice.toString();
        debugPrint('📌 Adding maxPrice: $maxPrice');
      }

      final uri = Uri.parse('${ApiRoutes.baseUrl}/rentals/nearby/$rentalId')
          .replace(queryParameters: queryParams);

      final headers = {
        'Content-Type': 'application/json',
        'Connection': 'keep-alive',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      debugPrint('🔍 Fetching nearby rentals:');
      debugPrint('   URL: $uri');
      debugPrint('   Radius: ${radius}km');
      debugPrint('   Price range: ${minPrice ?? "Any"} - ${maxPrice ?? "Any"}');

      final response = await _safeRequest(
            () => _client.get(uri, headers: headers),
        timeout: _longTimeout,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        debugPrint('📊 Response status: ${response.statusCode}');
        debugPrint('   Applied filters: ${data['appliedFilters']}');
        debugPrint('   Search method: ${data['searchMethod']}');

        final List<dynamic> rentalsData = data['rentals'] ?? [];

        final List<Rental> rentals = rentalsData
            .map((json) {
          try {
            return _parseRentalJson(json);
          } catch (e) {
            debugPrint('⚠️ Error parsing rental: $e');
            return null;
          }
        })
            .whereType<Rental>()
            .toList();

        debugPrint('✅ Parsed ${rentals.length} nearby rentals');

        return {
          'rentals': rentals,
          'warning': data['warning'],
          'searchMethod': data['searchMethod'],
          'total': data['total'] ?? rentals.length,
          'radiusKm': data['radiusKm'] ?? radius,
          'page': page,
          'hasMore': rentals.length >= limit,
          'appliedFilters': data['appliedFilters'], // 🔥 THÊM: Feedback filters
        };
      } else {
        throw Exception('Failed to fetch nearby rentals: ${response.statusCode}');
      }
    });
  }

  // ✅ Helper method to parse rental JSON safely
  Rental _parseRentalJson(Map<String, dynamic> json) {
    // Handle coordinates from array
    if (json['coordinates'] != null && json['coordinates'] is List) {
      final coords = json['coordinates'] as List;
      if (coords.length >= 2) {
        json['location'] = json['location'] ?? {};
        json['location']['longitude'] = coords[0];
        json['location']['latitude'] = coords[1];
      }
    }

    // Initialize area with defaults
    json['area'] = {
      'total': (json['area']?['total'] ?? 0).toDouble(),
      'livingRoom': (json['area']?['livingRoom'] ?? 0).toDouble(),
      'bedrooms': (json['area']?['bedrooms'] ?? 0).toDouble(),
      'bathrooms': (json['area']?['bathrooms'] ?? 0).toDouble(),
    };

    // Initialize contactInfo with defaults
    json['contactInfo'] = {
      'name': json['contactInfo']?['name'] ?? 'Chủ nhà',
      'phone': json['contactInfo']?['phone'] ?? 'Không có',
      'availableHours': json['contactInfo']?['availableHours'] ?? '',
    };

    // Initialize rentalTerms with defaults
    json['rentalTerms'] = {
      'minimumLease': json['rentalTerms']?['minimumLease'] ?? 'Liên hệ',
      'deposit': json['rentalTerms']?['deposit'] ?? 'Liên hệ',
      'paymentMethod': json['rentalTerms']?['paymentMethod'] ?? 'Liên hệ',
      'renewalTerms': json['rentalTerms']?['renewalTerms'] ?? 'Liên hệ',
    };

    // Initialize arrays with defaults
    json['furniture'] = json['furniture'] ?? [];
    json['amenities'] = json['amenities'] ?? [];
    json['surroundings'] = json['surroundings'] ?? [];
    json['images'] = json['images'] ?? [];
    json['videos'] = json['videos'] ?? [];

    // Ensure location has all required fields
    json['location'] = {
      'short': json['location']?['short'] ?? '',
      'fullAddress': json['location']?['fullAddress'] ?? '',
      'coordinates': {
        'type': 'Point',
        'coordinates': [
          (json['location']?['longitude'] ?? 0).toDouble(),
          (json['location']?['latitude'] ?? 0).toDouble(),
        ],
      },
    };

    json['status'] = json['status'] ?? 'available';
    json['userId'] = json['userId'] ?? '';

    return Rental.fromJson(json);
  }

  // ✅ Cleanup method - call this in app dispose
  static void dispose() {
    _client.close();
  }
}