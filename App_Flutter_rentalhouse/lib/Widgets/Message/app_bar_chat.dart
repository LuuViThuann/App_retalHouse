import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/models/conversation.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_chat.dart';
import 'package:provider/provider.dart';

class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String conversationId;
  final String landlordId;
  final String rentalId;

  const ChatAppBar({
    super.key,
    required this.conversationId,
    required this.landlordId,
    required this.rentalId,
  });

  Future<Map<String, dynamic>> _fetchLandlordInfo(BuildContext context) async {
    final chatViewModel = Provider.of<ChatViewModel>(context, listen: false);
    try {
      final conversation = chatViewModel.conversations.firstWhere(
        (c) => c.id == conversationId,
        orElse: () => Conversation(
          id: '',
          rentalId: rentalId,
          participants: [landlordId],
          isPending: true,
          createdAt: DateTime.now(),
          landlord: {
            'id': landlordId,
            'username': 'Chủ nhà',
            'avatarBase64': ''
          },
          rental: null,
        ),
      );
      if (conversation.id.isEmpty) {
        throw Exception('Không tìm thấy cuộc trò chuyện');
      }
      return conversation.landlord;
    } catch (_) {
      return {
        'id': landlordId,
        'username': 'Chủ nhà',
        'avatarBase64': ''
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: FutureBuilder<Map<String, dynamic>>(
        future: _fetchLandlordInfo(context),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Text('Loading...');
          }
          final landlord =
              snapshot.data ?? {'username': 'Chủ nhà', 'avatarBase64': ''};
          return Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: landlord['avatarBase64']?.isNotEmpty == true
                    ? MemoryImage(base64Decode(landlord['avatarBase64'] as String))
                    : null,
                child: landlord['avatarBase64']?.isEmpty == true
                    ? const Icon(Icons.person)
                    : null,
              ),
              const SizedBox(width: 10),
              Text(landlord['username'] ?? 'Chủ nhà'),
            ],
          );
        },
      ),
      backgroundColor: Colors.blue,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}