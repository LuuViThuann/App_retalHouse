import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/models/user.dart';
import 'package:flutter_rentalhouse/views/Admin/View/ManageBannersScreen.dart';
import 'package:flutter_rentalhouse/views/Admin/View/ManageFeedbackScreen.dart';
import 'package:flutter_rentalhouse/views/Admin/View/ManageNewsScreen.dart';
import 'package:flutter_rentalhouse/views/Admin/View/ManagePostsScreen.dart';
import 'package:flutter_rentalhouse/views/Admin/View/ManageUsersScreen.dart';
import 'package:flutter_rentalhouse/views/ManageAboutUsScreen.dart';
import 'package:flutter_rentalhouse/views/my_profile_view.dart';
import 'package:provider/provider.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_auth.dart';

// ✅ Hàm xử lý avatar từ Cloudinary và Base64
ImageProvider getAvatarProvider(String? avatarUrl) {
  if (avatarUrl == null || avatarUrl.isEmpty) {
    return const AssetImage('assets/images/admin_avatar.png');
  }

  // ✅ Nếu là URL Cloudinary
  if (avatarUrl.contains('cloudinary.com') ||
      avatarUrl.contains('res.cloudinary.com')) {
    return NetworkImage(avatarUrl);
  }

  // ✅ Nếu là Base64
  if (avatarUrl.contains(',')) {
    try {
      final base64String = avatarUrl.split(',').last;
      final bytes = base64Decode(base64String);
      return MemoryImage(bytes);
    } catch (e) {
      debugPrint('❌ Base64 decode error: $e');
      return const AssetImage('assets/images/admin_avatar.png');
    }
  }

  // ✅ Nếu là đường dẫn tương đối từ server
  return AssetImage(avatarUrl);
}

// ✅ Widget Avatar Admin với loading state
class AdminAvatar extends StatelessWidget {
  final AppUser? user;
  final double radius;
  final bool showBorder;

  const AdminAvatar({
    super.key,
    required this.user,
    this.radius = 35,
    this.showBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    final avatarProvider = getAvatarProvider(user?.avatarUrl);

    return Container(
      decoration: showBorder
          ? BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFFDC2626),
          width: 3,
        ),
      )
          : null,
      child: CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey[200],
        backgroundImage: avatarProvider is NetworkImage
            ? avatarProvider
            : avatarProvider is MemoryImage
            ? avatarProvider
            : null,
        child: avatarProvider is! NetworkImage && avatarProvider is! MemoryImage
            ? Icon(
          Icons.admin_panel_settings_rounded,
          size: radius * 1.2,
          color: const Color(0xFFDC2626),
        )
            : null,
        onBackgroundImageError: (exception, stackTrace) {
          debugPrint('❌ Avatar load error: $exception');
        },
      ),
    );
  }
}

// ✅ Admin Profile & Management Screen
class AdminProfileScreen extends StatelessWidget {
  final AppUser? user;

  const AdminProfileScreen({super.key, this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'Hồ sơ & Quản lý',
          style: TextStyle(
            color: Color(0xFF1F2937),
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        foregroundColor: const Color(0xFF1F2937),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ✅ Admin Info Card - Thông tin quản trị viên
          Container(
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
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                AdminAvatar(user: user, radius: 44, showBorder: true),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.username ?? 'Quản trị viên',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.email ?? 'admin@system.com',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Quản trị viên hệ thống',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ✅ Profile Section
          _buildMenuSection(
            context,
            'Cài đặt',
            [
              _menuItem(
                context,
                'Thông tin cá nhân',
                Icons.person_rounded,
                const Color(0xFFDC2626),
                    () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MyProfileView(),
                      settings: const RouteSettings(arguments: true),
                    ),
                  );
                },
              ),
            ],
          ),

          // ✅ Content Management Section
          _buildMenuSection(
            context,
            'Quản lý nội dung',
            [
              _menuItem(
                context,
                'Viết nội dung giới thiệu',
                Icons.description_rounded,
                const Color(0xFF4F46E5),
                    () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ManageAboutUsScreen(),
                  ),
                ),
              ),
              _menuItem(
                context,
                'Góp ý / Phản hồi người dùng',
                Icons.feedback_rounded,
                const Color(0xFFF59E0B),
                    () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ManageFeedbackScreen(),
                  ),
                ),
              ),
              _menuItem(
                context,
                'Quản lý bài đăng',
                Icons.article_rounded,
                const Color(0xFFF97316),
                    () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ManagePostsScreen(),
                  ),
                ),
              ),
              _menuItem(
                context,
                'Quản lý tin tức',
                Icons.newspaper_rounded,
                const Color(0xFF8B5CF6),
                    () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ManageNewsScreen(),
                  ),
                ),
              ),
              _menuItem(
                context,
                'Quản lý Banner quảng cáo',
                Icons.image_rounded,
                const Color(0xFF3B82F6),
                    () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ManageBannersScreen(),
                  ),
                ),
              ),
            ],
          ),

          // ✅ User Management Section
          _buildMenuSection(
            context,
            'Quản lý người dùng',
            [
              _menuItem(
                context,
                'Quản lý tài khoản',
                Icons.people_rounded,
                const Color(0xFF10B981),
                    () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ManageUsersScreen(),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ✅ Logout Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showLogoutDialog(context),
              icon: const Icon(Icons.logout_rounded, size: 22),
              label: const Text(
                'Đăng xuất',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildMenuSection(
      BuildContext context,
      String title,
      List<Widget> items,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B7280),
              letterSpacing: 0.5,
            ),
          ),
        ),
        ...items,
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _menuItem(
      BuildContext context,
      String title,
      IconData icon,
      Color color,
      VoidCallback onTap,
      ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: Color(0xFFDC2626),
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Đăng xuất',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Bạn có chắc muốn đăng xuất khỏi tài khoản Admin?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(_),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        'Hủy',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Provider.of<AuthViewModel>(context, listen: false)
                            .logout();
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/login',
                              (route) => false,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Đăng xuất',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}