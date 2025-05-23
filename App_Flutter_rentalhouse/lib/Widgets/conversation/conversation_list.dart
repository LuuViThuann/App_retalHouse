import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/Widgets/conversation/conversation_title.dart';
import 'package:flutter_rentalhouse/constants/app_style.dart';
import 'package:flutter_rentalhouse/models/conversation.dart';
import 'package:flutter_rentalhouse/utils/sort_conversation.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_auth.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_chat.dart';

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

    // Filter and sort conversations only once per build
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
      padding: EdgeInsets.all(16),
      itemCount: sortedConversations.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final conversation = sortedConversations[index];
        return ConversationTile(
          key: ValueKey(conversation.id), // Ensure stable keys for optimization
          conversation: conversation,
          token: authViewModel.currentUser!.token!,
        );
      },
    );
  }

  Widget _buildEmptyState({required IconData icon, required String message}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: AppStyles.grey400),
          SizedBox(height: 16),
          Text(
            message,
            style: AppStyles.emptyStateText,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppStyles.primaryColor),
          ),
          SizedBox(height: 16),
          Text(
            'Đang tải cuộc trò chuyện...',
            style: AppStyles.loadingText,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String errorMessage) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: AppStyles.errorColor),
          const SizedBox(height: 16),
          Text(
            errorMessage,
            style: AppStyles.errorText,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            style: AppStyles.retryButtonStyle,
            child: const Text('Thử lại', style: AppStyles.retryButtonText),
          ),
        ],
      ),
    );
  }
}
