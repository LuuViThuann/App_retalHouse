import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/views/Admin/View/user_detail_screen.dart';
import 'package:flutter_rentalhouse/views/Admin/ViewModel/admin_viewmodel.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final viewModel = context.read<AdminViewModel>();
        viewModel.clearAvatarCache();
        viewModel.resetUsersList();
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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'Quản lý người dùng',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black54),
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
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              ),
            );
          }

          return ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: users.length + (_isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == users.length) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor:
                      AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                  ),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'Xác nhận xóa',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        content: Text(
          'Bạn có chắc chắn muốn xóa tài khoản:\n"${username ?? 'Người dùng này'}"?\n\nHành động này không thể hoàn tác!',
          style: const TextStyle(height: 1.6, color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Hủy',
              style: TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade500,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              Navigator.pop(context);
              await vm.deleteUser(userId);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Đã xóa người dùng "$username"'),
                    backgroundColor: Colors.red.shade500,
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                );
              }
            },
            child: const Text(
              'Xóa vĩnh viễn',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
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
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              _buildAvatarWidget(),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.user['username'] ?? 'Chưa đặt tên',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.user['email'] ?? 'Chưa có email',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.user['phoneNumber'] ?? 'Chưa có số điện thoại',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: widget.user['role'] == 'admin'
                            ? Colors.orange.shade50
                            : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        widget.user['role'] == 'admin'
                            ? 'Quản trị viên'
                            : 'Người dùng',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: widget.user['role'] == 'admin'
                              ? Colors.orange.shade700
                              : Colors.green.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                key: ValueKey('menu_${widget.userId}'),
                icon: Icon(
                  Icons.more_vert,
                  color: Colors.grey[400],
                  size: 20,
                ),
                offset: const Offset(0, 40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 18, color: Colors.blue),
                        SizedBox(width: 10),
                        Text(
                          'Xem & Sửa',
                          style: TextStyle(fontSize: 13),
                        )
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 18, color: Colors.red),
                        SizedBox(width: 10),
                        Text(
                          'Xóa',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 13,
                          ),
                        )
                      ],
                    ),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'edit') {
                    widget.onTap();
                  } else if (value == 'delete') {
                    widget.onDelete();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarWidget() {
    // Lấy URL avatar từ Cloudinary
    String? avatarUrl = widget.user['avatarUrl'] as String?;

    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CachedNetworkImage(
          imageUrl: avatarUrl,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              ),
            ),
          ),
          errorWidget: (context, url, error) => _defaultAvatar(),
          fadeInDuration: const Duration(milliseconds: 300),
        ),
      );
    }

    return _defaultAvatar();
  }

  Widget _defaultAvatar() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(
        Icons.person,
        size: 24,
        color: Colors.grey,
      ),
    );
  }
}