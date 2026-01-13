class POI {
  final String id;
  final String osmId;
  final String category;
  final String categoryName;
  final String categoryIcon;
  final String name;
  final double latitude;
  final double longitude;
  final Map<String, dynamic> tags;
  final double? distance;
  final String address;

  POI({
    required this.id,
    required this.osmId,
    required this.category,
    required this.categoryName,
    required this.categoryIcon,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.tags,
    this.distance,
    required this.address,
  });

  factory POI.fromJson(Map<String, dynamic> json) {
    return POI(
      id: json['id'] ?? '',
      osmId: json['osmId']?.toString() ?? '',
      category: json['category'] ?? '',
      categoryName: json['categoryName'] ?? '',
      categoryIcon: json['categoryIcon'] ?? '📍',
      name: json['name'] ?? 'Không tên',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      tags: Map<String, dynamic>.from(json['tags'] ?? {}),
      distance: (json['distance'] as num?)?.toDouble(),
      address: json['address'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'osmId': osmId,
      'category': category,
      'categoryName': categoryName,
      'categoryIcon': categoryIcon,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'tags': tags,
      'distance': distance,
      'address': address,
    };
  }

  /// Tạo bản sao với các thuộc tính thay đổi
  POI copyWith({
    String? id,
    String? osmId,
    String? category,
    String? categoryName,
    String? categoryIcon,
    String? name,
    double? latitude,
    double? longitude,
    Map<String, dynamic>? tags,
    double? distance,
    String? address,
  }) {
    return POI(
      id: id ?? this.id,
      osmId: osmId ?? this.osmId,
      category: category ?? this.category,
      categoryName: categoryName ?? this.categoryName,
      categoryIcon: categoryIcon ?? this.categoryIcon,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      tags: tags ?? this.tags,
      distance: distance ?? this.distance,
      address: address ?? this.address,
    );
  }

  /// Kiểm tra POI có tọa độ hợp lệ
  bool get hasValidCoordinates {
    return latitude != 0.0 &&
        longitude != 0.0 &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }

  /// So sánh hai POI
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is POI &&
              runtimeType == other.runtimeType &&
              id == other.id &&
              osmId == other.osmId;

  @override
  int get hashCode => id.hashCode ^ osmId.hashCode;

  @override
  String toString() {
    return 'POI(id: $id, name: $name, category: $category, distance: $distance km)';
  }
}

/// 🏷️ Model cho POI Category
class POICategory {
  final String id;
  final String name;
  final String icon;
  final List<String> tags;

  POICategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.tags,
  });

  factory POICategory.fromJson(Map<String, dynamic> json) {
    return POICategory(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      icon: json['icon'] ?? '📍',
      tags: List<String>.from(json['tags'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'tags': tags,
    };
  }

  /// Tạo bản sao với các thuộc tính thay đổi
  POICategory copyWith({
    String? id,
    String? name,
    String? icon,
    List<String>? tags,
  }) {
    return POICategory(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      tags: tags ?? this.tags,
    );
  }

  /// So sánh hai category
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is POICategory &&
              runtimeType == other.runtimeType &&
              id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'POICategory(id: $id, name: $name, icon: $icon)';
}

/// 🗺️ Model cho POI hiển thị trên bản đồ (filter result)
class POIOnMap {
  final String id;
  final String name;
  final String category;
  final String categoryName;
  final String categoryIcon;
  final double latitude;
  final double longitude;
  final bool hasNearbyRentals;

  POIOnMap({
    required this.id,
    required this.name,
    required this.category,
    required this.categoryName,
    required this.categoryIcon,
    required this.latitude,
    required this.longitude,
    required this.hasNearbyRentals,
  });

  factory POIOnMap.fromJson(Map<String, dynamic> json) {
    return POIOnMap(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      category: json['category'] ?? '',
      categoryName: json['categoryName'] ?? '',
      categoryIcon: json['categoryIcon'] ?? '📍',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      hasNearbyRentals: json['hasNearbyRentals'] ?? false,
    );
  }

  /// Tạo POIOnMap từ POI
  factory POIOnMap.fromPOI(POI poi, {required bool hasNearbyRentals}) {
    return POIOnMap(
      id: poi.id,
      name: poi.name,
      category: poi.category,
      categoryName: poi.categoryName,
      categoryIcon: poi.categoryIcon,
      latitude: poi.latitude,
      longitude: poi.longitude,
      hasNearbyRentals: hasNearbyRentals,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'categoryName': categoryName,
      'categoryIcon': categoryIcon,
      'latitude': latitude,
      'longitude': longitude,
      'hasNearbyRentals': hasNearbyRentals,
    };
  }

  /// Tạo bản sao với các thuộc tính thay đổi
  POIOnMap copyWith({
    String? id,
    String? name,
    String? category,
    String? categoryName,
    String? categoryIcon,
    double? latitude,
    double? longitude,
    bool? hasNearbyRentals,
  }) {
    return POIOnMap(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      categoryName: categoryName ?? this.categoryName,
      categoryIcon: categoryIcon ?? this.categoryIcon,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      hasNearbyRentals: hasNearbyRentals ?? this.hasNearbyRentals,
    );
  }

  /// Kiểm tra POI có tọa độ hợp lệ
  bool get hasValidCoordinates {
    return latitude != 0.0 &&
        longitude != 0.0 &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }

  /// So sánh hai POI
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is POIOnMap &&
              runtimeType == other.runtimeType &&
              id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'POIOnMap(id: $id, name: $name, hasNearbyRentals: $hasNearbyRentals)';
  }
}

/// 📊 Model cho filter result với rentals + POIs
class POIFilterResult {
  final List<dynamic> rentals; // List<Rental>
  final List<POIOnMap> pois;
  final int total;
  final int poisTotal;
  final List<String> selectedCategories;
  final double radius;
  final String message;
  final bool success;

  POIFilterResult({
    required this.rentals,
    required this.pois,
    required this.total,
    required this.poisTotal,
    required this.selectedCategories,
    required this.radius,
    required this.message,
    this.success = true,
  });

  factory POIFilterResult.fromJson(Map<String, dynamic> json) {
    return POIFilterResult(
      rentals: json['rentals'] ?? [],
      pois: (json['pois'] as List?)
          ?.map((p) => POIOnMap.fromJson(p))
          .toList() ??
          [],
      total: json['total'] ?? 0,
      poisTotal: json['poisTotal'] ?? 0,
      selectedCategories: List<String>.from(json['selectedCategories'] ?? []),
      radius: (json['radius'] as num?)?.toDouble() ?? 3.0,
      message: json['message'] ?? '',
      success: json['success'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rentals': rentals,
      'pois': pois.map((p) => p.toJson()).toList(),
      'total': total,
      'poisTotal': poisTotal,
      'selectedCategories': selectedCategories,
      'radius': radius,
      'message': message,
      'success': success,
    };
  }

  /// Kiểm tra có kết quả nào không
  bool get isEmpty => rentals.isEmpty && pois.isEmpty;

  /// Kiểm tra có POI nào không
  bool get hasPOIs => pois.isNotEmpty;

  /// Kiểm tra có rental nào không
  bool get hasRentals => rentals.isNotEmpty;

  /// Tạo bản sao với các thuộc tính thay đổi
  POIFilterResult copyWith({
    List<dynamic>? rentals,
    List<POIOnMap>? pois,
    int? total,
    int? poisTotal,
    List<String>? selectedCategories,
    double? radius,
    String? message,
    bool? success,
  }) {
    return POIFilterResult(
      rentals: rentals ?? this.rentals,
      pois: pois ?? this.pois,
      total: total ?? this.total,
      poisTotal: poisTotal ?? this.poisTotal,
      selectedCategories: selectedCategories ?? this.selectedCategories,
      radius: radius ?? this.radius,
      message: message ?? this.message,
      success: success ?? this.success,
    );
  }

  @override
  String toString() {
    return 'POIFilterResult(rentals: $total, pois: $poisTotal, categories: ${selectedCategories.length}, radius: ${radius}km)';
  }
}

/// 🎯 Model cho nearest POI trong rental
class NearestPOI {
  final String name;
  final String category;
  final String icon;
  final String distance;

  NearestPOI({
    required this.name,
    required this.category,
    required this.icon,
    required this.distance,
  });

  factory NearestPOI.fromJson(Map<String, dynamic> json) {
    return NearestPOI(
      name: json['name'] ?? '',
      category: json['category'] ?? '',
      icon: json['icon'] ?? '📍',
      distance: json['distance']?.toString() ?? '0',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'category': category,
      'icon': icon,
      'distance': distance,
    };
  }

  /// Tạo bản sao với các thuộc tính thay đổi
  NearestPOI copyWith({
    String? name,
    String? category,
    String? icon,
    String? distance,
  }) {
    return NearestPOI(
      name: name ?? this.name,
      category: category ?? this.category,
      icon: icon ?? this.icon,
      distance: distance ?? this.distance,
    );
  }

  /// Lấy khoảng cách dưới dạng double
  double get distanceInKm {
    return double.tryParse(distance) ?? 0.0;
  }

  @override
  String toString() => 'NearestPOI(name: $name, distance: ${distance}km)';
}