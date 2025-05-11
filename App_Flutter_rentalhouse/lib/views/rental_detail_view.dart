import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/Widgets/full_screen_image.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/rental.dart';
import '../services/auth_service.dart';
import '../viewmodels/vm_auth.dart';
import '../config/api_routes.dart';

class RentalDetailScreen extends StatefulWidget {
  final Rental rental;

  const RentalDetailScreen({super.key, required this.rental});

  @override
  _RentalDetailScreenState createState() => _RentalDetailScreenState();
}

class _RentalDetailScreenState extends State<RentalDetailScreen> {
  String? currentUserName;
  String? currentUserPhone;
  int _selectedImageIndex = 0;
  bool _isFavorite = false; // Trạng thái yêu thích
  final double _rating = 4.5; // Giả lập số sao đánh giá
  final int _reviewCount = 120; // Giả lập số lượt đánh giá

  @override
  void initState() {
    super.initState();
    _loadCurrentUserInfo();
  }

  Future<void> _loadCurrentUserInfo() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    try {
      final currentUser = await authService.getCurrentUser();
      if (currentUser != null) {
        setState(() {
          currentUserName = authViewModel.currentUser?.email.split('@')[0] ?? 'Chủ nhà';
          currentUserPhone = currentUser.phoneNumber ?? 'Không có số điện thoại';
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi lấy thông tin người dùng: $e')),
      );
    }
  }

  void _showFullScreenImage(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenImageScreen(imageUrl: imageUrl),
      ),
    );
  }

  void _toggleFavorite() {
    setState(() {
      _isFavorite = !_isFavorite;
      // Thêm logic lưu trạng thái yêu thích vào backend hoặc ViewModel nếu cần
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isFavorite ? 'Đã thêm vào yêu thích!' : 'Đã xóa khỏi yêu thích!')),
      );
    });
  }

  String formatCurrency(double amount) {
    final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'VNĐ', decimalDigits: 0);
    return formatter.format(amount);
  }

  @override
  Widget build(BuildContext context) {
    final String mainImageUrl = widget.rental.images.isNotEmpty
        ? '${ApiRoutes.baseUrl.replaceAll('/api', '')}${widget.rental.images[_selectedImageIndex]}'
        : '';

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
                child: GestureDetector(
                  onTap: () => _showFullScreenImage(mainImageUrl),
                  child: CachedNetworkImage(
                    imageUrl: mainImageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                    errorWidget: (context, url, error) => const Icon(Icons.error, size: 50),
                  ),
                ),
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  _isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: _isFavorite ? Colors.red : Colors.white,
                  size: 28,
                ),
                onPressed: _toggleFavorite,
              ),
            ],
            backgroundColor: Colors.blue[700],
          ),
          SliverToBoxAdapter(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              child: Container(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tiêu đề và địa chỉ
                      Text(
                        widget.rental.title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              widget.rental.location['fullAddress'],
                              style: const TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Thông tin cơ bản
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _InfoChip(
                            label: 'Loại chỗ ở',
                            value: widget.rental.propertyType,
                          ),
                          _InfoChip(
                            label: 'Phong cách',
                            value: 'Hiện đại',
                          ),
                          _InfoChip(
                            label: 'Chi phí',
                            value: 'Phù hợp',
                          ),
                          _InfoChip(
                            label: 'Hợp đồng',
                            value: 'Đơn giản',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                     Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       children: [
                         Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             Row(
                               children: [
                                 const Text(
                                   'Giá: ',
                                   style: TextStyle(
                                     fontSize: 20,
                                     fontWeight: FontWeight.w500,
                                     color: Colors.black87,
                                   ),
                                 ),
                                 Text(
                                   formatCurrency(widget.rental.price),
                                   style: const TextStyle(
                                     fontSize: 22,
                                     fontWeight: FontWeight.bold,
                                     color: Colors.green,
                                   ),
                                 ),
                               ],
                             ),
                             const SizedBox(height: 8),
                             // Đánh giá
                             Row(
                               children: [
                                 Row(
                                   children: List.generate(5, (index) {
                                     return Icon(
                                       index < _rating.floor()
                                           ? Icons.star
                                           : index < _rating
                                           ? Icons.star_half
                                           : Icons.star_border,
                                       color: Colors.amber,
                                       size: 20,
                                     );
                                   }),
                                 ),
                                 const SizedBox(width: 8),
                                 Text(
                                   '($_reviewCount lượt đánh giá)',
                                   style: const TextStyle(fontSize: 16, color: Colors.grey),
                                 ),
                               ],
                             ),
                           ],
                         ),
                         GestureDetector(
                           onTap: () {
                             // Logic yêu thích
                           },
                           child: Container(
                             padding: const EdgeInsets.all(10),
                             margin: const EdgeInsets.only(right: 16),
                             decoration: BoxDecoration(
                               color: Colors.red.withOpacity(0.1),
                               shape: BoxShape.circle,
                             ),
                             child: const Icon(
                               Icons.favorite,
                               color: Colors.red,
                               size: 24,
                             ),
                           ),
                         ),
                       ],
                     ),
                      const SizedBox(height: 24),
                      // Ảnh nhỏ bên dưới (nếu có nhiều ảnh)
                      if (widget.rental.images.length > 1)
                        Container(
                          height: 80,
                          margin: const EdgeInsets.only(bottom: 16.0),
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: widget.rental.images.length,
                            itemBuilder: (context, index) {
                              final imageUrl = '${ApiRoutes.baseUrl.replaceAll('/api', '')}${widget.rental.images[index]}';
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedImageIndex = index;
                                  });
                                },
                                child: Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 4.0),
                                  width: 80,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: _selectedImageIndex == index ? Colors.blue[700]! : Colors.grey[300]!,
                                      width: _selectedImageIndex == index ? 2 : 1,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: CachedNetworkImage(
                                      imageUrl: imageUrl,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                                      errorWidget: (context, url, error) => const Icon(Icons.error),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      // Thông tin chi tiết
                      _SectionTitle('Thông tin chi tiết :'),
                      Container(
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Colors.white, Colors.grey[50]!],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _DetailRow(
                              icon: Icons.square_foot,
                              label: 'Diện tích',
                              value:
                              '${widget.rental.area['total']} m² (Phòng khách ${widget.rental.area['livingRoom']} m², 2PN ~${widget.rental.area['bedrooms']} m², 2WC ~${widget.rental.area['bathrooms']} m²)',
                            ),
                            const SizedBox(height: 16),
                            _DetailSection(
                              title: 'Nội thất & Tiện ích',
                              icon: Icons.chair,
                              items: [
                                ...widget.rental.furniture.map((item) => '• $item'),
                                ...widget.rental.amenities.map((item) => '• $item'),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _DetailSection(
                              title: 'Kết nối & Môi trường xung quanh',
                              icon: Icons.place,
                              items: widget.rental.surroundings.map((item) => '• $item').toList(),
                            ),
                            const SizedBox(height: 16),
                            _DetailSection(
                              title: 'Điều khoản thuê',
                              icon: Icons.description,
                              items: [
                                'Thời hạn thuê tối thiểu: ${widget.rental.rentalTerms['minimumLease']}',
                                'Cọc: ${widget.rental.rentalTerms['deposit']}',
                                'Thanh toán: ${widget.rental.rentalTerms['paymentMethod']}',
                                'Gia hạn hợp đồng: ${widget.rental.rentalTerms['renewalTerms']}',
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Thông tin liên hệ
                      _SectionTitle('Thông tin liên hệ'),
                      Container(
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Colors.white, Colors.grey[50]!],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _DetailRow(
                              icon: Icons.person,
                              label: 'Chủ nhà',
                              value: currentUserName ?? 'Đang tải...',
                            ),
                            const SizedBox(height: 8),
                            _DetailRow(
                              icon: Icons.phone,
                              label: 'SĐT/Zalo',
                              value: currentUserPhone ?? 'Đang tải...',
                            ),
                            const SizedBox(height: 8),
                            _DetailRow(
                              icon: Icons.access_time,
                              label: 'Giờ liên hệ',
                              value: '9:00–20:00',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Nút đặt chỗ
                      Center(
                        child: ElevatedButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Chức năng đặt chỗ đang phát triển')),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[700],
                            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            elevation: 3,
                          ),
                          child: const Text(
                            'Đặt chỗ ngay',
                            style: TextStyle(fontSize: 18, color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;

  const _InfoChip({
    required this.label,
    required this.value,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: Colors.blueAccent),
            const SizedBox(width: 8),
          ],
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.blue[700]),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(fontSize: 16, color: Colors.black54),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<String> items;

  const _DetailSection({required this.title, required this.icon, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: Colors.blue[700]),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...items.map(
              (item) => Padding(
            padding: const EdgeInsets.only(left: 28.0, bottom: 4.0),
            child: Text(
              item,
              style: const TextStyle(fontSize: 16, color: Colors.black54),
            ),
          ),
        ),
      ],
    );
  }
}