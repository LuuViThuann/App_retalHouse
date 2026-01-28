import 'package:flutter/foundation.dart';

class Rental {
  final String id;
  final String title;
  final double price;
  final Map<String, dynamic> area;
  final Map<String, dynamic> location;
  final String propertyType;
  final List<String> furniture;
  final List<String> amenities;
  final List<String> surroundings;
  final Map<String, dynamic> rentalTerms;
  final Map<String, dynamic> contactInfo;
  final String userId;
  final List<String> images;
  final List<String> videos;
  final String status;
  final DateTime createdAt;
  final String landlord;


  // PAYMENT FIELDS
  final String? paymentTransactionCode;
  final Map<String, dynamic>? paymentInfo;
  final DateTime? publishedAt;

  // 🔥 AI RECOMMENDATION FIELDS
  bool? isAIRecommended;
  double? aiScore;
  String? recommendationReason;
  String? distanceKm;
  double? locationBonus;
  double? finalScore;
  List<Map<String, dynamic>>? nearestPOIs;

  // 🔥 NEW: Additional AI Fields
  double? preferenceBonus;           // Bonus từ preferences người dùng (1.0-2.0)
  double? timeBonus;                 // Bonus từ thời gian trong ngày (1.0-1.5)
  double? confidence;                // 🆕 Độ tin cậy của gợi ý (0-1)
  int? markerPriority;               // 🆕 Thứ tự ưu tiên trên map
  Map<String, dynamic>? explanation; // 🆕 Chi tiết giải thích tại sao được gợi ý
  double? markerSize;                // 🆕 Kích thước marker trên map (1-5)
  double? markerOpacity;             // 🆕 Độ trong suốt marker (0-1)

  Rental({
    required this.id,
    required this.title,
    required this.price,
    required this.area,
    required this.location,
    required this.propertyType,
    required this.furniture,
    required this.amenities,
    required this.surroundings,
    required this.rentalTerms,
    required this.contactInfo,
    required this.userId,
    required this.images,
    required this.videos,
    required this.status,
    required this.createdAt,
    required this.landlord,
    // PAYMENT PARAMETERS
    this.paymentTransactionCode,
    this.paymentInfo,
    this.publishedAt,
    // 🔥 AI RECOMMENDATION FIELDS
    this.isAIRecommended,
    this.aiScore,
    this.recommendationReason,
    this.distanceKm,
    this.locationBonus,
    this.finalScore,
    this.nearestPOIs,
    // 🔥 NEW: Additional AI Fields
    this.preferenceBonus,
    this.timeBonus,
    this.confidence,
    this.markerPriority,
    this.explanation,
    this.markerSize,
    this.markerOpacity,
  });

  // ==================== GETTERS ====================

  bool get isPaid => paymentInfo?['status'] == 'completed';
  bool get isPublished => publishedAt != null;
  bool get requiresPayment => !isPaid;

  String get paymentStatus => paymentInfo?['status'] ?? 'pending';

  String get formattedPaymentAmount {
    final amount = paymentInfo?['amount'] ?? 10000;
    return '${amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
    )} đ';
  }

  // 🔥 NEW: AI-related getters

  /// Check if rental has valid AI metadata
  bool get hasAIMetadata =>
      aiScore != null &&
          finalScore != null &&
          confidence != null;

  /// Get AI recommendation score explanation
  String get aiScoreExplanation {
    final score = finalScore ?? aiScore ?? 0.0;
    if (score >= 80) return 'Rất phù hợp 🎯';
    if (score >= 60) return 'Khá phù hợp ✓';
    if (score >= 40) return 'Có thể phù hợp 👍';
    return 'Tham khảo thêm 🔍';
  }

  /// Get confidence percentage display
  String get confidenceDisplay {
    if (confidence == null) return 'N/A';
    return '${(confidence! * 100).toStringAsFixed(0)}% tự tin';
  }

  /// Get marker color hex based on AI score
  String get markerColorHex {
    final score = finalScore ?? aiScore ?? 0.0;
    if (score >= 80) return '#22c55e'; // Green - very good
    if (score >= 60) return '#3b82f6'; // Blue - good
    if (score >= 40) return '#f59e0b'; // Amber - fair
    return '#ef4444'; // Red - low
  }

  /// Get all bonus factors
  Map<String, double> get bonusFactors => {
    'location': locationBonus ?? 1.0,
    'preference': preferenceBonus ?? 1.0,
    'time': timeBonus ?? 1.0,
  };

  /// Get explanation reasons as list
  List<String> get explanationReasons {
    if (explanation == null) return [];
    final reasons = explanation!['reasons'] as Map?;
    if (reasons == null) return [];
    return reasons.values.whereType<String>().toList();
  }

  /// Get nearest POI count
  int get nearestPOICount => nearestPOIs?.length ?? 0;

  /// Get nearest POI formatted list (limit to 5)
  List<Map<String, dynamic>> get nearestPOIsFormatted {
    if (nearestPOIs == null) return [];
    return nearestPOIs!
        .take(5)
        .map((poi) {
      if (poi is Map) return poi.cast<String, dynamic>();
      return <String, dynamic>{};
    })
        .toList();
  }

  /// Check if this is an AI recommendation
  bool get isFromAI => isAIRecommended == true;

  // ==================== METHODS ====================

  Rental copyWith({
    String? id,
    String? title,
    double? price,
    Map<String, dynamic>? area,
    Map<String, dynamic>? location,
    String? propertyType,
    List<String>? furniture,
    List<String>? amenities,
    List<String>? surroundings,
    Map<String, dynamic>? rentalTerms,
    Map<String, dynamic>? contactInfo,
    String? userId,
    List<String>? images,
    List<String>? videos,
    String? status,
    DateTime? createdAt,
    String? landlord,
    // PAYMENT PARAMETERS
    String? paymentTransactionCode,
    Map<String, dynamic>? paymentInfo,
    DateTime? publishedAt,
    // AI PARAMETERS
    bool? isAIRecommended,
    double? aiScore,
    String? recommendationReason,
    String? distanceKm,
    double? locationBonus,
    double? finalScore,
    List<Map<String, dynamic>>? nearestPOIs,
    // 🔥 NEW: Additional AI Parameters
    double? preferenceBonus,
    double? timeBonus,
    double? confidence,
    int? markerPriority,
    Map<String, dynamic>? explanation,
    double? markerSize,
    double? markerOpacity,
  }) {
    return Rental(
      id: id ?? this.id,
      title: title ?? this.title,
      price: price ?? this.price,
      area: area ?? this.area,
      location: location ?? this.location,
      propertyType: propertyType ?? this.propertyType,
      furniture: furniture ?? this.furniture,
      amenities: amenities ?? this.amenities,
      surroundings: surroundings ?? this.surroundings,
      rentalTerms: rentalTerms ?? this.rentalTerms,
      contactInfo: contactInfo ?? this.contactInfo,
      userId: userId ?? this.userId,
      images: images ?? this.images,
      videos: videos ?? this.videos,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      landlord: landlord ?? this.landlord,
      // PAYMENT FIELDS
      paymentTransactionCode:
      paymentTransactionCode ?? this.paymentTransactionCode,
      paymentInfo: paymentInfo ?? this.paymentInfo,
      publishedAt: publishedAt ?? this.publishedAt,
      // AI FIELDS
      isAIRecommended: isAIRecommended ?? this.isAIRecommended,
      aiScore: aiScore ?? this.aiScore,
      recommendationReason: recommendationReason ?? this.recommendationReason,
      distanceKm: distanceKm ?? this.distanceKm,
      locationBonus: locationBonus ?? this.locationBonus,
      finalScore: finalScore ?? this.finalScore,
      nearestPOIs: nearestPOIs ?? this.nearestPOIs,
      // 🔥 NEW: Additional AI Fields
      preferenceBonus: preferenceBonus ?? this.preferenceBonus,
      timeBonus: timeBonus ?? this.timeBonus,
      confidence: confidence ?? this.confidence,
      markerPriority: markerPriority ?? this.markerPriority,
      explanation: explanation ?? this.explanation,
      markerSize: markerSize ?? this.markerSize,
      markerOpacity: markerOpacity ?? this.markerOpacity,
    );
  }

  Map<String, dynamic> toJson() => {
    '_id': id,
    'title': title,
    'price': price,
    'area': {
      'total': area['total'],
      'livingRoom': area['livingRoom'],
      'bedrooms': area['bedrooms'],
      'bathrooms': area['bathrooms'],
    },
    'location': {
      'short': location['short'],
      'fullAddress': location['fullAddress'],
      'latitude': location['latitude'],
      'longitude': location['longitude'],
    },
    'propertyType': propertyType,
    'furniture': furniture,
    'amenities': amenities,
    'surroundings': surroundings,
    'rentalTerms': rentalTerms,
    'contactInfo': contactInfo,
    'userId': userId,
    'images': images,
    'videos': videos,
    'status': status,
    'createdAt': createdAt.toIso8601String(),
    'landlord': landlord,
    // PAYMENT FIELDS
    if (paymentTransactionCode != null && paymentTransactionCode!.isNotEmpty)
      'paymentTransactionCode': paymentTransactionCode,
    if (paymentInfo != null) 'paymentInfo': paymentInfo,
    if (publishedAt != null) 'publishedAt': publishedAt!.toIso8601String(),
    // AI FIELDS
    if (isAIRecommended != null) 'isAIRecommended': isAIRecommended,
    if (aiScore != null) 'aiScore': aiScore,
    if (recommendationReason != null)
      'recommendationReason': recommendationReason,
    if (distanceKm != null) 'distanceKm': distanceKm,
    if (locationBonus != null) 'locationBonus': locationBonus,
    if (finalScore != null) 'finalScore': finalScore,
    if (nearestPOIs != null) 'nearestPOIs': nearestPOIs,
    // 🔥 NEW: Additional AI Fields
    if (preferenceBonus != null) 'preferenceBonus': preferenceBonus,
    if (timeBonus != null) 'timeBonus': timeBonus,
    if (confidence != null) 'confidence': confidence,
    if (markerPriority != null) 'markerPriority': markerPriority,
    if (explanation != null) 'explanation': explanation,
    if (markerSize != null) 'markerSize': markerSize,
    if (markerOpacity != null) 'markerOpacity': markerOpacity,
  };

  factory Rental.fromJson(Map<String, dynamic> json) {
    try {
      // Validate rental ID
      String? rentalId = json['_id'] as String? ?? json['id'] as String?;
      if (rentalId == null || rentalId.isEmpty) {
        throw Exception('Rental ID is missing');
      }

      // ===== SAFE PARSE FUNCTIONS =====

      Map<String, dynamic> _safeParseMap(dynamic value, Map<String, dynamic> defaultValue) {
        if (value == null) return defaultValue;
        if (value is Map) return Map<String, dynamic>.from(value);
        return defaultValue;
      }

      List<String> _safeParseStringList(dynamic value) {
        if (value == null) return [];
        if (value is List) {
          return value.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
        }
        if (value is String) return [value];
        return [];
      }

      double _safeParseDouble(dynamic value) {
        if (value == null) return 0.0;
        if (value is num) return value.toDouble();
        if (value is String) {
          final trimmed = value.trim().replaceAll(',', '.');
          return double.tryParse(trimmed) ?? 0.0;
        }
        return 0.0;
      }

      // ===== PARSE AREA =====
      final areaData = _safeParseMap(json['area'], {
        'total': 0.0,
        'livingRoom': 0.0,
        'bedrooms': 0.0,
        'bathrooms': 0.0,
      });

      final parsedArea = {
        'total': _safeParseDouble(areaData['total']),
        'livingRoom': _safeParseDouble(areaData['livingRoom']),
        'bedrooms': _safeParseDouble(areaData['bedrooms']),
        'bathrooms': _safeParseDouble(areaData['bathrooms']),
      };

      // ===== PARSE LOCATION =====
      Map<String, dynamic> locationData = {};
      final locationRaw = json['location'];

      if (locationRaw != null && locationRaw is Map) {
        locationData['short'] = locationRaw['short']?.toString() ?? '';
        locationData['fullAddress'] = locationRaw['fullAddress']?.toString() ??
            locationRaw['full']?.toString() ?? '';

        // Parse coordinates (multiple formats)
        double lat = 0.0;
        double lng = 0.0;

        // Format 1: GeoJSON nested coordinates
        if (locationRaw['coordinates'] is Map &&
            locationRaw['coordinates']['coordinates'] is List) {
          final coords = locationRaw['coordinates']['coordinates'] as List;
          if (coords.length >= 2) {
            lng = _safeParseDouble(coords[0]);
            lat = _safeParseDouble(coords[1]);
          }
        }
        // Format 2: Direct lat/lng
        else if (locationRaw['latitude'] != null && locationRaw['longitude'] != null) {
          lat = _safeParseDouble(locationRaw['latitude']);
          lng = _safeParseDouble(locationRaw['longitude']);
        }
        // Format 3: Coordinates object
        else if (locationRaw['coordinates'] is Map) {
          lat = _safeParseDouble(locationRaw['coordinates']['latitude']);
          lng = _safeParseDouble(locationRaw['coordinates']['longitude']);
        }

        locationData['latitude'] = lat;
        locationData['longitude'] = lng;
      } else {
        locationData = {
          'short': '',
          'fullAddress': '',
          'latitude': 0.0,
          'longitude': 0.0,
        };
      }

      // ===== PARSE RENTAL TERMS =====
      final rentalTermsData = _safeParseMap(json['rentalTerms'], {
        'minimumLease': '',
        'deposit': '',
        'paymentMethod': '',
        'renewalTerms': '',
      });

      // ===== PARSE CONTACT INFO =====
      final contactInfoData = _safeParseMap(json['contactInfo'], {
        'name': '',
        'phone': '',
        'availableHours': '',
      });

      // ===== PARSE NEAREST POIs =====
      List<Map<String, dynamic>>? poisData;
      if (json['nearestPOIs'] is List) {
        poisData = (json['nearestPOIs'] as List).map((poi) {
          if (poi is! Map) return <String, dynamic>{};
          return {
            'name': poi['name']?.toString() ?? '',
            'category': poi['category']?.toString() ?? '',
            'icon': poi['icon']?.toString() ?? '📍',
            'distance': poi['distance']?.toString() ?? '0',
          };
        }).toList();
      }

      // ===== 🔥 FIX: PARSE EXPLANATION (String or Map) =====
      Map<String, dynamic>? explanationData;
      final explanationRaw = json['explanation'];

      if (explanationRaw != null) {
        if (explanationRaw is Map) {
          // Already a Map - use it
          explanationData = Map<String, dynamic>.from(explanationRaw);
        } else if (explanationRaw is String) {
          // String - wrap it in a Map
          explanationData = {
            'text': explanationRaw,
            'reason': explanationRaw,
          };
        }
      }

      // ===== PARSE LISTS =====
      final furniture = _safeParseStringList(json['furniture']);
      final amenities = _safeParseStringList(json['amenities']);
      final surroundings = _safeParseStringList(json['surroundings']);
      final images = _safeParseStringList(json['images']);
      final videos = _safeParseStringList(json['videos']);

      // ===== CREATE RENTAL INSTANCE =====
      return Rental(
        id: rentalId,
        title: json['title']?.toString() ?? '',
        price: _safeParseDouble(json['price']),
        area: parsedArea,
        location: locationData,
        nearestPOIs: poisData,
        propertyType: json['propertyType']?.toString() ?? 'Khác',
        furniture: furniture,
        amenities: amenities,
        surroundings: surroundings,
        rentalTerms: rentalTermsData,
        contactInfo: contactInfoData,
        userId: json['userId']?.toString() ?? '',
        images: images,
        videos: videos,
        status: json['status']?.toString() ?? 'available',
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
        landlord: json['userId']?.toString() ?? '',

        // PAYMENT FIELDS
        paymentTransactionCode: json['paymentInfo']?['transactionCode']?.toString(),
        paymentInfo: json['paymentInfo'] is Map
            ? Map<String, dynamic>.from(json['paymentInfo'] as Map)
            : null,
        publishedAt: json['publishedAt'] != null
            ? DateTime.tryParse(json['publishedAt'].toString())
            : null,

        // AI RECOMMENDATION FIELDS
        isAIRecommended: json['isAIRecommended'] as bool?,
        aiScore: _safeParseDouble(json['aiScore']),
        recommendationReason: json['recommendationReason']?.toString(),
        distanceKm: json['distanceKm']?.toString() ?? json['distance_km']?.toString(),
        locationBonus: _safeParseDouble(json['locationBonus']),
        finalScore: _safeParseDouble(json['finalScore']),

        // ADDITIONAL AI FIELDS
        preferenceBonus: _safeParseDouble(json['preferenceBonus']),
        timeBonus: _safeParseDouble(json['timeBonus']),
        confidence: _safeParseDouble(json['confidence']),
        markerPriority: json['markerPriority'] as int?,
        explanation: explanationData,  // 🔥 FIXED
        markerSize: _safeParseDouble(json['markerSize']),
        markerOpacity: _safeParseDouble(json['markerOpacity']),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Error parsing Rental from JSON: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('JSON data: $json');
      rethrow;
    }
  }

// Keep existing _parseDouble method
  static double? _parseDouble(dynamic value, String fieldName) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      final trimmed = value.trim().replaceAll(',', '.');
      if (trimmed.isEmpty) return null;
      return double.tryParse(trimmed);
    }
    return null;
  }

  // ==================== PAYMENT-RELATED METHODS ====================

  /// Check if rental requires payment before publishing
  bool needsPayment() {
    return paymentInfo == null || paymentInfo!['status'] != 'completed';
  }

  /// Get payment status info
  String getPaymentInfoDisplay() {
    if (paymentInfo == null) {
      return 'Chưa thanh toán';
    }

    final status = paymentInfo!['status'] as String?;
    switch (status) {
      case 'completed':
        return '✅ Đã thanh toán';
      case 'pending':
        return '⏳ Đang chờ thanh toán';
      case 'processing':
        return '🔄 Đang xử lý';
      case 'failed':
        return '❌ Thanh toán thất bại';
      case 'cancelled':
        return '🚫 Đã hủy';
      default:
        return 'Không xác định';
    }
  }

  /// Get published date formatted
  String getPublishedDateFormatted() {
    if (publishedAt == null) return 'Chưa xuất bản';

    final now = DateTime.now();
    final difference = now.difference(publishedAt!);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} phút trước';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} giờ trước';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} ngày trước';
    } else {
      return '${publishedAt!.day}/${publishedAt!.month}/${publishedAt!.year}';
    }
  }

  /// Check if rental is new (published within last 30 minutes)
  bool isNew() {
    if (publishedAt == null) return false;
    final now = DateTime.now();
    final difference = now.difference(publishedAt!);
    return difference.inMinutes < 30;
  }

  // ==================== AI-RELATED METHODS ====================

  /// Get AI recommendation badge text
  String getAIBadgeText() {
    if (isAIRecommended == true) {
      return '🤖 Gợi ý AI';
    }
    return '';
  }

  /// Get AI score formatted (0-100%)
  String getAIScoreFormatted() {
    if (aiScore == null) return '';
    final percentage = (aiScore! * 100).toStringAsFixed(0);
    return '$percentage%';
  }

  /// Get recommendation reason or default message
  String getRecommendationReason() {
    return recommendationReason ?? 'Phù hợp với sở thích của bạn';
  }

  /// Get detailed AI explanation summary
  String getAIExplanationSummary() {
    if (!hasAIMetadata) return 'Chưa có đánh giá';

    final scoreText = aiScoreExplanation;
    final confidenceText = confidenceDisplay;
    return '$scoreText • $confidenceText';
  }

  /// Get bonus factors breakdown as formatted string
  String getBonusFactorsDisplay() {
    final factors = bonusFactors;
    return factors.entries
        .map((e) => '${e.key}: ${e.value.toStringAsFixed(2)}x')
        .join(' | ');
  }

  /// Check if AI recommendation is high quality (confidence >= 0.7)
  bool get isHighQualityAIRecommendation =>
      confidence != null && confidence! >= 0.7;

  /// Check if AI recommendation is medium quality (0.5 <= confidence < 0.7)
  bool get isMediumQualityAIRecommendation =>
      confidence != null && confidence! >= 0.5 && confidence! < 0.7;

  /// Check if AI recommendation is low quality (confidence < 0.5)
  bool get isLowQualityAIRecommendation =>
      confidence != null && confidence! < 0.5;

  @override
  String toString() {
    return 'Rental(id: $id, title: $title, price: $price, status: $status, '
        'paymentStatus: $paymentStatus, isPublished: $isPublished, '
        'isAIRecommended: $isAIRecommended, aiScore: $aiScore, '
        'confidence: $confidence, finalScore: $finalScore)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Rental && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}