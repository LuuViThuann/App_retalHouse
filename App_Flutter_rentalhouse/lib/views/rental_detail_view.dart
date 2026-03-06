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
import 'package:flutter_rentalhouse/viewmodels/vm_rental.dart';
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

  // Màu chủ đạo thống nhất
  static const primaryColor     = Color(0xFF2563EB);
  static const secondaryColor   = Color(0xFF64748B);
  static const backgroundColor  = Color(0xFFF8FAFC);

  // ── AI similar section state ─────────────────────────────────
  List<dynamic> _similarRentals = [];
  bool _isLoadingSimilar = false;
  bool _similarFetched   = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    _initializeData();
    _initializeFirstMedia();
    _fetchSimilarByPropertyType();
  }

  // ================================================================
  //  AI SIMILAR — fetch bài cùng loại BĐS
  // ================================================================

  Future<void> _fetchSimilarByPropertyType() async {
    if (_similarFetched) return;
    setState(() => _isLoadingSimilar = true);

    try {
      final rentalVM =
      Provider.of<RentalViewModel>(context, listen: false);

      // Gọi API similar items theo rentalId + lọc cùng propertyType
      final results = await rentalVM.fetchSimilarRentals(
        rentalId: widget.rental.id,
        propertyType: widget.rental.propertyType, // ← lọc đúng loại
        limit: 6,
      );

      if (mounted) {
        setState(() {
          _similarRentals  = results;
          _isLoadingSimilar = false;
          _similarFetched   = true;
        });
      }
    } catch (e) {
      debugPrint('❌ fetchSimilarByPropertyType error: $e');
      if (mounted) setState(() => _isLoadingSimilar = false);
    }
  }

  // ================================================================
  //  MEDIA HELPERS (giữ nguyên)
  // ================================================================

  bool _isCloudinaryUrl(String url) =>
      url.startsWith('http://') || url.startsWith('https://');

  String _getMediaUrl(String mediaUrl) => _isCloudinaryUrl(mediaUrl)
      ? mediaUrl
      : '${ApiRoutes.baseUrl.replaceAll('/api', '')}$mediaUrl';

  bool _isVideo(String url) {
    final lower = url.toLowerCase();
    return lower.contains('.mp4') ||
        lower.contains('.mov') ||
        lower.contains('.avi') ||
        lower.contains('.webm') ||
        lower.contains('video');
  }

  List<String> _getAllMedia() =>
      [...widget.rental.images, ...widget.rental.videos];

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
        _videoController =
            VideoPlayerController.networkUrl(Uri.parse(mediaUrl));
        await _videoController!.initialize();
        setState(() => _isVideoInitialized = true);
      } catch (e) {
        debugPrint('❌ Video init error: $e');
        setState(() => _isVideoInitialized = false);
      }
    }
  }

  // ================================================================
  //  BUILD MAIN MEDIA (giữ nguyên)
  // ================================================================

  Widget _buildMainMedia() {
    final allMedia = _getAllMedia();

    if (allMedia.isEmpty) {
      return Container(
        height: 300,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.grey[300]!, Colors.grey[200]!],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported_outlined,
                size: 60, color: Colors.grey[500]),
            const SizedBox(height: 12),
            Text('Chưa có ảnh hoặc video',
                style: TextStyle(color: Colors.grey[600], fontSize: 16)),
          ],
        ),
      );
    }

    final currentMediaUrl =
    _getMediaUrl(allMedia[_selectedMediaIndex]);
    final isCurrentVideo = _isVideo(currentMediaUrl);

    if (isCurrentVideo &&
        _videoController != null &&
        _isVideoInitialized) {
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
              _videoController!.value.isPlaying
                  ? Icons.pause_circle_filled
                  : Icons.play_circle_filled,
              color: Colors.white.withOpacity(0.9),
            ),
            onPressed: () => setState(() {
              _videoController!.value.isPlaying
                  ? _videoController!.pause()
                  : _videoController!.play();
            }),
          ),
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: VideoProgressIndicator(
              _videoController!,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: primaryColor,
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
        child: const Center(
            child: CircularProgressIndicator(color: Colors.white)),
      );
    } else {
      return GestureDetector(
        onTap: () => _showFullScreenImage(currentMediaUrl),
        child: CachedNetworkImage(
          imageUrl: currentMediaUrl,
          fit: BoxFit.cover,
          height: 300,
          placeholder: (_, __) => Container(
            height: 300,
            color: Colors.grey[200],
            child: const Center(child: CircularProgressIndicator()),
          ),
          errorWidget: (_, __, ___) => Container(
            height: 300,
            color: Colors.grey[300],
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image_outlined,
                    size: 60, color: Colors.grey[600]),
                const SizedBox(height: 12),
                Text('Không thể tải ảnh',
                    style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          ),
        ),
      );
    }
  }

  Widget _buildMediaThumbnail(String mediaUrl, int index) {
    final fullUrl      = _getMediaUrl(mediaUrl);
    final isVideoThumb = _isVideo(fullUrl);
    final isSelected   = _selectedMediaIndex == index;

    return GestureDetector(
      onTap: () async {
        setState(() => _selectedMediaIndex = index);
        await _loadMediaAtIndex(index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 4.0),
        width: 80,
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? primaryColor : Colors.grey[300]!,
            width: isSelected ? 2.5 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: primaryColor.withOpacity(0.3),
              blurRadius: 8,
              spreadRadius: 1,
            )
          ]
              : [],
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: isVideoThumb
                  ? Container(
                color: Colors.black87,
                child: const Center(
                  child: Icon(Icons.play_circle_outline,
                      color: Colors.white, size: 32),
                ),
              )
                  : CachedNetworkImage(
                imageUrl: fullUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                placeholder: (_, __) => Container(
                  color: Colors.grey[200],
                  child: const Center(
                      child: CircularProgressIndicator(
                          strokeWidth: 2)),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: Colors.grey[300],
                  child: Icon(Icons.error_outline,
                      color: Colors.grey[600], size: 24),
                ),
              ),
            ),
            if (isVideoThumb)
              Positioned(
                top: 4, right: 4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.videocam,
                      color: Colors.white, size: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ================================================================
  //  DATA & FAVORITE (giữ nguyên)
  // ================================================================

  Future<void> _initializeData() async {
    if (widget.rental.id.isNotEmpty && widget.rental.title.isNotEmpty) {
      setState(() { _averageRating = 0.0; _reviewCount = 0; });
    } else {
      await _rentalService.fetchRentalDetails(
        rental: widget.rental,
        onSuccess: (avg, count) =>
            setState(() { _averageRating = avg; _reviewCount = count; }),
        onError: (e) {
          debugPrint('Error fetching rental details: $e');
          setState(() { _averageRating = 0.0; _reviewCount = 0; });
        },
        context: context,
      );
    }

    await _rentalService.checkFavoriteStatus(
      rental: widget.rental,
      onSuccess: (isFav) => setState(() {
        _isFavorite = isFav;
        _isLoadingFavorite = false;
      }),
      onError: (e) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e)));
        setState(() { _isFavorite = false; _isLoadingFavorite = false; });
      },
      context: context,
    );
  }

  Future<void> _toggleFavorite() async {
    setState(() => _isLoadingFavorite = true);
    final authVM     = Provider.of<AuthViewModel>(context, listen: false);
    final favoriteVM = Provider.of<FavoriteViewModel>(context, listen: false);

    await _rentalService.toggleFavorite(
      rental: widget.rental,
      isFavorite: _isFavorite,
      onSuccess: (newStatus) {
        setState(() { _isFavorite = newStatus; _isLoadingFavorite = false; });
        if (newStatus) {
          if (!favoriteVM.isFavorite(widget.rental.id)) {
            favoriteVM.addFavoriteLocally(Favorite(
              userId: authVM.currentUser?.id ?? '',
              rentalId: widget.rental.id,
              createdAt: DateTime.now(),
            ));
          }
        } else {
          favoriteVM.removeFavoriteLocally(widget.rental.id);
        }
        _showSuccessSnackBar(newStatus);
      },
      onError: (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          backgroundColor: Colors.transparent,
          elevation: 0,
          content: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: Colors.red[600],
                borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(e,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 15))),
            ]),
          ),
        ));
        setState(() => _isLoadingFavorite = false);
      },
      context: context,
    );
  }

  void _showSuccessSnackBar(bool isFav) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      elevation: 0,
      backgroundColor: Colors.transparent,
      duration: const Duration(seconds: 2),
      content: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: Colors.green[600],
            borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Icon(isFav ? Icons.favorite : Icons.favorite_border,
              color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isFav ? 'Đã thêm vào yêu thích' : 'Đã xóa khỏi yêu thích',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ]),
      ),
    ));
  }

  void _showFullScreenImage(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          body: Stack(children: [
            Center(
              child: PhotoView(
                imageProvider: NetworkImage(imageUrl),
                minScale: PhotoViewComputedScale.contained * 0.8,
                maxScale: PhotoViewComputedScale.covered * 2.0,
              ),
            ),
            Positioned(
              top: 40, left: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  String formatCurrency(double amount) {
    final formatter = NumberFormat.currency(
        locale: 'vi_VN', symbol: 'VNĐ', decimalDigits: 0);
    return formatter.format(amount);
  }

  void _updateReviewCount(int count) =>
      setState(() => _reviewCount = count);

  void _navigateToMap() => Navigator.push(
    context,
    MaterialPageRoute(
        builder: (_) => RentalMapView(rental: widget.rental)),
  );

  @override
  void dispose() {
    _tabController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  // ================================================================
  //  AI SIMILAR SECTION — widget
  // ================================================================

  Widget _buildAISimilarSection() {
    final propertyType = widget.rental.propertyType;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                // AI icon với gradient
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    "assets/img/ai.jpg",
                    width: 78,
                    height: 78,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Trợ lý AI gợi ý thêm cho bạn',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      // Badge loại BĐS
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: primaryColor.withOpacity(0.2)),
                        ),
                        child: Text(
                          propertyType,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Refresh nếu cần
                if (!_isLoadingSimilar && _similarFetched)
                  GestureDetector(
                    onTap: () {
                      setState(() => _similarFetched = false);
                      _fetchSimilarByPropertyType();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.refresh_rounded,
                          size: 16, color: Colors.grey[600]),
                    ),
                  ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // ── Content ─────────────────────────────────────────
          if (_isLoadingSimilar)
            _buildSimilarLoading()
          else if (_similarRentals.isEmpty)
            _buildSimilarEmpty(propertyType)
          else
            _buildSimilarList(),
        ],
      ),
    );
  }

  Widget _buildSimilarLoading() => SizedBox(
    height: 180,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      itemBuilder: (_, __) => Container(
        width: 160,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
            child: CircularProgressIndicator(strokeWidth: 2)),
      ),
    ),
  );

  Widget _buildSimilarEmpty(String propertyType) => Padding(
    padding: const EdgeInsets.all(24),
    child: Center(
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 36, color: Colors.grey[400]),
          const SizedBox(height: 10),
          Text(
            'Chưa có bài "$propertyType" nào khác để gợi ý',
            style:
            TextStyle(fontSize: 13, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );

  Widget _buildSimilarList() {
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        itemCount: _similarRentals.length,
        itemBuilder: (_, i) =>
            _buildSimilarCard(_similarRentals[i], i),
      ),
    );
  }

  Widget _buildSimilarCard(dynamic item, int index) {
    // item là Rental object hoặc Map — tuỳ API trả về
    final rental = item is Rental ? item : null;
    final title  = rental?.title  ?? (item['title']  ?? 'Bài đăng');
    final price  = rental?.price  ?? (item['price']  ?? 0.0);
    final type   = rental?.propertyType ?? (item['propertyType'] ?? '');
    final images = rental?.images ?? (item['images'] as List? ?? []);
    final id     = rental?.id ?? (item['rentalId'] ?? item['_id'] ?? '');

    final imageUrl = images.isNotEmpty
        ? _getMediaUrl(images.first.toString())
        : null;

    // Confidence từ AI nếu có
    final confidence = item is Map
        ? (item['confidence'] as num?)?.toDouble()
        : null;

    return GestureDetector(
      onTap: () async {
        // ── Case 1: item đã là Rental object → navigate thẳng ──
        if (rental != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RentalDetailScreen(rental: rental),
            ),
          );
          return;
        }

        // ── Case 2: item là Map (từ ML API) → tìm Rental bằng id ──
        if (id.isEmpty) return;

        // Thử tìm trong cache ViewModel trước (nhanh, không cần network)
        final vm = context.read<RentalViewModel>();
        Rental? cached;
        try {
          cached = vm.rentals.firstWhere((r) => r.id == id);
        } catch (_) {
          cached = null;
        }

        if (cached != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RentalDetailScreen(rental: cached!),
            ),
          );
          return;
        }

        // Cache miss → fetch từ API bằng rentalId
        // Hiển thị loading trong lúc chờ
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(
            child: CircularProgressIndicator(),
          ),
        );

        try {
          final rentalService = RentalService();
          final fetched = await rentalService.fetchRentalById(rentalId: id);

          if (context.mounted) {
            Navigator.pop(context); // đóng loading
            if (fetched != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RentalDetailScreen(rental: fetched),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Không thể tải thông tin bài đăng'),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          }
        } catch (e) {
          if (context.mounted) {
            Navigator.pop(context); // đóng loading
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Lỗi: $e'),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200 + index * 60),
        curve: Curves.easeOut,
        width: 160,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Thumbnail ───────────────────────────────────
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12)),
                  child: imageUrl != null
                      ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    height: 110,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      height: 110,
                      color: Colors.grey[200],
                      child: const Center(
                          child: CircularProgressIndicator(
                              strokeWidth: 2)),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      height: 110,
                      color: Colors.grey[200],
                      child: Icon(Icons.image_not_supported,
                          color: Colors.grey[400]),
                    ),
                  )
                      : Container(
                    height: 110,
                    color: Colors.grey[200],
                    child: Icon(Icons.home_outlined,
                        size: 36, color: Colors.grey[400]),
                  ),
                ),

                Positioned(
                  bottom: 8, left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.88),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      type,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // ── Info ────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Text(
                      formatCurrency(price.toDouble()),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================================================================
  //  BUILD
  // ================================================================

  @override
  Widget build(BuildContext context) {
    final allMedia = _getAllMedia();

    return Scaffold(
      backgroundColor: backgroundColor,
      body: CustomScrollView(
        slivers: [
          // ── Hero Section ─────────────────────────────────────
          SliverAppBar(
            expandedHeight: 320,
            floating: false,
            pinned: true,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  _buildMainMedia(),
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: Container(
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.5),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.1), blurRadius: 8)
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.1), blurRadius: 8)
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.share, color: Colors.black87),
                  onPressed: () {},
                ),
              ),
            ],
            backgroundColor: Colors.white,
          ),

          // ── Main Content ─────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              color: backgroundColor,
              child: Column(
                children: [
                  // Media Gallery
                  if (allMedia.length > 1)
                    Container(
                      height: 90,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding:
                        const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: allMedia.length,
                        itemBuilder: (_, i) =>
                            _buildMediaThumbnail(allMedia[i], i),
                      ),
                    ),

                  // Title & Price Card
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 2))
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.rental.title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text('Giá thuê',
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w500)),
                                  const SizedBox(height: 4),
                                  Text(
                                    formatCurrency(widget.rental.price),
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _isLoadingFavorite
                                ? SizedBox(
                              width: 48, height: 48,
                              child: Lottie.asset(
                                  AssetsConfig.loadingLottie,
                                  fit: BoxFit.contain),
                            )
                                : Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _toggleFavorite,
                                borderRadius:
                                BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: _isFavorite
                                        ? Colors.red[50]
                                        : Colors.grey[100],
                                    borderRadius:
                                    BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    _isFavorite
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    color: _isFavorite
                                        ? Colors.red[600]
                                        : Colors.grey[600],
                                    size: 24,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Icon(Icons.star,
                                color: Colors.amber[600], size: 18),
                            const SizedBox(width: 4),
                            Text('$_reviewCount đánh giá',
                                style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700])),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Location Card
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 2))
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.location_on,
                                size: 20, color: secondaryColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.rental.location['fullAddress'],
                                style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.grey[800],
                                    height: 1.4),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _navigateToMap,
                            icon: const Icon(Icons.map, size: 20),
                            label: const Text('Xem trên bản đồ'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                  BorderRadius.circular(12)),
                              elevation: 0,
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
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        InfoChip(
                            label: 'Loại chỗ ở',
                            value: widget.rental.propertyType),
                        const InfoChip(
                            label: 'Phong cách', value: 'Hiện đại'),
                        const InfoChip(
                            label: 'Chi phí', value: 'Phù hợp'),
                        const InfoChip(
                            label: 'Hợp đồng', value: 'Đơn giản'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Owner Badge
                  Consumer<AuthViewModel>(
                    builder: (_, authVM, __) {
                      if (authVM.currentUser?.id == widget.rental.userId) {
                        return Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.amber[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.amber[200]!),
                          ),
                          child: Row(
                            mainAxisAlignment:
                            MainAxisAlignment.center,
                            children: [
                              Icon(Icons.verified_user,
                                  color: Colors.amber[800], size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Đây là bài viết của bạn',
                                style: TextStyle(
                                    color: Colors.amber[900],
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),

                  const SizedBox(height: 16),

                  // ════════════════════════════════════════════
                  //  🤖 AI SIMILAR SECTION  ← MỚI THÊM
                  // ════════════════════════════════════════════
                  _buildAISimilarSection(),
                  // ════════════════════════════════════════════

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // ── Tabs ─────────────────────────────────────────────
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverAppBarDelegate(
              TabBar(
                controller: _tabController,
                labelColor: primaryColor,
                unselectedLabelColor: secondaryColor,
                indicatorColor: primaryColor,
                indicatorWeight: 2.5,
                labelStyle: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 15),
                tabs: [
                  const Tab(text: 'Thông tin chi tiết'),
                  Tab(text: 'Đánh giá ($_reviewCount)'),
                ],
              ),
            ),
          ),

          // ── Tab Content ──────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              color: backgroundColor,
              padding: const EdgeInsets.all(16.0),
              child: IndexedStack(
                index: _tabController.index,
                children: [
                  DetailsTab(
                      rental: widget.rental,
                      formatCurrency: formatCurrency),
                  if (widget.rental.id.isNotEmpty)
                    CommentSection(
                      rentalId: widget.rental.id,
                      onCommentCountChanged: _updateReviewCount,
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        children: [
                          Icon(Icons.comment_outlined,
                              size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text('Chưa có đánh giá nào',
                              style: TextStyle(
                                  fontSize: 15, color: Colors.grey[600])),
                        ],
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

// ================================================================
//  SLIVER DELEGATE (giữ nguyên)
// ================================================================

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) =>
      Container(color: Colors.white, child: _tabBar);

  @override
  bool shouldRebuild(_SliverAppBarDelegate old) => false;
}