import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/config/api_routes.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_auth.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_chat.dart';
import 'package:flutter_rentalhouse/views/chat_user.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  _ConversationsScreenState createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final chatViewModel = Provider.of<ChatViewModel>(context, listen: false);

    if (authViewModel.currentUser == null) {
      setState(() {
        _errorMessage = 'Vui lòng đăng nhập để xem tin nhắn';
        _isLoading = false;
      });
      return;
    }

    try {
      await chatViewModel.fetchConversations(authViewModel.currentUser!.token!);
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Lỗi khi tải danh sách cuộc trò chuyện: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context);
    final chatViewModel = Provider.of<ChatViewModel>(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('Tin nhắn'), backgroundColor: Colors.blue),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tin nhắn'), backgroundColor: Colors.blue),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_errorMessage!),
              ElevatedButton(
                onPressed: _loadConversations,
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tin nhắn'),
        backgroundColor: Colors.blue,
      ),
      body: authViewModel.currentUser == null
          ? const Center(child: Text('Vui lòng đăng nhập để xem tin nhắn'))
          : Consumer<ChatViewModel>(
        builder: (context, chatViewModel, child) {
          if (chatViewModel.conversations.isEmpty) {
            return const Center(child: Text('Chưa có cuộc trò chuyện nào'));
          }

          return ListView.builder(
            itemExtent: 80.0,
            itemCount: chatViewModel.conversations.length,
            itemBuilder: (context, index) {
              final conversation = chatViewModel.conversations[index];
              return ListTile(
                leading: CircleAvatar(
                  radius: 25,
                  backgroundImage: conversation.landlord['avatarBase64']?.isNotEmpty == true
                      ? MemoryImage(base64Decode(conversation.landlord['avatarBase64'] as String))
                      : null,
                  child: conversation.landlord['avatarBase64']?.isEmpty == true
                      ? const Icon(Icons.person)
                      : null,
                ),
                title: Text(
                  conversation.landlord['username'] ?? 'Unknown',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conversation.rental?['title'] ?? 'Unknown Rental',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    if (conversation.lastMessage != null)
                      Text(
                        conversation.lastMessage!.content,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                  ],
                ),
                trailing: Text(
                  conversation.lastMessage != null
                      ? DateFormat('HH:mm, dd/MM').format(conversation.lastMessage!.createdAt)
                      : '',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                onTap: () async {
                  try {
                    await chatViewModel.fetchConversations(authViewModel.currentUser!.token!);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          rentalId: conversation.rentalId,
                          landlordId: conversation.landlord['id'],
                          conversationId: conversation.id,
                        ),
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Lỗi khi mở cuộc trò chuyện: $e')),
                    );
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}