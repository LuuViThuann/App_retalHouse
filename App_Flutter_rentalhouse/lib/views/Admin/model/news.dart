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

  /// Kiểm tra có phải ảnh Cloudinary không
  bool get isCloudinaryImage {
    return imageUrl.contains('cloudinary.com');
  }

  /// Đếm số ảnh
  int get imageCount => imageUrls.length;

  /// Lấy full URL ảnh theo index
  String getFullImageUrl(String baseUrl, {int index = 0}) {
    if (imageUrls.isEmpty) return '';

    final url = index < imageUrls.length ? imageUrls[index] : imageUrls[0];

    // Nếu đã là full URL (Cloudinary hoặc HTTP), trả về luôn
    if (url.startsWith('http')) {
      return url;
    }

    // Nếu là path local, thêm baseUrl
    if (url.startsWith('/')) {
      return '$baseUrl$url';
    }
    return '$baseUrl/$url';
  }

  /// Lấy tất cả full URLs
  List<String> getAllFullImageUrls(String baseUrl) {
    return imageUrls.map((url) {
      if (url.startsWith('http')) return url; // Cloudinary URL
      if (url.startsWith('/')) return '$baseUrl$url';
      return '$baseUrl/$url';
    }).toList();
  }

  factory NewsModel.fromJson(Map<String, dynamic> json) {
    try {
      // Xử lý imageUrls với 3 nguồn: images (mới), imageUrls (cũ), imageUrl (fallback)
      List<String> urls = [];

      // 1. Ưu tiên: Parse từ "images" array (format Cloudinary mới)
      if (json['images'] != null && json['images'] is List) {
        final imagesList = json['images'] as List;
        urls = imagesList
            .map((img) {
          if (img is Map<String, dynamic> && img['url'] != null) {
            return img['url'].toString().trim();
          } else if (img is String) {
            return img.trim();
          }
          return '';
        })
            .where((url) => url.isNotEmpty)
            .toList();
      }

      // 2. Fallback: Parse từ "imageUrls" (format cũ)
      if (urls.isEmpty && json['imageUrls'] != null && json['imageUrls'] is List) {
        urls = (json['imageUrls'] as List)
            .map((url) => url.toString().trim())
            .where((url) => url.isNotEmpty)
            .toList();
      }

      // 3. Fallback cuối: Lấy từ "imageUrl" đơn
      if (urls.isEmpty && json['imageUrl'] != null) {
        final singleUrl = json['imageUrl'].toString().trim();
        if (singleUrl.isNotEmpty) {
          urls = [singleUrl];
        }
      }

      // Đảm bảo có ít nhất 1 URL (empty string nếu không có)
      if (urls.isEmpty) {
        urls = [''];
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
        views: int.tryParse(json['views']?.toString() ?? '0') ?? 0,
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

  /// Copy with method (hữu ích khi cập nhật local)
  NewsModel copyWith({
    String? id,
    String? title,
    String? content,
    String? summary,
    List<String>? imageUrls,
    String? imageUrl,
    String? author,
    String? category,
    bool? isActive,
    int? views,
    bool? featured,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NewsModel(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      summary: summary ?? this.summary,
      imageUrls: imageUrls ?? this.imageUrls,
      imageUrl: imageUrl ?? this.imageUrl,
      author: author ?? this.author,
      category: category ?? this.category,
      isActive: isActive ?? this.isActive,
      views: views ?? this.views,
      featured: featured ?? this.featured,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'NewsModel(id: $id, title: $title, images: ${imageUrls.length}, featured: $featured, cloudinary: $isCloudinaryImage)';
}