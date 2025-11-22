class BannerModel {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final String? link;
  final bool isActive;
  final int position;
  final DateTime createdAt;
  final DateTime updatedAt;

  BannerModel({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    this.link,
    required this.isActive,
    required this.position,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Tạo full URL cho ảnh
  String getFullImageUrl(String baseUrl) {
    if (imageUrl.startsWith('http')) {
      return imageUrl; // Nếu đã là full URL
    }
    // Nếu chỉ là path, thêm base URL
    if (imageUrl.startsWith('/')) {
      return '$baseUrl$imageUrl';
    }
    return '$baseUrl/$imageUrl';
  }

  factory BannerModel.fromJson(Map<String, dynamic> json) {
    try {
      return BannerModel(
        id: json['_id']?.toString() ?? '',
        title: (json['title'] ?? '').toString().trim(),
        description: (json['description'] ?? '').toString().trim(),
        imageUrl: (json['imageUrl'] ?? '').toString().trim(),
        link: json['link'] != null ? json['link'].toString().trim() : null,
        isActive: json['isActive'] == true || json['isActive'] == 'true',
        position: int.tryParse(json['position'].toString()) ?? 0,
        createdAt: _parseDateTime(json['createdAt']),
        updatedAt: _parseDateTime(json['updatedAt']),
      );
    } catch (e) {
      throw Exception('Error parsing banner: $e');
    }
  }

  static DateTime _parseDateTime(dynamic dateValue) {
    try {
      if (dateValue == null) return DateTime.now();
      if (dateValue is DateTime) return dateValue;
      if (dateValue is String) return DateTime.parse(dateValue);
      return DateTime.now();
    } catch (e) {
      return DateTime.now();
    }
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'link': link,
      'isActive': isActive,
      'position': position,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  @override
  String toString() =>
      'BannerModel(id: $id, title: $title, imageUrl: $imageUrl, isActive: $isActive)';
}
