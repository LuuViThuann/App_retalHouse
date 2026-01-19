import 'dart:async';

import 'package:flutter_rentalhouse/services/poi_service.dart';
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
  // Timeout configuration =========================================================
  static const Duration _defaultTimeout = Duration(seconds: 30);
  static const Duration _longTimeout = Duration(seconds: 60);
  static const int _maxRetries = 2;

  //  HTTP Client với connection pooling ========================================================
  static final http.Client _client = http.Client();

  //  Circuit breaker pattern ========================================================
  static DateTime? _lastFailure;
  static int _consecutiveFailures = 0;
  static const int _failureThreshold = 5;
  static const Duration _recoveryTime = Duration(minutes: 1);

  // Kiểm tra trạng thái circuit breaker ========================================================
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

  // Ghi nhận thành công và thất bại ========================================================
  void _recordSuccess() {
    _consecutiveFailures = 0;
    _lastFailure = null;
  }

  // Ghi nhận thất bại ========================================================
  void _recordFailure() {
    _consecutiveFailures++;
    _lastFailure = DateTime.now();
  }

  //  Retry with exponential backoff ========================================================
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
          debugPrint(' Max retries ($maxRetries) reached: $e');
          rethrow;
        }

        // Exponential backoff
        debugPrint(' Retry attempt $attempt/$maxRetries after ${delay.inMilliseconds}ms');
        await Future.delayed(delay);
        delay *= 2; // Double the delay each time
      }
    }

    throw Exception('Max retries exceeded');
  }

  //  Safe request wrapper with proper error handling =========================================================
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

  // Fetch rentals with pagination ========================================================
  Future<List<Rental>> fetchRentals({
    int page = 1,
    int limit = 10,
    String? token,
  }) async {
    return _retryRequest(() async {
      final uri = Uri.parse('${ApiRoutes.baseUrl}/rentals?page=$page&limit=$limit');
      final headers = {
        'Content-Type': 'application/json',
        'Connection': 'keep-alive', // Keep connection alive
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

  // Fetch rental by ID ========================================================
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
          debugPrint(' Error fetching rental $rentalId: Status ${response.statusCode}');
          return null;
        }
      });
    } catch (e) {
      debugPrint(' Exception fetching rental $rentalId: $e');
      return null;
    }
  }

// Fetch rental details (average rating and review count) ========================================================
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

  // Kiểm tra trạng thái yêu thích ========================================================
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

  // Chuyển đổi trạng thái yêu thích ========================================================
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

  //  Cập nhật createRental để gửi ảnh và video =========================================================
  Future<void> createRental({
    required Rental rental,
    required List<String> imagePaths,
    required List<String> videoPaths, //  Add video paths
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

      //  Upload images
      for (var imagePath in imagePaths) {
        var file = await http.MultipartFile.fromPath('media', imagePath);
        request.files.add(file);
      }

      //  Upload videos
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

  //  Cập nhật updateRental để gửi ảnh và video =========================================================
  Future<void> updateRental({
    required Rental rental,
    required String token,
    List<String>? newImagePaths,
    List<String>? newVideoPaths,
    List<String>? removedMediaUrls,
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

      //  Add removed media URLs
      if (removedMediaUrls != null && removedMediaUrls.isNotEmpty) {
        request.fields['removedMedia'] = jsonEncode(removedMediaUrls);
      }

      //  Upload new images
      if (newImagePaths != null) {
        for (var imagePath in newImagePaths) {
          var file = await http.MultipartFile.fromPath('media', imagePath);
          request.files.add(file);
        }
      }

      //  Upload new videos
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
// Tìm kiếm nhà trọ gần vị trí hiện tại ========================================================
  Future<Map<String, dynamic>> fetchNearbyFromLocation({
    required double latitude,
    required double longitude,
    double radius = 10.0,
    double? minPrice,
    double? maxPrice,
    String? token,
    int page = 1,
    int limit = 10,
  }) async {
    //  CLIENT-SIDE VALIDATION
    if (latitude.abs() > 90 || longitude.abs() > 180) {
      throw Exception(
          'Tọa độ không hợp lệ: latitude=$latitude, longitude=$longitude'
      );
    }

    if (radius <= 0 || radius > 100) {
      throw Exception('Bán kính phải từ 0-100 km, nhận được: $radius');
    }

    return _retryRequest(
          () async {
        //  Build URL using ApiRoutes
        final url = ApiRoutes.nearbyFromLocation(
          latitude: latitude,
          longitude: longitude,
          radius: radius,
          page: page,
          limit: limit,
          minPrice: minPrice,
          maxPrice: maxPrice,
        );

        final uri = Uri.parse(url);

        final headers = {
          'Content-Type': 'application/json',
          'Connection': 'keep-alive',
          if (token != null) 'Authorization': 'Bearer $token',
        };

        debugPrint('🔍 [NEARBY-FROM-LOCATION] Requesting:');
        debugPrint('   Coords: ($latitude, $longitude)');
        debugPrint('   Radius: ${radius}km');
        debugPrint('   Prices: ${minPrice?.toStringAsFixed(0) ?? "Any"} - ${maxPrice?.toStringAsFixed(0) ?? "Any"}');

        final response = await _safeRequest(
              () => _client.get(uri, headers: headers),
          timeout: const Duration(seconds: 60), // 60s timeout cho geospatial query
        );

        //  HANDLE RESPONSES
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);

          debugPrint(' [NEARBY-FROM-LOCATION] Success');
          debugPrint('   Status: ${response.statusCode}');
          debugPrint('   Search method: ${data['searchMethod']}');
          debugPrint('   Found: ${data['rentals']?.length ?? 0} rentals');

          final List<dynamic> rentalsData = data['rentals'] ?? [];
          final List<Rental> rentals = rentalsData
              .map((json) {
            try {
              return _parseRentalJson(json);
            } catch (e) {
              debugPrint(' Error parsing rental: $e');
              return null;
            }
          })
              .whereType<Rental>()
              .toList();

          //  Return tất cả info (bao gồm warning từ backend) ========================================================
          return {
            'rentals': rentals,
            'warning': data['warning'],
            'searchMethod': data['searchMethod'],
            'total': data['total'] ?? rentals.length,
            'radiusKm': data['radiusKm'] ?? radius,
            'page': data['page'] ?? page,
            'hasMore': (data['page'] ?? page) < (data['pages'] ?? 1),
            'appliedFilters': data['appliedFilters'],
          };
        } else if (response.statusCode == 400) {
          //  Bad request - validation error
          final errorData = jsonDecode(response.body);
          throw Exception('Yêu cầu không hợp lệ: ${errorData['message']}');
        } else if (response.statusCode == 500) {
          // Server error - need to check backend logs
          final errorData = jsonDecode(response.body);
          debugPrint(' Server error details: ${errorData['error']}');
          debugPrint(' Hint: ${errorData['hint']}');

          // Provide helpful message
          throw Exception(
              'Lỗi máy chủ: ${errorData['message']}. '
                  'Vui lòng thử lại sau hoặc liên hệ admin.'
          );
        } else {
          throw Exception(
              'Failed to fetch nearby rentals: Status ${response.statusCode}'
          );
        }
      },
      maxRetries: 2, //  Fewer retries for faster feedback
    );
  }
// Tìm kiếm nhà trọ gần một nhà trọ cụ thể ========================================================
  Future<Map<String, dynamic>> fetchNearbyRentals({
    required String rentalId,
    double radius = 10.0,
    double? minPrice,
    double? maxPrice,
    String? token,
    int page = 1,
    int limit = 10,
  }) async {
    // CHECK: If rentalId starts with 'current_location_', it's invalid
    if (rentalId.startsWith('current_location_')) {
      throw Exception('Invalid rental ID for nearby search. Use fetchNearbyFromLocation instead.');
    }

    return _retryRequest(() async {
      //  SỬ DỤNG ApiRoutes
      final url = ApiRoutes.nearbyRentals(
        rentalId: rentalId,
        radius: radius,
        page: page,
        limit: limit,
        minPrice: minPrice,
        maxPrice: maxPrice,
      );

      final uri = Uri.parse(url);

      final headers = {
        'Content-Type': 'application/json',
        'Connection': 'keep-alive',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      debugPrint(' Fetching nearby rentals:');
      debugPrint('   URL: $uri');
      debugPrint('   Radius: ${radius}km');
      debugPrint('   Price range: ${minPrice ?? "Any"} - ${maxPrice ?? "Any"}');

      final response = await _safeRequest(
            () => _client.get(uri, headers: headers),
        timeout: _longTimeout,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        debugPrint(' Response status: ${response.statusCode}');
        debugPrint('   Applied filters: ${data['appliedFilters']}');
        debugPrint('   Search method: ${data['searchMethod']}');

        final List<dynamic> rentalsData = data['rentals'] ?? [];

        final List<Rental> rentals = rentalsData
            .map((json) {
          try {
            return _parseRentalJson(json);
          } catch (e) {
            debugPrint(' Error parsing rental: $e');
            return null;
          }
        })
            .whereType<Rental>()
            .toList();

        debugPrint(' Parsed ${rentals.length} nearby rentals');

        return {
          'rentals': rentals,
          'warning': data['warning'],
          'searchMethod': data['searchMethod'],
          'total': data['total'] ?? rentals.length,
          'radiusKm': data['radiusKm'] ?? radius,
          'page': page,
          'hasMore': rentals.length >= limit,
          'appliedFilters': data['appliedFilters'],
        };
      } else {
        throw Exception('Failed to fetch nearby rentals: ${response.statusCode}');
      }
    });
  }

  //  Helper method to parse rental JSON safely ========================================================
  Rental _parseRentalJson(Map<String, dynamic> json) {
    debugPrint('\n🔍 [PARSE-RENTAL] Starting parse for: ${json['_id']}');

    // 🔥 FIX: Handle coordinates từ API response (có thể từ geospatial query hoặc AI)
    if (json['coordinates'] != null && json['coordinates'] is List) {
      final coords = json['coordinates'] as List;
      if (coords.length >= 2) {
        debugPrint('   ✅ Found coordinates array: [${coords[0]}, ${coords[1]}]');

        // Initialize location nếu chưa có
        json['location'] = json['location'] ?? {};
        json['location']['longitude'] = double.parse(coords[0].toString());
        json['location']['latitude'] = double.parse(coords[1].toString());
        debugPrint('   ✅ Set from array: lon=${json['location']['longitude']}, lat=${json['location']['latitude']}');
      }
    }

    // 🔥 FIX: Handle longitude/latitude trực tiếp từ location object (từ AI API)
    if (json['location'] != null && json['location'] is Map) {
      final loc = json['location'] as Map;

      // If API sends longitude/latitude directly, preserve them
      if (loc['longitude'] != null) {
        debugPrint('   ✅ Found location.longitude: ${loc['longitude']}');
        loc['longitude'] = double.parse(loc['longitude'].toString());
      }

      if (loc['latitude'] != null) {
        debugPrint('   ✅ Found location.latitude: ${loc['latitude']}');
        loc['latitude'] = double.parse(loc['latitude'].toString());
      }

      // If coordinates array exists, also use it
      if (loc['coordinates'] != null && loc['coordinates'] is Map) {
        final coords = loc['coordinates'] as Map;
        if (coords['coordinates'] is List) {
          final arr = coords['coordinates'] as List;
          if (arr.length >= 2) {
            debugPrint('   ✅ Found location.coordinates.coordinates: [${arr[0]}, ${arr[1]}]');

            // Ensure longitude/latitude are set
            if (loc['longitude'] == null || (loc['longitude'] as num) == 0) {
              loc['longitude'] = double.parse(arr[0].toString());
              debugPrint('   ✅ Set longitude from array: ${loc['longitude']}');
            }

            if (loc['latitude'] == null || (loc['latitude'] as num) == 0) {
              loc['latitude'] = double.parse(arr[1].toString());
              debugPrint('   ✅ Set latitude from array: ${loc['latitude']}');
            }
          }
        }
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

    // 🔥 FIX: Ensure location has all required fields with proper coordinates
    final finalLocation = json['location'] ?? {};

    // Get coordinates từ các nguồn khác nhau
    double finalLon = 0.0;
    double finalLat = 0.0;

    // Priority: longitude/latitude trực tiếp > coordinates array > default
    if (finalLocation['longitude'] != null && (finalLocation['longitude'] as num) != 0) {
      finalLon = double.parse(finalLocation['longitude'].toString());
    } else if (finalLocation['coordinates'] is Map) {
      final coords = finalLocation['coordinates'] as Map;
      if (coords['coordinates'] is List) {
        final arr = coords['coordinates'] as List;
        if (arr.length >= 1 && arr[0] != null) {
          finalLon = double.parse(arr[0].toString());
        }
      }
    }

    if (finalLocation['latitude'] != null && (finalLocation['latitude'] as num) != 0) {
      finalLat = double.parse(finalLocation['latitude'].toString());
    } else if (finalLocation['coordinates'] is Map) {
      final coords = finalLocation['coordinates'] as Map;
      if (coords['coordinates'] is List) {
        final arr = coords['coordinates'] as List;
        if (arr.length >= 2 && arr[1] != null) {
          finalLat = double.parse(arr[1].toString());
        }
      }
    }

    debugPrint('   📍 Final coordinates: lon=$finalLon, lat=$finalLat');

    json['location'] = {
      'short': finalLocation['short'] ?? '',
      'fullAddress': finalLocation['fullAddress'] ?? '',
      'longitude': finalLon,  // 🔥 ENSURE coordinates
      'latitude': finalLat,    // 🔥 ENSURE coordinates
      'coordinates': {
        'type': 'Point',
        'coordinates': [finalLon, finalLat],
      },
    };

    json['status'] = json['status'] ?? 'available';
    json['userId'] = json['userId'] ?? '';

    // Parse AI metadata fields
    if (json['isAIRecommended'] != null) {
      json['isAIRecommended'] = json['isAIRecommended'] as bool;
    }

    if (json['aiScore'] != null) {
      json['aiScore'] = (json['aiScore'] as num).toDouble();
    }

    if (json['locationBonus'] != null) {
      json['locationBonus'] = (json['locationBonus'] as num).toDouble();
    }

    if (json['finalScore'] != null) {
      json['finalScore'] = (json['finalScore'] as num).toDouble();
    }

    if (json['recommendationReason'] != null) {
      json['recommendationReason'] = json['recommendationReason'] as String;
    }

    if (json['distanceKm'] != null) {
      json['distanceKm'] = json['distanceKm'].toString();
    }

    if (json['distance_km'] != null) {
      json['distanceKm'] = json['distance_km'].toString();
    }

    debugPrint('✅ [PARSE-RENTAL] Complete: $finalLon, $finalLat\n');

    return Rental.fromJson(json);
  }

  //  Cleanup method - call this in app dispose
  static void dispose() {
    _client.close();
  }

  /// 🤖🏢 Fetch AI Personalized + POI combined
  Future<Map<String, dynamic>> fetchAIPersonalizedWithPOI({
    required double latitude,
    required double longitude,
    required List<String> selectedCategories,
    required double radius,
    required double poiRadius,
    double? minPrice,
    double? maxPrice,
    int limit = 10,
    required String token,
  }) async {
    try {
      // ✅ Gọi endpoint mới
      final poiService = POIService();
      final result = await poiService.getAIPersonalizedWithPOI(
        latitude: latitude,
        longitude: longitude,
        selectedCategories: selectedCategories,
        radius: radius,
        poiRadius: poiRadius,
        minPrice: minPrice,
        maxPrice: maxPrice,
        limit: limit,
      );

      return result;
    } catch (e) {
      debugPrint('❌ [RENTAL-SERVICE] Error in fetchAIPersonalizedWithPOI: $e');
      return {
        'rentals': <Rental>[],
        'total': 0,
        'poisTotal': 0,
        'success': false,
      };
    }
  }
  /// Fetch AI-powered personalized recommendations


  Future<Map<String, dynamic>> fetchAIRecommendations({
    required double latitude,
    required double longitude,
    double radius = 10.0,
    double? minPrice,
    double? maxPrice,
    String? token,
    int limit = 10,
  }) async {
    // Validate coordinates
    if (latitude.abs() > 90 || longitude.abs() > 180) {
      throw Exception(
          'Tọa độ không hợp lệ: latitude=$latitude, longitude=$longitude'
      );
    }

    return _retryRequest(() async {
      // 🔥 SỬ DỤNG endpoint từ ai-recommendations.js
      final url = Uri.parse(
          '${ApiRoutes.baseUrl}/ai/recommendations/personalized'
              '?latitude=$latitude'
              '&longitude=$longitude'
              '&radius=$radius'
              '&limit=$limit'
              '${minPrice != null ? '&minPrice=$minPrice' : ''}'
              '${maxPrice != null ? '&maxPrice=$maxPrice' : ''}'
      );

      final headers = {
        'Content-Type': 'application/json',
        'Connection': 'keep-alive',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      debugPrint('🤖 [AI-RECOMMENDATIONS] Requesting:');
      debugPrint('   URL: $url');
      debugPrint('   Coords: ($latitude, $longitude)');
      debugPrint('   Radius: ${radius}km');
      debugPrint('   Prices: ${minPrice?.toStringAsFixed(0) ?? "Any"} - ${maxPrice?.toStringAsFixed(0) ?? "Any"}');

      final response = await _safeRequest(
            () => _client.get(url, headers: headers),
        timeout: const Duration(seconds: 30),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        debugPrint('✅ [AI-RECOMMENDATIONS] Success');
        debugPrint('   Status: ${response.statusCode}');
        debugPrint('   Is AI: ${data['isAIRecommendation']}');
        debugPrint('   Found: ${data['rentals']?.length ?? 0} rentals');
        debugPrint('   Message: ${data['message']}');

        final List<dynamic> rentalsData = data['rentals'] ?? [];

        // 🔥 DEBUG: Log first rental structure từ API
        if (rentalsData.isNotEmpty) {
          debugPrint('🔍 [DEBUG] First rental from AI API:');
          final first = rentalsData[0];
          debugPrint('   _id: ${first['_id']}');
          debugPrint('   title: ${first['title']}');
          debugPrint('   location keys: ${(first['location'] as Map?)?.keys.toString()}');
          debugPrint('   longitude: ${first['location']?['longitude']}');
          debugPrint('   latitude: ${first['location']?['latitude']}');
          debugPrint('   coordinates: ${first['location']?['coordinates']}');
          debugPrint('   aiScore: ${first['aiScore']}');
          debugPrint('   locationBonus: ${first['locationBonus']}');
          debugPrint('   finalScore: ${first['finalScore']}');
        }

        final List<Rental> rentals = rentalsData
            .map((json) {
          try {
            debugPrint('\n🔄 Parsing rental: ${json['_id']}');

            // 🔥 FIX: Ensure coordinates are properly set from API response
            // Backend already sends longitude/latitude in location object

            if (json['location'] != null && json['location'] is Map) {
              final loc = json['location'] as Map;

              // Backend sends both longitude/latitude AND coordinates object
              if (loc['longitude'] != null && loc['latitude'] != null) {
                debugPrint('   ✅ Has longitude/latitude from API');
                debugPrint('      longitude: ${loc['longitude']}, latitude: ${loc['latitude']}');
              }

              if (loc['coordinates'] != null) {
                final coords = loc['coordinates'];
                if (coords is Map && coords['coordinates'] is List) {
                  debugPrint('   ✅ Has coordinates array');
                  final arr = coords['coordinates'] as List;
                  if (arr.length >= 2) {
                    debugPrint('      [${arr[0]}, ${arr[1]}]');
                  }
                }
              }
            }

            final rental = _parseRentalJson(json);

            // 🔥 FIX: Set AI metadata từ API response
            if (json['aiScore'] != null) {
              rental.aiScore = (json['aiScore'] as num).toDouble();
              debugPrint('   ✅ aiScore: ${rental.aiScore}');
            }

            if (json['locationBonus'] != null) {
              rental.locationBonus = (json['locationBonus'] as num).toDouble();
              debugPrint('   ✅ locationBonus: ${rental.locationBonus}');
            }

            if (json['finalScore'] != null) {
              rental.finalScore = (json['finalScore'] as num).toDouble();
              debugPrint('   ✅ finalScore: ${rental.finalScore}');
            }

            if (json['isAIRecommended'] != null) {
              rental.isAIRecommended = json['isAIRecommended'] as bool;
              debugPrint('   ✅ isAIRecommended: ${rental.isAIRecommended}');
            }

            if (json['recommendationReason'] != null) {
              rental.recommendationReason = json['recommendationReason'] as String;
              debugPrint('   ✅ reason: ${rental.recommendationReason}');
            }

            // 🔥 DEBUG: Final check
            debugPrint('   Final coordinates: (${rental.location['longitude']}, ${rental.location['latitude']})');

            return rental;
          } catch (e) {
            debugPrint('❌ Error parsing AI rental: $e');
            debugPrint('   JSON: $json');
            return null;
          }
        })
            .whereType<Rental>()
            .toList();

        debugPrint('\n✅ [AI-RECOMMENDATIONS] Parsed ${rentals.length} rentals');

        // 🔥 DEBUG: Verify all rentals have coordinates
        final withCoords = rentals.where((r) =>
        (r.location['longitude'] as num?)?.toDouble() != 0 &&
            (r.location['latitude'] as num?)?.toDouble() != 0
        ).length;
        debugPrint('   Rentals with valid coordinates: $withCoords/${rentals.length}');

        return {
          'rentals': rentals,
          'isAIRecommendation': data['isAIRecommendation'] ?? false,
          'message': data['message'] ?? 'Gợi ý',
          'total': data['total'] ?? rentals.length,
          'filters': data['filters'],
        };
      } else if (response.statusCode == 400) {
        final errorData = jsonDecode(response.body);
        throw Exception('Yêu cầu không hợp lệ: ${errorData['message']}');
      } else if (response.statusCode == 500) {
        final errorData = jsonDecode(response.body);
        debugPrint('❌ Server error: ${errorData['error']}');
        throw Exception(
            'Lỗi máy chủ: ${errorData['message']}. '
                'Vui lòng thử lại sau.'
        );
      } else {
        throw Exception(
            'Failed to fetch AI recommendations: Status ${response.statusCode}'
        );
      }
    }, maxRetries: 2);
  }

  /// Fetch AI-powered nearby recommendations for a specific rental
  Future<Map<String, dynamic>> fetchAINearbyRecommendations({
    required String rentalId,
    double radius = 10.0,
    String? token,
    int limit = 10,
  }) async {
    // Validate rentalId
    if (rentalId.isEmpty || rentalId.startsWith('current_location_')) {
      throw Exception('Invalid rental ID for AI nearby search.');
    }

    return _retryRequest(() async {
      // 🔥 SỬ DỤNG endpoint từ ai-recommendations.js
      final url = Uri.parse(
          '${ApiRoutes.baseUrl}/ai/recommendations/nearby/$rentalId'
              '?limit=$limit'
              '&radius=$radius'
      );

      final headers = {
        'Content-Type': 'application/json',
        'Connection': 'keep-alive',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      debugPrint('🤖 [AI-NEARBY] Requesting:');
      debugPrint('   URL: $url');
      debugPrint('   Rental ID: $rentalId');
      debugPrint('   Radius: ${radius}km');

      final response = await _safeRequest(
            () => _client.get(url, headers: headers),
        timeout: const Duration(seconds: 30),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        debugPrint('✅ [AI-NEARBY] Success');
        debugPrint('   Status: ${response.statusCode}');
        debugPrint('   Is AI: ${data['isAIRecommendation']}');
        debugPrint('   Found: ${data['rentals']?.length ?? 0} rentals');
        debugPrint('   Message: ${data['message']}');

        final List<dynamic> rentalsData = data['rentals'] ?? [];

        // 🔥 DEBUG: Log structure
        if (rentalsData.isNotEmpty) {
          debugPrint('🔍 [DEBUG] First rental from AI nearby API:');
          final first = rentalsData[0];
          debugPrint('   _id: ${first['_id']}');
          debugPrint('   longitude: ${first['location']?['longitude']}');
          debugPrint('   latitude: ${first['location']?['latitude']}');
          debugPrint('   distance_km: ${first['distance_km']}');
          debugPrint('   aiScore: ${first['aiScore']}');
        }

        final List<Rental> rentals = rentalsData
            .map((json) {
          try {
            final rental = _parseRentalJson(json);

            // 🔥 FIX: Set AI metadata từ API
            if (json['aiScore'] != null) {
              rental.aiScore = (json['aiScore'] as num).toDouble();
            }

            if (json['locationBonus'] != null) {
              rental.locationBonus = (json['locationBonus'] as num).toDouble();
            }

            if (json['finalScore'] != null) {
              rental.finalScore = (json['finalScore'] as num).toDouble();
            }

            if (json['isAIRecommended'] != null) {
              rental.isAIRecommended = json['isAIRecommended'] as bool;
            }

            if (json['distance_km'] != null) {
              rental.distanceKm = json['distance_km'].toString();
            }

            if (json['distanceKm'] != null) {
              rental.distanceKm = json['distanceKm'].toString();
            }

            return rental;
          } catch (e) {
            debugPrint('❌ Error parsing AI nearby rental: $e');
            return null;
          }
        })
            .whereType<Rental>()
            .toList();

        debugPrint('✅ [AI-NEARBY] Parsed ${rentals.length} rentals');

        return {
          'rentals': rentals,
          'isAIRecommendation': data['isAIRecommendation'] ?? false,
          'message': data['message'] ?? 'Gợi ý gần đây',
          'total': data['total'] ?? rentals.length,
          'mainRental': data['mainRental'],
        };
      } else if (response.statusCode == 404) {
        throw Exception('Rental not found');
      } else if (response.statusCode == 400) {
        final errorData = jsonDecode(response.body);
        throw Exception('Yêu cầu không hợp lệ: ${errorData['message']}');
      } else {
        throw Exception(
            'Failed to fetch AI nearby recommendations: Status ${response.statusCode}'
        );
      }
    }, maxRetries: 2);
  }

}