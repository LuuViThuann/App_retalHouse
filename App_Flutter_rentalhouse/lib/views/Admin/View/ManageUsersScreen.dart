import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/views/Admin/View/user_detail_screen.dart';
import 'package:flutter_rentalhouse/views/Admin/ViewModel/admin_viewmodel.dart';
import 'package:provider/provider.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen>
    with AutomaticKeepAliveClientMixin {
  late ScrollController _scrollController;
  int _currentPage = 1;
  bool _isLoadingMore = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

    // ✅ FIX: Luôn fetch dữ liệu mới (xóa cache cũ)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final viewModel = context.read<AdminViewModel>();
        // ✅ THÊM: Xóa cache cũ trước khi fetch
        viewModel.clearAvatarCache();
        // ✅ THÊM: Reset danh sách cũ
        viewModel.resetUsersList();
        // Fetch page 1
        viewModel.fetchUsers(page: 1);
      }
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;

    setState(() => _isLoadingMore = true);
    _currentPage++;
    await context.read<AdminViewModel>().fetchUsers(page: _currentPage);
    if (mounted) {
      setState(() => _isLoadingMore = false);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý người dùng'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        // ✅ THÊM: Nút refresh
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _currentPage = 1;
              context.read<AdminViewModel>().clearAvatarCache();
              context.read<AdminViewModel>().resetUsersList();
              context.read<AdminViewModel>().fetchUsers(page: 1);
            },
          ),
        ],
      ),
      body: Selector<AdminViewModel, List<Map<String, dynamic>>>(
        selector: (_, viewModel) => viewModel.users,
        shouldRebuild: (previous, next) {
          if (previous.length != next.length) return true;
          for (int i = 0; i < previous.length; i++) {
            if (previous[i]['id'] != next[i]['id']) return true;
            if (previous[i]['username'] != next[i]['username']) return true;
            if (previous[i]['email'] != next[i]['email']) return true;
            if (previous[i]['phoneNumber'] != next[i]['phoneNumber'])
              return true;
            if (previous[i]['role'] != next[i]['role']) return true;
          }
          return false;
        },
        builder: (context, users, child) {
          if (users.isEmpty) {
            return const Center(
              child: SizedBox(
                width: 50,
                height: 50,
                child: CircularProgressIndicator(),
              ),
            );
          }

          return ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(12),
            itemCount: users.length + (_isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == users.length) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final user = users[index];
              final userId = user['id'] as String;

              return _UserListItem(
                user: user,
                userId: userId,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UserDetailScreen(userId: userId),
                    ),
                  );
                },
                onDelete: () {
                  _showDeleteDialog(
                    context,
                    context.read<AdminViewModel>(),
                    userId,
                    user['username'] as String?,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  void _showDeleteDialog(
    BuildContext context,
    AdminViewModel vm,
    String userId,
    String? username,
  ) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Xác nhận xóa'),
        content: Text(
          'Bạn có chắc chắn muốn xóa tài khoản:\n"${username ?? 'Người dùng này'}"?\n\nHành động này không thể hoàn tác!',
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              await vm.deleteUser(userId);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Đã xóa người dùng "$username"'),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            child: const Text('Xóa vĩnh viễn',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _UserListItem extends StatefulWidget {
  final Map<String, dynamic> user;
  final String userId;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _UserListItem({
    required this.user,
    required this.userId,
    required this.onTap,
    required this.onDelete,
  });

  @override
  State<_UserListItem> createState() => _UserListItemState();
}

class _UserListItemState extends State<_UserListItem> {
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: _buildAvatarWidget(),
        title: Text(
          widget.user['username'] ?? 'Chưa đặt tên',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              widget.user['email'] ?? 'Chưa có email',
              style: TextStyle(color: Colors.grey[700]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              widget.user['phoneNumber'] ?? 'Chưa có số điện thoại',
              style: TextStyle(color: Colors.grey[600]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Chip(
              label: Text(
                widget.user['role'] == 'admin' ? 'Quản trị viên' : 'Người dùng',
                style: const TextStyle(fontSize: 12),
              ),
              backgroundColor: widget.user['role'] == 'admin'
                  ? Colors.red.shade100
                  : Colors.green.shade100,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          key: ValueKey('menu_${widget.userId}'),
          icon: const Icon(Icons.more_vert),
          onSelected: (value) {
            if (value == 'edit') {
              widget.onTap();
            } else if (value == 'delete') {
              widget.onDelete();
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit),
                  SizedBox(width: 8),
                  Text('Xem & Sửa')
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Xóa', style: TextStyle(color: Colors.red))
                ],
              ),
            ),
          ],
        ),
        onTap: widget.onTap,
      ),
    );
  }

  Widget _buildAvatarWidget() {
    return Selector<AdminViewModel, String?>(
      selector: (_, viewModel) => viewModel.getAvatarFromCache(widget.userId),
      shouldRebuild: (previous, next) => previous != next,
      builder: (context, cachedAvatar, _) {
        final avatarBase64 =
            cachedAvatar ?? widget.user['avatarBase64'] as String?;

        if (avatarBase64 != null && avatarBase64.isNotEmpty) {
          try {
            return CircleAvatar(
              radius: 32,
              backgroundColor: Colors.grey.shade200,
              backgroundImage: MemoryImage(base64Decode(avatarBase64)),
              onBackgroundImageError: (_, __) {},
            );
          } catch (e) {
            return _defaultAvatar();
          }
        }

        if (avatarBase64 == null && widget.user['hasAvatar'] == true) {
          Future.microtask(
            () => context
                .read<AdminViewModel>()
                .fetchAvatarForUser(widget.userId),
          );
        }

        return _defaultAvatar();
      },
    );
  }

  Widget _defaultAvatar() {
    return CircleAvatar(
      radius: 32,
      backgroundColor: Colors.grey.shade200,
      child: const Icon(Icons.person, size: 32, color: Colors.grey),
    );
  }
}
