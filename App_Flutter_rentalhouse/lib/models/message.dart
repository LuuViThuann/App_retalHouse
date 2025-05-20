import 'dart:convert';

class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final List<String> images;
  final DateTime createdAt;
  final Map<String, dynamic> sender;

  Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.images,
    required this.createdAt,
    required this.sender,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    print('Parsing message JSON: $json');
    return Message(
      id: json['_id']?.toString() ?? '',
      conversationId: json['conversationId']?.toString() ?? '',
      senderId: json['senderId']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      images: List<String>.from(json['images'] ?? []),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      sender: {
        'id': json['sender']?['id']?.toString() ?? json['senderId']?.toString() ?? '',
        'username': json['sender']?['username']?.toString() ?? 'Unknown',
        'avatarBase64': json['sender']?['avatarBase64']?.toString() ?? '',
      },
    );
  }
}