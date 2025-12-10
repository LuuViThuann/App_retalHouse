import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/Widgets/Message/chat_image_full_screen.dart';
import 'package:flutter_rentalhouse/models/message.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_auth.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_chat.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class ChatMessageList extends StatefulWidget {
  final ScrollController scrollController;
  final bool isFetchingOlderMessages;
  final Function(Message) onLongPress;
  final Map<String, GlobalKey> messageKeys;
  final VoidCallback onComposeNewMessage;

  const ChatMessageList({
    super.key,
    required this.scrollController,
    required this.isFetchingOlderMessages,
    required this.onLongPress,
    required this.messageKeys,
    required this.onComposeNewMessage,
  });

  @override
  State<ChatMessageList> createState() => _ChatMessageListState();
}

class _ChatMessageListState extends State<ChatMessageList> {

  void _showSnackBarSafe(String message, {bool isSuccess = true}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? Colors.green[600] : Colors.red[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _deleteMessageSafe(
      Message message,
      ChatViewModel chatViewModel,
      AuthViewModel authViewModel,
      ) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      final success = await chatViewModel.deleteMessage(
        messageId: message.id,
        token: authViewModel.currentUser!.token!,
      );

      if (!mounted) return;

      if (success) {
        messenger.showSnackBar(
          SnackBar(
            content: const Text('Tin nhắn đã được xóa'),
            backgroundColor: Colors.green[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
                chatViewModel.errorMessage ?? 'Lỗi khi xóa tin nhắn'),
            backgroundColor: Colors.red[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      messenger.showSnackBar(
        SnackBar(
          content: Text('Lỗi: ${e.toString()}'),
          backgroundColor: Colors.red[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showDeleteConfirmDialog(
      Message message,
      ChatViewModel chatViewModel,
      AuthViewModel authViewModel,
      ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc chắn muốn xóa tin nhắn này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _deleteMessageSafe(message, chatViewModel, authViewModel);
            },
            child: const Text(
              'Xóa',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showMessageActions(
      Message message,
      ChatViewModel chatViewModel,
      AuthViewModel authViewModel,
      ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.edit, color: Colors.blue[600]),
              title: const Text('Chỉnh sửa'),
              onTap: () {
                Navigator.pop(sheetContext);
                widget.onLongPress(message);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Colors.red[600]),
              title: const Text('Xóa'),
              onTap: () {
                Navigator.pop(sheetContext);
                _showDeleteConfirmDialog(message, chatViewModel, authViewModel);
              },
            ),
          ],
        ),
      ),
    );
  }

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
    if (!mounted || !widget.scrollController.hasClients) return;

    if (messageId != null && widget.messageKeys.containsKey(messageId)) {
      final key = widget.messageKeys[messageId]!;
      final keyContext = key.currentContext;
      if (keyContext != null) {
        Scrollable.ensureVisible(
          keyContext,
          alignment: 0.5,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } else {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && widget.scrollController.hasClients) {
          widget.scrollController.animateTo(
            widget.scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  List<TextSpan> _highlightMatch(String text, String query) {
    if (query.isEmpty) return [TextSpan(text: text)];
    final matches = <TextSpan>[];
    int lastIndex = 0;
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    int index = lowerText.indexOf(lowerQuery);

    while (index != -1) {
      if (index > lastIndex) {
        matches.add(TextSpan(text: text.substring(lastIndex, index)));
      }
      matches.add(TextSpan(
        text: text.substring(index, index + query.length),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          backgroundColor: Colors.yellow[300],
        ),
      ));
      lastIndex = index + query.length;
      index = lowerText.indexOf(lowerQuery, lastIndex);
    }

    if (lastIndex < text.length) {
      matches.add(TextSpan(text: text.substring(lastIndex)));
    }

    return matches.isEmpty ? [TextSpan(text: text)] : matches;
  }

  // ✅ NEW: Build avatar widget with CachedNetworkImage
  Widget _buildAvatar(Map<String, dynamic> sender, {double radius = 20}) {
    final avatarUrl = sender['avatarUrl']?.toString() ?? '';

    return Container(
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
        radius: radius,
        backgroundColor: Colors.grey[200],
        child: avatarUrl.isNotEmpty
            ? ClipOval(
          child: CachedNetworkImage(
            imageUrl: avatarUrl,
            fit: BoxFit.cover,
            width: radius * 2,
            height: radius * 2,
            placeholder: (context, url) => SizedBox(
              width: radius,
              height: radius,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.grey[600],
              ),
            ),
            errorWidget: (context, url, error) => Icon(
              Icons.person,
              size: radius,
              color: Colors.grey[600],
            ),
          ),
        )
            : Icon(
          Icons.person,
          size: radius,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context);
    final chatViewModel = Provider.of<ChatViewModel>(context);
    final String conversationId = chatViewModel.currentConversationId ?? '';
    final Set<String> highlightedMessageIds =
        chatViewModel.highlightedMessageIds;
    final String? searchQuery = chatViewModel.searchQuery;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (widget.scrollController.hasClients && !widget.isFetchingOlderMessages) {
        if (highlightedMessageIds.isEmpty) {
          widget.scrollController.jumpTo(
            widget.scrollController.position.maxScrollExtent,
          );
        } else if (highlightedMessageIds.isNotEmpty &&
            widget.messageKeys.containsKey(highlightedMessageIds.first)) {
          _scrollToMessage(highlightedMessageIds.first, chatViewModel.messages);
        }
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

    Map<String, List<Message>> groupedMessages = {};
    for (var message in messages) {
      final header = _getDateHeader(message.createdAt);
      if (!groupedMessages.containsKey(header)) {
        groupedMessages[header] = [];
      }
      groupedMessages[header]!.add(message);
      widget.messageKeys[message.id] = GlobalKey();
    }

    final sortedHeaders = groupedMessages.keys.toList()
      ..sort((a, b) {
        DateTime dateA = a == 'Hôm nay'
            ? DateTime.now()
            : a == 'Hôm qua'
            ? DateTime.now().subtract(const Duration(days: 1))
            : a.contains('ngày trước')
            ? DateTime.now()
            .subtract(Duration(days: int.parse(a.split(' ')[0])))
            : DateFormat('dd/MM/yyyy').parse(a);
        DateTime dateB = b == 'Hôm nay'
            ? DateTime.now()
            : b == 'Hôm qua'
            ? DateTime.now().subtract(const Duration(days: 1))
            : b.contains('ngày trước')
            ? DateTime.now()
            .subtract(Duration(days: int.parse(b.split(' ')[0])))
            : DateFormat('dd/MM/yyyy').parse(b);
        return dateB.compareTo(dateA);
      });

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
            controller: widget.scrollController,
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
                  key: widget.messageKeys[message.id],
                  onLongPress: isMe
                      ? () => _showMessageActions(
                    message,
                    chatViewModel,
                    authViewModel,
                  )
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisAlignment: isMe
                          ? MainAxisAlignment.end
                          : MainAxisAlignment.start,
                      children: [
                        if (!isMe) ...[
                          _buildAvatar(message.sender),
                          const SizedBox(width: 10),
                        ],
                        Flexible(
                          child: GestureDetector(
                            onTap: () {
                              if (highlightedMessageIds.contains(message.id)) {
                                _scrollToMessage(
                                    message.id, chatViewModel.messages);
                              }
                            },
                            child: Container(
                              constraints: BoxConstraints(
                                  maxWidth:
                                  MediaQuery.of(context).size.width * 0.75),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isMe
                                      ? [Colors.blue[400]!, Colors.blue[600]!]
                                      : [Colors.grey[200]!, Colors.grey[300]!],
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
                                border:
                                highlightedMessageIds.contains(message.id)
                                    ? Border.all(
                                    color: Colors.red[700]!, width: 2)
                                    : null,
                              ),
                              child: Column(
                                crossAxisAlignment: isMe
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  // ✅ Image display with proper caching
                                  if (message.images.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          // ✅ Filter and display only valid URLs
                                          ...message.images
                                              .asMap()
                                              .entries
                                              .map((entry) {
                                            int index = entry.key;
                                            String imageUrl = entry.value;

                                            // ✅ Validate URL before rendering
                                            if (imageUrl.isEmpty ||
                                                (!imageUrl.startsWith('http://') &&
                                                    !imageUrl.startsWith('https://'))) {
                                              if (kDebugMode) {
                                                print('⚠️ Skipping invalid image URL: $imageUrl');
                                              }
                                              return const SizedBox.shrink();
                                            }

                                            // ✅ Show loading placeholder for uploading images
                                            if (imageUrl.startsWith('uploading_')) {
                                              if (kDebugMode) {
                                                print('⏳ Showing placeholder for: $imageUrl');
                                              }
                                              return Container(
                                                width: 120,
                                                height: 120,
                                                decoration: BoxDecoration(
                                                  color: Colors.grey[200],
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: const Center(
                                                  child: CircularProgressIndicator(strokeWidth: 2),
                                                ),
                                              );
                                            }

                                            if (kDebugMode) {
                                              print('🖼️ [Message: ${message.id}] Rendering image $index: $imageUrl');
                                            }

                                            return GestureDetector(
                                              onTap: () {
                                                if (kDebugMode) {
                                                  print('🖼️ Tapped image $index: $imageUrl');
                                                }
                                                showDialog(
                                                  context: context,
                                                  builder: (context) => ChatFullImage(
                                                    imageUrl: imageUrl,
                                                  ),
                                                );
                                              },
                                              child: Hero(
                                                tag: 'message_image_${message.id}_$index',
                                                child: ClipRRect(
                                                  borderRadius: BorderRadius.circular(12),
                                                  child: Stack(
                                                    children: [
                                                      // ✅ CachedNetworkImage with proper cache key
                                                      CachedNetworkImage(
                                                        imageUrl: imageUrl,
                                                        width: 120,
                                                        height: 120,
                                                        fit: BoxFit.cover,
                                                        memCacheHeight: 240,
                                                        memCacheWidth: 240,
                                                        // ✅ CRITICAL: Cache key includes updatedAt
                                                        // This forces refresh when message is edited
                                                        cacheKey: '${imageUrl}_${message.updatedAt?.millisecondsSinceEpoch ?? message.createdAt.millisecondsSinceEpoch}',
                                                        maxWidthDiskCache: 500,
                                                        maxHeightDiskCache: 500,
                                                        placeholder: (context, url) {
                                                          return Container(
                                                            width: 120,
                                                            height: 120,
                                                            color: Colors.grey[100],
                                                            child: const Center(
                                                              child: CircularProgressIndicator(
                                                                strokeWidth: 2,
                                                              ),
                                                            ),
                                                          );
                                                        },
                                                        errorWidget: (context, url, error) {
                                                          if (kDebugMode) {
                                                            print('❌ Error loading image: $url');
                                                            print('   Error: $error');
                                                          }
                                                          return Container(
                                                            width: 120,
                                                            height: 120,
                                                            color: Colors.red[100],
                                                            child: Column(
                                                              mainAxisAlignment: MainAxisAlignment.center,
                                                              children: [
                                                                Icon(
                                                                  Icons.broken_image,
                                                                  color: Colors.red[700],
                                                                  size: 32,
                                                                ),
                                                                const SizedBox(height: 4),
                                                                Text(
                                                                  'Lỗi tải ảnh',
                                                                  style: TextStyle(
                                                                    fontSize: 10,
                                                                    color: Colors.red[700],
                                                                  ),
                                                                  textAlign: TextAlign.center,
                                                                ),
                                                              ],
                                                            ),
                                                          );
                                                        },
                                                      ),
                                                      // ✅ Image counter badge
                                                      if (message.images.length > 1)
                                                        Positioned(
                                                          top: 4,
                                                          right: 4,
                                                          child: Container(
                                                            decoration: BoxDecoration(
                                                              color: Colors.black54,
                                                              borderRadius: BorderRadius.circular(8),
                                                            ),
                                                            padding: const EdgeInsets.symmetric(
                                                              horizontal: 6,
                                                              vertical: 2,
                                                            ),
                                                            child: Text(
                                                              '${index + 1}/${message.images.length}',
                                                              style: const TextStyle(
                                                                color: Colors.white,
                                                                fontSize: 10,
                                                                fontWeight: FontWeight.bold,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      // ✅ Edited indicator
                                                      if (message.updatedAt != null)
                                                        Positioned(
                                                          bottom: 4,
                                                          left: 4,
                                                          child: Container(
                                                            decoration: BoxDecoration(
                                                              color: Colors.black54,
                                                              borderRadius: BorderRadius.circular(8),
                                                            ),
                                                            padding: const EdgeInsets.symmetric(
                                                              horizontal: 4,
                                                              vertical: 2,
                                                            ),
                                                            child: const Text(
                                                              'Đã sửa',
                                                              style: TextStyle(
                                                                color: Colors.white,
                                                                fontSize: 9,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            );
                                          })
                                              .toList(),
                                        ],
                                      ),
                                    ),

                                  // Content text
                                  if (message.content.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      child: RichText(
                                        text: TextSpan(
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: isMe
                                                ? Colors.white
                                                : Colors.grey[800],
                                            fontWeight: FontWeight.w400,
                                          ),
                                          children: _highlightMatch(
                                              message.content,
                                              searchQuery ?? ''),
                                        ),
                                      ),
                                    ),

                                  // Timestamp
                                  const SizedBox(height: 6),
                                  Text(
                                    message.updatedAt != null
                                        ? 'Đã chỉnh sửa - ${DateFormat('HH:mm, dd/MM').format(message.updatedAt!)}'
                                        : DateFormat('HH:mm, dd/MM').format(message.createdAt),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isMe
                                          ? Colors.white70
                                          : Colors.grey[600],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              )
                            ),
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 10),
                          _buildAvatar(message.sender),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          if (widget.isFetchingOlderMessages)
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