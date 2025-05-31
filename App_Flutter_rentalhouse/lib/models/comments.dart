import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/models/Reply.dart';

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
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      avatarBase64:
          avatarBase64 != null && avatarBase64.isNotEmpty ? avatarBase64 : null,
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
  String toString() =>
      'User(id: $id, username: $username, avatarBase64: ${avatarBase64?.substring(0, 20)}...)';
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

class Comment {
  final String id;
  final String rentalId;
  final User userId;
  final String content;
  final double rating;
  final List<String> images;
  final bool isHidden;
  final DateTime createdAt;
  final List<Reply> replies;
  final List<Like> likes;
  final String? rentalTitle; // Added for recent comments
  final String? type; // Added to distinguish Comment vs Reply

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
