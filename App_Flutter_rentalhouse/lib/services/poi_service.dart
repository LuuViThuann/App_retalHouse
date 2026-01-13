import 'dart:convert';
import 'dart:math'; // ✅ FIX: Import dart:math
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../config/api_routes.dart';
import '../models/poi.dart';
import '../models/rental.dart';
import '../services/auth_service.dart';

class POIService {
  static final POIService _instance = POIService._internal();
  factory POIService() => _instance;
  POIService._internal();

  final http.Client _client = http.Client();
  static const Duration _timeout = Duration(seconds: 30);

  /// 🏷️ Lấy danh sách categories
  Future<List<POICategory>> getCategories() async {
    try {
      debugPrint('🔍 [POI-SERVICE] Fetching categories');

      final response = await _client
          .get(Uri.parse(ApiRoutes.poiCategories))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> categoriesData = data['categories'] ?? [];

        debugPrint('✅ [POI-SERVICE] Found ${categoriesData.length} categories');

        return categoriesData
            .map((json) => POICategory.fromJson(json))
            .toList();
      } else {
        throw Exception('Failed to get categories: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ [POI-SERVICE] Error getting POI categories: $e');
      rethrow;
    }
  }

  /// 📍 Lấy POI theo category và vị trí
  Future<List<POI>> getPOIsNearby({
    required double latitude,
    required double longitude,
    String? category,
    double radius = 5.0,
  }) async {
    try {
      final url = ApiRoutes.poiNearby(
        latitude: latitude,
        longitude: longitude,
        category: category,
        radius: radius,
      );

      debugPrint('🔍 [POI-SERVICE] Fetching POIs: category=$category, radius=${radius}km');

      final response = await _client
          .get(Uri.parse(url))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> poisData = data['pois'] ?? [];

        final pois = poisData.map((json) => POI.fromJson(json)).toList();

        debugPrint('✅ [POI-SERVICE] Found ${pois.length} POIs');
        return pois;
      } else {
        throw Exception('Failed to get POIs: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ [POI-SERVICE] Error getting POIs: $e');
      return [];
    }
  }

  /// 🔥 Lọc rentals theo POI và khoảng cách
  /// ✅ FIX: Sử dụng endpoint đúng từ ApiRoutes
  Future<POIFilterResult> filterRentalsByPOI({
    required double latitude,
    required double longitude,
    required List<String> selectedCategories,
    double radius = 3.0,
    double? minPrice,
    double? maxPrice,
    int limit = 20,
  }) async {
    try {
      final token = await AuthService().getIdToken();

      if (token == null) {
        throw Exception('Vui lòng đăng nhập');
      }

      final body = {
        'latitude': latitude,
        'longitude': longitude,
        'selectedCategories': selectedCategories,
        'radius': radius,
        'limit': limit,
        if (minPrice != null) 'minPrice': minPrice,
        if (maxPrice != null) 'maxPrice': maxPrice,
      };

      debugPrint('🔥 [POI-FILTER] Request: categories=${selectedCategories.join(", ")}, radius=${radius}km');

      final response = await _client.post(
        Uri.parse(ApiRoutes.filterRentalsByPOI),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      ).timeout(_timeout);

      debugPrint('🔥 [POI-FILTER] Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] != true) {
          throw Exception(data['message'] ?? 'API returned error');
        }

        // ✅ FIX: Parse rentals (remain as dynamic list)
        final List<dynamic> rentalsData = data['rentals'] ?? [];
        final rentals = rentalsData
            .map((json) => Rental.fromJson(json))
            .toList();

        // ✅ FIX: Convert pois từ Map<String, dynamic> sang POIOnMap
        final List<dynamic> poisData = data['pois'] ?? [];
        final pois = poisData
            .whereType<Map<String, dynamic>>()
            .map((poiJson) => POIOnMap.fromJson(poiJson))
            .toList();

        final result = POIFilterResult(
          rentals: rentals,
          pois: pois, // ✅ FIX: Giờ là List<POIOnMap>
          total: data['total'] as int? ?? rentals.length,
          poisTotal: data['poisTotal'] as int? ?? 0,
          selectedCategories: selectedCategories,
          radius: radius,
          message: data['message'] ?? 'Tìm thấy bài gần tiện ích',
          success: true,
        );

        debugPrint('✅ [POI-FILTER] Found ${result.total} rentals, ${result.poisTotal} POIs');
        return result;
      } else {
        throw Exception('Failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ [POI-FILTER] Error: $e');
      return POIFilterResult(
        rentals: [],
        pois: [], // ✅ Empty list<POIOnMap>
        total: 0,
        poisTotal: 0,
        selectedCategories: selectedCategories,
        radius: radius,
        message: 'Lỗi: $e',
        success: false,
      );
    }
  }
  /// 🏠 Lấy rentals gần POI
  Future<Map<String, dynamic>> getRentalsNearPOI({
    required POI poi,
    double radius = 5.0,
    double? minPrice,
    double? maxPrice,
    int limit = 20,
  }) async {
    try {
      final token = await AuthService().getIdToken();

      final body = {
        'poi': poi.toJson(),
        'radius': radius,
        'limit': limit,
        if (minPrice != null) 'minPrice': minPrice,
        if (maxPrice != null) 'maxPrice': maxPrice,
      };

      debugPrint('🏠 [POI-SERVICE] Fetching rentals near ${poi.name}');

      final response = await _client.post(
        Uri.parse(ApiRoutes.rentalsNearPOI),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> rentalsData = data['rentals'] ?? [];

        final rentals = rentalsData
            .map((json) => Rental.fromJson(json))
            .toList();

        debugPrint('✅ [POI-SERVICE] Found ${rentals.length} rentals');

        return {
          'rentals': rentals,
          'total': data['total'] ?? 0,
          'poi': poi,
          'success': true,
        };
      } else {
        throw Exception('Failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ [POI-SERVICE] Error: $e');
      return {
        'rentals': <Rental>[],
        'total': 0,
        'poi': poi,
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// 🗺️ Convert POI to POIOnMap
  POIOnMap toPOIOnMap(POI poi, {required bool hasNearbyRentals}) {
    return POIOnMap.fromPOI(poi, hasNearbyRentals: hasNearbyRentals);
  }

  /// 🎯 Filter POIs by category
  List<POI> filterPOIsByCategory(List<POI> allPOIs, String category) {
    return allPOIs.where((poi) => poi.category == category).toList();
  }

  /// 📏 Calculate distance (Haversine formula)
  /// ✅ FIX: Use dart:math functions
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371; // Earth radius in km
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _toRadians(double degrees) {
    return degrees * (pi / 180); // ✅ Use pi from dart:math
  }

  // ✅ FIX: Phần getAIPOIRecommendations trong poi_service.dart

  /// 🤖 Get AI + POI combined recommendations
  Future<Map<String, dynamic>> getAIPOIRecommendations({
    required double latitude,
    required double longitude,
    required List<String> selectedCategories,
    double radius = 10.0,
    double? minPrice,
    double? maxPrice,
    int limit = 20,
  }) async {
    try {
      final token = await AuthService().getIdToken();

      if (token == null) {
        throw Exception('Vui lòng đăng nhập để xem gợi ý AI');
      }

      final body = {
        'latitude': latitude,
        'longitude': longitude,
        'selectedCategories': selectedCategories,
        'radius': radius,
        'limit': limit,
        if (minPrice != null) 'minPrice': minPrice,
        if (maxPrice != null) 'maxPrice': maxPrice,
      };

      debugPrint('🤖 [AI+POI] Request: categories=${selectedCategories.join(", ")}, radius=${radius}km');

      final response = await _client.post(
        Uri.parse(ApiRoutes.aiPOIRecommendations),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      ).timeout(_timeout);

      debugPrint('🤖 [AI+POI] Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] != true) {
          throw Exception(data['message'] ?? 'API returned error');
        }

        // ✅ FIX: Parse rentals correctly
        final List<dynamic> rentalsData = data['rentals'] ?? [];
        final rentals = rentalsData
            .map((json) => Rental.fromJson(json))
            .toList();

        debugPrint('✅ [AI+POI] Found ${rentals.length} rentals');

        return {
          'rentals': rentals, // ✅ List<Rental>
          'isAIRecommendation': data['isAIRecommendation'] ?? true,
          'message': data['message'] ?? 'Gợi ý AI + POI',
          'total': data['total'] ?? rentals.length,
          'poisTotal': data['poisFound'] ?? 0,
          'success': true,
        };
      } else {
        throw Exception('Failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ [AI+POI] Error: $e');
      return {
        'rentals': <Rental>[],
        'isAIRecommendation': false,
        'message': 'Lỗi: $e',
        'total': 0,
        'poisTotal': 0,
        'success': false,
      };
    }
  }
  void dispose() {
    _client.close();
  }
}