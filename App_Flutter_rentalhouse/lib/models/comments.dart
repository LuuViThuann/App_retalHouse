import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/models/Reply.dart';

class User {
  final String id;
  final String username;
  final String? avatarUrl; // ✅ Đổi từ avatarBase64 → avatarUrl

  const User({
    required this.id,
    this.username = '',
    this.avatarUrl,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    // ✅ Backend có thể trả về 2 field: avatarBase64 (cũ) hoặc avatarUrl (mới)
    // Ưu tiên avatarUrl nếu có
    final avatarUrl = json['avatarUrl']?.toString();
    final avatarBase64 = json['avatarBase64']?.toString();

    return User(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      avatarUrl: avatarUrl ?? avatarBase64, // Fallback nếu vẫn còn base64
    );
  }

  // ✅ Không cần decode base64 nữa vì đã là URL
  // Giữ lại để backward compatible
  Uint8List? get avatarBytes {
    if (avatarUrl == null || avatarUrl!.isEmpty) return null;

    // Nếu là URL (bắt đầu với http/https), trả về null
    if (avatarUrl!.startsWith('http')) return null;

    // Nếu vẫn là base64, decode
    try {
      final data = avatarUrl!.contains(',')
          ? avatarUrl!.split(',')[1]
          : avatarUrl!;
      return base64Decode(data);
    } catch (e) {
      print('Error decoding avatar for user $id: $e');
      return null;
    }
  }

  // ✅ Helper để check xem avatar có phải URL không
  bool get isAvatarUrl => avatarUrl?.startsWith('http') ?? false;

  @override
  String toString() =>
      'User(id: $id, username: $username, avatarUrl: ${avatarUrl?.substring(0, 30)}...)';
}

class Like {
  final String userId;
  final String? username; // ✅ Thêm để hiển thị tên người like
  final String? avatarUrl; // ✅ Thêm để hiển thị avatar người like

  const Like({
    required this.userId,
    this.username,
    this.avatarUrl,
  });

  factory Like.fromJson(Map<String, dynamic> json) {
    // Backend trả về userId như object hoặc string
    if (json['userId'] is Map) {
      final userObj = json['userId'] as Map<String, dynamic>;
      return Like(
        userId: userObj['_id']?.toString() ?? '',
        username: userObj['username']?.toString(),
        avatarUrl: userObj['avatarUrl']?.toString() ?? userObj['avatarBase64']?.toString(),
      );
    }
    return Like(
      userId: json['userId']?.toString() ?? '',
      username: json['username']?.toString(),
      avatarUrl: json['avatarUrl']?.toString() ?? json['avatarBase64']?.toString(),
    );
  }

  @override
  String toString() => 'Like(userId: $userId, username: $username)';
}

class Comment {
  final String id;
  final String rentalId;
  final User userId;
  final String content;
  final double rating;
  final List<String> images; // ✅ Đã là URL từ Cloudinary
  final bool isHidden;
  final DateTime createdAt;
  final List<Reply> replies;
  final List<Like> likes;
  final String? rentalTitle;
  final String? type;

  const Comment({
    required this.id,
    required this.rentalId,
    required this.userId,
    required this.content,
    required this.rating,
    required this.images,
    required this.isHidden,
    required this.createdAt,
    required this.replies,
    required this.likes,
    this.rentalTitle,
    this.type,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    try {
      return Comment(
        id: json['_id']?.toString() ?? '',
        rentalId: json['rentalId'] is Map
            ? json['rentalId']['_id']?.toString() ?? ''
            : json['rentalId']?.toString() ?? '',
        userId: User.fromJson(json['userId'] ?? {}),
        content: json['content']?.toString() ?? '',
        rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
        images: (json['images'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
            [],
        isHidden: json['isHidden'] == true,
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
            DateTime.now(),
        replies: (json['replies'] as List<dynamic>?)
            ?.map((reply) => Reply.fromJson(reply))
            .toList() ??
            [],
        likes: (json['likes'] as List<dynamic>?)
            ?.map((like) => Like.fromJson(like))
            .toList() ??
            [],
        rentalTitle: json['rentalTitle']?.toString(),
        type: json['type']?.toString(),
      );
    } catch (e) {
      print('Error parsing comment JSON: $json\nError: $e');
      rethrow;
    }
  }

  @override
  String toString() =>
      'Comment(id: $id, rentalId: $rentalId, userId: $userId, content: $content, rating: $rating, images: $images, isHidden: $isHidden, createdAt: $createdAt, replies: $replies, likes: $likes, rentalTitle: $rentalTitle, type: $type)';
}