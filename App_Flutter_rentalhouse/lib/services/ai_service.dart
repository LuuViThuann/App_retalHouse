// 📝 File: services/ai_service.dart
// 🔥 SERVICE MỚI: Xử lý các endpoint AI recommendations, explain, preferences

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_routes.dart';
import '../models/rental.dart';
import 'auth_service.dart';

class AIService {
  static final AIService _instance = AIService._internal();

  factory AIService() {
    return _instance;
  }

  AIService._internal();

  static const Duration _timeout = Duration(seconds: 30);

  // ==================== AI RECOMMENDATIONS WITH CONTEXT ====================

  /// 🔥 NEW: Fetch AI recommendations with context (device, time, zoom level, impressions)
  ///
  /// Sử dụng endpoint: GET /api/ai/recommendations/personalized/context
  ///
  /// Tham số:
  /// - latitude, longitude: Vị trí map center
  /// - radius: Bán kính tìm kiếm (km)
  /// - zoomLevel: Mức zoom hiện tại
  /// - timeOfDay: Thời gian trong ngày (morning, afternoon, evening, night)
  /// - deviceType: Loại thiết bị (mobile, desktop, tablet)
  /// - impressions: Danh sách rental IDs đã hiển thị (để tránh duplicate)
  /// - scrollDepth: Độ scroll trên page (0-1)
  Future<Map<String, dynamic>> fetchAIRecommendationsWithContext({
    required double latitude,
    required double longitude,
    double radius = 10.0,
    int zoomLevel = 15,
    String timeOfDay = 'morning',
    String deviceType = 'mobile',
    int limit = 10,
    List<String> impressions = const [],
    double scrollDepth = 0.5,
    double? minPrice,
    double? maxPrice,
    String? token,
  }) async {
    try {
      final url = ApiRoutes.aiRecommendationsPersonalizedContext(
        latitude: latitude,
        longitude: longitude,
        radius: radius,
        zoomLevel: zoomLevel,
        timeOfDay: timeOfDay,
        deviceType: deviceType,
        limit: limit,
        impressions: impressions.join(','),
        scrollDepth: scrollDepth,
      );

      final uri = Uri.parse(url);

      final headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      debugPrint('🎯 [AI-CONTEXT] Requesting:');
      debugPrint('   Coords: ($latitude, $longitude)');
      debugPrint('   Radius: ${radius}km, Zoom: $zoomLevel');
      debugPrint('   Time: $timeOfDay, Device: $deviceType');
      debugPrint('   Impressions: ${impressions.length} items');
      debugPrint('   Scroll: ${(scrollDepth * 100).toInt()}%');

      final response = await http.get(uri, headers: headers)
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        debugPrint('✅ [AI-CONTEXT] Success');
        debugPrint('   Found: ${data['rentals']?.length ?? 0} rentals');
        debugPrint('   Avg Confidence: ${(data['personalization']?['avgConfidence'] ?? 0 * 100).toStringAsFixed(0)}%');

        // ✅ Parse rentals with AI metadata
        final List<dynamic> rentalsData = data['rentals'] ?? [];
        final List<Rental> rentals = rentalsData
            .map((json) {
          try {
            final rental = Rental.fromJson(json);

            // 🔥 EXTRACT AI METADATA
            if (json['aiScore'] != null) {
              rental.aiScore = (json['aiScore'] as num).toDouble();
            }
            if (json['locationBonus'] != null) {
              rental.locationBonus = (json['locationBonus'] as num).toDouble();
            }
            if (json['preferenceBonus'] != null) {
              rental.preferenceBonus = (json['preferenceBonus'] as num).toDouble();
            }
            if (json['finalScore'] != null) {
              rental.finalScore = (json['finalScore'] as num).toDouble();
            }
            if (json['confidence'] != null) {
              rental.confidence = (json['confidence'] as num).toDouble();
            }
            if (json['markerPriority'] != null) {
              rental.markerPriority = json['markerPriority'] as int;
            }
            if (json['explanation'] != null) {
              rental.explanation = json['explanation'] as Map<String, dynamic>;
            }
            if (json['markerSize'] != null) {
              rental.markerSize = (json['markerSize'] as num).toDouble();
            }
            if (json['markerOpacity'] != null) {
              rental.markerOpacity = (json['markerOpacity'] as num).toDouble();
            }

            return rental;
          } catch (e) {
            debugPrint('❌ Error parsing rental: $e');
            return null;
          }
        })
            .whereType<Rental>()
            .toList();

        return {
          'rentals': rentals,
          'isPersonalized': true,
          'context': data['context'],
          'personalization': data['personalization'],
          'mapHints': data['mapHints'],
          'total': data['total'] ?? rentals.length,
          'success': true,
        };
      } else if (response.statusCode == 401) {
        throw Exception('Vui lòng đăng nhập để xem gợi ý AI');
      } else if (response.statusCode == 400) {
        final errorData = jsonDecode(response.body);
        throw Exception('Yêu cầu không hợp lệ: ${errorData['message']}');
      } else {
        throw Exception(
            'Failed to fetch AI recommendations: Status ${response.statusCode}'
        );
      }
    } catch (e) {
      debugPrint('❌ [AI-CONTEXT] Error: $e');
      rethrow;
    }
  }

  // ==================== AI EXPLAIN ====================

  /// 🔥 NEW: Get explanation for why a rental was recommended
  ///
  /// Sử dụng endpoint: GET /api/ai/explain/:userId/:rentalId
  ///
  /// Response:
  /// {
  ///   "success": true,
  ///   "explanation": {
  ///     "scores": {
  ///       "confidence": 0.85,
  ///       "price_match": 0.9,
  ///       "location_match": 0.8,
  ///       "preference_match": 0.75
  ///     },
  ///     "reasons": {
  ///       "price": "Giá phù hợp với bạn (5M-7M)",
  ///       "location": "Gần khu vực bạn yêu thích",
  ///       "amenities": "Có các tiện ích bạn quan tâm"
  ///     },
  ///     "rental": { ... }
  ///   }
  /// }
  Future<Map<String, dynamic>> fetchAIExplanation({
    required String userId,
    required String rentalId,
    String? token,
  }) async {
    try {
      final url = ApiRoutes.aiExplain(userId: userId, rentalId: rentalId);

      final headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      debugPrint('🤔 [AI-EXPLAIN] Requesting for rental: $rentalId');

      final response = await http.get(Uri.parse(url), headers: headers)
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        debugPrint('✅ [AI-EXPLAIN] Success');
        debugPrint('   Confidence: ${(data['explanation']['scores']['confidence'] * 100).toStringAsFixed(0)}%');
        debugPrint('   Reasons: ${data['explanation']['reasons'].keys.length} factors');

        return {
          'success': true,
          'explanation': data['explanation'],
        };
      } else if (response.statusCode == 404) {
        throw Exception('Không tìm thấy giải thích cho bài viết này');
      } else if (response.statusCode == 401) {
        throw Exception('Vui lòng đăng nhập để xem giải thích');
      } else {
        throw Exception(
            'Failed to fetch explanation: Status ${response.statusCode}'
        );
      }
    } catch (e) {
      debugPrint('❌ [AI-EXPLAIN] Error: $e');
      rethrow;
    }
  }

  // ==================== USER PREFERENCES ====================

  /// 🔥 NEW: Get user's preferences and interaction history
  ///
  /// Sử dụng endpoint: GET /api/ai/user-preferences/:userId
  ///
  /// Response:
  /// {
  ///   "success": true,
  ///   "preferences": {
  ///     "userId": "user123",
  ///     "summary": {
  ///       "totalInteractions": 45,
  ///       "avgPrice": 5500000,
  ///       "priceRange": "3M - 8M",
  ///       "favoritePropertyType": "Apartment",
  ///       "topLocations": [...]
  ///     },
  ///     "detailed": { ... }
  ///   }
  /// }
  Future<Map<String, dynamic>> fetchUserPreferences({
    required String userId,
    String? token,
  }) async {
    try {
      final url = ApiRoutes.userPreferences(userId: userId);

      final headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      debugPrint('👤 [USER-PREFS] Requesting for user: $userId');

      final response = await http.get(Uri.parse(url), headers: headers)
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        debugPrint('✅ [USER-PREFS] Success');
        debugPrint('   Total interactions: ${data['preferences']['summary']['totalInteractions']}');
        debugPrint('   Avg price: ${data['preferences']['summary']['avgPrice']}');
        debugPrint('   Top property type: ${data['preferences']['summary']['favoritePropertyType']}');

        return {
          'success': true,
          'preferences': data['preferences'],
        };
      } else if (response.statusCode == 404) {
        debugPrint('⚠️ [USER-PREFS] No preferences found for user');
        return {
          'success': false,
          'message': 'No preferences found',
          'preferences': null,
        };
      } else if (response.statusCode == 401) {
        throw Exception('Vui lòng đăng nhập để xem preferences');
      } else {
        throw Exception(
            'Failed to fetch preferences: Status ${response.statusCode}'
        );
      }
    } catch (e) {
      debugPrint('❌ [USER-PREFS] Error: $e');
      rethrow;
    }
  }

  // ==================== HELPER METHODS ====================

  /// Format confidence score to percentage
  String formatConfidence(double confidence) {
    return '${(confidence * 100).toStringAsFixed(0)}%';
  }

  /// Format score for display
  String formatScore(double score) {
    return score.toStringAsFixed(2);
  }

  /// Get marker color based on AI score
  Color getMarkerColorFromScore(double score) {
    if (score >= 0.8) return Colors.green;
    if (score >= 0.6) return Colors.blue;
    if (score >= 0.4) return Colors.amber;
    return Colors.orange;
  }

  /// Get marker size based on confidence
  double getMarkerSizeFromConfidence(double confidence) {
    // Returns value between 1 and 5
    return 1 + (confidence * 4);
  }

  /// Get explanation text for a score
  String getScoreExplanation(double score) {
    if (score >= 0.8) return 'Rất phù hợp';
    if (score >= 0.6) return 'Phù hợp';
    if (score >= 0.4) return 'Có thể phù hợp';
    return 'Ít phù hợp';
  }
}