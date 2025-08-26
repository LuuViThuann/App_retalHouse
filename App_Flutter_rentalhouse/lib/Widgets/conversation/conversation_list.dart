import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/Widgets/conversation/conversation_title.dart';
import 'package:flutter_rentalhouse/config/loading.dart';
import 'package:flutter_rentalhouse/constants/app_style.dart';
import 'package:flutter_rentalhouse/models/conversation.dart';
import 'package:flutter_rentalhouse/utils/sort_conversation.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_auth.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_chat.dart';
import 'package:lottie/lottie.dart';

class ConversationList extends StatelessWidget {
  final AuthViewModel authViewModel;
  final ChatViewModel chatViewModel;
  final VoidCallback onRetry;
  final String searchQuery;

  const ConversationList({
    super.key,
    required this.authViewModel,
    required this.chatViewModel,
    required this.onRetry,
    required this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    if (authViewModel.currentUser == null) {
      return _buildEmptyState(
        icon: Icons.login,
        message: 'Vui lòng đăng nhập để xem cuộc trò chuyện',
      );
    }

    if (chatViewModel.isLoading) {
      return _buildLoadingState();
    }

    if (chatViewModel.errorMessage != null) {
      return _buildErrorState(context, chatViewModel.errorMessage!);
    }

    if (chatViewModel.conversations.isEmpty) {
      return _buildEmptyState(
        icon: Icons.chat_bubble_outline,
        message: 'Chưa có cuộc trò chuyện nào',
      );
    }

    final filteredConversations =
        chatViewModel.conversations.where((conversation) {
      final landlordUsername =
          conversation.landlord['username']?.toLowerCase() ?? 'chủ nhà';
      final query = searchQuery.toLowerCase();
      return query.isEmpty || landlordUsername.contains(query);
    }).toList();

    final sortedConversations =
        ConversationSorter.sortConversations(filteredConversations);

    if (sortedConversations.isEmpty && searchQuery.isNotEmpty) {
      return _buildEmptyState(
        icon: Icons.search_off,
        message: 'Không tìm thấy cuộc trò chuyện nào',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: sortedConversations.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final conversation = sortedConversations[index];
        return ConversationTile(
          key: ValueKey(conversation.id),
          conversation: conversation,
          token: authViewModel.currentUser!.token!,
        );
      },
    );
  }

  Widget _buildEmptyState({required IconData icon, required String message}) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.shade100.withOpacity(0.2),
              blurRadius: 8,
              spreadRadius: 1,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: 1.0,
              duration: const Duration(milliseconds: 200),
              child: Icon(icon, size: 64, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
                letterSpacing: 0.2,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Lottie.asset(
              AssetsConfig.loadingLottie,
              width: 120,
              height: 120,
              fit: BoxFit.fill,
            ),
            const SizedBox(height: 16),
            Text(
              'Đang tải cuộc trò chuyện...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String errorMessage) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.shade100.withOpacity(0.2),
              blurRadius: 8,
              spreadRadius: 1,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: 1.0,
              duration: const Duration(milliseconds: 200),
              child: Icon(Icons.error_outline,
                  size: 64, color: AppStyles.errorColor),
            ),
            const SizedBox(height: 16),
            Text(
              errorMessage,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: onRetry,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade700, Colors.blue.shade900],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.shade300.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Text(
                  'Thử lại',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
