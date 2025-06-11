import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/Widgets/Rental/edit_rental.dart';
import 'package:flutter_rentalhouse/config/api_routes.dart';
import 'package:flutter_rentalhouse/config/loading.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_auth.dart';
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
        return 'Đang cho thuê';
      case 'rented':
        return 'Đã thuê';
      case 'inactive':
        return 'Không hoạt động';
      default:
        return 'Không xác định';
    }
  }

  Future<void> _confirmDelete(BuildContext context, String rentalId) async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text(
            'Bạn có chắc chắn muốn xóa bài đăng này? Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (result == true) {
      try {
        print('MyPostsView: Initiating delete for rentalId: $rentalId');
        await authViewModel.deleteRental(rentalId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Xóa bài đăng thành công'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        print('MyPostsView: Error deleting rentalId: $rentalId: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Lỗi khi xóa: ${e.toString().replaceAll('Exception: ', '')}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthViewModel>(
      builder: (context, authViewModel, child) {
        if (authViewModel.errorMessage != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(authViewModel.errorMessage!),
                backgroundColor: Colors.redAccent,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          });
        }
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            title: const Text(
              'Danh sách bài đăng của bạn',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black,
                fontFamily: 'Roboto',
              ),
            ),
            elevation: 0,
          ),
          body: authViewModel.isLoading && authViewModel.myPosts.isEmpty
              ? Center(
                  child: Lottie.asset(
                    AssetsConfig.loadingLottie,
                    width: 150,
                    height: 150,
                    fit: BoxFit.fill,
                  ),
                )
              : authViewModel.myPosts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.post_add,
                            size: 60,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Chưa có bài đăng nào',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                              fontFamily: 'Roboto',
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            itemCount: authViewModel.myPosts.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final rental = authViewModel.myPosts[index];
                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            RentalDetailScreen(rental: rental),
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Stack(
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          ClipRRect(
                                            borderRadius:
                                                const BorderRadius.only(
                                              topLeft: Radius.circular(12),
                                              bottomLeft: Radius.circular(12),
                                            ),
                                            child: rental.images.isNotEmpty
                                                ? CachedNetworkImage(
                                                    imageUrl:
                                                        '${ApiRoutes.serverBaseUrl}${rental.images[0]}',
                                                    width: 160,
                                                    height:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .height *
                                                            0.2,
                                                    fit: BoxFit.cover,
                                                    placeholder:
                                                        (context, url) =>
                                                            Shimmer.fromColors(
                                                      baseColor:
                                                          Colors.grey[300]!,
                                                      highlightColor:
                                                          Colors.grey[100]!,
                                                      child: Container(
                                                        width: 160,
                                                        height: MediaQuery.of(
                                                                    context)
                                                                .size
                                                                .height *
                                                            0.2,
                                                        color: Colors.grey[300],
                                                      ),
                                                    ),
                                                    errorWidget:
                                                        (context, url, error) {
                                                      print(
                                                          'Image load error: $error for URL: ${ApiRoutes.serverBaseUrl}${rental.images[0]}');
                                                      return Container(
                                                        width: 160,
                                                        height: MediaQuery.of(
                                                                    context)
                                                                .size
                                                                .height *
                                                            0.2,
                                                        color: Colors.grey[300],
                                                        child: Icon(
                                                          Icons
                                                              .image_not_supported,
                                                          size: 30,
                                                          color:
                                                              Colors.grey[600],
                                                        ),
                                                      );
                                                    },
                                                  )
                                                : Container(
                                                    width: 160,
                                                    height:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .height *
                                                            0.2,
                                                    color: Colors.grey[300],
                                                    child: Icon(
                                                      Icons.image_not_supported,
                                                      size: 30,
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                          ),
                                          Expanded(
                                            child: Padding(
                                              padding: const EdgeInsets.all(10),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    rental.title,
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontFamily: 'Roboto',
                                                    ),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    '${formatCurrency(rental.price)}/tháng',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: Colors.blue[700],
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontFamily: 'Roboto',
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        Icons.location_on,
                                                        size: 14,
                                                        color: Colors.grey[600],
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Expanded(
                                                        child: Text(
                                                          rental.location[
                                                              'short'],
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: Colors
                                                                .grey[600],
                                                            fontFamily:
                                                                'Roboto',
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        Icons.square_foot,
                                                        size: 14,
                                                        color: Colors.grey[600],
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        '${rental.area['total']} m²',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color:
                                                              Colors.grey[600],
                                                          fontFamily: 'Roboto',
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Icon(
                                                        Icons.home,
                                                        size: 14,
                                                        color: Colors.grey[600],
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        rental.propertyType,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color:
                                                              Colors.grey[600],
                                                          fontFamily: 'Roboto',
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        Icons.info_outline,
                                                        size: 14,
                                                        color: Colors.grey[600],
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        formatStatus(
                                                            rental.status),
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color:
                                                              Colors.grey[600],
                                                          fontFamily: 'Roboto',
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: PopupMenuButton<PostAction>(
                                          icon: Icon(
                                            Icons.more_vert,
                                            color: Colors.grey[600],
                                            size: 24,
                                          ),
                                          onSelected: (value) {
                                            print(
                                                'MyPostsView: Menu action selected: $value for rentalId: ${rental.id}');
                                            switch (value) {
                                              case PostAction.edit:
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        EditRentalScreen(
                                                            rental: rental),
                                                  ),
                                                );
                                                break;
                                              case PostAction.delete:
                                                _confirmDelete(
                                                    context, rental.id);
                                                break;
                                            }
                                          },
                                          itemBuilder: (context) => [
                                            const PopupMenuItem(
                                              value: PostAction.edit,
                                              child: Row(
                                                children: [
                                                  Icon(Icons.edit,
                                                      color: Colors.green),
                                                  SizedBox(width: 8),
                                                  Text('Chỉnh sửa'),
                                                ],
                                              ),
                                            ),
                                            const PopupMenuItem(
                                              value: PostAction.delete,
                                              child: Row(
                                                children: [
                                                  Icon(Icons.delete,
                                                      color: Colors.red),
                                                  SizedBox(width: 8),
                                                  Text('Xóa'),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        if (authViewModel.postsPage <
                            authViewModel.postsTotalPages)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, -2),
                                ),
                              ],
                            ),
                            child: Center(
                              child: ElevatedButton(
                                onPressed: authViewModel.isLoading
                                    ? null
                                    : () => authViewModel.fetchMyPosts(
                                        page: authViewModel.postsPage + 1),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue[700],
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 12),
                                  elevation: 2,
                                ),
                                child: authViewModel.isLoading
                                    ? const CircularProgressIndicator(
                                        color: Colors.white)
                                    : const Text(
                                        'Tải thêm',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          fontFamily: 'Roboto',
                                        ),
                                      ),
                              ),
                            ),
                          ),
                      ],
                    ),
        );
      },
    );
  }
}
