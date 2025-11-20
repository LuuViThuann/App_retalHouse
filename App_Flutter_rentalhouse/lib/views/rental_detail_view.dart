import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/Widgets/Detail/rentalMap.dart';
import 'package:flutter_rentalhouse/config/loading.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_rental.dart';
import 'package:lottie/lottie.dart' hide Marker;
import 'package:provider/provider.dart';
import 'package:flutter_rentalhouse/Widgets/Comment/comment_user.dart';
import 'package:flutter_rentalhouse/Widgets/Detail/detail_tab.dart';
import 'package:flutter_rentalhouse/Widgets/Detail/info_chip.dart';
import 'package:flutter_rentalhouse/models/rental.dart';
import 'package:flutter_rentalhouse/models/favorite.dart';
import 'package:flutter_rentalhouse/services/rental_service.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_auth.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_favorite.dart';
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
    if (widget.rental.id.isNotEmpty && widget.rental.title.isNotEmpty) {
      setState(() {
        _averageRating = 0.0;
        _reviewCount = 0;
      });
    } else {
      await _rentalService.fetchRentalDetails(
        rental: widget.rental,
        onSuccess: (averageRating, reviewCount) {
          setState(() {
            _averageRating = averageRating;
            _reviewCount = reviewCount;
          });
        },
        onError: (error) {
          print('Error fetching rental details: $error');
          setState(() {
            _averageRating = 0.0;
            _reviewCount = 0;
          });
        },
        context: context,
      );
    }

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

    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    if (authViewModel.currentUser != null) {}
  }

  Future<void> _toggleFavorite() async {
    setState(() => _isLoadingFavorite = true);

    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final favoriteViewModel =
        Provider.of<FavoriteViewModel>(context, listen: false);
    final token = authViewModel.currentUser?.token ?? '';

    await _rentalService.toggleFavorite(
      rental: widget.rental,
      isFavorite: _isFavorite,
      onSuccess: (newFavoriteStatus) {
        setState(() {
          _isFavorite = newFavoriteStatus;
          _isLoadingFavorite = false;
        });

        // 👇 CẬP NHẬT FAVORITE VIEWMODEL
        if (newFavoriteStatus) {
          // Thêm vào yêu thích
          if (!favoriteViewModel.isFavorite(widget.rental.id)) {
            final newFavorite = Favorite(
              userId: authViewModel.currentUser?.id ?? '',
              rentalId: widget.rental.id,
              createdAt: DateTime.now(),
            );
            // Thêm vào danh sách và lưu cache
            favoriteViewModel.addFavoriteLocally(newFavorite);
          }
        } else {
          // Xóa khỏi yêu thích
          favoriteViewModel.removeFavoriteLocally(widget.rental.id);
        }

        // Hiển thị SnackBar thành công
        _showSuccessSnackBar(newFavoriteStatus);
      },
      onError: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            backgroundColor: Colors.transparent,
            elevation: 0,
            content: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange.shade300, Colors.deepOrange.shade400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      error,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        setState(() => _isLoadingFavorite = false);
      },
      context: context,
    );
  }

  void _showSuccessSnackBar(bool isFavorited) {
    final snackBar = SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      elevation: 0,
      backgroundColor: Colors.transparent,
      duration: const Duration(seconds: 2),
      content: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, (1 - value) * 20),
              child: child,
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color.fromARGB(255, 1, 180, 64),
                const Color.fromARGB(255, 85, 221, 112),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: Icon(
                  isFavorited ? Icons.favorite : Icons.favorite_border,
                  key: ValueKey(isFavorited),
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isFavorited
                      ? 'Đã thêm vào yêu thích'
                      : 'Đã xóa khỏi yêu thích',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
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

  Future<void> _refreshBookingStatus() async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    if (authViewModel.currentUser != null) {
      //
    }
  }

  void _navigateToMap() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RentalMapView(rental: widget.rental),
      ),
    );
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
                  padding: const EdgeInsets.all(13.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.shade50,
                              Colors.blue.shade100.withOpacity(0.3),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.rental.title,
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue.shade800,
                                          height: 1.3,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      GestureDetector(
                                        onTap: _navigateToMap,
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: Colors.blue.shade100,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Icon(
                                                Icons.location_on,
                                                size: 16,
                                                color: Colors.blue.shade700,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                widget.rental
                                                    .location['fullAddress'],
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.blue.shade700,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Align(
                                        alignment: Alignment.center,
                                        child: GestureDetector(
                                          onTap: _navigateToMap,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.shade600,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.map,
                                                  color: Colors.white,
                                                  size: 16,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'Xem trên bản đồ',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
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
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.account_balance_wallet,
                                      color: Colors.green.shade700,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Giá: ',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    Text(
                                      formatCurrency(widget.rental.price),
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.amber.shade50,
                                      Colors.amber.shade100.withOpacity(0.3),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.amber.shade200
                                          .withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                  border:
                                      Border.all(color: Colors.amber.shade100),
                                ),
                                child: Row(
                                  children: [
                                    AnimatedScale(
                                      scale: _averageRating > 0 ? 1.1 : 1.0,
                                      duration:
                                          const Duration(milliseconds: 200),
                                      child: Icon(
                                        Icons.star,
                                        color: Colors.amber.shade700,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '($_reviewCount lượt đánh giá)',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _isLoadingFavorite
                                  ? Container(
                                      width: 32,
                                      height: 32,
                                      padding: const EdgeInsets.all(4.0),
                                      child: Lottie.asset(
                                        AssetsConfig.loadingLottie,
                                        width: 24,
                                        height: 24,
                                        fit: BoxFit.contain,
                                      ),
                                    )
                                  : InkWell(
                                      onTap: _toggleFavorite,
                                      borderRadius: BorderRadius.circular(20),
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 200),
                                        padding: const EdgeInsets.all(10),
                                        margin:
                                            const EdgeInsets.only(right: 16),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.red.shade400
                                                  .withOpacity(0.9),
                                              Colors.red.shade600
                                                  .withOpacity(0.9),
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  Colors.red.withOpacity(0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: AnimatedScale(
                                          scale: _isFavorite ? 1.1 : 1.0,
                                          duration:
                                              const Duration(milliseconds: 200),
                                          child: Icon(
                                            _isFavorite
                                                ? Icons.favorite
                                                : Icons.favorite_border,
                                            color: Colors.white,
                                            size: 24,
                                          ),
                                        ),
                                      ),
                                    ),
                            ],
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

                            return const SizedBox.shrink();
                          },
                        ),
                      ),
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
                  if (widget.rental.id.isNotEmpty)
                    CommentSection(
                      rentalId: widget.rental.id,
                      onCommentCountChanged: _updateReviewCount,
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(20),
                      child: const Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.comment_outlined,
                              size: 48,
                              color: Color(0xFF9E9E9E),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Không có bình luận cho bài viết này',
                              style: TextStyle(
                                fontSize: 16,
                                color: Color(0xFF9E9E9E),
                              ),
                            ),
                          ],
                        ),
                      ),
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
