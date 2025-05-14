import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/models/rental.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_auth.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_favorite.dart';
import 'package:flutter_rentalhouse/views/rental_detail_view.dart';
import 'package:intl/intl.dart';
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
    final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
    return formatter.format(amount);
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context);
    final favoriteViewModel = Provider.of<FavoriteViewModel>(context);

    final rentalId = rental.id ?? '';
    final isFavorite = favoriteViewModel.isFavorite(rentalId);
    final isLoading = favoriteViewModel.isLoading(rentalId);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RentalDetailScreen(rental: rental),
          ),
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
                          ? CachedNetworkImage(
                        imageUrl: '${ApiRoutes.serverBaseUrl}${rental.images[0]}',
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                        errorWidget: (context, url, error) {
                          print('Image load error: $error for URL: $url');
                          return const Icon(Icons.error, size: 50);
                        },
                      )
                          : Container(
                        height: 200,
                        color: Colors.grey[300],
                        child: const Icon(Icons.image, size: 50, color: Colors.grey),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: (rental.status == 'available' ? Colors.green : Colors.red).withOpacity(0.9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          rental.status == 'available' ? 'Đang hoạt động' : 'Đã được thuê',
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
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rental.title.isNotEmpty ? rental.title : 'Không có tiêu đề',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Giá: ${formatCurrency(rental.price)} (có thương lượng)',
                            style: const TextStyle(fontSize: 16, color: Colors.green, fontWeight: FontWeight.bold),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: isLoading
                                    ? null
                                    : () async {
                                  if (authViewModel.currentUser == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Vui lòng đăng nhập để thêm vào yêu thích!'),
                                        backgroundColor: Colors.redAccent,
                                      ),
                                    );
                                    return;
                                  }

                                  bool success;
                                  String message;

                                  if (isFavorite) {
                                    success = await favoriteViewModel.removeFavorite(
                                      rentalId,
                                      authViewModel.currentUser!.token!,
                                    );
                                    message = success ? 'Đã xóa khỏi yêu thích!' : (favoriteViewModel.errorMessage ?? 'Lỗi khi xóa');
                                  } else {
                                    success = await favoriteViewModel.addFavorite(
                                      authViewModel.currentUser!.id,
                                      rentalId,
                                      authViewModel.currentUser!.token!,
                                    );
                                    message = success ? 'Đã thêm vào yêu thích!' : (favoriteViewModel.errorMessage ?? 'Lỗi khi thêm');
                                  }

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(message),
                                      backgroundColor: success ? Colors.green : Colors.redAccent,
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  margin: const EdgeInsets.only(right: 16),
                                  decoration: BoxDecoration(
                                    color: isFavorite ? Colors.red.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: isLoading
                                      ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                                    ),
                                  )
                                      : Icon(
                                    Icons.favorite,
                                    color: isFavorite ? Colors.red : Colors.grey,
                                    size: 24,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  // Logic nhắn tin
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.chat,
                                    color: Colors.blue,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Diện tích: ${rental.area['total']?.toString() ?? '0.0'} m² | ${(rental.area['bedrooms'] ?? 0) > 0 ? '2PN' : ''}, ${(rental.area['bathrooms'] ?? 0) > 0 ? '2WC' : ''}',
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: List.generate(5, (starIndex) {
                                  const rating = 4.5;
                                  return Icon(
                                    starIndex < rating.floor() ? Icons.star : Icons.star_border,
                                    color: Colors.amber,
                                    size: 16,
                                  );
                                }),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '(19 lượt đánh giá)',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.lightBlue.shade400, Colors.blue.shade800],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => RentalDetailScreen(rental: rental),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Text('Xem chi tiết', style: TextStyle(fontSize: 14)),
                                  SizedBox(width: 5),
                                  Icon(Icons.chevron_right, size: 18),
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