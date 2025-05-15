import 'package:flutter/material.dart';
import 'dart:convert';

class User {
  final String id;
  final String? username;
  final String? avatarBase64;

  User({
    required this.id,
    this.username,
    this.avatarBase64,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      avatarBase64: json['avatarBase64']?.toString(),
    );
  }

  String? get processedAvatarBase64 {
    if (avatarBase64 == null || avatarBase64!.isEmpty) return null;
    // Remove any data URI prefix if present (e.g., "data:image/jpeg;base64,")
    return avatarBase64!.contains(',') ? avatarBase64!.split(',')[1] : avatarBase64;
  }
}

class Like {
  final String userId;

  Like({required this.userId});

  factory Like.fromJson(Map<String, dynamic> json) {
    return Like(
      userId: json['userId']?.toString() ?? '',
    );
  }
}

class Reply {
  final User userId;
  final String content;
  final DateTime createdAt;

  Reply({
    required this.userId,
    required this.content,
    required this.createdAt,
  });

  factory Reply.fromJson(Map<String, dynamic> json) {
    return Reply(
      userId: User.fromJson(json['userId'] is String ? {'_id': json['userId']} : (json['userId'] ?? {})),
      content: json['content']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class Comment {
  final String id;
  final String rentalId;
  final User userId;
  final String content;
  final DateTime createdAt;
  final List<Reply> replies;
  final List<Like> likes;

  Comment({
    required this.id,
    required this.rentalId,
    required this.userId,
    required this.content,
    required this.createdAt,
    required this.replies,
    required this.likes,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    print('Parsing comment JSON: $json');
    return Comment(
      id: json['_id']?.toString() ?? '',
      rentalId: json['rentalId']?.toString() ?? '',
      userId: User.fromJson(json['userId'] ?? {}),
      content: json['content']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      replies: (json['replies'] as List<dynamic>?)
          ?.map((reply) => Reply.fromJson(reply))
          .toList() ?? [],
      likes: (json['likes'] as List<dynamic>?)
          ?.map((like) => Like.fromJson(like))
          .toList() ?? [],
    );
  }
}