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

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
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
                  SizedBox(height: 20),
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: avatarImage,
                  ),
                  SizedBox(height: 16),
                  Text(
                    user.username ?? 'Tên người dùng',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    user.email ?? 'Email@gmail.com',
                    style: TextStyle(color: Colors.grey),
                  ),
                  SizedBox(height: 24),
                  ProfileMenuItem(
                    icon: Icons.person_outline,
                    text: 'Thông tin cá nhân',
                    onTap: () => AppNavigator.goToProfile(context),
                  ),
                  ProfileMenuItem(
                      icon: Icons.notifications_paused,
                      text: 'Thông báo gần đây',
                      onTap: () => AppNavigator.goToNotification(context)),
                  ProfileMenuItem(
                      icon: Icons.newspaper,
                      text: 'Tin tức đã lưu',
                      onTap: () => AppNavigator.goToNewsSave(context)),
                  ProfileMenuItem(
                      icon: Icons.book,
                      text: 'Danh sách bài đăng của bạn',
                      onTap: () => AppNavigator.goToPosts(context)),
                  ProfileMenuItem(
                      icon: Icons.comment,
                      text: 'Bình luận gần đây',
                      onTap: () => AppNavigator.goToComments(context)),
                  ProfileMenuItem(
                      icon: Icons.password,
                      text: 'Thay đổi mật khẩu',
                      onTap: () => AppNavigator.goToChangePassword(context)),
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
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
