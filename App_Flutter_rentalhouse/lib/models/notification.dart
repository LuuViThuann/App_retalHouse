class NotificationModel {
  final String id;
  final String type;
  final String message;
  final String content;
  final DateTime createdAt;
  final String rentalId;
  final String commentId;
  final String? postId;
  final String? userId;
  final String? username;

  NotificationModel({
    required this.id,
    required this.type,
    required this.message,
    required this.content,
    required this.createdAt,
    required this.rentalId,
    required this.commentId,
    this.postId,
    this.userId,
    this.username,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['_id']?.toString() ?? '',
      type: json['type'] ?? '',
      message: json['message'] ?? '',
      content: json['content'] ?? '',
      createdAt:
          DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      rentalId: json['rentalId']?.toString() ?? '',
      commentId: json['commentId']?.toString() ?? '',
      postId: json['postId']?.toString(),
      userId: json['userId']?.toString(),
      username: json['username']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'type': type,
      'message': message,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'rentalId': rentalId,
      'commentId': commentId,
      'postId': postId,
      'userId': userId,
      'username': username,
    };
  }
}
