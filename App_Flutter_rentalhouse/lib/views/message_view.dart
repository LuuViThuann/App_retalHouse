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

class _ConversationsScreenState extends State<ConversationsScreen> with TickerProviderStateMixin {
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
        SnackBar(
          content: Text(
            'Vui lòng đăng nhập để xem cuộc trò chuyện',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Route _createRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOut;

        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        var offsetAnimation = animation.drive(tween);

        return SlideTransition(
          position: offsetAnimation,
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 400),
    );
  }

  void _deleteConversation(String conversationId, String token) async {
    final chatViewModel = Provider.of<ChatViewModel>(context, listen: false);
    final success = await chatViewModel.deleteConversation(conversationId, token);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã xóa cuộc trò chuyện'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Xóa cuộc trò chuyện thất bại'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false, // bỏ Icon quay lại
        title: Row(
          children: [
            Icon(
              Icons.chat,
              color: Colors.white,
            ),
            SizedBox(width: 8),
            Text(
              'Cuộc Trò Chuyện',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: Colors.white,
              ),
            ),
          ],
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue, Colors.blueAccent.shade700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 4,
        shadowColor: Colors.black26,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.grey[100]!, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Consumer2<AuthViewModel, ChatViewModel>(
          builder: (context, authViewModel, chatViewModel, child) {
            if (authViewModel.currentUser == null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.login, size: 64, color: Colors.grey[400]),
                    SizedBox(height: 16),
                    Text(
                      'Vui lòng đăng nhập để xem cuộc trò chuyện',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            if (chatViewModel.isLoading) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Đang tải cuộc trò chuyện...',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }

            if (chatViewModel.errorMessage != null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
                    SizedBox(height: 16),
                    Text(
                      chatViewModel.errorMessage!,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadConversations,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: Text(
                        'Thử lại',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            if (chatViewModel.conversations.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
                    SizedBox(height: 16),
                    Text(
                      'Chưa có cuộc trò chuyện nào',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            // Create a sorted copy of conversations
            final sortedConversations = List<Conversation>.from(chatViewModel.conversations);
            sortedConversations.sort((a, b) {
              // Prioritize conversations with unread messages
              if (a.unreadCount > 0 && b.unreadCount == 0) return -1;
              if (a.unreadCount == 0 && b.unreadCount > 0) return 1;

              // Within unread conversations, sort by updatedAt (newest first)
              if (a.unreadCount > 0 && b.unreadCount > 0) {
                final aTime = a.lastMessage?.createdAt ?? a.updatedAt;
                final bTime = b.lastMessage?.createdAt ?? b.updatedAt;
                if (bTime == null && aTime == null) return 0;
                if (bTime == null) return 1;
                if (aTime == null) return -1;
                return bTime.compareTo(aTime);
              }

              // For read conversations, check if they have messages
              final aHasMessages = a.lastMessage != null;
              final bHasMessages = b.lastMessage != null;

              // Prioritize conversations with messages over those without
              if (aHasMessages && !bHasMessages) return -1;
              if (!aHasMessages && bHasMessages) return 1;

              // Within conversations with messages, sort by last message time
              if (aHasMessages && bHasMessages) {
                return b.lastMessage!.createdAt.compareTo(a.lastMessage!.createdAt);
              }

              // For conversations without messages, sort by createdAt
              return b.createdAt.compareTo(a.createdAt);
            });

            return ListView.separated(
              padding: EdgeInsets.all(16),
              itemCount: sortedConversations.length,
              separatorBuilder: (context, index) => SizedBox(height: 12),
              itemBuilder: (context, index) {
                final conversation = sortedConversations[index];
                final bool hasUnread = conversation.unreadCount > 0;
                String subtitleText = 'Chưa có tin nhắn';
                if (conversation.lastMessage != null) {
                  if (conversation.lastMessage!.content.isNotEmpty) {
                    subtitleText = conversation.lastMessage!.content;
                  } else if (conversation.lastMessage!.images.isNotEmpty) {
                    subtitleText = '[Hình ảnh]';
                  }
                }

                return Dismissible(
                  key: Key(conversation.id),
                  direction: DismissDirection.endToStart,
                  onDismissed: (direction) {
                    if (authViewModel.currentUser != null) {
                      _deleteConversation(conversation.id, authViewModel.currentUser!.token!);
                    }
                  },
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: EdgeInsets.only(right: 20),
                    color: Colors.red,
                    child: Icon(Icons.delete, color: Colors.white),
                  ),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        _createRoute(ChatScreen(
                          rentalId: conversation.rentalId,
                          landlordId: conversation.landlord['id'],
                          conversationId: conversation.id,
                        )),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: hasUnread
                            ? LinearGradient(
                                colors: [Colors.blue[50]!, Colors.blue[100]!],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: hasUnread ? null : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: hasUnread ? 6 : 1,
                            offset: Offset(0, hasUnread ? 4 : 2),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: hasUnread ? 16 : 12),
                        leading: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundImage: conversation.landlord['avatarBase64']?.isNotEmpty == true
                                  ? MemoryImage(base64Decode(conversation.landlord['avatarBase64']))
                                  : null,
                              backgroundColor: Colors.blue[100],
                              child: conversation.landlord['avatarBase64']?.isEmpty == true
                                  ? Icon(Icons.person, size: 28, color: Colors.blue[800])
                                  : null,
                            ),
                            if (hasUnread)
                              Positioned(
                                right: 0,
                                top: -10,
                                child: AnimatedScale(
                                  scale: hasUnread ? 1.1 : 1.0,
                                  duration: Duration(milliseconds: 1000),
                                  curve: Curves.easeInOut,
                                  child: Container(
                                    padding: EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.red.withOpacity(0.3),
                                          blurRadius: 4,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    constraints: BoxConstraints(
                                      minWidth: 24,
                                      minHeight: 24,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${conversation.unreadCount}',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        title: Text(
                          conversation.landlord['username'] ?? 'Chủ nhà',
                          style: TextStyle(
                            fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
                            fontSize: 16,
                            color: hasUnread ? Colors.blue[900] : Colors.black87,
                          ),
                        ),
                        subtitle: Text(
                          subtitleText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: hasUnread ? FontWeight.w500 : FontWeight.w400,
                            color: hasUnread ? Colors.blue[700] : Colors.grey[600],
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (hasUnread)
                              Container(
                                width: 8,
                                height: 8,
                                margin: EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            Text(
                              conversation.lastMessage != null
                                  ? DateFormat('HH:mm, dd/MM').format(conversation.lastMessage!.createdAt)
                                  : DateFormat('HH:mm, dd/MM').format(conversation.createdAt),
                              style: TextStyle(
                                fontSize: 12,
                                color: hasUnread ? Colors.blue[700] : Colors.grey[500],
                                fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}