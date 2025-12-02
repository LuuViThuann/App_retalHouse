import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/config/api_routes.dart';
import 'package:flutter_rentalhouse/models/rental.dart';
import 'package:flutter_rentalhouse/views/Admin/View/UserPostDetail.dart';
import 'package:flutter_rentalhouse/views/Admin/ViewModel/admin_viewmodel.dart';
import 'package:flutter_rentalhouse/views/Admin/Widget/UserDetail/DeleteReasonDialog.dart';
import 'package:flutter_rentalhouse/views/Admin/Widget/UserDetail/EditRentalDialog.dart';
import 'package:provider/provider.dart';

class ManagePostsScreen extends StatefulWidget {
  const ManagePostsScreen({super.key});

  @override
  State<ManagePostsScreen> createState() => _ManagePostsScreenState();
}

class _ManagePostsScreenState extends State<ManagePostsScreen> {
  String _searchTerm = '';
  bool _showUsersList = true;
  String? _selectedUserId;
  String? _selectedUserName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final adminVM = context.read<AdminViewModel>();
        adminVM.resetUsersList();
        adminVM.fetchUsersWithPostCount(page: 1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: !_showUsersList
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
                onPressed: () {
                  setState(() {
                    _showUsersList = true;
                    _selectedUserId = null;
                    _selectedUserName = null;
                  });
                },
              )
            : null,
        title: Text(
          _showUsersList
              ? 'Quản lý bài đăng'
              : 'Bài đăng của $_selectedUserName',
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey[200]),
        ),
      ),
      body: _showUsersList ? _buildUsersList() : _buildPostsList(),
    );
  }

  // ========== BUILD USERS LIST ==========
  Widget _buildUsersList() {
    return Consumer<AdminViewModel>(
      builder: (context, viewModel, child) {
        debugPrint('🔍 Users count: ${viewModel.users.length}');
        debugPrint('📍 Is loading: ${viewModel.isLoading}');
        debugPrint('❌ Error: ${viewModel.error}');

        // Loading state
        if (viewModel.isLoading && viewModel.users.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.blue),
          );
        }

        // Error state
        if (viewModel.error != null && viewModel.users.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    viewModel.error ?? 'Có lỗi xảy ra',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    viewModel.resetUsersList();
                    viewModel.fetchUsersWithPostCount(page: 1);
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Thử lại'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    debugPrint('Error details: ${viewModel.error}');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(viewModel.error ?? '')),
                    );
                  },
                  icon: const Icon(Icons.info),
                  label: const Text('Chi tiết lỗi'),
                )
              ],
            ),
          );
        }

        // Filter users based on search term
        final filteredUsers = viewModel.users.where((user) {
          final searchLower = _searchTerm.toLowerCase();
          final username = (user['username'] as String?)?.toLowerCase() ?? '';
          final email = (user['email'] as String?)?.toLowerCase() ?? '';
          return username.contains(searchLower) || email.contains(searchLower);
        }).toList();

        return Column(
          children: [
            // 🔍 Search Bar
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                onChanged: (value) => setState(() => _searchTerm = value),
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm theo tên hoặc email...',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  suffixIcon: _searchTerm.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            setState(() => _searchTerm = '');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.blue, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
            ),

            // 👥 Users List
            Expanded(
              child: viewModel.users.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_off,
                              size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          Text(
                            _searchTerm.isEmpty
                                ? 'Không có người dùng nào'
                                : 'Không tìm thấy người dùng',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : filteredUsers.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off,
                                  size: 48, color: Colors.grey[400]),
                              const SizedBox(height: 12),
                              Text(
                                'Không tìm thấy "$_searchTerm"',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () async {
                            viewModel.resetUsersList();
                            await viewModel.fetchUsersWithPostCount(page: 1);
                          },
                          child: ListView.builder(
                            itemCount: filteredUsers.length,
                            itemBuilder: (context, index) {
                              final user = filteredUsers[index];
                              final postsCount = user['postsCount'] ?? 0;
                              final username =
                                  user['username'] ?? 'Chưa đặt tên';
                              final email = user['email'] ?? '';

                              return Card(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    radius: 24,
                                    backgroundColor: Colors.blue[100],
                                    child: Text(
                                      username.isNotEmpty
                                          ? username[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        color: Colors.blue,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    username,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    email,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue[100],
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '$postsCount bài',
                                      style: const TextStyle(
                                        color: Colors.blue,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  onTap: () {
                                    _selectUserAndFetchPosts(context, user);
                                  },
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        );
      },
    );
  }

  // ========== SELECT USER & FETCH POSTS ==========
  void _selectUserAndFetchPosts(
    BuildContext context,
    Map<String, dynamic> user,
  ) {
    final userId = user['id'] as String;
    final username = user['username'] ?? 'Người dùng';

    setState(() {
      _selectedUserId = userId;
      _selectedUserName = username;
      _showUsersList = false;
    });

    // Fetch posts for this user
    context.read<AdminViewModel>().fetchUserPosts(userId);
  }

  // ========== BUILD POSTS LIST ==========
  Widget _buildPostsList() {
    return Consumer<AdminViewModel>(
      builder: (context, viewModel, child) {
        // Loading state
        if (viewModel.isLoading && viewModel.userPosts.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.blue),
          );
        }

        final posts = viewModel.userPosts;

        // Empty state
        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.article_outlined,
                  size: 48,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 12),
                Text(
                  'Người dùng này chưa có bài đăng nào',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            final isNew = _isNewPost(post.createdAt);

            return _buildPostCard(context, post, isNew);
          },
        );
      },
    );
  }

  // ========== BUILD POST CARD ==========
  Widget _buildPostCard(BuildContext context, Rental post, bool isNew) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          // 🖼️ Image Section
          if (post.images.isNotEmpty)
            _buildImageSection(post, isNew)
          else
            Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.image_not_supported,
                  size: 48,
                  color: Colors.grey[400],
                ),
              ),
            ),

          // 📄 Post Details Section
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title with New Badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        post.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isNew)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          '🔥',
                          style: TextStyle(fontSize: 10),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 8),

                // Price, Area
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoItem(
                        '💰',
                        '${(post.price / 1000000).toStringAsFixed(1)}M',
                      ),
                    ),
                    Expanded(
                      child: _buildInfoItem(
                        '📐',
                        '${post.area['total']?.toStringAsFixed(0) ?? '0'}m²',
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Location
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      size: 14,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        post.location['short'] ?? 'Chưa cập nhật',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Posted Time
                Text(
                  'Đăng ${_getTimeAgo(post.createdAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),

                const SizedBox(height: 12),

                // ✅ ACTION BUTTONS - 3 BUTTONS (View, Edit, Delete)
                Column(
                  children: [
                    // Row 1: Xem & Chỉnh sửa
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              _showPostDetailDialog(context, post);
                            },
                            icon: const Icon(Icons.visibility, size: 16),
                            label: const Text('Xem'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              _showEditDialog(context, post);
                            },
                            icon: const Icon(Icons.edit, size: 16),
                            label: const Text('Sửa'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              _showDeleteConfirmDialog(context, post);
                            },
                            icon: const Icon(Icons.delete, size: 16),
                            label: const Text('Xóa'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, Rental post) {
    showDialog(
      context: context,
      builder: (dialogContext) => EditRentalDialogComplete(
        rental: post,
        onEditSuccess: () {
          debugPrint('✅ Post edited successfully');
          // ✅ Refresh danh sách bài đăng
          if (_selectedUserId != null) {
            context.read<AdminViewModel>().fetchUserPosts(_selectedUserId!);
          }
        },
      ),
    );
  }

  // ========== BUILD IMAGE SECTION ==========
  Widget _buildImageSection(Rental post, bool isNew) {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Stack(
        children: [
          // Image
          Image.network(
            post.images[0].contains('http')
                ? post.images[0]
                : '${ApiRoutes.rootUrl}${post.images[0]}',
            fit: BoxFit.cover,
            width: double.infinity,
            errorBuilder: (context, error, stackTrace) {
              return Center(
                child: Icon(
                  Icons.image_not_supported,
                  size: 48,
                  color: Colors.grey[400],
                ),
              );
            },
          ),

          // 🔥 New Badge
          if (isNew)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.5),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Text(
                  '🔥 MỚI',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),

          // Status Badge
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: post.status == 'available'
                    ? Colors.green
                    : Colors.grey[700],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                post.status == 'available' ? 'Còn trống' : 'Đã thuê',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========== SHOW POST DETAIL DIALOG ==========
  void _showPostDetailDialog(BuildContext context, Rental post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserPostDetailScreen(
          post: post,
          userName: _selectedUserName ?? 'Người dùng',
          onPostDeleted: () {
            debugPrint('🔄 Post deleted! Refreshing list...');

            // ✅ Cập nhật danh sách bài đăng
            if (_selectedUserId != null) {
              context.read<AdminViewModel>().fetchUserPosts(_selectedUserId!);
            }
          },
          onPostUpdated: () {
            debugPrint('🔄 Post updated! Refreshing list...');

            // ✅ Cập nhật danh sách bài đăng
            if (_selectedUserId != null) {
              context.read<AdminViewModel>().fetchUserPosts(_selectedUserId!);
            }
          },
        ),
      ),
    );
  }

  // ========== SHOW DELETE CONFIRM DIALOG WITH REASON ==========
  void _showDeleteConfirmDialog(BuildContext context, Rental post) {
    showDialog(
      context: context,
      builder: (dialogContext) => DeleteReasonDialog(
        postTitle: post.title,
        postAddress: post.location['short'] ?? 'N/A',
        postPrice: post.price,
        onConfirmDelete: () {
          _deletePost(context, post.id);
        },
      ),
    );
  }

  // ========== DELETE POST ==========
  Future<void> _deletePost(BuildContext context, String rentalId) async {
    final adminVM = context.read<AdminViewModel>();

    // Show loading indicator
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 12),
              Text('Đang xóa bài viết...'),
            ],
          ),
          duration: Duration(seconds: 30),
        ),
      );
    }

    final success = await adminVM.deleteUserPost(rentalId);

    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (success) {
        debugPrint('✅ Delete successful from ManagePostsScreen');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Xóa bài viết thành công'),
            backgroundColor: Colors.green[600],
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );

        // trong deleteUserPost() của AdminViewModel
      } else {
        debugPrint('❌ Delete failed');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              adminVM.error ?? '❌ Xóa bài viết thất bại',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red[600],
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  // ========== HELPER METHODS ==========

  /// Check if post is new (within 30 minutes)
  bool _isNewPost(DateTime createdAt) {
    final difference = DateTime.now().difference(createdAt);
    return difference.inMinutes < 30;
  }

  /// Format time ago
  String _getTimeAgo(DateTime date) {
    final difference = DateTime.now().difference(date);

    if (difference.inSeconds < 60) return 'vừa xong';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m trước';
    if (difference.inHours < 24) return '${difference.inHours}h trước';
    if (difference.inDays < 7) return '${difference.inDays}d trước';
    if (difference.inDays < 30)
      return '${(difference.inDays / 7).floor()}w trước';

    return '${(difference.inDays / 30).floor()}mo trước';
  }

  /// Build info item (icon + text)
  Widget _buildInfoItem(String icon, String text) {
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
