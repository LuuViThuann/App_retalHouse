import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/config/api_routes.dart';
import 'package:flutter_rentalhouse/config/loading.dart';
import 'package:flutter_rentalhouse/models/rental.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_auth.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_chat.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_favorite.dart';
import 'package:flutter_rentalhouse/views/chat_user.dart';
import 'package:flutter_rentalhouse/views/rental_detail_view.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';

class RentalCardHorizontal extends StatelessWidget {
  final Rental rental;

  const RentalCardHorizontal({super.key, required this.rental});

  String formatCurrency(double amount) {
    final formatter =
        NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
    return formatter.format(amount);
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
        return SlideTransition(position: animation.drive(tween), child: child);
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context);
    final favoriteViewModel = Provider.of<FavoriteViewModel>(context);
    final chatViewModel = Provider.of<ChatViewModel>(context);

    final currentUser = authViewModel.currentUser;
    final rentalId = rental.id ?? '';
    final isFavorite = favoriteViewModel.isFavorite(rentalId);
    final isLoadingFavorite = favoriteViewModel.isLoading(rentalId);
    final bool isMyPost =
        currentUser != null && rental.userId == currentUser.id;

    return GestureDetector(
      onTap: () => Navigator.push(
          context, _createRoute(RentalDetailScreen(rental: rental))),
      child: Container(
        width: 300,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.grey.withOpacity(0.18),
                blurRadius: 8,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==================== ẢNH + TRẠNG THÁI + NHÃN CHÍNH CHỦ ====================
            Stack(
              children: [
                // Ảnh chính
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(14)),
                  child: rental.images.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl:
                              '${ApiRoutes.serverBaseUrl}${rental.images[0]}',
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                              color: Colors.grey[300],
                              child: const Center(
                                  child: CircularProgressIndicator())),
                          errorWidget: (_, __, ___) => Container(
                              color: Colors.grey[300],
                              child: const Icon(Icons.image, size: 60)),
                        )
                      : Container(
                          height: 150,
                          color: Colors.grey[300],
                          child: const Icon(Icons.image, size: 60),
                        ),
                ),

                // Trạng thái bài đăng (Đang hoạt động / Đã cho thuê)
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: (rental.status == 'available'
                              ? Colors.green
                              : Colors.red)
                          .withOpacity(0.92),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      rental.status == 'available'
                          ? 'Đang hoạt động'
                          : 'Đã cho thuê',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                if (isMyPost)
                  Positioned(
                    top: 44,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade600,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Text(
                        'Bài viết của bạn',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                // Nút Yêu thích + Chat
                if (!isMyPost && currentUser != null)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Column(
                      children: [
                        // Nút Yêu thích
                        GestureDetector(
                          onTap: isLoadingFavorite
                              ? null
                              : () async {
                                  if (isFavorite) {
                                    final success =
                                        await favoriteViewModel.removeFavorite(
                                            rentalId, currentUser!.token!);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                        content: Text(success
                                            ? 'Đã xóa khỏi yêu thích'
                                            : 'Lỗi khi xóa'),
                                        backgroundColor:
                                            success ? Colors.green : Colors.red,
                                      ));
                                    }
                                  } else {
                                    final success =
                                        await favoriteViewModel.addFavorite(
                                            currentUser!.id,
                                            rentalId,
                                            currentUser!.token!);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                        content: Text(success
                                            ? 'Đã thêm vào yêu thích!'
                                            : 'Lỗi khi thêm'),
                                        backgroundColor:
                                            success ? Colors.green : Colors.red,
                                      ));
                                    }
                                  }
                                },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: const [
                                BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 6,
                                    offset: Offset(0, 2))
                              ],
                            ),
                            child: isLoadingFavorite
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : Icon(
                                    isFavorite
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    color: isFavorite
                                        ? Colors.red
                                        : Colors.grey[700],
                                    size: 22,
                                  ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Nút Chat
                        GestureDetector(
                          onTap: () async {
                            if (rental.id == null) return;

                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              barrierColor: Colors.black.withOpacity(0.8),
                              builder: (_) => Center(
                                child: Container(
                                  padding: const EdgeInsets.all(28),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Lottie.asset(
                                        AssetsConfig.loadingLottie,
                                        width: 120,
                                        height: 120,
                                        fit: BoxFit.contain,
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'Đang mở cuộc trò chuyện...',
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

                            try {
                              final conversation =
                                  await chatViewModel.getOrCreateConversation(
                                rentalId: rental.id!,
                                landlordId: rental.userId,
                                token: currentUser!.token!,
                              );

                              if (!context.mounted) return;
                              Navigator.pop(context); // Đóng loading

                              if (conversation != null) {
                                await chatViewModel
                                    .fetchConversations(currentUser!.token!);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ChatScreen(
                                      rentalId: rental.id!,
                                      landlordId: rental.userId,
                                      conversationId: conversation.id,
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Lỗi khi mở chat: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.blue,
                                    blurRadius: 8,
                                    spreadRadius: 1)
                              ],
                            ),
                            child: const Icon(Icons.message_rounded,
                                color: Colors.white, size: 22),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            // ==================== NỘI DUNG BÊN DƯỚI ====================
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rental.title.isNotEmpty ? rental.title : 'Không có tiêu đề',
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    formatCurrency(rental.price),
                    style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.green),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    rental.location['fullAddress'] ?? 'Không xác định',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
