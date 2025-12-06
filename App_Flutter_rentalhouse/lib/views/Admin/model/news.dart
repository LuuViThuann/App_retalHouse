// models/news_model.dart
class NewsModel {
  final String id;
  final String title;
  final String content;
  final String summary;
  final List<String> imageUrls; // Nhiều ảnh
  final String imageUrl; // Ảnh đầu tiên (tương thích)
  final String author;
  final String category;
  final bool isActive;
  final int views;
  final bool featured;
  final DateTime createdAt;
  final DateTime updatedAt;

  NewsModel({
    required this.id,
    required this.title,
    required this.content,
    required this.summary,
    required this.imageUrls,
    required this.imageUrl,
    required this.author,
    required this.category,
    required this.isActive,
    required this.views,
    required this.featured,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Lấy full URL ảnh
  String getFullImageUrl(String baseUrl, {int index = 0}) {
    if (imageUrls.isEmpty) return '';

    final url = index < imageUrls.length ? imageUrls[index] : imageUrls[0];

    if (url.startsWith('http')) {
      return url;
    }
    if (url.startsWith('/')) {
      return '$baseUrl$url';
    }
    return '$baseUrl/$url';
  }

  /// Lấy tất cả full URLs
  List<String> getAllFullImageUrls(String baseUrl) {
    return imageUrls.map((url) {
      if (url.startsWith('http')) return url;
      if (url.startsWith('/')) return '$baseUrl$url';
      return '$baseUrl/$url';
    }).toList();
  }

  factory NewsModel.fromJson(Map<String, dynamic> json) {
    try {
      // Xử lý imageUrls (mảng hoặc string cũ)
      List<String> urls = [];

      if (json['imageUrls'] is List) {
        urls = List<String>.from(json['imageUrls']);
      } else if (json['imageUrl'] is String) {
        urls = [(json['imageUrl'] as String).trim()];
      }

      return NewsModel(
        id: json['_id']?.toString() ?? '',
        title: (json['title'] ?? '').toString().trim(),
        content: (json['content'] ?? '').toString(),
        summary: (json['summary'] ?? '').toString().trim(),
        imageUrls: urls,
        imageUrl: urls.isNotEmpty ? urls[0] : '',
        author: (json['author'] ?? 'Admin').toString().trim(),
        category: (json['category'] ?? 'Tin tức').toString().trim(),
        isActive: json['isActive'] == true || json['isActive'] == 'true',
        views: int.tryParse(json['views'].toString()) ?? 0,
        featured: json['featured'] == true || json['featured'] == 'true',
        createdAt: _parseDateTime(json['createdAt']),
        updatedAt: _parseDateTime(json['updatedAt']),
      );
    } catch (e) {
      throw Exception('Error parsing news: $e');
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
      'content': content,
      'summary': summary,
      'imageUrls': imageUrls,
      'imageUrl': imageUrl,
      'author': author,
      'category': category,
      'isActive': isActive,
      'views': views,
      'featured': featured,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  @override
  String toString() =>
      'NewsModel(id: $id, title: $title, images: ${imageUrls.length}, featured: $featured)';
}