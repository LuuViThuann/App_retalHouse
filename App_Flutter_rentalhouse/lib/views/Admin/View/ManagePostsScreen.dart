import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/config/api_routes.dart';
import 'package:flutter_rentalhouse/config/loading.dart';
import 'package:flutter_rentalhouse/models/rental.dart';
import 'package:flutter_rentalhouse/views/Admin/View/UserPostDetail.dart';
import 'package:flutter_rentalhouse/views/Admin/ViewModel/admin_viewmodel.dart';
import 'package:flutter_rentalhouse/views/Admin/Widget/UserDetail/DeleteReasonDialog.dart';
import 'package:flutter_rentalhouse/views/Admin/Widget/UserDetail/EditRentalDialog.dart';
import 'package:lottie/lottie.dart';
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
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: !_showUsersList
            ? IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1F2937)),
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
            color: Color(0xFF1F2937),
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey.shade200),
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
          return  Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Lottie.asset(
                    AssetsConfig.loadingLottie,
                    width: 80,
                    height: 80,
                    fit: BoxFit.fill,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Đang tải dữ liệu...',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),)
                ],
              )
          );
        }

        // Error state
        if (viewModel.error != null && viewModel.users.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    viewModel.error ?? 'Có lỗi xảy ra',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    viewModel.resetUsersList();
                    viewModel.fetchUsersWithPostCount(page: 1);
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Thử lại'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
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
              padding: const EdgeInsets.all(16),
              child: TextField(
                onChanged: (value) => setState(() => _searchTerm = value),
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm theo tên hoặc email...',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                  suffixIcon: _searchTerm.isNotEmpty
                      ? IconButton(
                    icon: Icon(Icons.clear, color: Colors.grey[600]),
                    onPressed: () {
                      setState(() => _searchTerm = '');
                    },
                  )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF4F46E5),
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
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
                        size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      _searchTerm.isEmpty
                          ? 'Không có người dùng nào'
                          : 'Không tìm thấy người dùng',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
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
                        size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'Không tìm thấy "$_searchTerm"',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
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
                color: const Color(0xFF4F46E5),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredUsers.length,
                  itemBuilder: (context, index) {
                    final user = filteredUsers[index];
                    final postsCount = user['postsCount'] ?? 0;
                    final username = user['username'] ?? 'Chưa đặt tên';
                    final email = user['email'] ?? '';
                    final avatarUrl = user['avatar'] as String?;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            _selectUserAndFetchPosts(context, user);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                // Avatar với Cloudinary
                                _buildUserAvatar(avatarUrl, username),
                                const SizedBox(width: 14),

                                // User Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        username,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF1F2937),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        email,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Post Count Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4F46E5)
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFF4F46E5)
                                          .withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    '$postsCount',
                                    style: const TextStyle(
                                      color: Color(0xFF4F46E5),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),

                                const SizedBox(width: 8),

                                // Arrow
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 16,
                                  color: Colors.grey[400],
                                ),
                              ],
                            ),
                          ),
                        ),
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

  // ========== BUILD USER AVATAR ==========
  Widget _buildUserAvatar(String? avatarUrl, String username) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF4F46E5).withOpacity(0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF4F46E5).withOpacity(0.2),
          width: 2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: avatarUrl != null && avatarUrl.isNotEmpty
            ? Image.network(
          avatarUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildDefaultAvatar(username);
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: const Color(0xFF4F46E5),
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                      : null,
                ),
              ),
            );
          },
        )
            : _buildDefaultAvatar(username),
      ),
    );
  }

  // ========== BUILD DEFAULT AVATAR ==========
  Widget _buildDefaultAvatar(String username) {
    return Center(
      child: Text(
        username.isNotEmpty ? username[0].toUpperCase() : '?',
        style: const TextStyle(
          color: Color(0xFF4F46E5),
          fontWeight: FontWeight.w700,
          fontSize: 20,
        ),
      ),
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

    context.read<AdminViewModel>().fetchUserPosts(userId);
  }

  // ========== BUILD POSTS LIST ==========
  Widget _buildPostsList() {
    return Consumer<AdminViewModel>(
      builder: (context, viewModel, child) {
        // Loading state
        if (viewModel.isLoading && viewModel.userPosts.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
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
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'Người dùng này chưa có bài đăng nào',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Column(
        children: [
          // 🖼️ Image Section
          if (post.images.isNotEmpty)
            _buildImageSection(post, isNew)
          else
            Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.image_not_supported,
                  size: 56,
                  color: Colors.grey[400],
                ),
              ),
            ),

          // 📄 Post Details Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        post.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2937),
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
                          color: Colors.red.shade400,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'MỚI',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                // Info Row: Price, Area
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoItem(
                        Icons.payments_rounded,
                        _formatPrice(post.price),
                        const Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInfoItem(
                        Icons.aspect_ratio_rounded,
                        '${post.area['total']?.toStringAsFixed(0) ?? '0'}m²',
                        const Color(0xFF3B82F6),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Location
                Row(
                  children: [
                    Icon(
                      Icons.location_on_rounded,
                      size: 14,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        post.location['short'] ?? 'Chưa cập nhật',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
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
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),

                const SizedBox(height: 14),

                // ACTION BUTTONS - Updated với icon đẹp hơn
                Row(
                  children: [
                    Expanded(
                      child: _actionButton(
                        Icons.visibility_rounded,
                        'Xem',
                        const Color(0xFF3B82F6),
                            () => _showPostDetailDialog(context, post),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _actionButton(
                        Icons.edit_rounded,
                        'Sửa',
                        const Color(0xFFF59E0B),
                            () => _showEditDialog(context, post),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _actionButton(
                        Icons.delete_rounded,
                        'Xóa',
                        Colors.red.shade400,
                            () => _showDeleteConfirmDialog(context, post),
                      ),
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

  // ========== ACTION BUTTON HELPER - Updated ==========
  Widget _actionButton(
      IconData icon,
      String label,
      Color color,
      VoidCallback onPressed,
      ) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: color.withOpacity(0.3), width: 1),
        ),
      ),
    );
  }

  // ========== SHOW EDIT DIALOG ==========
  void _showEditDialog(BuildContext context, Rental post) {
    showDialog(
      context: context,
      builder: (dialogContext) => EditRentalDialogComplete(
        rental: post,
        onEditSuccess: () {
          debugPrint('✅ Post edited successfully');
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
          topLeft: Radius.circular(14),
          topRight: Radius.circular(14),
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
                  size: 56,
                  color: Colors.grey[400],
                ),
              );
            },
          ),

          // 🔥 New Badge
          if (isNew)
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.shade400,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Text(
                  '🔥 MỚI',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ),

          // Status Badge
          Positioned(
            bottom: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: post.status == 'available'
                    ? Colors.green.shade500
                    : Colors.grey[600],
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                post.status == 'available' ? 'Còn trống' : 'Đã thuê',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
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
            if (_selectedUserId != null) {
              context.read<AdminViewModel>().fetchUserPosts(_selectedUserId!);
            }
          },
          onPostUpdated: () {
            debugPrint('🔄 Post updated! Refreshing list...');
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
            backgroundColor: Colors.green.shade600,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      } else {
        debugPrint('❌ Delete failed');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              adminVM.error ?? '❌ Xóa bài viết thất bại',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red.shade600,
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

  // Format giá tiền theo chuẩn Việt Nam
  String _formatPrice(double price) {
    if (price >= 1000000000) {
      // Tỷ
      final ty = price / 1000000000;
      return '${ty.toStringAsFixed(ty % 1 == 0 ? 0 : 1)} tỷ/tháng';
    } else if (price >= 1000000) {
      // Triệu
      final trieu = price / 1000000;
      return '${trieu.toStringAsFixed(trieu % 1 == 0 ? 0 : 1)} triệu/tháng';
    } else if (price >= 1000) {
      // Nghìn
      final nghin = price / 1000;
      return '${nghin.toStringAsFixed(nghin % 1 == 0 ? 0 : 1)} nghìn/tháng';
    } else {
      return '${price.toStringAsFixed(0)}đ/tháng';
    }
  }

  bool _isNewPost(DateTime createdAt) {
    final difference = DateTime.now().difference(createdAt);
    return difference.inMinutes < 30;
  }

  String _getTimeAgo(DateTime date) {
    final difference = DateTime.now().difference(date);

    if (difference.inSeconds < 60) return 'vừa xong';
    if (difference.inMinutes < 60) return '${difference.inMinutes} phút trước';
    if (difference.inHours < 24) return '${difference.inHours} giờ trước';
    if (difference.inDays < 7) return '${difference.inDays} ngày trước';
    if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks tuần trước';
    }
    if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months tháng trước';
    }

    final years = (difference.inDays / 365).floor();
    return '$years năm trước';
  }

  Widget _buildInfoItem(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}