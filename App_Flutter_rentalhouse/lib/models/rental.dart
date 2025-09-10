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
  final String status;
  final DateTime createdAt;
  final String landlord;

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
    required this.status,
    required this.createdAt,
    required this.landlord,
  });

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
    String? status,
    DateTime? createdAt,
    String? landlord,
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
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      landlord: landlord ?? this.landlord,
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
        'rentalTerms': {
          'minimumLease': rentalTerms['minimumLease'],
          'deposit': rentalTerms['deposit'],
          'paymentMethod': rentalTerms['paymentMethod'],
          'renewalTerms': rentalTerms['renewalTerms'],
        },
        'contactInfo': {
          'name': contactInfo['name'],
          'phone': contactInfo['phone'],
          'availableHours': contactInfo['availableHours'],
        },
        'userId': userId,
        'images': images,
        'status': status,
        'createdAt': createdAt.toIso8601String(),
        'landlord': landlord,
      };

  factory Rental.fromJson(Map<String, dynamic> json) {
    try {
      // Parse area với null check
      Map<String, dynamic> areaData = {};
      if (json['area'] != null && json['area'] is Map) {
        areaData = {
          'total': (json['area']['total'] as num?)?.toDouble() ?? 0.0,
          'livingRoom': (json['area']['livingRoom'] as num?)?.toDouble() ?? 0.0,
          'bedrooms': (json['area']['bedrooms'] as num?)?.toDouble() ?? 0.0,
          'bathrooms': (json['area']['bathrooms'] as num?)?.toDouble() ?? 0.0,
        };
      } else {
        // Fallback cho nearby API (không có area)
        areaData = {
          'total': 0.0,
          'livingRoom': 0.0,
          'bedrooms': 0.0,
          'bathrooms': 0.0,
        };
      }

      // Parse location với nhiều format
      Map<String, dynamic> locationData = {};
      if (json['location'] != null && json['location'] is Map) {
        locationData['short'] = json['location']['short'] as String? ?? '';
        locationData['fullAddress'] =
            json['location']['fullAddress'] as String? ?? '';

        // Xử lý coordinates - format GeoJSON
        if (json['location']['coordinates'] != null &&
            json['location']['coordinates']['coordinates'] != null) {
          var coords = json['location']['coordinates']['coordinates'];
          if (coords is List && coords.length >= 2) {
            locationData['longitude'] = (coords[0] as num?)?.toDouble() ?? 0.0;
            locationData['latitude'] = (coords[1] as num?)?.toDouble() ?? 0.0;
          }
        }
        // Fallback: coordinates trực tiếp trong location (từ nearby API)
        else if (json['location']['longitude'] != null &&
            json['location']['latitude'] != null) {
          locationData['longitude'] =
              (json['location']['longitude'] as num?)?.toDouble() ?? 0.0;
          locationData['latitude'] =
              (json['location']['latitude'] as num?)?.toDouble() ?? 0.0;
        }
        // Fallback: coordinates array ở root level (từ nearby API)
        else if (json['coordinates'] is List &&
            json['coordinates'].length >= 2) {
          locationData['longitude'] =
              (json['coordinates'][0] as num?)?.toDouble() ?? 0.0;
          locationData['latitude'] =
              (json['coordinates'][1] as num?)?.toDouble() ?? 0.0;
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

      // Parse rentalTerms với null check
      Map<String, dynamic> rentalTermsData = {};
      if (json['rentalTerms'] != null && json['rentalTerms'] is Map) {
        rentalTermsData = {
          'minimumLease': json['rentalTerms']['minimumLease'] as String? ?? '',
          'deposit': json['rentalTerms']['deposit'] as String? ?? '',
          'paymentMethod':
              json['rentalTerms']['paymentMethod'] as String? ?? '',
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

      // Parse contactInfo với null check
      Map<String, dynamic> contactInfoData = {};
      if (json['contactInfo'] != null && json['contactInfo'] is Map) {
        contactInfoData = {
          'name': json['contactInfo']['name'] as String? ?? '',
          'phone': json['contactInfo']['phone'] as String? ?? '',
          'availableHours':
              json['contactInfo']['availableHours'] as String? ?? '',
        };
      } else {
        contactInfoData = {
          'name': '',
          'phone': '',
          'availableHours': '',
        };
      }

      return Rental(
        id: json['_id'] as String? ??
            (throw Exception('Rental ID is missing in JSON response')),
        title: json['title'] as String? ?? '',
        price: (json['price'] as num?)?.toDouble() ?? 0.0,
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
        status: json['status'] as String? ?? 'available',
        createdAt: DateTime.parse(
            json['createdAt'] as String? ?? DateTime.now().toIso8601String()),
        landlord: json['userId'] as String? ?? '',
      );
    } catch (e, stackTrace) {
      debugPrint('Error parsing Rental from JSON: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('JSON data: $json');
      rethrow;
    }
  }
}
