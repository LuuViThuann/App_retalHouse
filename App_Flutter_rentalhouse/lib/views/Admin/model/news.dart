// models/news_model.dart
class NewsModel {
  final String id;
  final String title;
  final String content; // JSON Delta format
  final String summary;
  final String imageUrl;
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
    required this.imageUrl,
    required this.author,
    required this.category,
    required this.isActive,
    required this.views,
    required this.featured,
    required this.createdAt,
    required this.updatedAt,
  });

  String getFullImageUrl(String baseUrl) {
    if (imageUrl.startsWith('http')) {
      return imageUrl;
    }
    if (imageUrl.startsWith('/')) {
      return '$baseUrl$imageUrl';
    }
    return '$baseUrl/$imageUrl';
  }

  factory NewsModel.fromJson(Map<String, dynamic> json) {
    try {
      return NewsModel(
        id: json['_id']?.toString() ?? '',
        title: (json['title'] ?? '').toString().trim(),
        content: (json['content'] ?? '').toString(),
        summary: (json['summary'] ?? '').toString().trim(),
        imageUrl: (json['imageUrl'] ?? '').toString().trim(),
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
      'NewsModel(id: $id, title: $title, featured: $featured, views: $views)';
}
