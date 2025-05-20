class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final List<String> images;
  final DateTime createdAt;

  Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.images,
    required this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    print('Parsing message JSON: $json'); // Log để debug
    return Message(
      id: json['_id']?.toString() ?? '',
      conversationId: json['conversationId']?.toString() ?? '',
      senderId: json['senderId']?.toString() ?? '', // Directly use senderId as string
      content: json['content']?.toString() ?? '',
      images: List<String>.from(json['images'] ?? []),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}