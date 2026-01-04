import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/config/api_routes.dart';
import 'package:flutter_rentalhouse/config/loading.dart';
import 'package:flutter_rentalhouse/views/Admin/View/AdminProfileScreen.dart';
import 'package:flutter_rentalhouse/views/Admin/View/ManageBannersScreen.dart';
import 'package:flutter_rentalhouse/views/Admin/View/ManageFeedbackScreen.dart';
import 'package:flutter_rentalhouse/views/Admin/View/ManageNewsScreen.dart';
import 'package:flutter_rentalhouse/views/Admin/View/ManagePostsScreen.dart';
import 'package:flutter_rentalhouse/views/Admin/View/ManageUsersScreen.dart';
import 'package:flutter_rentalhouse/views/ManageAboutUsScreen.dart';
import 'package:flutter_rentalhouse/views/my_profile_view.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_auth.dart';
import 'package:flutter_rentalhouse/services/auth_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _isLoading = true;
  String? _error;

  final AuthService _authService = AuthService();

  Map<String, dynamic> dashboardData = {
    'totalPosts': 0,
    'postsToday': 0,
    'newUsers': 0,
    'totalNews': 0,
    'revenueToday': 0,
    'totalRevenue': 0,
    'feedbackToday': 0,
    'lastUpdated': null,
  };

  @override
  void initState() {
    super.initState();
    _initializeLocale();
    _fetchDashboardData();
  }

  Future<void> _initializeLocale() async {
    try {
      await initializeDateFormatting('vi_VN', null);
    } catch (e) {
      print('Error initializing locale: $e');
    }
  }

  Future<void> _fetchDashboardData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = await _authService.getIdToken();

      if (token == null) {
        throw Exception('Không tìm thấy token xác thực');
      }

      final response = await http.get(
        Uri.parse(ApiRoutes.adminDashboard),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          dashboardData = {
            'totalPosts': data['totalPosts'] ?? 0,
            'postsToday': data['postsToday'] ?? 0,
            'newUsers': data['newUsers'] ?? 0,
            'totalNews': data['totalNews'] ?? 0,
            'revenueToday': data['revenueToday'] ?? 0,
            'totalRevenue': data['totalRevenue'] ?? 0,
            'feedbackToday': data['feedbackToday'] ?? 0,
            'lastUpdated': data['lastUpdated'],
          };
          _isLoading = false;
        });
      } else if (response.statusCode == 401) {
        throw Exception('Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại');
      } else if (response.statusCode == 403) {
        throw Exception('Bạn không có quyền truy cập');
      } else {
        throw Exception('Lỗi tải dữ liệu: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_error ?? 'Có lỗi xảy ra'),
            backgroundColor: Colors.grey[800],
            action: SnackBarAction(
              label: 'Thử lại',
              textColor: Colors.white,
              onPressed: _fetchDashboardData,
            ),
          ),
        );
      }

      print('Error fetching dashboard data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthViewModel>(context).currentUser;

    String formattedToday = '';
    try {
      formattedToday = DateFormat('EEEE, dd/MM/yyyy', 'vi_VN').format(DateTime.now());
    } catch (e) {
      formattedToday = DateFormat('dd/MM/yyyy').format(DateTime.now());
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      body: _isLoading
          ?  Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              AssetsConfig.loadingLottie,
              width: 80,
              height: 80,
              fit: BoxFit.fill,
            ),
          SizedBox(height: 16),
          Text(
            'Đang tải dữ liệu...',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),)
          ],
        )
      )
          : _error != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 80,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 24),
              Text(
                'Có lỗi xảy ra',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _fetchDashboardData,
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      )
          : RefreshIndicator(
        onRefresh: _fetchDashboardData,
        color: const Color(0xFF4F46E5),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // Header Section
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                // Avatar
                                  InkWell(
                                  borderRadius: BorderRadius.circular(44),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const MyProfileView(),
                                    settings: const RouteSettings(arguments: true),
                                  ),
                                );
                              },
                              child: AdminAvatar(
                                user: user,
                                radius: 44,
                              ),
                            ),
                             const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Xin chào, ${user?.username ?? 'Admin'}',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF1F2937),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        user?.email ?? 'admin@system.com',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF4F46E5).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'Quản trị viên',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF4F46E5),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh_rounded),
                            tooltip: 'Làm mới dữ liệu',
                            onPressed: _isLoading ? null : _fetchDashboardData,
                            color: const Color(0xFF4F46E5),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        formattedToday,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Stats Grid
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Row 1
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const ManagePostsScreen(), // trang cần điều hướng
                                ),
                              );
                            },
                            child: _statCard(
                              'Tổng bài đăng',
                              '${dashboardData['totalPosts']}',
                              Icons.home_work_rounded,
                              const Color(0xFF4F46E5),
                              0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _statCard(
                            'Hôm nay',
                            '${dashboardData['postsToday']}',
                            Icons.post_add_rounded,
                            const Color(0xFF3B82F6),
                            1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Row 2
                    Row(
                      children: [
                        Expanded(
                          child: _statCard(
                            'Người dùng mới',
                            '${dashboardData['newUsers']}',
                            Icons.person_add_rounded,
                            const Color(0xFF06B6D4),
                            2,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const ManageNewsScreen(), // trang cần điều hướng
                                ),
                              );
                            },
                            child: _statCard(
                              'Tin tức',
                              '${dashboardData['totalNews']}',
                              Icons.article_rounded,
                              const Color(0xFF8B5CF6),
                              3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Row 3 - Revenue
                    Row(
                      children: [
                        Expanded(
                          child: _revenueCard(
                            'Doanh thu hôm nay',
                            dashboardData['revenueToday'] as int,
                            const Color(0xFF10B981),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _revenueCard(
                            'Tổng doanh thu',
                            dashboardData['totalRevenue'] as int,
                            const Color(0xFFF59E0B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Row 4 - Feedback
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ManageFeedbackScreen(), // trang cần điều hướng
                          ),
                        );
                      },
                      child: _feedbackCard(
                        'Phản hồi hôm nay',
                        '${dashboardData['feedbackToday']}',
                        Icons.feedback_rounded,
                        const Color(0xFF14B8A6),
                      ),
                    ),
                  ],
                ),
              ),

              // Management Section
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quản lý',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _managementGrid(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _managementGrid() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _managementCard(
          'Bài đăng',
          Icons.article_rounded,
          const Color(0xFF4F46E5),
              () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ManagePostsScreen()),
          ),
        ),
        _managementCard(
          'Người dùng',
          Icons.people_rounded,
          const Color(0xFF3B82F6),
              () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ManageUsersScreen()),
          ),
        ),
        _managementCard(
          'Tin tức',
          Icons.newspaper_rounded,
          const Color(0xFF8B5CF6),
              () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ManageNewsScreen()),
          ),
        ),
        _managementCard(
          'Phản hồi',
          Icons.feedback_rounded,
          const Color(0xFFF59E0B),
              () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ManageFeedbackScreen()),
          ),
        ),
        _managementCard(
          'Banner',
          Icons.image_rounded,
          const Color(0xFF06B6D4),
              () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ManageBannersScreen()),
          ),
        ),
        _managementCard(
          'Giới thiệu',
          Icons.description_rounded,
          const Color(0xFF14B8A6),
              () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ManageAboutUsScreen()),
          ),
        ),
      ],
    );
  }

  Widget _managementCard(
      String title,
      IconData icon,
      Color color,
      VoidCallback onTap,
      ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.grey.shade200,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(
      String title,
      String value,
      IconData icon,
      Color color,
      int index,
      ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _revenueCard(String title, int amount, Color color) {
    final formatter = NumberFormat('#,###', 'vi_VN');
    final formattedAmount = formatter.format(amount);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.trending_up_rounded, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            formattedAmount,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '₫',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[500],
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _feedbackCard(
      String title,
      String value,
      IconData icon,
      Color color,
      ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 32, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(String? isoString) {
    if (isoString == null) return '';
    try {
      final dateTime = DateTime.parse(isoString);
      return DateFormat('HH:mm - dd/MM/yyyy').format(dateTime);
    } catch (e) {
      return '';
    }
  }
}