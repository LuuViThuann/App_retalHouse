import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/constants/app_style.dart';
import 'package:flutter_rentalhouse/models/conversation.dart';
import 'package:flutter_rentalhouse/utils/navigation_conversation.dart';
import 'package:flutter_rentalhouse/views/chat_user.dart';
import 'package:shimmer/shimmer.dart';

void showSearchBottomSheet({
  required BuildContext context,
  required TextEditingController searchController,
  required FocusNode searchFocusNode,
  required ValueNotifier<List<Conversation>> filteredConversations,
  required Function(String) onSearchChanged,
  required TickerProvider vsync,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    transitionAnimationController: AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 350),
    )..forward(),
    builder: (context) {
      final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.grey.shade50, Colors.white],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              spreadRadius: 5,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: keyboardHeight > 0 ? keyboardHeight : 16, // Đẩy lên khi có bàn phím
            left: 24,
            right: 24,
            top: 8,
          ),
          child: Column(
            children: [
              // Drag Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.search_rounded, color: Colors.blue.shade700, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Tìm kiếm tin nhắn',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.grey.shade900),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close_rounded, color: Colors.grey.shade600, size: 24),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.grey.shade100,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Search Field + Kết quả
              Expanded(
                child: ValueListenableBuilder<List<Conversation>>(
                  valueListenable: filteredConversations,
                  builder: (context, conversations, child) {
                    return Column(
                      children: [
                        // Search TextField
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: searchFocusNode.hasFocus ? Colors.blue.shade300 : Colors.grey.shade200,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: searchFocusNode.hasFocus
                                    ? Colors.blue.shade100.withOpacity(0.3)
                                    : Colors.grey.shade200.withOpacity(0.2),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: searchController,
                            focusNode: searchFocusNode,
                            autofocus: true,
                            decoration: InputDecoration(
                              hintText: 'Nhập tên người dùng...',
                              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
                              prefixIcon: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Icon(
                                  Icons.search_rounded,
                                  color: searchFocusNode.hasFocus ? Colors.blue.shade600 : Colors.grey.shade400,
                                  size: 24,
                                ),
                              ),
                              suffixIcon: searchController.text.isNotEmpty
                                  ? IconButton(
                                icon: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(color: Colors.grey.shade200, shape: BoxShape.circle),
                                  child: Icon(Icons.close_rounded, color: Colors.grey.shade700, size: 16),
                                ),
                                onPressed: () {
                                  searchController.clear();
                                  onSearchChanged('');
                                },
                              )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                            ),
                            style: TextStyle(fontSize: 16, color: Colors.grey.shade900),
                            onChanged: onSearchChanged,
                          ),
                        ),

                        // Kết quả tìm kiếm (số lượng)
                        if (searchController.text.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                conversations.isEmpty ? 'Không có kết quả' : '${conversations.length} kết quả',
                                style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),

                        // Danh sách kết quả - chiếm hết không gian còn lại
                        Expanded(
                          child: conversations.isEmpty
                              ? _buildEmptyState(searchController.text.isEmpty)
                              : ListView.separated(
                            padding: EdgeInsets.zero,
                            itemCount: conversations.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              return _buildConversationItem(context, conversations[index]);
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  ).whenComplete(() {
    searchController.clear();
    onSearchChanged('');
  });
}

Widget _buildEmptyState(bool isInitial) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isInitial ? Icons.chat_bubble_outline_rounded : Icons.search_off_rounded,
              size: 48,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isInitial
                ? 'Bắt đầu tìm kiếm'
                : 'Không tìm thấy kết quả',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isInitial
                ? 'Nhập tên người dùng để tìm kiếm'
                : 'Thử tìm kiếm với từ khóa khác',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    ),
  );
}

// ✅ Helper widget để hiển thị avatar - support cả network và base64
Widget _buildAvatarWidget(Map<String, dynamic> landlord) {
  final avatarUrl = landlord['avatarUrl']?.toString() ?? '';
  final avatarBase64 = landlord['avatarBase64']?.toString() ?? '';

  // ✅ Priority: URL > Base64 > Default icon
  if (avatarUrl.isNotEmpty && (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://'))) {
    // ✅ Display network image from URL
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: avatarUrl,
        fit: BoxFit.cover,
        width: 52,
        height: 52,
        placeholder: (context, url) => Container(
          color: Colors.blue.shade100,
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade700),
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          color: Colors.blue.shade100,
          child: Icon(
            Icons.person_rounded,
            color: Colors.blue.shade700,
            size: 28,
          ),
        ),
        memCacheHeight: 104,
        memCacheWidth: 104,
      ),
    );
  } else if (avatarBase64.isNotEmpty) {
    // ✅ Display memory image from base64
    try {
      return ClipOval(
        child: Image.memory(
          base64Decode(avatarBase64),
          fit: BoxFit.cover,
          width: 52,
          height: 52,
          errorBuilder: (context, error, stackTrace) => Container(
            color: Colors.blue.shade100,
            child: Icon(
              Icons.person_rounded,
              color: Colors.blue.shade700,
              size: 28,
            ),
          ),
        ),
      );
    } catch (e) {
      print('❌ Error decoding base64 avatar: $e');
      return Container(
        color: Colors.blue.shade100,
        child: Icon(
          Icons.person_rounded,
          color: Colors.blue.shade700,
          size: 28,
        ),
      );
    }
  } else {
    // ✅ Default icon when no avatar
    return Container(
      color: Colors.blue.shade100,
      child: Icon(
        Icons.person_rounded,
        color: Colors.blue.shade700,
        size: 28,
      ),
    );
  }
}

Widget _buildConversationItem(
    BuildContext context,
    Conversation conversation,
    ) {
  final landlord = conversation.landlord;
  final hasUnread = conversation.unreadCount > 0;

  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: () {
        Navigator.pop(context);
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: hasUnread ? Colors.blue.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasUnread
                ? Colors.blue.shade200.withOpacity(0.5)
                : Colors.grey.shade200,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: hasUnread
                  ? Colors.blue.shade100.withOpacity(0.2)
                  : Colors.grey.shade200.withOpacity(0.2),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar with badge
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: hasUnread
                          ? Colors.blue.shade300
                          : Colors.grey.shade300,
                      width: 2,
                    ),
                  ),
                  // ✅ Use helper widget to display avatar
                  child: _buildAvatarWidget(landlord),
                ),
                if (hasUnread)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.red.shade400, Colors.red.shade600],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 20,
                        minHeight: 20,
                      ),
                      child: Center(
                        child: Text(
                          conversation.unreadCount > 9
                              ? '9+'
                              : '${conversation.unreadCount}',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    landlord['username'] ?? 'Chủ nhà',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: Colors.grey.shade900,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (conversation.lastMessage != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      conversation.lastMessage!.content.isNotEmpty
                          ? conversation.lastMessage!.content
                          : conversation.lastMessage!.images.isNotEmpty
                          ? '${conversation.lastMessage!.images.length} hình ảnh'
                          : 'Tin nhắn',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Action icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.chevron_right_rounded,
                color: Colors.blue.shade600,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}