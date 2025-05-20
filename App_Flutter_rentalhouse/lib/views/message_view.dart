import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/config/api_routes.dart';
import 'package:flutter_rentalhouse/models/conversation.dart';
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
  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final chatViewModel = Provider.of<ChatViewModel>(context, listen: false);

    if (authViewModel.currentUser != null) {
      await chatViewModel.fetchConversations(authViewModel.currentUser!.token!);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để xem cuộc trò chuyện')),
      );
    }
  }

  Route _createRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 1.0);
        const end = Offset.zero;
        const curve = Curves.easeInOut;

        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        var offsetAnimation = animation.drive(tween);

        return SlideTransition(
          position: offsetAnimation,
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cuộc trò chuyện'),
        backgroundColor: Colors.blue,
      ),
      body: Consumer2<AuthViewModel, ChatViewModel>(
        builder: (context, authViewModel, chatViewModel, child) {
          if (authViewModel.currentUser == null) {
            return const Center(child: Text('Vui lòng đăng nhập để xem cuộc trò chuyện'));
          }

          if (chatViewModel.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (chatViewModel.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(chatViewModel.errorMessage!),
                  ElevatedButton(
                    onPressed: _loadConversations,
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            );
          }

          if (chatViewModel.conversations.isEmpty) {
            return const Center(child: Text('Chưa có cuộc trò chuyện nào'));
          }

          return ListView.builder(
            itemCount: chatViewModel.conversations.length,
            itemBuilder: (context, index) {
              final conversation = chatViewModel.conversations[index];
              String subtitleText = 'Chưa có tin nhắn';
              if (conversation.lastMessage != null) {
                if (conversation.lastMessage!.content.isNotEmpty) {
                  subtitleText = conversation.lastMessage!.content;
                } else if (conversation.lastMessage!.images.isNotEmpty) {
                  subtitleText = '[Hình ảnh]';
                }
              }
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: conversation.landlord['avatarBase64']?.isNotEmpty == true
                      ? MemoryImage(base64Decode(conversation.landlord['avatarBase64']))
                      : null,
                  child: conversation.landlord['avatarBase64']?.isEmpty == true
                      ? const Icon(Icons.person)
                      : null,
                ),
                title: Text(conversation.landlord['username'] ?? 'Unknown'),
                subtitle: Text(
                  subtitleText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(
                  conversation.lastMessage != null
                      ? DateFormat('HH:mm, dd/MM').format(conversation.lastMessage!.createdAt)
                      : DateFormat('HH:mm, dd/MM').format(conversation.createdAt),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                onTap: () {
                  print('Navigating to ChatScreen with conversationId: ${conversation.id}');
                  Navigator.push(
                    context,
                    _createRoute(ChatScreen(
                      rentalId: conversation.rentalId,
                      landlordId: conversation.landlord['id'],
                      conversationId: conversation.id,
                    )),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}