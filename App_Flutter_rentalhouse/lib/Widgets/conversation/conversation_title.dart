import 'package:cached_network_image/cached_network_image.dart'; // ✅ ADD THIS
import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/models/conversation.dart';
import 'package:flutter_rentalhouse/utils/navigation_conversation.dart';
import 'package:flutter_rentalhouse/utils/snackbar_conversation.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_chat.dart';
import 'package:flutter_rentalhouse/views/chat_user.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final String token;

  const ConversationTile({
    super.key,
    required this.conversation,
    required this.token,
  });

  void _deleteConversation(BuildContext context) async {
    final chatViewModel = Provider.of<ChatViewModel>(context, listen: false);
    final success =
    await chatViewModel.deleteConversation(conversation.id, token);
    if (success) {
      SnackbarUtils.showSuccess(context, 'Đã xóa cuộc trò chuyện');
    } else {
      SnackbarUtils.showError(context, 'Xóa cuộc trò chuyện thất bại');
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return DateFormat('HH:mm').format(dateTime);
    } else if (difference.inDays == 1) {
      return 'Hôm qua';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} ngày';
    } else {
      return DateFormat('dd/MM').format(dateTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasUnread = conversation.unreadCount > 0;
    String subtitleText = 'Chưa có tin nhắn';
    IconData? messageIcon;

    if (conversation.lastMessage != null) {
      if (conversation.lastMessage!.content.isNotEmpty) {
        subtitleText = conversation.lastMessage!.content;
      } else if (conversation.lastMessage!.images.isNotEmpty) {
        subtitleText = 'Hình ảnh';
        messageIcon = Icons.image_rounded;
      }
    }

    // ✅ Changed: Get avatarUrl instead of avatarBase64
    final avatarUrl = conversation.landlord['avatarUrl']?.toString() ?? '';

    return Dismissible(
      key: Key(conversation.id),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) => _deleteConversation(context),
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.red.shade400, Colors.red.shade600],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          Icons.delete_rounded,
          color: Colors.white,
          size: 26,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              NavigationUtils.createSlideRoute(
                ChatScreen(
                  rentalId: conversation.rentalId,
                  landlordId: conversation.landlord['id'],
                  conversationId: conversation.id,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: hasUnread ? Colors.blue.shade50 : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: hasUnread
                    ? Colors.blue.shade200.withOpacity(0.5)
                    : Colors.grey.shade200,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: hasUnread
                      ? Colors.blue.shade100.withOpacity(0.3)
                      : Colors.grey.shade200.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // ✅ Avatar - UPDATED to use CachedNetworkImage
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: hasUnread
                              ? Colors.blue.shade300
                              : Colors.grey.shade300,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: hasUnread
                                ? Colors.blue.shade200.withOpacity(0.3)
                                : Colors.grey.shade300.withOpacity(0.2),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: avatarUrl.isNotEmpty
                            ? CachedNetworkImage(
                          imageUrl: avatarUrl, // ✅ Direct Cloudinary URL
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.blue.shade100,
                            child: Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.blue.shade100,
                            child: Icon(
                              Icons.person_rounded,
                              size: 28,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        )
                            : Container(
                          color: Colors.blue.shade100,
                          child: Icon(
                            Icons.person_rounded,
                            size: 28,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ),
                    if (hasUnread)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.red.shade400, Colors.red.shade600],
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.shade300.withOpacity(0.5),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 22,
                            minHeight: 22,
                          ),
                          child: Center(
                            child: Text(
                              conversation.unreadCount > 99
                                  ? '99+'
                                  : '${conversation.unreadCount}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              conversation.landlord['username'] ?? 'Chủ nhà',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: Colors.grey.shade900,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            conversation.lastMessage != null
                                ? _formatTime(conversation.lastMessage!.createdAt)
                                : _formatTime(conversation.createdAt),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: hasUnread
                                  ? Colors.blue.shade700
                                  : Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (messageIcon != null) ...[
                            Icon(
                              messageIcon,
                              size: 16,
                              color: hasUnread
                                  ? Colors.blue.shade600
                                  : Colors.grey.shade500,
                            ),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(
                              subtitleText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: hasUnread
                                    ? FontWeight.w500
                                    : FontWeight.w400,
                                color: hasUnread
                                    ? Colors.grey.shade700
                                    : Colors.grey.shade600,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (hasUnread) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.circle,
                    size: 10,
                    color: Colors.blue.shade600,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}