import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/Widgets/Profile/my_post.dart';
import 'package:flutter_rentalhouse/Widgets/Profile/notification_view.dart';
import 'package:flutter_rentalhouse/Widgets/Profile/recent_comment.dart';
import 'package:flutter_rentalhouse/Widgets/item_menu_profile.dart';
import 'package:flutter_rentalhouse/config/navigator.dart';
import 'package:flutter_rentalhouse/models/user.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_auth.dart';
import 'package:flutter_rentalhouse/views/change_password_view.dart';
import 'package:flutter_rentalhouse/views/forgot_password.dart';
import 'package:flutter_rentalhouse/views/login_view.dart';
import 'package:flutter_rentalhouse/views/my_profile_view.dart';
import 'package:provider/provider.dart';

import '../Widgets/Profile/PaymentHistoryView.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  // Widget để hiển thị tiêu đề phân loại
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 24, 0, 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.blue[700],
          ),
        ),
      ),
    );
  }

  //  Widget để hiển thị badge kế tiêu đề (giữ giao diện ban đầu)
  Widget _buildMenuItemWithBadge({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
    required int badgeCount,
  }) {
    return Stack(
      children: [
        ProfileMenuItem(
          icon: icon,
          text: text,
          onTap: onTap,
        ),
        //  Badge nhỏ hiển thị kế tiêu đề
        if (badgeCount > 0)
          Positioned(
            right: 0,
            bottom: 28,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                badgeCount > 99 ? '99+' : '$badgeCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthViewModel>(
      builder: (context, authViewModel, child) {
        final AppUser? user = authViewModel.currentUser;

        // Nếu không có user, chuyển hướng về màn hình đăng nhập
        if (user == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            );
          });
          return const SizedBox.shrink();
        }

        //  Tính toán số thông báo chưa đọc
        final unreadNotificationCount = authViewModel.notifications
            .where((notification) => !notification.read)
            .length;

        // Use a default image or avatarBase64 if available
        ImageProvider avatarImage = const AssetImage('assets/img/imageuser.png');
        if (user.avatarUrl != null && user.avatarUrl!.isNotEmpty) {
          avatarImage = NetworkImage(user.avatarUrl!);
        }

        return Scaffold(
          backgroundColor: Colors.white,
          // --------------
          appBar: AppBar(
            backgroundColor: Colors.blue[700],
            elevation: 0,
            title: Text(
              'Hồ sơ người dùng',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 19),
            ),
            leading: IconButton(
              icon: const Icon(Icons.person, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
          ),

          //---------------

          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: avatarImage,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user.username ?? 'Tên người dùng',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    user.email ?? 'Email@gmail.com',
                    style: const TextStyle(color: Colors.grey),
                  ),

                  // ===== PHÂN LOẠI: TÀI KHOẢN =====
                  _buildSectionHeader('Tài Khoản'),
                  ProfileMenuItem(
                    icon: Icons.person_outline,
                    text: 'Thông tin cá nhân',
                    onTap: () => AppNavigator.goToProfile(context),
                  ),
                  ProfileMenuItem(
                    icon: Icons.password,
                    text: 'Thay đổi mật khẩu',
                    onTap: () => AppNavigator.goToChangePassword(context),
                  ),

                  // ===== PHÂN LOẠI: HOẠT ĐỘNG =====
                  _buildSectionHeader('Hoạt Động'),
                  //  Updated: Notification with badge
                  _buildMenuItemWithBadge(
                    icon: Icons.notifications_paused,
                    text: 'Thông báo gần đây',
                    badgeCount: unreadNotificationCount,
                    onTap: () => AppNavigator.goToNotification(context),
                  ),
                  ProfileMenuItem(
                      icon: Icons.newspaper,
                      text: 'Tin tức đã lưu',
                      onTap: () => AppNavigator.goToNewsSave(context)),
                  ProfileMenuItem(
                      icon: Icons.book,
                      text: 'Danh sách bài đăng của bạn',
                      onTap: () => AppNavigator.goToPosts(context)),
                  ProfileMenuItem(
                    icon: Icons.receipt_long,
                    text: 'Lịch sử giao dịch',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PaymentHistoryView(),
                        ),
                      );
                    },
                  ),
                  ProfileMenuItem(
                      icon: Icons.comment,
                      text: 'Bình luận gần đây',
                      onTap: () => AppNavigator.goToComments(context)),

                  // ===== PHÂN LOẠI: HỖ TRỢ =====
                  _buildSectionHeader('Hỗ Trợ'),
                  ProfileMenuItem(
                      icon: Icons.info_outline,
                      text: 'Về chúng tôi',
                      onTap: () => AppNavigator.goToAboutUs(context)),
                  ProfileMenuItem(
                      icon: Icons.send_sharp,
                      text: 'Góp ý / phản hồi',
                      onTap: () => AppNavigator.goToresponUser(context)),
                  ProfileMenuItem(
                    icon: Icons.logout,
                    text: 'Đăng xuất',
                    onTap: () {
                      authViewModel.logout();
                      if (authViewModel.errorMessage == null) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const LoginScreen()),
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
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}