import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/Widgets/Rental/edit_rental.dart';
import 'package:flutter_rentalhouse/config/api_routes.dart';
import 'package:flutter_rentalhouse/config/loading.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_auth.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_rental.dart';
import 'package:flutter_rentalhouse/views/rental_detail_view.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

enum PostAction { edit, delete }

class MyPostsView extends StatefulWidget {
  const MyPostsView({super.key});

  @override
  _MyPostsViewState createState() => _MyPostsViewState();
}

class _MyPostsViewState extends State<MyPostsView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AuthViewModel>(context, listen: false).fetchMyPosts(page: 1);
    });
  }

  String formatCurrency(double amount) {
    final formatter =
    NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
    return formatter.format(amount);
  }

  String formatStatus(String status) {
    switch (status.toLowerCase()) {
      case 'available':
        return 'Có sẵn';
      case 'rented':
        return 'Đã cho thuê';
      case 'inactive':
        return 'Không hoạt động';
      default:
        return 'Không xác định';
    }
  }

  Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'available':
        return Colors.green;
      case 'rented':
        return Colors.orange;
      case 'inactive':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _confirmDelete(BuildContext context, String rentalId) async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final rentalViewModel = Provider.of<RentalViewModel>(context, listen: false);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Xác nhận xóa',
            style: TextStyle(fontWeight: FontWeight.w600)),
        content: const Text(
            'Bạn có chắc chắn muốn xóa bài đăng này? Hành động này không thể hoàn tác.',
            style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy',
                style: TextStyle(
                    color: Colors.grey, fontWeight: FontWeight.w500)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa',
                style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        print('MyPostsView: Initiating delete for rentalId: $rentalId');
        await authViewModel.deleteRental(rentalId);

        // 🔥 Cập nhật danh sách rental toàn cục
        await rentalViewModel.refreshAllRentals();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Xóa bài đăng thành công',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w500)),
              backgroundColor: Colors.green[600],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      } catch (e) {
        print('MyPostsView: Error deleting rentalId: $rentalId: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Lỗi khi xóa: ${e.toString().replaceAll('Exception: ', '')}',
                  style: const TextStyle(color: Colors.white)),
              backgroundColor: Colors.red[600],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthViewModel, RentalViewModel>(
      builder: (context, authViewModel, rentalViewModel, child) {
        return Scaffold(
          backgroundColor: const Color(0xFFF5F6FA),
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 0,
                floating: false,
                pinned: true,
                elevation: 0,
                backgroundColor: Colors.blue[700],
                title: const Text(
                  'Bài đăng của tôi',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                ),
              ),
              if (authViewModel.errorMessage != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red[600]),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              authViewModel.errorMessage!,
                              style: TextStyle(
                                color: Colors.red[700],
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (authViewModel.isLoading && authViewModel.myPosts.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: _buildLoadingState(),
                  ),
                )
              else if (authViewModel.myPosts.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: _buildEmptyState(),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (context, index) {
                        final rental = authViewModel.myPosts[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _buildPostCard(
                              context, rental, authViewModel, rentalViewModel),
                        );
                      },
                      childCount: authViewModel.myPosts.length,
                    ),
                  ),
                ),
              if (authViewModel.postsPage <
                  authViewModel.postsTotalPages)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: authViewModel.isLoading
                            ? null
                            : () => authViewModel.fetchMyPosts(
                            page: authViewModel.postsPage + 1),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: authViewModel.isLoading
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                            : const Text(
                          'Tải thêm',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              const SliverToBoxAdapter(
                child: SizedBox(height: 24),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.transparent,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Lottie.asset(
            AssetsConfig.loadingLottie,
            width: 60,
            height: 60,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Đang tải bài đăng...',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.post_add_rounded,
            size: 48,
            color: Colors.blue[600],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Chưa có bài đăng nào',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Hãy tạo bài đăng mới để bắt đầu',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildPostCard(BuildContext context, dynamic rental,
      AuthViewModel authViewModel, RentalViewModel rentalViewModel) {
    final statusColor = getStatusColor(rental.status);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RentalDetailScreen(rental: rental),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Column(
                children: [
                  // Image Section
                  SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (rental.images.isNotEmpty)
                          CachedNetworkImage(
                            imageUrl:
                            '${ApiRoutes.serverBaseUrl}${rental.images[0]}',
                            fit: BoxFit.cover,
                            placeholder: (context, url) =>
                                Shimmer.fromColors(
                                  baseColor: Colors.grey[300]!,
                                  highlightColor: Colors.grey[100]!,
                                  child:
                                  Container(color: Colors.grey[300]),
                                ),
                            errorWidget: (context, url, error) {
                              print('Image load error: $error');
                              return Container(
                                color: Colors.grey[200],
                                child: Icon(
                                  Icons
                                      .image_not_supported_outlined,
                                  size: 40,
                                  color: Colors.grey[400],
                                ),
                              );
                            },
                          )
                        else
                          Container(
                            color: Colors.grey[200],
                            child: Icon(
                              Icons.image_not_supported_outlined,
                              size: 40,
                              color: Colors.grey[400],
                            ),
                          ),
                        // Gradient overlay
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.3),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Content Section
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                rental.title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1a1a1a),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.12),
                                borderRadius:
                                BorderRadius.circular(8),
                              ),
                              child: Text(
                                formatStatus(rental.status),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          formatCurrency(rental.price) +
                              '/tháng',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.green[600],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Column(
                          children: [
                            _buildInfoRow(Icons.location_on,
                                rental.location['short']),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildInfoRow(
                                      Icons.square_foot,
                                      '${rental.area['total']} m²'),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildInfoRow(
                                      Icons.home,
                                      rental.propertyType),
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
              // Actions menu
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: PopupMenuButton<PostAction>(
                    icon: Icon(
                      Icons.more_vert,
                      color: Colors.grey[700],
                      size: 22,
                    ),
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: PostAction.edit,
                        child: Row(
                          children: [
                            Icon(Icons.edit_rounded,
                                color: Colors.blue[600]),
                            const SizedBox(width: 10),
                            const Text('Chỉnh sửa',
                                style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: PostAction.delete,
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded,
                                color: Colors.red[600]),
                            const SizedBox(width: 10),
                            const Text('Xóa',
                                style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14)),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      print(
                          'MyPostsView: Menu action selected: $value for rentalId: ${rental.id}');
                      switch (value) {
                        case PostAction.edit:
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  EditRentalScreen(rental: rental),
                            ),
                          ).then((_) {
                            // 🔥 Cập nhật danh sách rental sau khi chỉnh sửa
                            rentalViewModel.refreshAllRentals();
                          });
                          break;
                        case PostAction.delete:
                          _confirmDelete(context, rental.id);
                          break;
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}