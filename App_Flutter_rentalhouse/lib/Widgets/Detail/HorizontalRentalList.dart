import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../config/api_routes.dart';
import '../../models/rental.dart';
import 'NearbyRentals.dart';

class HorizontalRentalListWidget extends StatelessWidget {
  final List<Rental> rentals;
  final Rental mainRental;
  final Function(Rental rental) onRentalTap;
  final bool Function(Rental rental) validateRental;

  // 🔥 THÊM: Tham số cho hiển thị trạng thái lọc
  final bool isFilterApplied;
  final int totalRentals;

  const HorizontalRentalListWidget({
    super.key,
    required this.rentals,
    required this.mainRental,
    required this.onRentalTap,
    required this.validateRental,
    this.isFilterApplied = false,
    this.totalRentals = 0,
  });

  String _buildImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) {
      return 'https://via.placeholder.com/400x300?text=No+Image';
    }
    if (imagePath.startsWith('http')) return imagePath;
    return '${ApiRoutes.baseUrl.replaceAll('/api', '')}${imagePath.startsWith('/') ? '' : '/'}$imagePath';
  }

  String _formatPrice(double price) {
    final formatter = NumberFormat('#,###', 'vi_VN');
    return '${formatter.format(price.round())} VNĐ';
  }

  Widget _buildHorizontalRentalCard(BuildContext context, Rental rental) {
    final imageUrl = _buildImageUrl(rental.images.isNotEmpty ? rental.images[0] : null);

    return Container(
      width: 285,
      margin: const EdgeInsets.only(right: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onRentalTap(rental),
          borderRadius: BorderRadius.circular(16),
          splashColor: Colors.blue.withOpacity(0.12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    width: 118,
                    height: 118,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      width: 118,
                      height: 118,
                      color: Colors.grey[200],
                      child: const Icon(Icons.home_outlined, color: Colors.grey, size: 44),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: 118,
                      height: 118,
                      color: Colors.grey[200],
                      child: const Icon(Icons.error_outline, color: Colors.grey, size: 44),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          rental.title,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            height: 1.32,
                            letterSpacing: -0.1,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _formatPrice(rental.price),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.teal[700],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              size: 15,
                              color: Colors.grey[700],
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                rental.location['short'] ?? 'Chưa xác định',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
          ),
        ),
      ),
    );
  }

  // 🔥 THÊM: Widget hiển thị trạng thái không có kết quả
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Không tìm thấy bất động sản\ntrong khoảng giá đã chọn',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 CẬP NHẬT: Hiển thị toàn bộ widget ngay cả khi không có bài
    // (trước là dùng rentals.isEmpty -> return SizedBox.shrink())

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        color: Colors.white,
        constraints: const BoxConstraints(minHeight: 180, maxHeight: 240),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ============================================
            // HEADER - CẬP NHẬT để hiển thị trạng thái lọc
            // ============================================
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 🔥 CẬP NHẬT: Hiển thị số bài và trạng thái lọc
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.location_city_rounded,
                          size: 20,
                          color: isFilterApplied ? Colors.orange[700] : Colors.blue[700],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Bất động sản gần đây',
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              // 🔥 THÊM: Hiển thị số bài đã lọc nếu có
                              if (isFilterApplied && totalRentals > 0)
                                Text(
                                  '${rentals.length}/$totalRentals bài',
                                  style: TextStyle(
                                    color: Colors.orange[700],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                )
                              else
                                Text(
                                  '${rentals.length} bài',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  // 🔥 CẬP NHẬT: Nút "Xem thêm" chỉ hiển thị khi có bài
                  if (rentals.isNotEmpty)
                    TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => NearbyRentalsListView(
                              rentals: rentals,
                              mainRental: mainRental,
                            ),
                          ),
                        );
                      },
                      icon: Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: isFilterApplied ? Colors.orange[700] : Colors.blue[700],
                      ),
                      label: Text(
                        'Xem thêm',
                        style: TextStyle(
                          color: isFilterApplied ? Colors.orange[700] : Colors.blue[700],
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        backgroundColor: isFilterApplied
                            ? Colors.orange[50]
                            : Colors.blue[50],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ============================================
            // CONTENT AREA - Danh sách hoặc trạng thái rỗng
            // ============================================
            SizedBox(
              height: 148,
              child: rentals.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                itemCount: rentals.length,
                itemBuilder: (context, index) {
                  final rental = rentals[index];
                  if (!validateRental(rental)) {
                    return const SizedBox.shrink();
                  }
                  return _buildHorizontalRentalCard(context, rental);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}