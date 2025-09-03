import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/config/loading.dart';
import 'package:lottie/lottie.dart' hide Marker;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:geocoding/geocoding.dart';
import 'package:custom_map_markers/custom_map_markers.dart';
import 'package:location/location.dart' as loc;
import 'package:flutter_rentalhouse/Widgets/Comment/comment_user.dart';
import 'package:flutter_rentalhouse/Widgets/Detail/detail_tab.dart';
import 'package:flutter_rentalhouse/Widgets/Detail/info_chip.dart';
import 'package:flutter_rentalhouse/models/rental.dart';
import 'package:flutter_rentalhouse/services/rental_service.dart';
import 'package:flutter_rentalhouse/views/booking_view.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_auth.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_booking.dart';
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
    if (authViewModel.currentUser != null) {
      final bookingViewModel =
          Provider.of<BookingViewModel>(context, listen: false);
      await bookingViewModel.checkUserHasBooked(rentalId: widget.rental.id);
    }
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

  Future<void> _refreshBookingStatus() async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    if (authViewModel.currentUser != null) {
      final bookingViewModel =
          Provider.of<BookingViewModel>(context, listen: false);
      await bookingViewModel.checkUserHasBooked(rentalId: widget.rental.id);
    }
  }

  void _navigateToMap() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RentalMapView(
          address: widget.rental.location['fullAddress'],
          title: widget.rental.title,
        ),
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
                  padding: const EdgeInsets.all(16.0),
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
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade600,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.blue.shade200,
                                        spreadRadius: 1,
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.home,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
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
                                      const SizedBox(height: 8),
                                      GestureDetector(
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

                            return Consumer<BookingViewModel>(
                              builder: (context, bookingViewModel, child) {
                                if (bookingViewModel.isCheckingBooking) {
                                  return Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[50],
                                      borderRadius: BorderRadius.circular(12),
                                      border:
                                          Border.all(color: Colors.grey[200]!),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          'Đang kiểm tra...',
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

                                if (bookingViewModel.userHasBooked != null) {
                                  final booking =
                                      bookingViewModel.userHasBooked!;
                                  String statusText = '';
                                  Color statusColor = Colors.blue;

                                  switch (booking.status) {
                                    case 'pending':
                                      statusText = 'Chờ xác nhận';
                                      statusColor = Colors.orange;
                                      break;
                                    case 'confirmed':
                                      statusText = 'Đã xác nhận';
                                      statusColor = Colors.green;
                                      break;
                                    default:
                                      statusText = 'Đã đặt chỗ';
                                      statusColor = Colors.blue;
                                  }

                                  return Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          statusColor.withOpacity(0.1),
                                          statusColor.withOpacity(0.05),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: statusColor.withOpacity(0.3)),
                                    ),
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: statusColor,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Icon(
                                                Icons.check_circle,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Bạn đã đặt chỗ nhà này',
                                                    style: TextStyle(
                                                      color: statusColor,
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'Trạng thái: $statusText',
                                                    style: TextStyle(
                                                      color: statusColor
                                                          .withOpacity(0.8),
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'Chủ nhà sẽ liên hệ với bạn sớm nhất để xác nhận thời gian xem nhà.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Colors.grey[700],
                                            fontSize: 13,
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }

                                return InkWell(
                                  onTap: () {
                                    if (authViewModel.currentUser == null) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
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
                                    ).then((_) => _refreshBookingStatus());
                                  },
                                  borderRadius: BorderRadius.circular(24),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 32, vertical: 16),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.blue.shade700,
                                          Colors.blue.shade900,
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(24),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.blue.shade300
                                              .withOpacity(0.4),
                                          spreadRadius: 2,
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        AnimatedScale(
                                          scale:
                                              authViewModel.currentUser == null
                                                  ? 1.0
                                                  : 1.1,
                                          duration:
                                              const Duration(milliseconds: 200),
                                          child: Icon(
                                            Icons.event_available,
                                            color: Colors.white,
                                            size: 26,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          'Đặt chỗ ngay',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
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

// New Map View for Rental
class RentalMapView extends StatefulWidget {
  final String address;
  final String title;

  const RentalMapView({super.key, required this.address, required this.title});

  @override
  State<RentalMapView> createState() => _RentalMapViewState();
}

class _RentalMapViewState extends State<RentalMapView> {
  GoogleMapController? _controller;
  LatLng? _rentalLatLng;
  LatLng? _currentLatLng;
  List<MarkerData> _customMarkers = [];
  String? _errorMessage;
  bool _isMapLoading = true;

  @override
  void initState() {
    super.initState();
    _getLocationFromAddress();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Widget _customRentalMarkerWidget(String title) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/img/location.png',
          width: 35,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => const Icon(
            Icons.location_pin,
            color: Colors.red,
            size: 35,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _customCurrentLocationMarkerWidget() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.my_location,
          color: Colors.blue,
          size: 35,
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Text(
            "Vị trí hiện tại",
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Future<void> _getLocationFromAddress() async {
    try {
      final locations = await locationFromAddress(widget.address);
      if (locations.isNotEmpty) {
        final location = locations.first;
        final latLng = LatLng(location.latitude, location.longitude);
        setState(() {
          _rentalLatLng = latLng;
          _customMarkers = [
            MarkerData(
              marker: Marker(
                markerId: const MarkerId('rental-location'),
                position: latLng,
                infoWindow: InfoWindow(title: widget.title),
              ),
              child: _customRentalMarkerWidget(widget.title),
            ),
            if (_currentLatLng != null)
              MarkerData(
                marker: Marker(
                  markerId: const MarkerId('current-location'),
                  position: _currentLatLng!,
                  infoWindow: const InfoWindow(title: 'Vị trí hiện tại'),
                ),
                child: _customCurrentLocationMarkerWidget(),
              ),
          ];
          _isMapLoading = false;
        });
        if (_controller != null) {
          _controller?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 16));
        }
      } else {
        setState(() {
          _errorMessage = 'Không tìm thấy tọa độ cho địa chỉ này.';
          _isMapLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Lỗi khi lấy tọa độ: $e';
        _isMapLoading = false;
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final location = loc.Location();

      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) {
          setState(() => _errorMessage = 'Dịch vụ vị trí chưa được bật.');
          return;
        }
      }

      var permissionGranted = await location.hasPermission();
      if (permissionGranted == loc.PermissionStatus.denied) {
        permissionGranted = await location.requestPermission();
        if (permissionGranted != loc.PermissionStatus.granted) {
          setState(() => _errorMessage = 'Quyền truy cập vị trí bị từ chối.');
          return;
        }
      }

      final currentLocation = await location.getLocation();

      if (currentLocation.latitude != null &&
          currentLocation.longitude != null) {
        final latLng = LatLng(
          currentLocation.latitude!,
          currentLocation.longitude!,
        );

        setState(() {
          _currentLatLng = latLng;
          if (_rentalLatLng != null) {
            _customMarkers = [
              MarkerData(
                marker: Marker(
                  markerId: const MarkerId('rental-location'),
                  position: _rentalLatLng!,
                  infoWindow: InfoWindow(title: widget.title),
                ),
                child: _customRentalMarkerWidget(widget.title),
              ),
              MarkerData(
                marker: Marker(
                  markerId: const MarkerId('current-location'),
                  position: latLng,
                  infoWindow: const InfoWindow(title: 'Vị trí hiện tại'),
                ),
                child: _customCurrentLocationMarkerWidget(),
              ),
            ];
          }
        });

        if (_controller != null && _rentalLatLng == null) {
          _controller?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 16));
        }
      } else {
        setState(() => _errorMessage = 'Không lấy được tọa độ hiện tại.');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Lỗi khi lấy vị trí hiện tại: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.black),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 14),
              ),
            ),
          Expanded(
            child: _isMapLoading
                ? const Center(child: CircularProgressIndicator())
                : CustomGoogleMapMarkerBuilder(
                    customMarkers: _customMarkers,
                    builder: (BuildContext context, Set<Marker>? markers) {
                      return GoogleMap(
                        mapType: MapType.normal,
                        initialCameraPosition: CameraPosition(
                          target: _rentalLatLng ??
                              _currentLatLng ??
                              const LatLng(10.0, 105.0),
                          zoom: 16.0,
                        ),
                        onMapCreated: (GoogleMapController controller) {
                          _controller = controller;
                          if (_rentalLatLng != null) {
                            controller.animateCamera(
                              CameraUpdate.newLatLngZoom(_rentalLatLng!, 16),
                            );
                          } else if (_currentLatLng != null) {
                            controller.animateCamera(
                              CameraUpdate.newLatLngZoom(_currentLatLng!, 16),
                            );
                          }
                        },
                        markers: markers ?? {},
                        myLocationEnabled: true,
                        myLocationButtonEnabled: true,
                        zoomControlsEnabled: true,
                        scrollGesturesEnabled: true,
                        rotateGesturesEnabled: true,
                        tiltGesturesEnabled: true,
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              widget.address,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
