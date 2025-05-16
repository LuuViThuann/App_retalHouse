import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class User {
  final String id;
  final String username;
  final String? avatarBase64;

  const User({
    required this.id,
    this.username = '',
    this.avatarBase64,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    final avatarBase64 = json['avatarBase64']?.toString();
    return User(
      id: json['_id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      avatarBase64: avatarBase64 != null && avatarBase64.isNotEmpty ? avatarBase64 : null,
    );
  }

  Uint8List? get avatarBytes {
    if (avatarBase64 == null || avatarBase64!.isEmpty) return null;
    try {
      final data = avatarBase64!.contains(',')
          ? avatarBase64!.split(',')[1]
          : avatarBase64!;
      return base64Decode(data);
    } catch (e) {
      print('Error decoding avatarBase64 for user $id: $e');
      return null;
    }
  }

  @override
  String toString() => 'User(id: $id, username: $username, avatarBase64: ${avatarBase64?.substring(0, 20)}...)';
}

class Like {
  final String userId;

  const Like({required this.userId});

  factory Like.fromJson(Map<String, dynamic> json) {
    return Like(userId: json['userId']?.toString() ?? '');
  }

  @override
  String toString() => 'Like(userId: $userId)';
}

class Reply {
  final String id;
  final User userId;
  final String content;
  final DateTime createdAt;
  final List<Like> likes; // Added likes field

  const Reply({
    required this.id,
    required this.userId,
    required this.content,
    required this.createdAt,
    required this.likes,
  });

  factory Reply.fromJson(Map<String, dynamic> json) {
    return Reply(
      id: json['_id']?.toString() ?? '',
      userId: User.fromJson(json['userId'] is String ? {'_id': json['userId']} : (json['userId'] ?? {})),
      content: json['content']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      likes: (json['likes'] as List<dynamic>?)?.map((like) => Like.fromJson(like)).toList() ?? [], // Handle likes field
    );
  }

  @override
  String toString() => 'Reply(id: $id, userId: $userId, content: $content, createdAt: $createdAt, likes: $likes)';
}

class Comment {
  final String id;
  final String rentalId;
  final User userId;
  final String content;
  final double rating;
  final List<String> images;
  final DateTime createdAt;
  final List<Reply> replies;
  final List<Like> likes;

  const Comment({
    required this.id,
    required this.rentalId,
    required this.userId,
    required this.content,
    required this.rating,
    required this.images,
    required this.createdAt,
    required this.replies,
    required this.likes,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    try {
      return Comment(
        id: json['_id']?.toString() ?? '',
        rentalId: json['rentalId']?.toString() ?? '',
        userId: User.fromJson(json['userId'] ?? {}),
        content: json['content']?.toString() ?? '',
        rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
        images: (json['images'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
        replies: (json['replies'] as List<dynamic>?)
            ?.map((reply) => Reply.fromJson(reply))
            .toList() ?? [],
        likes: (json['likes'] as List<dynamic>?)
            ?.map((like) => Like.fromJson(like))
            .toList() ?? [],
      );
    } catch (e) {
      print('Error parsing comment JSON: $json\nError: $e');
      rethrow;
    }
  }

  @override
  String toString() => 'Comment(id: $id, rentalId: $rentalId, userId: $userId, content: $content, rating: $rating, images: $images, createdAt: $createdAt, replies: $replies, likes: $likes)';
}