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

  // 🔥 PAYMENT FIELDS
  final String? paymentTransactionCode;
  final Map<String, dynamic>? paymentInfo;
  final DateTime? publishedAt;

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
    // 🔥 PAYMENT PARAMETERS
    this.paymentTransactionCode,
    this.paymentInfo,
    this.publishedAt,
  });

  // 🔥 PAYMENT HELPER GETTERS
  bool get isPaid => paymentInfo?['status'] == 'completed';
  bool get isPublished => publishedAt != null;
  bool get requiresPayment => !isPaid;

  // 🔥 Get payment status info
  String get paymentStatus => paymentInfo?['status'] ?? 'pending';

  // 🔥 Get formatted payment amount
  String get formattedPaymentAmount {
    final amount = paymentInfo?['amount'] ?? 10000;
    return '${amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
    )} đ';
  }

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
    // 🔥 PAYMENT PARAMETERS
    String? paymentTransactionCode,
    Map<String, dynamic>? paymentInfo,
    DateTime? publishedAt,
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
      // 🔥 PAYMENT FIELDS
      paymentTransactionCode: paymentTransactionCode ?? this.paymentTransactionCode,
      paymentInfo: paymentInfo ?? this.paymentInfo,
      publishedAt: publishedAt ?? this.publishedAt,
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

    // 🔥 THÊM PAYMENT TRANSACTION CODE KHI TẠO MỚI
    if (paymentTransactionCode != null && paymentTransactionCode!.isNotEmpty)
      'paymentTransactionCode': paymentTransactionCode,
  };

  factory Rental.fromJson(Map<String, dynamic> json) {
    try {
      // Parse area
      Map<String, dynamic> areaData = {};
      if (json['area'] != null && json['area'] is Map) {
        areaData = {
          'total': _parseDouble(json['area']['total'], 'area.total') ?? 0.0,
          'livingRoom':
          _parseDouble(json['area']['livingRoom'], 'area.livingRoom') ?? 0.0,
          'bedrooms':
          _parseDouble(json['area']['bedrooms'], 'area.bedrooms') ?? 0.0,
          'bathrooms':
          _parseDouble(json['area']['bathrooms'], 'area.bathrooms') ?? 0.0,
        };
      } else {
        areaData = {
          'total': 0.0,
          'livingRoom': 0.0,
          'bedrooms': 0.0,
          'bathrooms': 0.0,
        };
      }

      // Parse location
      Map<String, dynamic> locationData = {};
      if (json['location'] != null && json['location'] is Map) {
        locationData['short'] = json['location']['short'] as String? ?? '';
        locationData['fullAddress'] =
            json['location']['fullAddress'] as String? ?? '';

        // Handle GeoJSON coordinates
        if (json['location']['coordinates'] != null &&
            json['location']['coordinates']['coordinates'] != null) {
          var coords = json['location']['coordinates']['coordinates'];
          if (coords is List && coords.length >= 2) {
            final lat = _parseDouble(coords[1], 'location.coordinates[1]');
            final lng = _parseDouble(coords[0], 'location.coordinates[0]');
            locationData['longitude'] = lng ?? 0.0;
            locationData['latitude'] = lat ?? 0.0;
          } else {
            locationData['longitude'] = 0.0;
            locationData['latitude'] = 0.0;
          }
        }
        // Handle direct latitude/longitude
        else if (json['location']['longitude'] != null &&
            json['location']['latitude'] != null) {
          locationData['longitude'] =
              _parseDouble(json['location']['longitude'], 'location.longitude') ?? 0.0;
          locationData['latitude'] =
              _parseDouble(json['location']['latitude'], 'location.latitude') ?? 0.0;
        }
        // Handle root-level coordinates
        else if (json['coordinates'] is List && json['coordinates'].length >= 2) {
          locationData['longitude'] =
              _parseDouble(json['coordinates'][0], 'coordinates[0]') ?? 0.0;
          locationData['latitude'] =
              _parseDouble(json['coordinates'][1], 'coordinates[1]') ?? 0.0;
        } else {
          locationData['longitude'] = 0.0;
          locationData['latitude'] = 0.0;
        }
      } else {
        locationData = {
          'short': '',
          'fullAddress': '',
          'longitude': 0.0,
          'latitude': 0.0,
        };
      }

      // Parse rentalTerms
      Map<String, dynamic> rentalTermsData = {};
      if (json['rentalTerms'] != null && json['rentalTerms'] is Map) {
        rentalTermsData = {
          'minimumLease': json['rentalTerms']['minimumLease'] as String? ?? '',
          'deposit': json['rentalTerms']['deposit'] as String? ?? '',
          'paymentMethod': json['rentalTerms']['paymentMethod'] as String? ?? '',
          'renewalTerms': json['rentalTerms']['renewalTerms'] as String? ?? '',
        };
      } else {
        rentalTermsData = {
          'minimumLease': '',
          'deposit': '',
          'paymentMethod': '',
          'renewalTerms': '',
        };
      }

      // Parse contactInfo
      Map<String, dynamic> contactInfoData = {};
      if (json['contactInfo'] != null && json['contactInfo'] is Map) {
        contactInfoData = {
          'name': json['contactInfo']['name'] as String? ?? '',
          'phone': json['contactInfo']['phone'] as String? ?? '',
          'availableHours': json['contactInfo']['availableHours'] as String? ?? '',
        };
      } else {
        contactInfoData = {
          'name': '',
          'phone': '',
          'availableHours': '',
        };
      }

      final price = _parseDouble(json['price'], 'price') ?? 0.0;

      return Rental(
        id: json['_id'] as String? ??
            (throw Exception('Rental ID is missing in JSON response')),
        title: json['title'] as String? ?? '',
        price: price,
        area: areaData,
        location: locationData,
        propertyType: json['propertyType'] as String? ?? 'Khác',
        furniture: List<String>.from(json['furniture'] as List? ?? []),
        amenities: List<String>.from(json['amenities'] as List? ?? []),
        surroundings: List<String>.from(json['surroundings'] as List? ?? []),
        rentalTerms: rentalTermsData,
        contactInfo: contactInfoData,
        userId: json['userId'] as String? ?? '',
        images: List<String>.from(json['images'] as List? ?? []),
        videos: List<String>.from(json['videos'] as List? ?? []),
        status: json['status'] as String? ?? 'available',
        createdAt: DateTime.parse(
            json['createdAt'] as String? ?? DateTime.now().toIso8601String()),
        landlord: json['userId'] as String? ?? '',

        // 🔥 PARSE PAYMENT INFO
        paymentTransactionCode: json['paymentInfo']?['transactionCode'] as String?,
        paymentInfo: json['paymentInfo'] != null
            ? Map<String, dynamic>.from(json['paymentInfo'] as Map)
            : null,
        publishedAt: json['publishedAt'] != null
            ? DateTime.parse(json['publishedAt'] as String)
            : null,
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Error parsing Rental from JSON: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('JSON data: $json');
      rethrow;
    }
  }

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

  // 🔥 ADDITIONAL HELPER METHODS

  /// Check if rental requires payment before publishing
  bool needsPayment() {
    return paymentInfo == null || paymentInfo!['status'] != 'completed';
  }

  /// Get payment info display string
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

  @override
  String toString() {
    return 'Rental(id: $id, title: $title, price: $price, status: $status, '
        'paymentStatus: $paymentStatus, isPublished: $isPublished)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Rental && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}