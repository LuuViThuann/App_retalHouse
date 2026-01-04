import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/utils/Snackbar_process.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/notification.dart';
import '../viewmodels/vm_auth.dart';
import '../constants/app_color.dart';
import 'dart:async';

class NotificationUser extends StatefulWidget {
  const NotificationUser({super.key});

  @override
  State<NotificationUser> createState() => _NotificationUserState();
}

class _NotificationUserState extends State<NotificationUser>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;

  bool _isSelectionMode = false;
  final Set<String> _selectedIds = <String>{};
  final StreamController<void> _trashRefreshController = StreamController<void>.broadcast();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    _tabController.addListener(() {
      if (_tabController.index == 2 && _tabController.previousIndex != 2) {
        _trashRefreshController.add(null);
      }
    });

    _loadNotifications();
  }

  @override
  void dispose() {
    _trashRefreshController.close();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    if (!mounted) return;
    final authVM = Provider.of<AuthViewModel>(context, listen: false);
    await authVM.fetchNotifications(page: 1);
  }

  Future<void> _manualRefresh() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final authVM = Provider.of<AuthViewModel>(context, listen: false);
      await authVM.fetchNotifications(page: 1);
      if (mounted) {
        AppSnackBar.show(
          context,
          AppSnackBar.success(
            message: 'Đã cập nhật thông báo',
            icon: Icons.check_circle,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          AppSnackBar.error(
            message: 'Lỗi cập nhật: $e',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _cancelSelection() {
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }

      if (_selectedIds.isEmpty) {
        _isSelectionMode = false;
      }
    });
  }

  void _enterSelectionMode(String id) {
    setState(() {
      _isSelectionMode = true;
      _selectedIds.add(id);
    });
  }

  void _selectAll(List<NotificationModel> notifications) {
    setState(() {
      if (_selectedIds.length == notifications.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.clear();
        _selectedIds.addAll(notifications.map((n) => n.id));
      }
    });
  }

  Future<void> _markSelectedAsRead(AuthViewModel authVM) async {
    final selectedList = _selectedIds.toList();
    for (final id in selectedList) {
      await authVM.markNotificationAsRead(id);
    }
    _cancelSelection();
    if (mounted) {
      AppSnackBar.show(
        context,
        AppSnackBar.success(
          message: 'Đã đánh dấu ${selectedList.length} thông báo',
          icon: Icons.done_all,
        ),
      );
    }
  }

  Future<void> _deleteSelected(AuthViewModel authVM) async {
    final selectedList = _selectedIds.toList();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.delete_outline, color: Colors.red[700], size: 24),
            ),
            const SizedBox(width: 12),
            Text('Xóa ${selectedList.length} thông báo?'),
          ],
        ),
        content: const Text('Bạn có thể hoàn tác trong vòng 30 phút từ thùng rác'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Hủy', style: TextStyle(color: AppColors.grey600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    for (final id in selectedList) {
      await authVM.deleteNotification(id);
    }
    _cancelSelection();

    if (mounted) {
      AppSnackBar.show(
        context,
        AppSnackBar.success(
          message: 'Đã xóa ${selectedList.length} thông báo',
          icon: Icons.delete_sweep,
        ),
      );
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Vừa xong';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} phút trước';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} giờ trước';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} ngày trước';
    } else {
      return DateFormat('dd/MM/yyyy').format(dateTime);
    }
  }

  Widget _buildStatusBadge(String status, {bool isSmall = false}) {
    final Map<String, Map<String, dynamic>> statusConfig = {
      'pending': {
        'label': 'Chờ xử lý',
        'color': Colors.orange[700],
        'icon': Icons.schedule,
      },
      'reviewing': {
        'label': 'Đang xem xét',
        'color': AppColors.primaryBlue,
        'icon': Icons.search,
      },
      'resolved': {
        'label': 'Đã giải quyết',
        'color': Colors.green[700],
        'icon': Icons.check_circle,
      },
      'closed': {
        'label': 'Đã đóng',
        'color': AppColors.grey600,
        'icon': Icons.check,
      },
    };

    final config = statusConfig[status] ?? statusConfig['pending']!;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 10 : 14,
        vertical: isSmall ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: (config['color'] as Color).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (config['color'] as Color).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            config['icon'] as IconData,
            size: isSmall ? 14 : 16,
            color: config['color'] as Color,
          ),
          const SizedBox(width: 6),
          Text(
            config['label'] as String,
            style: TextStyle(
              fontSize: isSmall ? 11 : 13,
              fontWeight: FontWeight.w600,
              color: config['color'] as Color,
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Hàm xác định icon dựa trên loại thông báo
  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'Comment':
        return Icons.chat_bubble_outline_rounded;
      case 'Reply':
      case 'Comment_Reply':
        return Icons.reply_rounded;
      case 'feedback_response':
        return Icons.feedback_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  // ✅ Hàm xác định màu dựa trên loại thông báo
  Color _getNotificationColor(String type) {
    switch (type) {
      case 'Comment':
        return const Color(0xFF4CAF50);
      case 'Reply':
      case 'Comment_Reply':
        return const Color(0xFF2196F3);
      case 'feedback_response':
        return AppColors.primaryBlue;
      default:
        return AppColors.primaryBlue;
    }
  }

  // ✅ Hàm lấy tiêu đề loại thông báo
  String _getNotificationType(String type) {
    switch (type) {
      case 'Comment':
        return 'Bình luận mới';
      case 'Reply':
        return 'Phản hồi mới';
      case 'Comment_Reply':
        return 'Phản hồi bình luận';
      case 'feedback_response':
        return 'Phản hồi phản ánh';
      default:
        return 'Thông báo';
    }
  }

  // ✅ Build Comment Notification Detail
  Widget _buildCommentNotificationDetail(NotificationModel notification) {
    final details = notification.details as Map<String, dynamic>? ?? {};
    final rentalTitle = details['rentalTitle'] as String? ?? 'Bài viết';
    final commenterName = details['commenterName'] as String? ?? 'Người dùng';
    final commentContent = details['commentContent'] as String? ?? notification.message;
    final rating = details['rating'] as int? ?? 0;

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF4CAF50), const Color(0xFF45a049)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: Color(0xFF4CAF50),
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTime(notification.createdAt),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.blue50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primaryBlue.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.article, size: 16, color: AppColors.primaryBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Bài viết: $rentalTitle',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFF4CAF50).withOpacity(0.2),
                child: const Icon(Icons.person, size: 16, color: Color(0xFF4CAF50)),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    commenterName,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  Text(
                    'đã bình luận',
                    style: TextStyle(fontSize: 12, color: AppColors.grey600),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.grey100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (rating > 0) ...[
                  Row(
                    children: [
                      ...List.generate(5, (index) {
                        return Icon(
                          index < rating ? Icons.star : Icons.star_border,
                          size: 18,
                          color: Colors.amber,
                        );
                      }),
                      const SizedBox(width: 8),
                      Text(
                        '$rating/5',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  commentContent,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: AppColors.grey700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Đóng',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Build Reply Notification Detail
  Widget _buildReplyNotificationDetail(NotificationModel notification) {
    final details = notification.details as Map<String, dynamic>? ?? {};
    final rentalTitle = details['rentalTitle'] as String? ?? 'Bài viết';
    final replierName = details['replierName'] as String? ?? 'Người dùng';
    final replyContent = details['replyContent'] as String? ?? notification.message;
    final originalComment = details['originalComment'] as String?;

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF2196F3), const Color(0xFF1976D2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.reply_rounded,
                      color: Color(0xFF2196F3),
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTime(notification.createdAt),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.blue50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primaryBlue.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.article, size: 16, color: AppColors.primaryBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Bài viết: $rentalTitle',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (originalComment != null && originalComment.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bình luận gốc:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.grey600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    originalComment,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.grey700,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFF2196F3).withOpacity(0.2),
                child: const Icon(Icons.person, size: 16, color: Color(0xFF2196F3)),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    replierName,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  Text(
                    'đã phản hồi',
                    style: TextStyle(fontSize: 12, color: AppColors.grey600),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.blue50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primaryBlue.withOpacity(0.3)),
            ),
            child: Text(
              replyContent,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppColors.grey700,
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Đóng',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackNotificationDetail(NotificationModel notification) {
    final details = notification.details as Map<String, dynamic>? ?? {};
    final feedbackTitle = details['feedbackTitle'] as String? ?? 'Phản hồi của bạn';
    final previousStatus = details['previousStatus'] as String? ?? 'pending';
    final newStatus = details['newStatus'] as String? ?? 'reviewing';
    final adminResponse = details['adminResponse'] as String?;

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primaryBlue, AppColors.primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.feedback,
                      color: AppColors.primaryBlue,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTime(notification.createdAt),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Text(
            notification.message,
            style: const TextStyle(fontSize: 15, height: 1.5),
          ),
          const SizedBox(height: 20),

          Container(
            decoration: BoxDecoration(
              color: AppColors.blue50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primaryBlue.withOpacity(0.2)),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.article, size: 18, color: AppColors.primaryBlue),
                    const SizedBox(width: 8),
                    Text(
                      'Tiêu đề phản hồi',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.grey700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  feedbackTitle,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Trạng thái cũ',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.grey600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            _buildStatusBadge(previousStatus, isSmall: true),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward, color: AppColors.primaryBlue, size: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Trạng thái mới',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.grey600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            _buildStatusBadge(newStatus, isSmall: true),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (adminResponse != null && adminResponse.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.blue50, AppColors.blue100],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primaryBlue.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.support_agent, size: 18, color: AppColors.primaryBlue),
                      SizedBox(width: 8),
                      Text(
                        'Phản hồi từ quản trị viên',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    adminResponse,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.grey700,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Đóng',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.blue50,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              size: 60,
              color: AppColors.primaryBlue,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Không có thông báo',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Bạn sẽ nhận thông báo khi có cập nhật mới',
            style: TextStyle(
              color: AppColors.grey600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationList(
      List<NotificationModel> notifications, AuthViewModel authVM) {
    if (notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.blue50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _tabController.index == 0
                    ? Icons.mark_email_read_rounded
                    : Icons.notifications_none_rounded,
                size: 60,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _tabController.index == 0
                  ? 'Bạn đã đọc hết thông báo!'
                  : 'Không có thông báo',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: notifications.length + (_isSelectionMode ? 1 : 0),
      itemBuilder: (context, index) {
        if (_isSelectionMode && index == 0) {
          final allSelected = _selectedIds.length == notifications.length;
          final someSelected = _selectedIds.isNotEmpty && !allSelected;

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.blue50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: Checkbox(
                value: allSelected || someSelected,
                tristate: true,
                onChanged: (value) => _selectAll(notifications),
                activeColor: AppColors.primaryBlue,
              ),
              title: Text(
                allSelected ? 'Bỏ chọn tất cả' : 'Chọn tất cả',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              onTap: () => _selectAll(notifications),
            ),
          );
        }

        final notification = notifications[_isSelectionMode ? index - 1 : index];
        final isSelected = _selectedIds.contains(notification.id);

        return _buildNotificationCard(notification, authVM, isSelected: isSelected);
      },
    );
  }

  Widget _buildNotificationCard(
      NotificationModel notification,
      AuthViewModel authVM, {
        bool isSelected = false,
      }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.blue50 : AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? AppColors.primaryBlue : Colors.grey[200]!,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _isSelectionMode
            ? () => _toggleSelection(notification.id)
            : () {
          _showNotificationDetail(notification);
          if (!notification.read) {
            authVM.markNotificationAsRead(notification.id);
          }
        },
        onLongPress: () => _enterSelectionMode(notification.id),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              if (_isSelectionMode)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Checkbox(
                    value: isSelected,
                    onChanged: (_) => _toggleSelection(notification.id),
                    activeColor: AppColors.primaryBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _getNotificationColor(notification.type).withOpacity(0.1),
                      _getNotificationColor(notification.type).withOpacity(0.05)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _getNotificationColor(notification.type).withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Icon(
                    _getNotificationIcon(notification.type),
                    color: _getNotificationColor(notification.type),
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: TextStyle(
                        fontWeight: notification.read ? FontWeight.w500 : FontWeight.w600,
                        fontSize: 15,
                        color: notification.read ? AppColors.grey700 : AppColors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notification.message,
                      style: TextStyle(
                        color: AppColors.grey600,
                        fontSize: 13,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 13,
                          color: AppColors.grey500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatTime(notification.createdAt),
                          style: TextStyle(
                            color: AppColors.grey500,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getNotificationColor(notification.type).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _getNotificationType(notification.type),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _getNotificationColor(notification.type),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!notification.read && !_isSelectionMode)
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryBlue.withOpacity(0.5),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNotificationDetail(NotificationModel notification) {
    if (notification.type == 'Comment') {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (context, scrollController) => SingleChildScrollView(
              controller: scrollController,
              child: _buildCommentNotificationDetail(notification),
            ),
          ),
        ),
      );
    } else if (notification.type == 'Reply' || notification.type == 'Comment_Reply') {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (context, scrollController) => SingleChildScrollView(
              controller: scrollController,
              child: _buildReplyNotificationDetail(notification),
            ),
          ),
        ),
      );
    } else if (notification.type == 'feedback_response') {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (context, scrollController) => SingleChildScrollView(
              controller: scrollController,
              child: _buildFeedbackNotificationDetail(notification),
            ),
          ),
        ),
      );
    }
  }

  Widget _buildDetailsDisplay(Map<String, dynamic> details) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: details.entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.circle, size: 6, color: AppColors.primaryBlue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${entry.key}: ${entry.value}',
                  style: TextStyle(
                    color: AppColors.grey700,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Future<void> _performUndoSingle(String notificationId, AuthViewModel authVM) async {
    try {
      bool success = await authVM.undoDeleteNotificationSingle(notificationId);

      if (success && mounted) {
        AppSnackBar.show(
          context,
          AppSnackBar.success(
            message: 'Đã hoàn tác thông báo',
            icon: Icons.restore,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          AppSnackBar.error(message: 'Lỗi hoàn tác: $e'),
        );
      }
    }
  }

  Future<void> _permanentDeleteFromUndo(String notificationId, AuthViewModel authVM) async {
    try {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.delete_forever, color: Colors.red[700], size: 24),
              ),
              const SizedBox(width: 12),
              const Text('Xóa vĩnh viễn?'),
            ],
          ),
          content: const Text('Không thể hoàn tác sau khi xóa vĩnh viễn'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Hủy', style: TextStyle(color: AppColors.grey600)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Xóa vĩnh viễn'),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      bool success = await authVM.permanentDeleteFromUndo(notificationId);

      if (success && mounted) {
        AppSnackBar.show(
          context,
          AppSnackBar.success(
            message: 'Đã xóa vĩnh viễn',
            icon: Icons.delete_forever,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          AppSnackBar.error(message: 'Lỗi xóa: $e'),
        );
      }
    }
  }

  Widget _buildDeletedNotificationsList() {
    final authVM = Provider.of<AuthViewModel>(context, listen: false);

    return StreamBuilder<void>(
      stream: _trashRefreshController.stream,
      builder: (context, _) {
        return FutureBuilder<Map<String, dynamic>>(
          key: ValueKey('trash_${DateTime.now().millisecondsSinceEpoch}'),
          future: authVM.getDeletedNotifications(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
                ),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                    const SizedBox(height: 16),
                    Text(
                      'Lỗi tải dữ liệu',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.red[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      style: TextStyle(color: AppColors.grey600, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            final result = snapshot.data ?? {'count': 0, 'data': []};
            final count = result['count'] as int? ?? 0;
            final deletedList = result['data'] as List? ?? [];

            if (count == 0 || deletedList.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppColors.blue50,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        size: 60,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Thùng rác trống',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Không có thông báo nào đã xóa',
                      style: TextStyle(
                        color: AppColors.grey600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.orange[50]!, Colors.orange[100]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange[300]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_rounded, color: Colors.orange[700], size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Tự động xóa vĩnh viễn sau 30 phút',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.orange[900],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                ...deletedList.map((item) {
                  final data = item as Map<String, dynamic>;
                  final id = data['_id'] ?? '';
                  final title = data['title'] ?? 'Thông báo';
                  final message = data['message'] ?? '';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[200]!),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.red[200]!,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.notifications_rounded,
                              color: Colors.red[400],
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  message,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.grey600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryBlue.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              onPressed: () => _performUndoSingle(id, authVM),
                              icon: const Icon(Icons.restore_rounded, size: 16),
                              label: const Text(
                                'Hoàn tác',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: IconButton(
                              onPressed: () => _permanentDeleteFromUndo(id, authVM),
                              icon: Icon(
                                Icons.delete_forever_rounded,
                                size: 20,
                                color: Colors.red[700],
                              ),
                              padding: EdgeInsets.zero,
                              tooltip: 'Xóa vĩnh viễn',
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          _isSelectionMode ? '${_selectedIds.length} đã chọn' : 'Thông báo',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        leading: _isSelectionMode
            ? IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: _cancelSelection,
          tooltip: 'Hủy chọn',
        )
            : null,
        actions: [
          if (_isSelectionMode) ...[
            IconButton(
              icon: const Icon(Icons.done_all_rounded),
              tooltip: 'Đánh dấu đã đọc',
              onPressed: _selectedIds.isEmpty
                  ? null
                  : () => _markSelectedAsRead(
                Provider.of<AuthViewModel>(context, listen: false),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: 'Xóa',
              onPressed: _selectedIds.isEmpty
                  ? null
                  : () => _deleteSelected(
                Provider.of<AuthViewModel>(context, listen: false),
              ),
            ),
          ] else if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _manualRefresh,
              tooltip: 'Cập nhật thông báo',
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: AppColors.primaryBlue,
            child: TabBar(
              controller: _tabController,
              onTap: (_) {
                if (_isSelectionMode) _cancelSelection();
              },
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              tabs: const [
                Tab(text: 'Chưa đọc'),
                Tab(text: 'Tất cả'),
                Tab(text: 'Thùng rác'),
              ],
            ),
          ),
        ),
      ),
      body: Consumer<AuthViewModel>(
        builder: (context, authVM, _) {
          final allNotifications = authVM.notifications;
          final unreadNotifications = allNotifications.where((n) => !n.read).toList();
          final currentList = _tabController.index == 0 ? unreadNotifications : allNotifications;

          if (authVM.isLoading && allNotifications.isEmpty && _tabController.index != 2) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
              ),
            );
          }

          if (allNotifications.isEmpty && _tabController.index != 2) {
            return _buildEmptyState();
          }

          return Stack(
            children: [
              TabBarView(
                controller: _tabController,
                children: [
                  _buildNotificationList(unreadNotifications, authVM),
                  _buildNotificationList(allNotifications, authVM),
                  _buildDeletedNotificationsList(),
                ],
              ),
              if (!_isSelectionMode && currentList.isNotEmpty && _tabController.index != 2)
                Positioned(
                  bottom: 24,
                  right: 24,
                  child: FloatingActionButton(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    onPressed: () {
                      setState(() {
                        _isSelectionMode = true;
                      });
                    },
                    tooltip: 'Chọn nhiều',
                    elevation: 4,
                    child: const Icon(Icons.checklist_rounded, size: 28),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}