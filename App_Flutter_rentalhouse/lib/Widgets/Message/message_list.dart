import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/Widgets/Message/chat_image_full_screen.dart';
import 'package:flutter_rentalhouse/config/api_routes.dart';
import 'package:flutter_rentalhouse/models/message.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_auth.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_chat.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:convert';

class ChatMessageList extends StatelessWidget {
  final ScrollController scrollController;
  final bool isFetchingOlderMessages;
  final Function(Message) onLongPress;
  final Map<String, GlobalKey> messageKeys;

  const ChatMessageList({
    super.key,
    required this.scrollController,
    required this.isFetchingOlderMessages,
    required this.onLongPress,
    required this.messageKeys,
  });

  String _getDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(date.year, date.month, date.day);
    final difference = today.difference(messageDate).inDays;

    if (difference == 0) return 'Hôm nay';
    if (difference == 1) return 'Hôm qua';
    if (difference <= 7) return '$difference ngày trước';
    return DateFormat('dd/MM/yyyy').format(messageDate);
  }

  void _scrollToMessage(String? messageId, List<Message> messages) {
    if (scrollController.hasClients) {
      if (messageId != null && messageKeys.containsKey(messageId)) {
        final key = messageKeys[messageId]!;
        final context = key.currentContext;
        if (context != null) {
          Scrollable.ensureVisible(
            context,
            alignment: 0.5,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      } else {
        Future.delayed(const Duration(milliseconds: 100), () {
          scrollController.animateTo(
            scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context);
    final chatViewModel = Provider.of<ChatViewModel>(context);

    // Scroll to bottom after the frame is built to show newest messages
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients && !isFetchingOlderMessages) {
        scrollController.jumpTo(scrollController.position.maxScrollExtent);
      }
    });

    if (chatViewModel.messages.isEmpty) {
      return Container(
        color: Colors.white,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 60,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'Hãy bắt đầu nhắn tin ngay!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final items = <dynamic>[];
    final messages = chatViewModel.messages;

    // Nhóm tin nhắn theo ngày và thêm tiêu đề phía trên mỗi nhóm
    Map<String, List<Message>> groupedMessages = {};
    for (var message in messages) {
      final header = _getDateHeader(message.createdAt);
      if (!groupedMessages.containsKey(header)) {
        groupedMessages[header] = [];
      }
      groupedMessages[header]!.add(message);
      messageKeys[message.id] = GlobalKey();
    }

    // Sắp xếp các nhóm theo ngày, từ mới đến cũ
    final sortedHeaders = groupedMessages.keys.toList()
      ..sort((a, b) {
        DateTime dateA = a == 'Hôm nay'
            ? DateTime.now()
            : a == 'Hôm qua'
                ? DateTime.now().subtract(Duration(days: 1))
                : a.contains('ngày trước')
                    ? DateTime.now().subtract(Duration(
                        days: int.parse(a.split(' ')[0]),
                      ))
                    : DateFormat('dd/MM/yyyy').parse(a);
        DateTime dateB = b == 'Hôm nay'
            ? DateTime.now()
            : b == 'Hôm qua'
                ? DateTime.now().subtract(Duration(days: 1))
                : b.contains('ngày trước')
                    ? DateTime.now().subtract(Duration(
                        days: int.parse(b.split(' ')[0]),
                      ))
                    : DateFormat('dd/MM/yyyy').parse(b);
        return dateB.compareTo(dateA); // Đảo ngược để từ mới đến cũ
      });

    // Xây dựng items: tin nhắn trước, tiêu đề sau (do reverse: true)
    for (var header in sortedHeaders) {
      for (var message in groupedMessages[header]!.reversed) {
        items.add(message);
      }
      items.add(header);
    }

    return Container(
      color: Colors.white,
      child: Stack(
        children: [
          ListView.builder(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            itemCount: items.length,
            reverse: true,
            itemBuilder: (context, index) {
              final item = items[index];
              if (item is String) {
                return Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 8),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        item,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                  ),
                );
              }
              final message = item as Message;
              final isMe = message.senderId == authViewModel.currentUser?.id;
              return AnimatedOpacity(
                opacity: 1.0,
                duration: const Duration(milliseconds: 300),
                child: GestureDetector(
                  key: messageKeys[message.id],
                  onLongPress: isMe
                      ? () {
                          showModalBottomSheet(
                            context: context,
                            backgroundColor: Colors.white,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(20)),
                            ),
                            builder: (context) => SafeArea(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    leading: Icon(
                                      Icons.edit,
                                      color: Colors.blue[600],
                                    ),
                                    title: const Text('Chỉnh sửa'),
                                    onTap: () {
                                      Navigator.pop(context);
                                      onLongPress(message);
                                    },
                                  ),
                                  ListTile(
                                    leading: Icon(
                                      Icons.delete,
                                      color: Colors.red[600],
                                    ),
                                    title: const Text('Xóa'),
                                    onTap: () async {
                                      Navigator.pop(context);
                                      final success =
                                          await chatViewModel.deleteMessage(
                                        messageId: message.id,
                                        token:
                                            authViewModel.currentUser!.token!,
                                      );
                                      if (success) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: const Text(
                                                'Tin nhắn đã được xóa'),
                                            backgroundColor: Colors.green[600],
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                        );
                                        final remainingMessages = chatViewModel
                                            .messages
                                            .where((m) => m.id != message.id)
                                            .toList();
                                        final nextMessageId =
                                            remainingMessages.isNotEmpty
                                                ? remainingMessages.last.id
                                                : null;
                                        _scrollToMessage(
                                            nextMessageId, remainingMessages);
                                      } else {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                chatViewModel.errorMessage ??
                                                    'Lỗi khi xóa tin nhắn'),
                                            backgroundColor: Colors.red[600],
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisAlignment: isMe
                          ? MainAxisAlignment.end
                          : MainAxisAlignment.start,
                      children: [
                        if (!isMe) ...[
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.2),
                                  spreadRadius: 1,
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.grey[200],
                              backgroundImage:
                                  message.sender['avatarBase64']?.isNotEmpty ==
                                          true
                                      ? MemoryImage(base64Decode(
                                          message.sender['avatarBase64']))
                                      : null,
                              child: message.sender['avatarBase64']?.isEmpty ==
                                      true
                                  ? Icon(
                                      Icons.person,
                                      size: 20,
                                      color: Colors.grey[600],
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Flexible(
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.75,
                            ),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isMe
                                    ? [
                                        Colors.blue[400]!,
                                        Colors.blue[600]!,
                                      ]
                                    : [
                                        Colors.grey[200]!,
                                        Colors.grey[300]!,
                                      ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.2),
                                  spreadRadius: 1,
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: isMe
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                if (message.images.isNotEmpty)
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: message.images
                                        .map((img) => GestureDetector(
                                              onTap: () {
                                                showDialog(
                                                  context: context,
                                                  builder: (context) =>
                                                      ChatFullImage(
                                                    imageUrl:
                                                        '${ApiRoutes.serverBaseUrl}$img',
                                                  ),
                                                );
                                              },
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                child: CachedNetworkImage(
                                                  imageUrl:
                                                      '${ApiRoutes.serverBaseUrl}$img',
                                                  width: 120,
                                                  height: 120,
                                                  fit: BoxFit.cover,
                                                  memCacheHeight: 240,
                                                  memCacheWidth: 240,
                                                  placeholder: (context, url) =>
                                                      Container(
                                                    width: 120,
                                                    height: 120,
                                                    color: Colors.grey[100],
                                                    child: const Center(
                                                        child:
                                                            CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    )),
                                                  ),
                                                  errorWidget:
                                                      (context, url, error) =>
                                                          Container(
                                                    width: 120,
                                                    height: 120,
                                                    color: Colors.grey[100],
                                                    child: const Icon(
                                                      Icons.error_outline,
                                                      color: Colors.red,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ))
                                        .toList(),
                                  ),
                                if (message.content.isNotEmpty)
                                  Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 4),
                                    child: Text(
                                      message.content,
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: isMe
                                            ? Colors.white
                                            : Colors.grey[800],
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 6),
                                Text(
                                  message.updatedAt != null
                                      ? 'Đã chỉnh sửa - ${DateFormat('HH:mm, dd/MM').format(message.updatedAt!)}'
                                      : DateFormat('HH:mm, dd/MM')
                                          .format(message.createdAt),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isMe
                                        ? Colors.white70
                                        : Colors.grey[600],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 10),
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.2),
                                  spreadRadius: 1,
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.grey[200],
                              backgroundImage:
                                  message.sender['avatarBase64']?.isNotEmpty ==
                                          true
                                      ? MemoryImage(base64Decode(
                                          message.sender['avatarBase64']))
                                      : null,
                              child: message.sender['avatarBase64']?.isEmpty ==
                                      true
                                  ? Icon(
                                      Icons.person,
                                      size: 20,
                                      color: Colors.grey[600],
                                    )
                                  : null,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          if (isFetchingOlderMessages)
            Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.3),
                        spreadRadius: 1,
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
