import 'dart:async';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/Widgets/Favorite/favorite_item_shimmer.dart';
import 'package:flutter_rentalhouse/Widgets/Favorite/favorite_rental.dart';
import 'package:flutter_rentalhouse/Widgets/HomeMain/PropertyType_house.dart';
import 'package:flutter_rentalhouse/Widgets/HomeMain/all_rental.dart';
import 'package:flutter_rentalhouse/Widgets/Rental/RentalCardHorizontal.dart';
import 'package:flutter_rentalhouse/config/navigator.dart';
import 'package:flutter_rentalhouse/constants/app_color.dart';
import 'package:flutter_rentalhouse/models/rental.dart';
import 'package:flutter_rentalhouse/services/chat_ai_service.dart';
import 'package:flutter_rentalhouse/services/rental_service.dart';
import 'package:flutter_rentalhouse/utils/rental_filter.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_auth.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_favorite.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_rental.dart';
import 'package:flutter_rentalhouse/views/Admin/Service/banner.dart';
import 'package:flutter_rentalhouse/views/Admin/Widget/HomeMain/News_home.dart';
import 'package:flutter_rentalhouse/views/Admin/model/banner.dart';
import 'package:flutter_rentalhouse/views/favorite_view.dart';
import 'package:flutter_rentalhouse/views/login_view.dart';
import 'package:flutter_rentalhouse/views/rental_detail_view.dart';
import 'package:flutter_rentalhouse/views/search_rental.dart';
import 'package:location/location.dart' as loc;
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../Widgets/Detail/analytics_screen.dart';
import '../Widgets/Detail/rentalMap.dart';
import '../Widgets/HomeMain/AllAIRecommendations.dart';
import '../Widgets/Profile/PaymentHistoryView.dart';
import '../config/loading.dart';
import '../models/user.dart';
import 'package:intl/intl.dart';
import '../config/api_routes.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../utils/Snackbar_process.dart';


class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  final TextEditingController _searchController = TextEditingController();
  final PageController _bannerController = PageController();
  final BannerService _bannerService = BannerService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late ValueNotifier<int> _unreadNotificationCount;

  List<dynamic> provinces = [];
  List<BannerModel> banners = [];
  bool isLoadingProvinces = true;
  bool isLoadingBanners = true;
  late ValueNotifier<int> _currentBannerIndex;
  Timer? _bannerTimer;
  Timer? _notificationTimer;

  // BIẾN GƠI Ý AI
  late loc.Location _location;
  bool _isLoadingAI = false;
  List<Rental> _aiRecommendations = [];

  RentalFilter filter = const RentalFilter();

  @override
  void initState() {
    super.initState();
    _currentBannerIndex = ValueNotifier<int>(0);
    _unreadNotificationCount = ValueNotifier<int>(0);
    _location = loc.Location();
    fetchProvinces();
    fetchBanners();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
      final favoriteViewModel =
      Provider.of<FavoriteViewModel>(context, listen: false);
      final rentalViewModel = Provider.of<RentalViewModel>(context, listen: false);

      if (authViewModel.currentUser != null) {
        final token = authViewModel.currentUser!.token ?? '';
        if (token.isNotEmpty) {
          favoriteViewModel.fetchFavorites(token);

          rentalViewModel.refreshAllRentals();
          _loadUnreadCount();
          _startNotificationTimer();
          _loadAIRecommendations();
        }
      }
    });
  }

  // ============================================================
// 🔥 THÊM PHƯƠNG THỨC LOAD AI RECOMMENDATIONS

  Future<void> _loadAIRecommendations() async {
    try {
      final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
      final rentalViewModel = Provider.of<RentalViewModel>(context, listen: false);

      if (authViewModel.currentUser == null) return;

      // Kiểm tra quyền GPS
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) return;
      }

      var permissionGranted = await _location.hasPermission();
      if (permissionGranted == loc.PermissionStatus.denied) {
        permissionGranted = await _location.requestPermission();
        if (permissionGranted != loc.PermissionStatus.granted) return;
      }

      // Lấy vị trí hiện tại
      final currentLocation = await _location.getLocation();

      if (currentLocation.latitude == null || currentLocation.longitude == null) {
        return;
      }

      setState(() => _isLoadingAI = true);

      // Gọi AI recommendations từ ViewModel
      await rentalViewModel.fetchAIRecommendations(
        latitude: currentLocation.latitude!,
        longitude: currentLocation.longitude!,
        radius: 10.0,
      );

      if (mounted) {
        setState(() {
          _aiRecommendations = rentalViewModel.nearbyRentals;
          _isLoadingAI = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading AI recommendations: $e');
      if (mounted) {
        setState(() => _isLoadingAI = false);
      }
    }
  }

  // 🔥 THÊM WIDGET BUILD AI SECTION
  Widget _buildAIRecommendationsSection() {
    if (_aiRecommendations.isEmpty && !_isLoadingAI) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF1E88E5),
                        Color(0xFF42A5F5),
                        Color(0xFF26C6DA),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Trợ lý AI gợi ý cho bạn',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )

              ],
            ),
            TextButton(
              onPressed: () async {
                // Lấy vị trí hiện tại
                final currentLocation = await _location.getLocation();

                if (currentLocation.latitude != null && currentLocation.longitude != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AllAIRecommendationsScreen(
                        initialLatitude: currentLocation.latitude,
                        initialLongitude: currentLocation.longitude,
                        initialRadius: 10.0,
                      ),
                    ),
                  );
                } else {
                  // Nếu không lấy được vị trí, vẫn mở màn hình (sẽ tự lấy vị trí)
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AllAIRecommendationsScreen()),
                  );
                }
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Xem tất cả',
                    style: TextStyle(fontSize: 14, color: Colors.blue[700]),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward,
                    size: 14,
                    color: Colors.blue[700],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_isLoadingAI)
          SizedBox(
            height: 280,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 3,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) => Shimmer.fromColors(
                baseColor: Colors.grey[300]!,
                highlightColor: Colors.grey[100]!,
                child: const RentalCardPlaceholder(),
              ),
            ),
          )
        else if (_aiRecommendations.isNotEmpty)
          SizedBox(
            height: 280,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _aiRecommendations.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final rental = _aiRecommendations[index];
                return Stack(
                  children: [
                    RentalCardHorizontal(rental: rental),
                  ],
                );
              },
            ),
          )
        else
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'Không có gợi ý AI',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ),
        const SizedBox(height: 20),
      ],
    );
  }

  Future<void> _getCurrentLocationAndNavigateToMap() async {
    try {
      final location = loc.Location();

      //  Kiểm tra dịch vụ định vị
      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) {
          if (mounted) {
            Navigator.pop(context); // Đóng loading dialog
            AppSnackBar.show(
              context,
              AppSnackBar.error(
                message: 'Dịch vụ vị trí chưa được bật. Vui lòng bật GPS.',
              ),
            );
          }
          return;
        }
      }

      //  Kiểm tra quyền truy cập
      var permissionGranted = await location.hasPermission();
      if (permissionGranted == loc.PermissionStatus.denied) {
        permissionGranted = await location.requestPermission();
        if (permissionGranted != loc.PermissionStatus.granted) {
          if (mounted) {
            Navigator.pop(context); // Đóng loading dialog
            AppSnackBar.show(
              context,
              AppSnackBar.error(
                message: 'Vui lòng cấp quyền truy cập vị trí.',
              ),
            );
          }
          return;
        }
      }

      //  Lấy vị trí hiện tại
      final currentLocation = await location.getLocation();

      if (currentLocation.latitude == null || currentLocation.longitude == null) {
        if (mounted) {
          Navigator.pop(context); // Đóng loading dialog
          AppSnackBar.show(
            context,
            AppSnackBar.error(
              message: 'Không thể lấy vị trí hiện tại. Vui lòng thử lại.',
            ),
          );
        }
        return;
      }

      //  Tạo rental đại diện cho vị trí hiện tại từ dữ liệu thực
      final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
      final currentUser = authViewModel.currentUser;

      final currentLocationRental = Rental(
        id: 'current_location_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Vị trí của tôi',
        price: 0,
        propertyType: 'Location',
        location: {
          'short': 'Vị trí hiện tại',
          'fullAddress': 'Vị trí hiện tại của tôi',
          'latitude': currentLocation.latitude!,
          'longitude': currentLocation.longitude!,
        },
        images: [],
        videos: [],
        createdAt: DateTime.now(),
        userId: currentUser?.id ?? '',
        landlord: currentUser?.id ?? '',
        area: {
          'total': 0.0,
          'livingRoom': 0.0,
          'bedrooms': 0,
          'bathrooms': 0,
        },
        furniture: [],
        amenities: [],
        surroundings: [],
        rentalTerms: {
          'minimumLease': '',
          'deposit': '',
          'paymentMethod': '',
          'renewalTerms': '',
        },
        contactInfo: {
          'name': currentUser?.username ?? 'Người dùng',
          'phone': currentUser?.phoneNumber ?? '',
          'availableHours': '',
        },
        status: 'available',
      );

      // Delay một chút để loading dialog hiển thị rõ
      await Future.delayed(const Duration(milliseconds: 500));

      //Đóng loading dialog
      if (mounted) {
        Navigator.pop(context);
      }

      // 🔥 Điều hướng tới RentalMapView với vị trí hiện tại thực tế
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RentalMapView(
              rental: currentLocationRental,
            ),
          ),
        );
      }

      print('✅ Opened map with real location: (${currentLocation.latitude}, ${currentLocation.longitude})');
    } catch (e) {
      print('❌ Error getting location: $e');
      if (mounted) {
        Navigator.pop(context); // Đóng loading dialog
        AppSnackBar.show(
          context,
          AppSnackBar.error(
            message: 'Lỗi: $e',
          ),
        );
      }
    }
  }

  Future<void> fetchProvinces() async {
    try {
      final response = await http.get(ApiRoutes.provinces);
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes)) as List;
        setState(() {
          provinces = data;
          isLoadingProvinces = false;

          final canTho = data.firstWhere(
                (p) => p['name'] == 'Cần Thơ',
            orElse: () => null,
          );

          if (canTho != null) {
            filter = filter.copyWith(selectedProvince: canTho);
          }
        });
      }
    } catch (e) {
      setState(() => isLoadingProvinces = false);
    }
  }

  Future<void> fetchBanners() async {
    try {
      final fetchedBanners = await _bannerService.fetchActiveBanners();
      setState(() {
        banners = fetchedBanners;
        isLoadingBanners = false;
      });
      _startBannerAutoScroll();
    } catch (e) {
      setState(() => isLoadingBanners = false);
      debugPrint('Lỗi tải banner: $e');
    }
  }

  Future<void> _loadUnreadCount() async {
    try {
      final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
      final count = await authViewModel.getUnreadCount();

      if (mounted) {

        _unreadNotificationCount.value = count;
        debugPrint('📊 Updated notification count: $count');
      }
    } catch (e) {
      debugPrint('❌ Lỗi tải số thông báo: $e');
      if (mounted) {
        _unreadNotificationCount.value = 0;
      }
    }
  }

  void _startNotificationTimer() {
    _notificationTimer?.cancel();
    _notificationTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _loadUnreadCount();
      }
    });
  }

  void _startBannerAutoScroll() {
    _bannerTimer?.cancel();
    if (banners.isEmpty) return;

    _bannerTimer = Timer.periodic(const Duration(seconds: 7), (timer) {
      if (!mounted || !_bannerController.hasClients) return;

      try {
        final nextPage = (_currentBannerIndex.value + 1) % banners.length;
        _bannerController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 1),
          curve: Curves.easeInOut,
        );
      } catch (e) {
        debugPrint('Banner scroll error: $e');
      }
    });
  }

  String _getBannerImageUrl(String imageUrl) {
    if (imageUrl.isEmpty) return '';
    if (imageUrl.startsWith('http')) {
      return imageUrl;
    }
    return '${ApiRoutes.serverBaseUrl}$imageUrl';
  }

  void clearAllFilters() {
    final canTho = provinces.firstWhere(
          (p) => p['name'] == 'Cần Thơ',
      orElse: () => null,
    );
    setState(() {
      filter = filter.clear(defaultProvince: canTho);
    });
  }

  List<dynamic> getFilteredLatestRentals(RentalViewModel vm) {
    final now = DateTime.now();
    final thisMonthRentals = vm.rentals
        .where((r) =>
    r.createdAt.year == now.year && r.createdAt.month == now.month)
        .toList();

    return filter.apply(rentals: thisMonthRentals).take(5).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _bannerTimer?.cancel();
    _notificationTimer?.cancel();
    _bannerController.dispose();
    _currentBannerIndex.dispose();
    _unreadNotificationCount.dispose();
    super.dispose();
  }

  String formatCurrency(double amount) {
    final formatter =
    NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
    return formatter.format(amount);
  }

  Widget _buildDrawer(BuildContext context, AuthViewModel authViewModel) {
    final AppUser? user = authViewModel.currentUser;
    return Drawer(
      child: Container(
        color: Colors.grey[50],
        child: Column(
          children: [
            // Header Drawer - Style ngân hàng
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 32),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.blue[700]!,
                        width: 2,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.grey[200],
                      child: user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty
                          ? ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: user.avatarUrl!,
                          fit: BoxFit.cover,
                          width: 64,
                          height: 64,
                          placeholder: (context, url) => const CircularProgressIndicator(),
                          errorWidget: (context, url, error) =>
                              Image.asset('assets/img/imageuser.png'),
                        ),
                      )
                          : Image.asset('assets/img/imageuser.png'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.username ?? 'Tên người dùng',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A),
                            letterSpacing: -0.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user?.email ?? 'Email@gmail.com',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                            letterSpacing: -0.2,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Menu Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  // Tài khoản Section
                  _buildSectionHeader('TÀI KHOẢN'),
                  _buildModernMenuItem(
                    icon: Icons.person_outline_rounded,
                    text: 'Thông tin cá nhân',
                    iconColor: AppColors.primaryColorIconDetail,
                    onTap: () {
                      Navigator.pop(context);
                      AppNavigator.goToProfile(context);
                    },
                  ),
                  _buildModernMenuItem(
                    icon: Icons.lock_outline_rounded,
                    text: 'Thay đổi mật khẩu',
                    iconColor: AppColors.primaryColorIconDetail,
                    onTap: () {
                      Navigator.pop(context);
                      AppNavigator.goToChangePassword(context);
                    },
                  ),

                  // Hoạt động Section
                  _buildSectionHeader('HOẠT ĐỘNG'),
                  _buildModernMenuItem(
                    icon: Icons.notifications_none_rounded,
                    text: 'Thông báo',
                    iconColor: AppColors.primaryColorIconDetail,
                    trailing: ValueListenableBuilder<int>(
                      valueListenable: _unreadNotificationCount,
                      builder: (context, count, child) {
                        return count > 0 ? _buildBadge(count.toString()) : const SizedBox.shrink();
                      },
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      AppNavigator.goToNotification(context);
                      Future.delayed(const Duration(milliseconds: 500), () {
                        if (mounted) _loadUnreadCount();
                      });
                    },
                  ),
                  _buildModernMenuItem(
                    icon: Icons.receipt_long,
                    text: 'Lịch sử giao dịch',
                    iconColor: AppColors.primaryColorIconDetail,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PaymentHistoryView(),
                        ),
                      );
                    },
                  ),
                  _buildModernMenuItem(
                    icon: Icons.article_outlined,
                    text: 'Bài đăng của tôi',
                    iconColor: AppColors.primaryColorIconDetail,
                    onTap: () {
                      Navigator.pop(context);
                      AppNavigator.goToPosts(context);
                    },
                  ),
                  _buildModernMenuItem(
                    icon: Icons.chat_bubble_outline_rounded,
                    text: 'Bình luận gần đây',
                    iconColor: AppColors.primaryColorIconDetail,
                    onTap: () {
                      Navigator.pop(context);
                      AppNavigator.goToComments(context);
                    },
                  ),
                  _buildModernMenuItem(
                    icon: Icons.bookmark_border_rounded,
                    text: 'Tin tức đã lưu',
                    iconColor: AppColors.primaryColorIconDetail,
                    onTap: () {
                      Navigator.pop(context);
                      AppNavigator.goToNewsSave(context);
                    },
                  ),

                  // Hỗ trợ Section
                  _buildSectionHeader('HỖ TRỢ'),
                  _buildModernMenuItem(
                    icon: Icons.info_outline_rounded,
                    text: 'Về chúng tôi',
                    iconColor: AppColors.primaryColorIconDetail,
                    onTap: () {
                      Navigator.pop(context);
                      AppNavigator.goToAboutUs(context);
                    },
                  ),
                  _buildModernMenuItem(
                    icon: Icons.feedback_outlined,
                    text: 'Góp ý & Phản hồi',
                    iconColor: AppColors.primaryColorIconDetail,
                    onTap: () {
                      Navigator.pop(context);
                      AppNavigator.goToresponUser(context);
                    },
                  ),

                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Divider(color: Colors.grey[300], height: 1),
                  ),
                  const SizedBox(height: 8),

                  _buildModernMenuItem(
                    icon: Icons.logout_rounded,
                    text: 'Đăng xuất',
                    iconColor: Colors.red[600]!,
                    textColor: Colors.red[600]!,
                    onTap: () {
                      Navigator.pop(context);
                      _showLogoutDialog(context, authViewModel);
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.grey[600],
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildModernMenuItem({
    required IconData icon,
    required String text,
    required Color iconColor,
    Color? textColor,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(

                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: textColor ?? const Color(0xFF1A1A1A),
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                if (trailing != null)
                  trailing
                else
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.grey[400],
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.red[500],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        count,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, AuthViewModel authViewModel) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Xác nhận đăng xuất'),
          content: const Text('Bạn có chắc chắn muốn đăng xuất?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () {
                authViewModel.logout();
                Navigator.pop(context);
                if (authViewModel.errorMessage == null) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(authViewModel.errorMessage!),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text(
                'Đăng xuất',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBannerSlider() {
    if (isLoadingBanners) {
      return Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.22,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      );
    }

    if (banners.isEmpty) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.22,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Image.asset(
            'assets/img/banner.jpg',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: Colors.grey[300],
              child:
              const Icon(Icons.broken_image, size: 50, color: Colors.grey),
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        Container(
          height: MediaQuery.of(context).size.height * 0.22,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
          ),
          child: PageView.builder(
            controller: _bannerController,
            onPageChanged: (index) {
              _currentBannerIndex.value = index;
            },
            itemCount: banners.length,
            itemBuilder: (context, index) {
              final banner = banners[index];
              final fullImageUrl = _getBannerImageUrl(banner.imageUrl);

              return GestureDetector(
                onTap: () {
                  if (banner.link != null && banner.link!.isNotEmpty) {
                    debugPrint('Banner link: ${banner.link}');
                  }
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: fullImageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Shimmer.fromColors(
                          baseColor: Colors.grey[300]!,
                          highlightColor: Colors.grey[100]!,
                          child: Container(color: Colors.white),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[300],
                          child: const Icon(Icons.broken_image,
                              size: 50, color: Colors.grey),
                        ),
                      ),
                      if (banner.title.isNotEmpty)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  Colors.black.withOpacity(0.8),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  banner.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (banner.description.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    banner.description,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.85),
                                      fontSize: 11,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ]
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Positioned(
          bottom: 10,
          left: 0,
          right: 0,
          child: ValueListenableBuilder<int>(
            valueListenable: _currentBannerIndex,
            builder: (context, currentIndex, child) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  banners.length,
                      (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: currentIndex == index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: currentIndex == index
                          ? Colors.white
                          : Colors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFavoriteShimmer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(width: 240, height: 24, color: Colors.white),
        ),
        const SizedBox(height: 16),
        Column(
          children: List.generate(
              2,
                  (_) => const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: RentalItemShimmer())),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildFavoriteSection() {
    return Consumer<FavoriteViewModel>(
      builder: (context, favoriteViewModel, child) {
        final favorites = favoriteViewModel.favorites;
        final isLoading = favoriteViewModel.isListLoading;

        if (isLoading && favorites.isEmpty) return _buildFavoriteShimmer();
        if (favorites.isEmpty) return const SizedBox.shrink();

        final recentFavorites = favorites.toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final displayItems = recentFavorites.take(2).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Bài viết đã lưu gần đây',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
                TextButton(
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const FavoriteView())),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('Xem tất cả',
                        style:
                        TextStyle(fontSize: 14, color: Colors.blue[700])),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward,
                        size: 14, color: Colors.blue[700]),
                  ]),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: displayItems.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final fav = displayItems[index];
                return FutureBuilder<Rental?>(
                  future: fav.rental != null
                      ? Future.value(fav.rental)
                      : RentalService().fetchRentalById(
                    rentalId: fav.rentalId,
                    token:
                    Provider.of<AuthViewModel>(context, listen: false)
                        .currentUser
                        ?.token ??
                        '',
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting)
                      return const RentalItemShimmer();
                    if (!snapshot.hasData || snapshot.data == null)
                      return const SizedBox.shrink();
                    return GestureDetector(
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  RentalDetailScreen(rental: snapshot.data!))),
                      child: RentalFavoriteWidget(
                        rental: snapshot.data!,
                        showFavoriteButton: false,
                        showCheckbox: false,
                        isSelected: false,
                        onSelectChanged: (bool) {},
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  Widget _buildLatestPostsSection() {
    final rentalViewModel = Provider.of<RentalViewModel>(context, listen: true);
    final filteredRentals = getFilteredLatestRentals(rentalViewModel);
    final hasActiveFilter = filter.hasActiveFilter;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Bài đăng mới nhất',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87)),
            TextButton(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AllLatestPostsScreen())),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('Xem tất cả',
                    style: TextStyle(fontSize: 14, color: Colors.blue[700])),
                const SizedBox(width: 4),
                Icon(Icons.arrow_forward, size: 14, color: Colors.blue[700]),
              ]),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          color: Colors.grey[50],
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [Colors.blue[600]!, Colors.blue[800]!]),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.tune_rounded,
                        color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    const Text("Bộ lọc",
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                    if (hasActiveFilter) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(10)),
                        child: const Text("●",
                            style:
                            TextStyle(color: Colors.white, fontSize: 10)),
                      ),
                    ],
                  ]),
                ),
                const SizedBox(width: 14),
                _buildFilterChip(
                  icon: Icons.location_on_outlined,
                  title: 'Tỉnh/Thành phố',
                  value: filter.selectedProvince?['name'] ?? 'Tỉnh/TP',
                  color: Colors.indigo,
                  onTap: () =>
                      _showFilterSheet('province', 'Chọn Tỉnh/Thành phố'),
                ),
                const SizedBox(width: 12),
                _buildFilterChip(
                  icon: Icons.home_outlined,
                  title: 'Loại nhà',
                  value: filter.selectedPropertyType,
                  color: Colors.teal,
                  onTap: () => _showFilterSheet('property', 'Chọn Loại nhà'),
                ),
                const SizedBox(width: 12),
                _buildFilterChip(
                  icon: Icons.space_dashboard_outlined,
                  title: 'Diện tích',
                  value: filter.selectedAreaRange ?? 'Diện tích',
                  color: Colors.orange,
                  onTap: () => _showFilterSheet('area', 'Chọn Diện tích'),
                ),
                const SizedBox(width: 12),
                _buildFilterChip(
                  icon: Icons.attach_money_outlined,
                  title: 'Mức giá',
                  value: filter.selectedPriceRange ?? 'Mức giá',
                  color: Colors.green,
                  onTap: () => _showFilterSheet('price', 'Chọn Mức giá'),
                ),
              ],
            ),
          ),
        ),
        if (hasActiveFilter)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: clearAllFilters,
              child: const Text('Xóa bộ lọc',
                  style: TextStyle(
                      color: Colors.redAccent, fontWeight: FontWeight.w600)),
            ),
          ),
        const SizedBox(height: 10),
        filteredRentals.isEmpty
            ? const Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text('Không có bài đăng phù hợp!',
                style: TextStyle(fontSize: 16, color: Colors.grey)),
          ),
        )
            : SizedBox(
          height: 280,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: filteredRentals.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) =>
                RentalCardHorizontal(rental: filteredRentals[index]),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildFilterChip({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required VoidCallback onTap,
  }) {
    final bool isSelected = value != title &&
        value != 'Tỉnh/TP' &&
        value != 'Diện tích' &&
        value != 'Mức giá' &&
        value != 'Tất cả';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.grey[50],
          border: Border.all(
              color: isSelected ? color : Colors.grey.shade300, width: 1.5),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 20, color: isSelected ? color : Colors.grey[700]),
          const SizedBox(width: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? color : Colors.grey[800])),
          if (isSelected) ...[
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: color),
          ],
        ]),
      ),
    );
  }

  void _showFilterSheet(String type, String sheetTitle) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding:
        EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          builder: (_, controller) => Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Container(
                        width: 50,
                        height: 5,
                        decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(10))),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(sheetTitle,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                        IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context)),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  itemCount: type == 'province'
                      ? provinces.length
                      : type == 'property'
                      ? RentalFilter.propertyTypes.length
                      : type == 'area'
                      ? RentalFilter.areaOptions.length
                      : RentalFilter.priceOptions.length,
                  itemBuilder: (context, index) {
                    dynamic item;
                    String display;

                    if (type == 'province') {
                      item = provinces[index];
                      display = item['name'];
                    } else if (type == 'property') {
                      item = RentalFilter.propertyTypes[index];
                      display = item;
                    } else if (type == 'area') {
                      item = RentalFilter.areaOptions[index];
                      display = item['label'];
                    } else {
                      item = RentalFilter.priceOptions[index];
                      display = item['label'];
                    }

                    final bool isSelected = (type == 'province' &&
                        filter.selectedProvince?['name'] == display) ||
                        (type == 'property' &&
                            filter.selectedPropertyType == display) ||
                        (type == 'area' &&
                            filter.selectedAreaRange == display) ||
                        (type == 'price' &&
                            filter.selectedPriceRange == display);

                    return ListTile(
                      leading: isSelected
                          ? const Icon(Icons.check_circle, color: Colors.blue)
                          : const Icon(Icons.circle_outlined),
                      title:
                      Text(display, style: const TextStyle(fontSize: 16)),
                      onTap: () {
                        setState(() {
                          if (type == 'province') {
                            filter = filter.copyWith(selectedProvince: item);
                          } else if (type == 'property') {
                            filter =
                                filter.copyWith(selectedPropertyType: display);
                          } else if (type == 'area') {
                            filter =
                                filter.copyWith(selectedAreaRange: display);
                          } else if (type == 'price') {
                            filter =
                                filter.copyWith(selectedPriceRange: display);
                          }
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      period: const Duration(milliseconds: 1000),
      child: Column(
        children: [
          Container(
              height: 50,
              width: double.infinity,
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12))),
          const SizedBox(height: 20),
          Container(
              height: MediaQuery.of(context).size.height * 0.22,
              width: double.infinity,
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15))),
          const SizedBox(height: 20),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 3,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, __) => Container(
                height: 120,
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rentalViewModel = Provider.of<RentalViewModel>(context, listen: true);
    final authViewModel = Provider.of<AuthViewModel>(context);

    final AppUser? user = authViewModel.currentUser;


    final location = user?.address ?? 'Nguyễn Văn Cừ nối dài - TP - Cần Thơ';
    final username = user?.username ?? 'Người dùng';

    final propertyTypes = [
      'Căn hộ chung cư',
      'Nhà riêng',
      'Nhà trọ/Phòng trọ',
      'Biệt thự',
      'Văn phòng',
      'Mặt bằng kinh doanh',
      'Đất nền',
    ];

    final propertyIcons = [
      Icons.apartment,
      Icons.house,
      Icons.meeting_room,
      Icons.villa,
      Icons.business,
      Icons.storefront,
      Icons.terrain,
    ];

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.grey[50],
      drawer: _buildDrawer(context, authViewModel),
      drawerEdgeDragWidth: 0,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.location_on,
                              color: Colors.blue[700], size: 28),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Vị trí của bạn - $username',
                                    style: TextStyle(
                                        color: Colors.grey[600], fontSize: 12)),
                                Text(location,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Colors.black87),
                                    overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _scaffoldKey.currentState?.openDrawer(),
                      child: CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.grey[200],
                        child: user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty
                            ? ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: user.avatarUrl!,
                            fit: BoxFit.cover,
                            width: 48,
                            height: 48,
                            placeholder: (context, url) =>
                            const CircularProgressIndicator(),
                            errorWidget: (context, url, error) =>
                                Image.asset('assets/img/imageuser.png'),
                          ),
                        )
                            : Image.asset('assets/img/imageuser.png'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Nhập thông tin tìm kiếm...',
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ICON CHUYỂN TRANG TÌM KIẾM ===============================
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SearchScreen()),
                          ),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue[700],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.tune, color: Colors.white, size: 25),
                          ),
                        ),
                        // ICON XEM THỐNG KÊ ==========================================
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) =>const AnalyticsScreen()),
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue[700],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.analytics,
                              color: Colors.white,
                              size: 25,
                            ),
                          ),
                        ),
                        // ICON MỞ MAP THEO VỊ TRÍ TÀI KHON HIỆN TẠI ===============================
                        GestureDetector(
                          onTap: () {
                            //  Hiển thị loading dialog
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (BuildContext dialogContext) {
                                return Dialog(
                                  backgroundColor: Colors.transparent,
                                  elevation: 0,
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.all(20),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Loading animation
                                          Lottie.asset(
                                            AssetsConfig.loadingLottie,
                                            width: 80,
                                            height: 80,
                                            fit: BoxFit.fill,
                                          ),
                                          const SizedBox(height: 16),
                                          // Loading text
                                          const Text(
                                            'Đang mở bản đồ',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          // Subtext
                                          Text(
                                            'Vui lòng đợi...',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );

                            //  Lấy vị trí hiện tại từ device
                            _getCurrentLocationAndNavigateToMap();
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue[700],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.map_outlined,
                              color: Colors.white,
                              size: 25,
                            ),
                          ),
                        )

                        // ============================================================
                      ],
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  ),
                  onSubmitted: (value) {
                    if (value.trim().isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SearchScreen(initialSearchQuery: value),
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(height: 25),
                _buildBannerSlider(),
                const SizedBox(height: 20),
                Container(

                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1.2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 5),
                  child: SizedBox(
                    height: 155,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: List.generate(
                              3,
                                  (i) => _buildCategoryItem(
                                propertyIcons[i],
                                propertyTypes[i],
                                context,
                                propertyTypes[i],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: List.generate(
                              3,
                                  (i) => _buildCategoryItem(
                                propertyIcons[i + 4],
                                propertyTypes[i + 4],
                                context,
                                propertyTypes[i + 4],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (authViewModel.currentUser != null) _buildFavoriteSection(),
                _buildAIRecommendationsSection(),
                if (authViewModel.currentUser == null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 50),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.lock_outline,
                              size: 60, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          const Text('Vui lòng đăng nhập để xem bài đăng',
                              style:
                              TextStyle(fontSize: 16, color: Colors.grey)),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[700],
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 32, vertical: 14)),
                            onPressed: () => Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const LoginScreen())),
                            child: const Text('Đăng Nhập Ngay',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 16)),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (rentalViewModel.isLoading)
                  _buildShimmerLoading()
                else if (rentalViewModel.errorMessage != null)
                    Center(
                        child: Text('Lỗi: ${rentalViewModel.errorMessage}',
                            style: const TextStyle(color: Colors.red)))
                  else
                    _buildLatestPostsSection(),
                const NewsHighlightSection(),
              ],
            ),
          ),
        ),
      ),
      // ========================= NÚT CHAT AI ======================================
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          RawMaterialButton(
            onPressed: () {
              final apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';

              if (apiKey.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('API Key không tồn tại!')),
                );
                return;
              }

              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
                ),
                builder: (_) => ChatAIBottomSheet(apiKey: ApiRoutes.openAIApiKey),
              );
            },
            constraints: const BoxConstraints.tightFor(width: 145, height: 145),
            shape: const CircleBorder(),
            child: ClipOval(
              child: Image.asset(
                'assets/img/chatbox.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.broken_image,
                  size: 40,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
        ],
      ),
      // ==========================================================================
    );
  }


  Widget _buildCategoryItem(
      IconData icon, String label, BuildContext context, String propertyType) {
    return Container(
      margin: const EdgeInsets.only(right: 14),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200, width: 1.2),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      PropertyTypeScreen(propertyType: propertyType))),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: Colors.blue.shade700, size: 22),
              ),
              const SizedBox(width: 10),
              Text(label,
                  style: const TextStyle(
                      color: Color(0xFF2D3436),
                      fontSize: 14.3,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
// ======================== Rental Card Placeholder =============================
class RentalCardPlaceholder extends StatelessWidget {
  const RentalCardPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 150,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  height: 16,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 8),
                Container(
                  width: 120,
                  height: 14,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 8),
                Container(
                  width: 200,
                  height: 12,
                  color: Colors.grey[300],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
