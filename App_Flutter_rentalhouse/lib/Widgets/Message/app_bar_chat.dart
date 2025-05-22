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
      return {'id': landlordId, 'username': 'Chủ nhà', 'avatarBase64': ''};
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue[600]!, Colors.blue[800]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
      ),
      iconTheme: const IconThemeData(
        color: Colors.white,
      ),
      title: FutureBuilder<Map<String, dynamic>>(
        future: _fetchLandlordInfo(context),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Text(
              'Loading...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                fontFamily: 'Roboto',
              ),
            );
          }
          final landlord =
              snapshot.data ?? {'username': 'Chủ nhà', 'avatarBase64': ''};
          return Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: landlord['avatarBase64']?.isNotEmpty == true
                      ? MemoryImage(
                          base64Decode(landlord['avatarBase64'] as String))
                      : null,
                  child: landlord['avatarBase64']?.isEmpty == true
                      ? Icon(Icons.person, size: 22, color: Colors.grey[600])
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                landlord['username'] ?? 'Chủ nhà',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  fontFamily: 'Roboto',
                ),
              ),
            ],
          );
        },
      ),
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.info_outline, color: Colors.white),
          onPressed: () {
            // Handle more options
          },
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
