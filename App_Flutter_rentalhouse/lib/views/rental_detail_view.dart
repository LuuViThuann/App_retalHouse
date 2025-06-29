import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:flutter_rentalhouse/Widgets/Comment/comment_user.dart';
import 'package:flutter_rentalhouse/Widgets/Detail/detail_tab.dart';
import 'package:flutter_rentalhouse/Widgets/Detail/info_chip.dart';
import 'package:flutter_rentalhouse/models/rental.dart';
import 'package:flutter_rentalhouse/services/rental_service.dart';
import 'package:flutter_rentalhouse/views/booking_view.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_auth.dart';

import 'package:intl/intl.dart';
import 'package:photo_view/photo_view.dart';

import '../config/api_routes.dart';

class RentalDetailScreen extends StatefulWidget {
  final Rental rental;

  const RentalDetailScreen({super.key, required this.rental});

  @override
  _RentalDetailScreenState createState() => _RentalDetailScreenState();
}

class _RentalDetailScreenState extends State<RentalDetailScreen>
    with SingleTickerProviderStateMixin {
  int _selectedImageIndex = 0;
  bool _isFavorite = false;
  bool _isLoadingFavorite = true;
  double _averageRating = 0.0;
  int _reviewCount = 0;
  late TabController _tabController;
  final RentalService _rentalService = RentalService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _rentalService.fetchRentalDetails(
      rental: widget.rental,
      onSuccess: (averageRating, reviewCount) {
        setState(() {
          _averageRating = averageRating;
          _reviewCount = reviewCount;
        });
      },
      onError: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
      },
      context: context,
    );

    await _rentalService.checkFavoriteStatus(
      rental: widget.rental,
      onSuccess: (isFavorited) {
        setState(() {
          _isFavorite = isFavorited;
          _isLoadingFavorite = false;
        });
      },
      onError: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
        setState(() {
          _isFavorite = false;
          _isLoadingFavorite = false;
        });
      },
      context: context,
    );
  }

  Future<void> _toggleFavorite() async {
    setState(() => _isLoadingFavorite = true);
    await _rentalService.toggleFavorite(
      rental: widget.rental,
      isFavorite: _isFavorite,
      onSuccess: (newFavoriteStatus) {
        setState(() {
          _isFavorite = newFavoriteStatus;
          _isLoadingFavorite = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newFavoriteStatus
                  ? 'Đã thêm vào yêu thích'
                  : 'Đã xóa khỏi yêu thích',
            ),
          ),
        );
      },
      onError: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
        setState(() => _isLoadingFavorite = false);
      },
      context: context,
    );
  }

  void _showFullScreenImage(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              Center(
                child: PhotoView(
                  imageProvider: NetworkImage(imageUrl),
                  minScale: PhotoViewComputedScale.contained * 0.8,
                  maxScale: PhotoViewComputedScale.covered * 2.0,
                ),
              ),
              Positioned(
                top: 40,
                left: 20,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String formatCurrency(double amount) {
    final formatter =
        NumberFormat.currency(locale: 'vi_VN', symbol: 'VNĐ', decimalDigits: 0);
    return formatter.format(amount);
  }

  void _updateReviewCount(int count) {
    setState(() {
      _reviewCount = count;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
                child: GestureDetector(
                  onTap: () => _showFullScreenImage(mainImageUrl),
                  child: CachedNetworkImage(
                    imageUrl: mainImageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        const Center(child: CircularProgressIndicator()),
                    errorWidget: (context, url, error) =>
                        const Icon(Icons.error, size: 50),
                  ),
                ),
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            backgroundColor: Colors.blue[700],
          ),
          SliverToBoxAdapter(
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(30)),
              child: Container(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                          const Icon(Icons.location_on,
                              size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              widget.rental.location['fullAddress'],
                              style: const TextStyle(
                                  fontSize: 16, color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            InfoChip(
                              label: 'Loại chỗ ở',
                              value: widget.rental.propertyType,
                            ),
                            const SizedBox(width: 4),
                            const InfoChip(
                              label: 'Phong cách',
                              value: 'Hiện đại',
                            ),
                            const SizedBox(width: 4),
                            const InfoChip(
                              label: 'Chi phí',
                              value: 'Phù hợp',
                            ),
                            const SizedBox(width: 4),
                            const InfoChip(
                              label: 'Hợp đồng',
                              value: 'Đơn giản',
                            ),
                          ],
                        ),
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
                              Row(
                                children: [
                                  Row(
                                    children: List.generate(5, (index) {
                                      final starValue = (index + 1).toDouble();
                                      return Icon(
                                        starValue <= _averageRating
                                            ? Icons.star
                                            : starValue - 0.5 <= _averageRating
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
                                    style: const TextStyle(
                                        fontSize: 16, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          GestureDetector(
                            onTap: () {},
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              margin: const EdgeInsets.only(right: 16),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: _isLoadingFavorite
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.grey,
                                      ),
                                    )
                                  : Icon(
                                      _isFavorite
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      color: _isFavorite
                                          ? Colors.red
                                          : Colors.grey,
                                      size: 24,
                                    ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      if (widget.rental.images.length > 1)
                        Container(
                          height: 80,
                          margin: const EdgeInsets.only(bottom: 16.0),
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: widget.rental.images.length,
                            itemBuilder: (context, index) {
                              final imageUrl =
                                  '${ApiRoutes.baseUrl.replaceAll('/api', '')}${widget.rental.images[index]}';
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedImageIndex = index;
                                  });
                                },
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 4.0),
                                  width: 80,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: _selectedImageIndex == index
                                          ? Colors.blue[700]!
                                          : Colors.grey[300]!,
                                      width:
                                          _selectedImageIndex == index ? 2 : 1,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: CachedNetworkImage(
                                      imageUrl: imageUrl,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) =>
                                          const Center(
                                              child:
                                                  CircularProgressIndicator()),
                                      errorWidget: (context, url, error) =>
                                          const Icon(Icons.error),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 24),
                      Center(
                        child: Consumer<AuthViewModel>(
                          builder: (context, authViewModel, child) {
                            // Kiểm tra nếu là bài viết của chính mình thì ẩn nút đặt chỗ
                            if (authViewModel.currentUser?.id ==
                                widget.rental.userId) {
                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.orange[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                      Border.all(color: Colors.orange[200]!),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.info_outline,
                                        color: Colors.orange[600], size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Đây là bài viết của bạn',
                                      style: TextStyle(
                                        color: Colors.orange[600],
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return ElevatedButton.icon(
                              onPressed: () {
                                if (authViewModel.currentUser == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Vui lòng đăng nhập để đặt chỗ xem nhà'),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );
                                  return;
                                }

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        BookingView(rental: widget.rental),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.event_available,
                                  size: 24, color: Colors.white),
                              label: const Text(
                                'Đặt chỗ ngay',
                                style: TextStyle(
                                    fontSize: 18, color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[700],
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 32, vertical: 16),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20)),
                                elevation: 3,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 25),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverAppBarDelegate(
              TabBar(
                controller: _tabController,
                labelColor: Colors.blue[700],
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.blue[700],
                tabs: [
                  const Tab(text: 'Thông tin chi tiết'),
                  Tab(text: 'Bình luận / đánh giá ($_reviewCount)'),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16.0),
              child: IndexedStack(
                index: _tabController.index,
                children: [
                  DetailsTab(
                    rental: widget.rental,
                    formatCurrency: formatCurrency,
                  ),
                  CommentSection(
                    rentalId: widget.rental.id,
                    onCommentCountChanged: _updateReviewCount,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Delegate for SliverPersistentHeader to handle TabBar
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
