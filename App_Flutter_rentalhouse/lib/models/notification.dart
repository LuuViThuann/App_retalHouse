class NotificationModel {
  final String type;
  final String message;
  final String content;
  final DateTime createdAt;
  final String rentalId;
  final String commentId;

  NotificationModel({
    required this.type,
    required this.message,
    required this.content,
    required this.createdAt,
    required this.rentalId,
    required this.commentId,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      type: json['type'] ?? '',
      message: json['message'] ?? '',
      content: json['content'] ?? '',
      createdAt:
          DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      rentalId: json['rentalId'] ?? '',
      commentId: json['commentId'] ?? '',
    );
  }
}
