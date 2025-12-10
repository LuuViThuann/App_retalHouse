import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/Widgets/Detail/rentalMap.dart';
import 'package:flutter_rentalhouse/config/loading.dart';
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
import 'package:video_player/video_player.dart';
import '../config/api_routes.dart';

class RentalDetailScreen extends StatefulWidget {
  final Rental rental;
  const RentalDetailScreen({super.key, required this.rental});

  @override
  _RentalDetailScreenState createState() => _RentalDetailScreenState();
}

class _RentalDetailScreenState extends State<RentalDetailScreen>
    with SingleTickerProviderStateMixin {
  int _selectedMediaIndex = 0;
  bool _isFavorite = false;
  bool _isLoadingFavorite = true;
  double _averageRating = 0.0;
  int _reviewCount = 0;
  late TabController _tabController;
  final RentalService _rentalService = RentalService();
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    _initializeData();
    _initializeFirstMedia();
  }

  /// ✅ Cloudinary Helper Functions
  bool _isCloudinaryUrl(String url) =>
      url.startsWith('http://') || url.startsWith('https://');

  String _getMediaUrl(String mediaUrl) =>
      _isCloudinaryUrl(mediaUrl) ? mediaUrl : '${ApiRoutes.baseUrl.replaceAll('/api', '')}$mediaUrl';

  bool _isVideo(String url) {
    final lower = url.toLowerCase();
    return lower.contains('.mp4') || lower.contains('.mov') ||
        lower.contains('.avi') || lower.contains('.webm') ||
        lower.contains('video');
  }

  List<String> _getAllMedia() => [...widget.rental.images, ...widget.rental.videos];

  void _initializeFirstMedia() {
    final allMedia = _getAllMedia();
    if (allMedia.isNotEmpty) _loadMediaAtIndex(0);
  }

  Future<void> _loadMediaAtIndex(int index) async {
    final allMedia = _getAllMedia();
    if (index >= allMedia.length) return;

    final mediaUrl = _getMediaUrl(allMedia[index]);

    if (_videoController != null) {
      await _videoController!.pause();
      await _videoController!.dispose();
      _videoController = null;
      setState(() => _isVideoInitialized = false);
    }

    if (_isVideo(mediaUrl)) {
      try {
        _videoController = VideoPlayerController.networkUrl(Uri.parse(mediaUrl));
        await _videoController!.initialize();
        setState(() => _isVideoInitialized = true);
      } catch (e) {
        debugPrint('❌ Video init error: $e');
        setState(() => _isVideoInitialized = false);
      }
    }
  }

  /// ✅ Main Media Widget (Image or Video)
  Widget _buildMainMedia() {
    final allMedia = _getAllMedia();

    if (allMedia.isEmpty) {
      return Container(
        height: 300,
        color: Colors.grey[300],
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported_outlined, size: 60, color: Colors.grey[600]),
            const SizedBox(height: 12),
            Text('Chưa có ảnh hoặc video', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
          ],
        ),
      );
    }

    final currentMediaUrl = _getMediaUrl(allMedia[_selectedMediaIndex]);
    final isCurrentVideo = _isVideo(currentMediaUrl);

    if (isCurrentVideo && _videoController != null && _isVideoInitialized) {
      return Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: _videoController!.value.aspectRatio,
            child: VideoPlayer(_videoController!),
          ),
          IconButton(
            iconSize: 64,
            icon: Icon(
              _videoController!.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
              color: Colors.white.withOpacity(0.9),
            ),
            onPressed: () {
              setState(() {
                _videoController!.value.isPlaying ? _videoController!.pause() : _videoController!.play();
              });
            },
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: VideoProgressIndicator(
              _videoController!,
              allowScrubbing: true,
              colors: VideoProgressColors(
                playedColor: Colors.blue,
                bufferedColor: Colors.grey,
                backgroundColor: Colors.white24,
              ),
            ),
          ),
        ],
      );
    } else if (isCurrentVideo) {
      return Container(
        height: 300,
        color: Colors.black,
        child: const Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    } else {
      return GestureDetector(
        onTap: () => _showFullScreenImage(currentMediaUrl),
        child: CachedNetworkImage(
          imageUrl: currentMediaUrl,
          fit: BoxFit.cover,
          height: 300,
          placeholder: (context, url) => Container(
            height: 300,
            color: Colors.grey[200],
            child: const Center(child: CircularProgressIndicator()),
          ),
          errorWidget: (context, url, error) {
            debugPrint('❌ Image error: $error');
            return Container(
              height: 300,
              color: Colors.grey[300],
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image_outlined, size: 60, color: Colors.grey[600]),
                  const SizedBox(height: 12),
                  Text('Không thể tải ảnh', style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            );
          },
        ),
      );
    }
  }

  /// ✅ Media Thumbnail Widget
  Widget _buildMediaThumbnail(String mediaUrl, int index) {
    final fullUrl = _getMediaUrl(mediaUrl);
    final isVideoThumb = _isVideo(fullUrl);

    return GestureDetector(
      onTap: () async {
        setState(() => _selectedMediaIndex = index);
        await _loadMediaAtIndex(index);
      },
      child: Stack(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4.0),
            width: 80,
            decoration: BoxDecoration(
              border: Border.all(
                color: _selectedMediaIndex == index ? Colors.blue[700]! : Colors.grey[300]!,
                width: _selectedMediaIndex == index ? 3 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: isVideoThumb
                  ? Container(
                color: Colors.black87,
                child: const Icon(Icons.play_circle_outline, color: Colors.white, size: 32),
              )
                  : CachedNetworkImage(
                imageUrl: fullUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey[200],
                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[300],
                  child: Icon(Icons.error_outline, color: Colors.grey[600], size: 24),
                ),
              ),
            ),
          ),
          if (isVideoThumb)
            Positioned(
              top: 4,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.videocam, color: Colors.white, size: 12),
              ),
            ),
        ],
      ),
    );
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
          debugPrint('Error fetching rental details: $error');
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
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

    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final favoriteViewModel = Provider.of<FavoriteViewModel>(context, listen: false);

    await _rentalService.toggleFavorite(
      rental: widget.rental,
      isFavorite: _isFavorite,
      onSuccess: (newFavoriteStatus) {
        setState(() {
          _isFavorite = newFavoriteStatus;
          _isLoadingFavorite = false;
        });

        if (newFavoriteStatus) {
          if (!favoriteViewModel.isFavorite(widget.rental.id)) {
            final newFavorite = Favorite(
              userId: authViewModel.currentUser?.id ?? '',
              rentalId: widget.rental.id,
              createdAt: DateTime.now(),
            );
            favoriteViewModel.addFavoriteLocally(newFavorite);
          }
        } else {
          favoriteViewModel.removeFavoriteLocally(widget.rental.id);
        }
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
                  Expanded(child: Text(error, style: const TextStyle(color: Colors.white, fontSize: 16))),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        elevation: 0,
        backgroundColor: Colors.transparent,
        duration: const Duration(seconds: 2),
        content: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color.fromARGB(255, 1, 180, 64), Color.fromARGB(255, 85, 221, 112)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))],
          ),
          child: Row(
            children: [
              Icon(isFavorited ? Icons.favorite : Icons.favorite_border, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isFavorited ? 'Đã thêm vào yêu thích' : 'Đã xóa khỏi yêu thích',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
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
    final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'VNĐ', decimalDigits: 0);
    return formatter.format(amount);
  }

  void _updateReviewCount(int count) => setState(() => _reviewCount = count);

  void _navigateToMap() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RentalMapView(rental: widget.rental)),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allMedia = _getAllMedia();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(background: _buildMainMedia()),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            backgroundColor: Colors.blue[700],
          ),
          SliverToBoxAdapter(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              child: Container(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(13.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title & Location Section
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.blue.shade50, Colors.blue.shade100.withOpacity(0.3)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(Icons.location_on, size: 16, color: Colors.blue.shade700),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      widget.rental.location['fullAddress'],
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
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade600,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.map, color: Colors.white, size: 16),
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
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Info Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            InfoChip(label: 'Loại chỗ ở', value: widget.rental.propertyType),
                            const SizedBox(width: 4),
                            const InfoChip(label: 'Phong cách', value: 'Hiện đại'),
                            const SizedBox(width: 4),
                            const InfoChip(label: 'Chi phí', value: 'Phù hợp'),
                            const SizedBox(width: 4),
                            const InfoChip(label: 'Hợp đồng', value: 'Đơn giản'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Price & Rating & Favorite
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    Icon(Icons.account_balance_wallet, color: Colors.green.shade700, size: 24),
                                    const SizedBox(width: 8),
                                    Text('Giá: ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
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
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.amber.shade50, Colors.amber.shade100.withOpacity(0.3)],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.amber.shade100),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.star, color: Colors.amber.shade700, size: 24),
                                    const SizedBox(width: 8),
                                    Text(
                                      '($_reviewCount lượt đánh giá)',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          _isLoadingFavorite
                              ? SizedBox(
                            width: 32,
                            height: 32,
                            child: Lottie.asset(AssetsConfig.loadingLottie, fit: BoxFit.contain),
                          )
                              : InkWell(
                            onTap: _toggleFavorite,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              margin: const EdgeInsets.only(right: 16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.red.shade400.withOpacity(0.9),
                                    Colors.red.shade600.withOpacity(0.9)
                                  ],
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _isFavorite ? Icons.favorite : Icons.favorite_border,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // ✅ Media Gallery (Images + Videos)
                      if (allMedia.length > 1)
                        Container(
                          height: 80,
                          margin: const EdgeInsets.only(bottom: 16.0),
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: allMedia.length,
                            itemBuilder: (context, index) => _buildMediaThumbnail(allMedia[index], index),
                          ),
                        ),
                      const SizedBox(height: 24),
                      // Owner Badge
                      Consumer<AuthViewModel>(
                        builder: (context, authViewModel, child) {
                          if (authViewModel.currentUser?.id == widget.rental.userId) {
                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.orange[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.orange[200]!),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.info_outline, color: Colors.orange[600], size: 20),
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
                  DetailsTab(rental: widget.rental, formatCurrency: formatCurrency),
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
                            Icon(Icons.comment_outlined, size: 48, color: Color(0xFF9E9E9E)),
                            SizedBox(height: 16),
                            Text(
                              'Không có bình luận cho bài viết này',
                              style: TextStyle(fontSize: 16, color: Color(0xFF9E9E9E)),
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
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: Colors.white, child: _tabBar);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}