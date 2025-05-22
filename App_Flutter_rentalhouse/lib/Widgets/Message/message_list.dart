import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/config/api_routes.dart';
import 'package:flutter_rentalhouse/models/message.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_auth.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_chat.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:convert';

import '../../utils/date_chat.dart';

class ChatMessageList extends StatelessWidget {
  final ScrollController scrollController;
  final bool isFetchingOlderMessages;
  final Function(Message) onLongPress;

  const ChatMessageList({
    super.key,
    required this.scrollController,
    required this.isFetchingOlderMessages,
    required this.onLongPress,
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

  @override
  Widget build(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context);
    final chatViewModel = Provider.of<ChatViewModel>(context);

    if (chatViewModel.messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 50,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 10),
            Text(
              'Hãy bắt đầu nhắn tin bây giờ!',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    final items = <dynamic>[];
    String? lastHeader;

    for (var message in chatViewModel.messages) {
      final header = _getDateHeader(message.createdAt);
      if (header != lastHeader) {
        items.add(header);
        lastHeader = header;
      }
      items.add(message);
    }

    return Stack(
      children: [
        ListView.builder(
          controller: scrollController,
          reverse: true,
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            if (item is String) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      item,
                      style: TextStyle(fontSize: 12, color: Colors.grey[800]),
                    ),
                  ),
                ),
              );
            }
            final message = item as Message;
            final isMe = message.senderId == authViewModel.currentUser?.id;
            return GestureDetector(
              key: ValueKey(message.id),
              onLongPress: isMe
                  ? () {
                      showModalBottomSheet(
                        context: context,
                        builder: (context) => SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                leading: const Icon(Icons.edit),
                                title: const Text('Chỉnh sửa'),
                                onTap: () {
                                  Navigator.pop(context);
                                  onLongPress(message);
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.delete),
                                title: const Text('Xóa'),
                                onTap: () async {
                                  Navigator.pop(context);
                                  final success =
                                      await chatViewModel.deleteMessage(
                                    messageId: message.id,
                                    token: authViewModel.currentUser!.token!,
                                  );
                                  if (success) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Tin nhắn đã được xóa'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                    scrollToBottom(scrollController);
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            chatViewModel.errorMessage ??
                                                'Lỗi khi xóa tin nhắn'),
                                        backgroundColor: Colors.redAccent,
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
              child: Row(
                mainAxisAlignment:
                    isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                children: [
                  if (!isMe) ...[
                    CircleAvatar(
                      radius: 16,
                      backgroundImage:
                          message.sender['avatarBase64']?.isNotEmpty == true
                              ? MemoryImage(
                                  base64Decode(message.sender['avatarBase64']))
                              : null,
                      child: message.sender['avatarBase64']?.isEmpty == true
                          ? const Icon(Icons.person, size: 16)
                          : null,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                          vertical: 5, horizontal: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isMe ? Colors.blue[100] : Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: isMe
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          if (message.images.isNotEmpty)
                            Wrap(
                              spacing: 5,
                              children: message.images
                                  .map((img) => ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: CachedNetworkImage(
                                          imageUrl:
                                              '${ApiRoutes.serverBaseUrl}$img',
                                          width: 100,
                                          height: 100,
                                          fit: BoxFit.cover,
                                          memCacheHeight: 200,
                                          memCacheWidth: 200,
                                          placeholder: (context, url) =>
                                              const CircularProgressIndicator(),
                                          errorWidget: (context, url, error) =>
                                              const Icon(Icons.error),
                                        ),
                                      ))
                                  .toList(),
                            ),
                          if (message.content.isNotEmpty)
                            Text(
                              message.content,
                              style: const TextStyle(fontSize: 16),
                            ),
                          const SizedBox(height: 5),
                          Text(
                            message.updatedAt != null
                                ? 'Đã chỉnh sửa - ${DateFormat('HH:mm, dd/MM').format(message.updatedAt!)}'
                                : DateFormat('HH:mm, dd/MM')
                                    .format(message.createdAt),
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 8),
                    CircleAvatar(
                      radius: 16,
                      backgroundImage:
                          message.sender['avatarBase64']?.isNotEmpty == true
                              ? MemoryImage(
                                  base64Decode(message.sender['avatarBase64']))
                              : null,
                      child: message.sender['avatarBase64']?.isEmpty == true
                          ? const Icon(Icons.person, size: 16)
                          : null,
                    ),
                  ],
                ],
              ),
            );
          },
        ),
        if (isFetchingOlderMessages)
          const Positioned(
            top: 10,
            left: 0,
            right: 0,
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
      ],
    );
  }
}
