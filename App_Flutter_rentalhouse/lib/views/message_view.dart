import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/models/message.dart';
import 'package:flutter_rentalhouse/services/chat_service.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_auth.dart';
import 'package:flutter_rentalhouse/views/chat_user.dart';

import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class MessageView extends StatefulWidget {
  const MessageView({super.key});

  @override
  State<MessageView> createState() => _MessageViewState();
}

class _MessageViewState extends State<MessageView> {

  final ChatService _chatService = ChatService();
  List<Conversation> _pendingConversations = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchPendingConversations();
  }

  Future<void> _fetchPendingConversations() async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    if (authViewModel.currentUser == null) return;

    setState(() => _isLoading = true);
    try {
      final conversations = await _chatService.fetchPendingConversations(
        authViewModel.currentUser!.token!,
      );
      setState(() {
        _pendingConversations = conversations;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }


  @override
  Widget build(BuildContext context) {

    final authViewModel = Provider.of<AuthViewModel>(context);
    final currentUserId = authViewModel.currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tin nhắn đang chờ'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pendingConversations.isEmpty
          ? const Center(child: Text('Không có tin nhắn đang chờ.'))
          : ListView.builder(
        itemCount: _pendingConversations.length,
        itemBuilder: (context, index) {
          final conversation = _pendingConversations[index];
          final otherParticipant = conversation.participants.firstWhere(
                (p) => p.id != currentUserId,
          );
          return ListTile(
            leading: CircleAvatar(
              backgroundImage: otherParticipant.avatarBase64 != null
                  ? MemoryImage(base64Decode(otherParticipant.avatarBase64!.split(',')[1]))
                  : const AssetImage('assets/img/imageuser.png') as ImageProvider,
            ),
            title: Text(otherParticipant.username ?? 'Không có tên'),
            subtitle: Text(conversation.lastMessage?.content ?? ''),
            trailing: Text(
              DateFormat('dd/MM HH:mm').format(conversation.updatedAt),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatScreen(
                    rentalId: conversation.rentalId,
                    recipientId: otherParticipant.id,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
