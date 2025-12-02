
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/models/user.dart';
import 'package:flutter_rentalhouse/views/Admin/View/ManageBannersScreen.dart';
import 'package:flutter_rentalhouse/views/Admin/View/ManageFeedbackScreen.dart';
import 'package:flutter_rentalhouse/views/Admin/View/ManageNewsScreen.dart';
import 'package:flutter_rentalhouse/views/Admin/View/ManagePostsScreen.dart';
import 'package:flutter_rentalhouse/views/Admin/View/ManageUsersScreen.dart';
import 'package:flutter_rentalhouse/views/ManageAboutUsScreen.dart';
import 'package:flutter_rentalhouse/views/UserFeedbackScreen%20.dart';
import 'package:flutter_rentalhouse/views/my_profile_view.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_auth.dart';

class HomeAdminScreen extends StatefulWidget {
  const HomeAdminScreen({super.key});

  @override
  State<HomeAdminScreen> createState() => _HomeAdminScreenState();
}

class _HomeAdminScreenState extends State<HomeAdminScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context);
    final user = authViewModel.currentUser;

    final List<Widget> _pages = [
      const DashboardOverview(),
      ProfileAdminScreen(user: user),
    ];

    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: Colors.redAccent,
        unselectedItemColor: Colors.grey.shade600,
        backgroundColor: Colors.white,
        elevation: 12,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.dashboard), label: 'Tổng quan'),
          BottomNavigationBarItem(
              icon: Icon(Icons.admin_panel_settings), label: 'Quản lý'),
        ],
      ),
    );
  }
}

// Hàm xử lý ảnh avatar
ImageProvider getAvatarProvider(String? avatarUrl) {
  if (avatarUrl != null && avatarUrl.isNotEmpty && avatarUrl.contains(',')) {
    try {
      final base64String = avatarUrl.split(',').last;
      final bytes = base64Decode(base64String);
      return MemoryImage(bytes);
    } catch (e) {
      return const AssetImage('assets/images/admin_avatar.png');
    }
  }
  return const AssetImage('assets/images/admin_avatar.png');
}

// Widget Avatar Admin
class AdminAvatar extends StatelessWidget {
  final AppUser? user;
  final double radius;
  const AdminAvatar({super.key, required this.user, this.radius = 35});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.white,
      backgroundImage: getAvatarProvider(user?.avatarUrl),
      child: user?.avatarUrl == null
          ? Icon(Icons.admin_panel_settings,
          size: radius * 1.2, color: Colors.redAccent)
          : null,
    );
  }
}

// Dashboard Overview
class DashboardOverview extends StatelessWidget {
  const DashboardOverview({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthViewModel>(context).currentUser;
    final today = DateFormat('dd/MM/yyyy').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tổng quan Quản trị'),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.redAccent, Colors.deepOrangeAccent],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Card(
                elevation: 12,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      AdminAvatar(user: user, radius: 42),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Xin chào, ${user?.username ?? 'Admin'}!',
                              style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87),
                            ),
                            const SizedBox(height: 4),
                            Text('Hôm nay: $today',
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 15)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  children: [
                    _statCard(
                        'Bài đăng hôm nay', '0', Icons.post_add, Colors.orange),
                    _statCard(
                        'Người dùng mới', '0', Icons.person_add, Colors.green),
                    _statCard(
                        'Tổng bài đăng', '0', Icons.home_work, Colors.blue),
                    _statCard(
                        'Tin tức đã đăng', '0', Icons.article, Colors.purple),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ManagePostsScreen())),
                icon: const Icon(Icons.warning_amber_rounded, size: 28),
                label: const Text('Xem bài đăng vi phạm',
                    style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  padding:
                  const EdgeInsets.symmetric(vertical: 18, horizontal: 32),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
              colors: [color.withOpacity(0.9), color],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: Colors.white),
            const SizedBox(height: 12),
            Text(value,
                style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const SizedBox(height: 6),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}

// Admin Management Screen
class ProfileAdminScreen extends StatelessWidget {
  final AppUser? user;
  const ProfileAdminScreen({super.key, this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý hệ thống'),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Thông tin Admin
          Card(
            elevation: 8,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: ListTile(
              leading: AdminAvatar(user: user, radius: 36),
              title: Text(user?.username ?? 'Quản trị viên',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              subtitle: Text(user?.email ?? 'admin@system.com',
                  style: const TextStyle(fontSize: 14)),
              trailing: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.admin_panel_settings,
                    color: Colors.white, size: 28),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Thông tin cá nhân (nổi bật)
          Card(
            elevation: 10,
            color: Colors.red.shade50,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Colors.redAccent, width: 2)),
            child: ListTile(
              leading: const CircleAvatar(
                  backgroundColor: Colors.redAccent,
                  child: Icon(Icons.person, color: Colors.white, size: 28)),
              title: const Text('Thông tin cá nhân',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.redAccent)),
              subtitle: const Text('Xem và chỉnh sửa hồ sơ Admin',
                  style: TextStyle(color: Colors.black87)),
              trailing:
              const Icon(Icons.arrow_forward_ios, color: Colors.redAccent),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MyProfileView(),
                    settings:
                    const RouteSettings(arguments: true), // từ admin
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          // ✅ VIẾT NỘI DUNG GIỚI THIỆU (MỚI)
          _menuItem(
              context,
              'Viết nội dung giới thiệu',
              Icons.description,
              Colors.indigo,
                  () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ManageAboutUsScreen()))),

          // ✅ GÓP Ý / PHẢN HỒI (MỚI)
          _menuItem(
              context,
              'Góp ý / Phản hồi người dùng',
              Icons.feedback,
              Colors.amber,
                  () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ManageFeedbackScreen()))),

          _menuItem(
              context,
              'Quản lý bài đăng',
              Icons.article_outlined,
              Colors.orangeAccent,
                  () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ManagePostsScreen()))),

          _menuItem(
              context,
              'Quản lý người dùng',
              Icons.people_alt_rounded,
              Colors.green,
                  () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ManageUsersScreen()))),

          _menuItem(
              context,
              'Quản lý Banner quảng cáo',
              Icons.image_search,
              Colors.blue,
                  () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ManageBannersScreen()))),

          _menuItem(
              context,
              'Quản lý tin tức',
              Icons.newspaper,
              Colors.purple,
                  () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ManageNewsScreen()))),

          const SizedBox(height: 40),
          ElevatedButton.icon(
            onPressed: () => _showLogoutDialog(context),
            icon: const Icon(Icons.logout_rounded, size: 28),
            label: const Text('Đăng xuất',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuItem(BuildContext context, String title, IconData icon,
      Color color, VoidCallback onTap) {
    return Card(
      elevation: 6,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ListTile(
        leading: CircleAvatar(
            backgroundColor: color, child: Icon(icon, color: Colors.white)),
        title: Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Đăng xuất',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Bạn có chắc muốn đăng xuất khỏi tài khoản Admin?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Provider.of<AuthViewModel>(context, listen: false).logout();
              Navigator.pushNamedAndRemoveUntil(
                  context, '/login', (route) => false);
            },
            child:
            const Text('Đăng xuất', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

