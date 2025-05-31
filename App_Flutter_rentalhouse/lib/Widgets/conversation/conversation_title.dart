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
        padding: EdgeInsets.only(right: 20),
        color: AppStyles.errorColor,
        child: Icon(Icons.delete, color: AppStyles.whiteColor),
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
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            gradient: hasUnread
                ? LinearGradient(
                    colors: [
                      AppStyles.unreadGradientStart,
                      AppStyles.unreadGradientEnd
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: hasUnread ? null : AppStyles.whiteColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppStyles.shadowColor,
                blurRadius: hasUnread ? 6 : 1,
                offset: Offset(0, hasUnread ? 4 : 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: EdgeInsets.symmetric(
                horizontal: 16, vertical: hasUnread ? 16 : 12),
            leading: Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage: conversation
                              .landlord['avatarBase64']?.isNotEmpty ==
                          true
                      ? MemoryImage(
                          base64Decode(conversation.landlord['avatarBase64']))
                      : null,
                  backgroundColor: AppStyles.avatarBackground,
                  child: conversation.landlord['avatarBase64']?.isEmpty == true
                      ? Icon(Icons.person,
                          size: 28, color: AppStyles.avatarIconColor)
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
                        constraints: BoxConstraints(
                          minWidth: 24,
                          minHeight: 24,
                        ),
                        child: Center(
                          child: Text(
                            '${conversation.unreadCount}',
                            style: AppStyles.unreadBadgeText,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            title: Text(
              conversation.landlord['username'] ?? 'Chủ nhà',
              style:
                  hasUnread ? AppStyles.unreadTitleText : AppStyles.titleText,
            ),
            subtitle: Text(
              subtitleText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: hasUnread
                  ? AppStyles.unreadSubtitleText
                  : AppStyles.subtitleText,
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
                  style: hasUnread
                      ? AppStyles.unreadTimestampText
                      : AppStyles.timestampText,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
