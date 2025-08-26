import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/constants/app_style.dart';
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

  @override
  Widget build(BuildContext context) {
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
      onDismissed: (direction) => _deleteConversation(context),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppStyles.errorColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: AnimatedScale(
          scale: 1.0,
          duration: const Duration(milliseconds: 200),
          child: Icon(Icons.delete, color: AppStyles.whiteColor, size: 28),
        ),
      ),
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
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: hasUnread
                ? LinearGradient(
                    colors: [
                      Colors.blue.shade100,
                      Colors.blue.shade50,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : LinearGradient(
                    colors: [Colors.white, Colors.blue.shade50],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.shade100.withOpacity(hasUnread ? 0.3 : 0.2),
                blurRadius: hasUnread ? 8 : 6,
                spreadRadius: 1,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(color: Colors.blue.shade100.withOpacity(0.5)),
          ),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedScale(
                  scale: hasUnread ? 1.1 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: CircleAvatar(
                    radius: 30,
                    backgroundImage: conversation
                                .landlord['avatarBase64']?.isNotEmpty ==
                            true
                        ? MemoryImage(
                            base64Decode(conversation.landlord['avatarBase64']))
                        : null,
                    backgroundColor: Colors.blue.shade100,
                    child:
                        conversation.landlord['avatarBase64']?.isEmpty == true
                            ? Icon(Icons.person,
                                size: 32, color: Colors.blue.shade700)
                            : null,
                  ),
                ),
                if (hasUnread)
                  Positioned(
                    right: -2,
                    top: -8,
                    child: AnimatedScale(
                      scale: hasUnread ? 1.2 : 1.0,
                      duration: const Duration(milliseconds: 1000),
                      curve: Curves.easeInOut,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppStyles.errorColor,
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: AppStyles.whiteColor, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: AppStyles.errorColor.withOpacity(0.3),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 26,
                          minHeight: 26,
                        ),
                        child: Center(
                          child: Text(
                            '${conversation.unreadCount}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
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
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: hasUnread ? Colors.blue.shade800 : Colors.black87,
                letterSpacing: 0.2,
              ),
            ),
            subtitle: Text(
              subtitleText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: hasUnread ? Colors.blue.shade600 : Colors.grey.shade600,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasUnread)
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: AppStyles.errorColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                Text(
                  conversation.lastMessage != null
                      ? DateFormat('HH:mm, dd/MM')
                          .format(conversation.lastMessage!.createdAt)
                      : DateFormat('HH:mm, dd/MM')
                          .format(conversation.createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color:
                        hasUnread ? Colors.blue.shade700 : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
