import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/config/loading.dart';
import 'package:flutter_rentalhouse/models/rental.dart';
import 'package:flutter_rentalhouse/services/rental_service.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_auth.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_chat.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_favorite.dart';
import 'package:flutter_rentalhouse/views/chat_user.dart';
import 'package:flutter_rentalhouse/views/rental_detail_view.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import '../config/api_routes.dart';

class RentalItemWidget extends StatelessWidget {
  final Rental rental;
  final bool showCheckbox;
  final bool isSelected;
  final VoidCallback? onSelect;
  final VoidCallback? onDeselect;

  const RentalItemWidget({
    super.key,
    required this.rental,
    this.showCheckbox = false,
    this.isSelected = false,
    this.onSelect,
    this.onDeselect,
  });

  String formatCurrency(double amount) {
    final formatter =
    NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
    return formatter.format(amount);
  }

  ///  Helper: Kiểm tra xem URL có phải từ Cloudinary không
  bool _isCloudinaryUrl(String url) {
    return url.startsWith('http://') || url.startsWith('https://');
  }

  ///  Helper: Lấy URL hình ảnh đầy đủ
  String _getImageUrl(String imageUrl) {
    if (_isCloudinaryUrl(imageUrl)) {
      // URL đã là Cloudinary URL đầy đủ
      return imageUrl;
    }
    // Legacy: URL cục bộ (fallback cho dữ liệu cũ)
    return '${ApiRoutes.serverBaseUrl}$imageUrl';
  }

  ///  Widget hiển thị ảnh với error handling tốt hơn
  Widget _buildImageWidget(String imageUrl, {double height = 200}) {
    final fullUrl = _getImageUrl(imageUrl);

    return CachedNetworkImage(
      imageUrl: fullUrl,
      height: height,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        height: height,
        color: Colors.grey[200],
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
        ),
      ),
      errorWidget: (context, url, error) {
        debugPrint('❌ Image load error: $error');
        debugPrint('   URL: $url');
        return Container(
          height: height,
          color: Colors.grey[300],
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.broken_image_outlined,
                size: 50,
                color: Colors.grey[600],
              ),
              const SizedBox(height: 8),
              Text(
                'Không thể tải ảnh',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Route _createRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 1.0);
        const end = Offset.zero;
        const curve = Curves.easeInOut;

        var tween =
        Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        var offsetAnimation = animation.drive(tween);

        return SlideTransition(
          position: offsetAnimation,
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context);
    final chatViewModel = Provider.of<ChatViewModel>(context);
    final favoriteViewModel = Provider.of<FavoriteViewModel>(context);
    final rentalService = RentalService();

    final rentalId = rental.id ?? '';
    final isFavorite = favoriteViewModel.isFavorite(rentalId);
    final isLoading = favoriteViewModel.isLoading(rentalId);
    final isMyPost = authViewModel.currentUser != null &&
        rental.userId == authViewModel.currentUser!.id;

    final ValueNotifier<double> averageRating = ValueNotifier(0.0);
    final ValueNotifier<int> reviewCount = ValueNotifier(0);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      rentalService.fetchRentalDetails(
        rental: rental,
        onSuccess: (rating, count) {
          averageRating.value = rating;
          reviewCount.value = count;
        },
        onError: (error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error)),
          );
        },
        context: context,
      );
    });

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          _createRoute(RentalDetailScreen(rental: rental)),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: rental.images.isNotEmpty
                          ? Row(
                        children: [
                          //  First image with Cloudinary support
                          Expanded(
                            child: ClipRRect(
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(8),
                                bottomLeft: Radius.circular(8),
                              ),
                              child: _buildImageWidget(rental.images[0]),
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Second image with Cloudinary support
                          Expanded(
                            child: ClipRRect(
                              borderRadius: const BorderRadius.only(
                                topRight: Radius.circular(8),
                                bottomRight: Radius.circular(8),
                              ),
                              child: rental.images.length > 1
                                  ? _buildImageWidget(rental.images[1])
                                  : _buildImageWidget(rental.images[0]),
                            ),
                          ),
                        ],
                      )
                          : Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.image_not_supported_outlined,
                              size: 50,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Chưa có ảnh',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: (rental.status == 'available'
                                  ? Colors.green
                                  : Colors.red)
                                  .withOpacity(0.9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              rental.status == 'available'
                                  ? 'Đang hoạt động'
                                  : 'Đã được thuê',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (isMyPost)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.deepOrange,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.deepOrange.withOpacity(0.5),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Text(
                                'Bài viết của bạn',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rental.title.isNotEmpty
                            ? rental.title
                            : 'Không có tiêu đề',
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Giá: ${formatCurrency(rental.price)}',
                            style: const TextStyle(
                                fontSize: 16,
                                color: Colors.green,
                                fontWeight: FontWeight.bold),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!isMyPost)
                                GestureDetector(
                                  onTap: isLoading
                                      ? null
                                      : () async {
                                    if (authViewModel.currentUser ==
                                        null) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Vui lòng đăng nhập để thêm vào yêu thích!'),
                                          backgroundColor:
                                          Colors.redAccent,
                                        ),
                                      );
                                      return;
                                    }

                                    bool success;
                                    String message;

                                    if (isFavorite) {
                                      success = await favoriteViewModel
                                          .removeFavorite(
                                        rentalId,
                                        authViewModel.currentUser!.token!,
                                      );
                                      message = success
                                          ? 'Đã xóa khỏi yêu thích!'
                                          : (favoriteViewModel
                                          .errorMessage ??
                                          'Lỗi khi xóa');
                                    } else {
                                      success = await favoriteViewModel
                                          .addFavorite(
                                        authViewModel.currentUser!.id,
                                        rentalId,
                                        authViewModel.currentUser!.token!,
                                      );
                                      message = success
                                          ? 'Đã thêm vào yêu thích!'
                                          : (favoriteViewModel
                                          .errorMessage ??
                                          'Lỗi khi thêm');
                                    }

                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      SnackBar(
                                        content: Text(message),
                                        backgroundColor: success
                                            ? Colors.green
                                            : Colors.redAccent,
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    margin: const EdgeInsets.only(right: 16),
                                    decoration: BoxDecoration(
                                      color: isFavorite
                                          ? Colors.red.shade600
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: isFavorite
                                          ? null
                                          : Border.all(
                                          color: Colors.grey.shade300,
                                          width: 1),
                                    ),
                                    child: isLoading
                                        ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                        AlwaysStoppedAnimation<Color>(
                                            Colors.blueGrey),
                                      ),
                                    )
                                        : Icon(
                                      isFavorite
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      color: isFavorite
                                          ? Colors.white
                                          : Colors.red.shade700,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              if (!isMyPost)
                                GestureDetector(
                                  onTap: () async {
                                    if (authViewModel.currentUser == null) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Vui lòng đăng nhập để nhắn tin!'),
                                          backgroundColor: Colors.redAccent,
                                        ),
                                      );
                                      return;
                                    }

                                    if (rental.id == null ||
                                        rental.userId.isEmpty) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Thông tin bài đăng không hợp lệ!'),
                                          backgroundColor: Colors.redAccent,
                                        ),
                                      );
                                      return;
                                    }

                                    try {
                                      showDialog(
                                        context: context,
                                        barrierDismissible: false,
                                        builder: (_) => Dialog(
                                          backgroundColor: Colors.transparent,
                                          child: SizedBox(
                                            height: 140,
                                            child: Column(
                                              mainAxisAlignment:
                                              MainAxisAlignment.center,
                                              children: [
                                                Lottie.asset(
                                                  AssetsConfig.loadingLottie,
                                                  width: 100,
                                                  height: 100,
                                                  fit: BoxFit.contain,
                                                ),
                                                const SizedBox(height: 12),
                                                const Text(
                                                  'Đang mở cuộc trò chuyện ...',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );

                                      final conversation = await chatViewModel
                                          .getOrCreateConversation(
                                        rentalId: rental.id!,
                                        landlordId: rental.userId,
                                        token:
                                        authViewModel.currentUser!.token!,
                                      );

                                      if (conversation == null) {
                                        throw Exception(
                                            'Không thể tạo hoặc lấy cuộc trò chuyện');
                                      }

                                      await chatViewModel.fetchConversations(
                                          authViewModel.currentUser!.token!);

                                      Navigator.of(context).pop();

                                      Navigator.push(
                                        context,
                                        _createRoute(ChatScreen(
                                          rentalId: rental.id!,
                                          landlordId: rental.userId,
                                          conversationId: conversation.id,
                                        )),
                                      );
                                    } catch (e) {
                                      Navigator.of(context).pop();
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              'Lỗi khi mở cuộc trò chuyện: $e'),
                                          backgroundColor: Colors.redAccent,
                                        ),
                                      );
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade600,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.message_rounded,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                ),
                            ],
                          )
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Diện tích: ${rental.area['total']?.toString() ?? '0.0'} m² | ${(rental.area['bedrooms'] ?? 0) > 0 ? '${rental.area['bedrooms']}PN' : ''}, ${(rental.area['bathrooms'] ?? 0) > 0 ? '${rental.area['bathrooms']}WC' : ''}',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Vị trí: ${rental.location['short'] ?? 'Không xác định'}',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Nội thất: ${rental.furniture.isNotEmpty ? rental.furniture.join(', ') : 'Không có'}',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Chủ nhà: ${rental.contactInfo['name'] ?? 'Chủ nhà'}',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 15),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ValueListenableBuilder(
                                valueListenable: averageRating,
                                builder: (context, rating, child) {
                                  return ValueListenableBuilder(
                                    valueListenable: reviewCount,
                                    builder: (context, count, child) {
                                      return Row(
                                        mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children:
                                            List.generate(5, (starIndex) {
                                              final starValue =
                                              (starIndex + 1).toDouble();
                                              return Icon(
                                                starValue <= rating
                                                    ? Icons.star
                                                    : starValue - 0.5 <= rating
                                                    ? Icons.star_half
                                                    : Icons.star_border,
                                                color: Colors.amber,
                                                size: 16,
                                              );
                                            }),
                                          ),
                                          Text(
                                            '($count lượt đánh giá)',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600]),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                              ),
                            ],
                          ),
                          SizedBox(
                            height: 44,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  _createRoute(
                                      RentalDetailScreen(rental: rental)),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade700,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding:
                                const EdgeInsets.symmetric(horizontal: 20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Text(
                                    'Xem chi tiết',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(width: 6),
                                  Icon(Icons.chevron_right, size: 20),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (showCheckbox)
              Positioned(
                top: 8,
                left: 8,
                child: Checkbox(
                  value: isSelected,
                  onChanged: (bool? value) {
                    if (value == true) {
                      onSelect?.call();
                    } else {
                      onDeselect?.call();
                    }
                  },
                  activeColor: Colors.blue,
                ),
              ),
          ],
        ),
      ),
    );
  }
}