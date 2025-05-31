import 'package:flutter_rentalhouse/models/comments.dart';

class Reply {
  final String id;
  final String commentId;
  final String? parentReplyId;
  final User userId;
  final String content;
  final List<String> images;
  final String icon;
  final DateTime createdAt;
  final List<Like> likes;
  final List<Reply> replies;

  const Reply({
    required this.id,
    required this.commentId,
    this.parentReplyId,
    required this.userId,
    required this.content,
    required this.images,
    required this.icon,
    required this.createdAt,
    required this.likes,
    required this.replies,
  });

  factory Reply.fromJson(Map<String, dynamic> json) {
    return Reply(
      id: json['_id']?.toString() ?? '',
      commentId: json['commentId']?.toString() ?? '',
      parentReplyId: json['parentReplyId']?.toString(),
      userId: User.fromJson(json['userId'] is String
          ? {'_id': json['userId']}
          : (json['userId'] ?? {})),
      content: json['content']?.toString() ?? '',
      images: (json['images'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      icon: json['icon']?.toString() ?? '/assets/img/arr.jpg',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      likes: (json['likes'] as List<dynamic>?)
              ?.map((like) => Like.fromJson(like))
              .toList() ??
          [],
      replies: (json['replies'] as List<dynamic>?)
              ?.map((reply) => Reply.fromJson(reply))
              .toList() ??
          [],
    );
  }

  @override
  String toString() =>
      'Reply(id: $id, commentId: $commentId, parentReplyId: $parentReplyId, userId: $userId, content: $content, images: $images, icon: $icon, createdAt: $createdAt, likes: $likes, replies: $replies)';
}
