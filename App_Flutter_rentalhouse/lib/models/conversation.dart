import 'package:flutter_rentalhouse/models/message.dart';

class Conversation {
  final String id;
  final List<String> participants;
  final String rentalId;
  final Message? lastMessage;
  final bool isPending;
  final DateTime createdAt;
  final DateTime updatedAt;

  Conversation({
    required this.id,
    required this.participants,
    required this.rentalId,
    this.lastMessage,
    required this.isPending,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['_id'] as String,
      participants: List<String>.from(json['participants'] as List),
      rentalId: json['rentalId'] as String,
      lastMessage: json['lastMessage'] != null ? Message.fromJson(json['lastMessage']) : null,
      isPending: json['isPending'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}