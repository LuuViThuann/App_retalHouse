import 'package:flutter_rentalhouse/models/message.dart';

class Conversation {
  final String id;
  final String rentalId;
  final List<String> participants;
  final Message? lastMessage;
  final bool isPending;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic> landlord;
  final Map<String, dynamic>? rental;
  final int unreadCount;

  Conversation({
    required this.id,
    required this.rentalId,
    required this.participants,
    this.lastMessage,
    required this.isPending,
    required this.createdAt,
    this.updatedAt,
    required this.landlord,
    this.rental,
    required this.unreadCount,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    print('Parsing conversation JSON: $json');
    return Conversation(
      id: json['_id']?.toString() ?? '',
      rentalId: json['rentalId']?.toString() ?? '',
      participants: List<String>.from(
          json['participants']?.map((id) => id.toString()) ?? []),
      lastMessage: json['lastMessage'] != null
          ? Message.fromJson(json['lastMessage'] as Map<String, dynamic>)
          : null,
      isPending: json['isPending'] as bool? ?? true,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt']?.toString() ?? '')
          : null,
      landlord: {
        'id': json['landlord']?['id']?.toString() ?? '',
        'username': json['landlord']?['username']?.toString() ?? 'Unknown',
        'avatarBase64': json['landlord']?['avatarBase64']?.toString() ?? '',
      },
      rental: json['rental'] != null
          ? {
              'id': json['rental']?['id']?.toString() ?? '',
              'title': json['rental']?['title']?.toString() ?? '',
              'image': json['rental']?['image']?.toString() ?? '',
            }
          : null,
      unreadCount: (json['unreadCounts']?[json['user']?['id']] ?? 0) as int,
    );
  }
}
