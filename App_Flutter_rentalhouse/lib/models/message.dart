import 'dart:convert';
import 'dart:math' as math;

class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final List<String> images;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic> sender;

  Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.images,
    required this.createdAt,
    this.updatedAt,
    required this.sender,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    print(' [Message.fromJson] Parsing message:');
    print('   - ID: ${json['_id']}');
    print('   - Images raw: ${json['images']}');
    print('   - Images type: ${json['images'].runtimeType}');
    print('   - Images is Array: ${json['images'] is List}');

    // ✅ CRITICAL FIX: Robust image parsing with validation
    List<String> parsedImages = [];

    if (json['images'] != null) {
      try {

        if (json['images'] is List) {
          parsedImages = (json['images'] as List)
              .cast<dynamic>()
              .map((img) {
            if (img == null) return null;
            final url = img.toString().trim();

            // ✅ Validate URL
            final isValid = url.isNotEmpty &&
                (url.startsWith('http://') || url.startsWith('https://'));

            if (!isValid && url.isNotEmpty) {
              print('   ⚠️ Invalid image URL: $url');
            }

            return isValid ? url : null;
          })
              .whereType<String>() // Filter out nulls
              .toList();
        }

        else if (json['images'] is String) {
          final imagesStr = (json['images'] as String).trim();

          // Try to decode as JSON array
          try {
            final decoded = jsonDecode(imagesStr);

            if (decoded is List) {
              parsedImages = (decoded as List)
                  .cast<dynamic>()
                  .map((img) {
                if (img == null) return null;
                final url = img.toString().trim();

                final isValid = url.isNotEmpty &&
                    (url.startsWith('http://') || url.startsWith('https://'));

                return isValid ? url : null;
              })
                  .whereType<String>()
                  .toList();
            } else if (decoded is String) {
              // Single URL wrapped in quotes
              if (decoded.startsWith('http')) {
                parsedImages = [decoded];
              }
            }
          } catch (jsonErr) {
            // ✅ Case 3: Single URL as plain string
            if (imagesStr.startsWith('http://') || imagesStr.startsWith('https://')) {
              parsedImages = [imagesStr];
            } else {
              print('   ⚠️ Failed to parse images string: $jsonErr');
            }
          }
        }
      } catch (e) {
        print('   ❌ Error parsing images: $e');
        parsedImages = [];
      }
    }


    if (parsedImages.isNotEmpty) {
      print('   ✅ Parsed ${parsedImages.length} valid images:');
      for (int i = 0; i < parsedImages.length; i++) {
        print('      [$i] ${parsedImages[i]}');
      }
    } else {
      print('   ℹ️ No valid images found');
    }

    return Message(
      id: json['_id']?.toString() ?? '',
      conversationId: json['conversationId']?.toString() ?? '',
      senderId: json['senderId']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      images: parsedImages,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt']?.toString() ?? '')
          : null,
      sender: {
        'id': json['sender']?['id']?.toString() ?? json['senderId']?.toString() ?? '',
        'username': json['sender']?['username']?.toString() ?? 'Chủ nhà',
        'avatarUrl': json['sender']?['avatarUrl']?.toString() ?? '',
      },
    );
  }

  // ✅ Helper method with logging
  Message copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? content,
    List<String>? images,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? sender,
  }) {
    final newMessage = Message(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      content: content ?? this.content,
      images: images ?? this.images,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sender: sender ?? this.sender,
    );

    print('🔄 [Message.copyWith] Created copy:');
    print('   - ID: ${newMessage.id}');
    print('   - Images: ${newMessage.images.length}');
    print('   - Content: ${newMessage.content.substring(0, math.min(30, newMessage.content.length))}...');

    return newMessage;
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'conversationId': conversationId,
      'senderId': senderId,
      'content': content,
      'images': images,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'sender': sender,
    };
  }

  @override
  String toString() {
    return 'Message(id: $id, content: $content, images: ${images.length})';
  }
}

// ✅ Helper to check if URL is valid
bool isValidImageUrl(String url) {
  return url.isNotEmpty &&
      (url.startsWith('http://') || url.startsWith('https://')) &&
      !url.startsWith('uploading_');
}