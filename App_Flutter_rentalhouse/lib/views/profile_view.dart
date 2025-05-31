import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/Widgets/Profile/my_post.dart';
import 'package:flutter_rentalhouse/Widgets/Profile/notification_view.dart';
import 'package:flutter_rentalhouse/Widgets/Profile/recent_comment.dart';
import 'package:flutter_rentalhouse/Widgets/item_menu_profile.dart';
import 'package:flutter_rentalhouse/models/user.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_auth.dart';
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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
      if (authViewModel.currentUser == null) {
        // Fetch only if no user data
        authViewModel.fetchCurrentUser();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthViewModel>(
      builder: (context, authViewModel, child) {
        final AppUser? user = authViewModel.currentUser;

        // Use a default image or avatarBase64 if available
        ImageProvider avatarImage =
            const AssetImage('assets/img/imageuser.jpg');
        if (user != null &&
            user.avatarBase64 != null &&
            user.avatarBase64!.isNotEmpty) {
          try {
            final bytes = base64Decode(user.avatarBase64!);
            avatarImage = MemoryImage(bytes);
          } catch (e) {
            print('Error decoding avatarBase64: $e');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Lỗi tải ảnh đại diện: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: Row(
              children: [
                Icon(
                  Icons.person,
                  color: Colors.white,
                ),
                SizedBox(width: 8),
                Text(
                  'Hồ sơ người dùng',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
              ],
            ),
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue, Colors.blueAccent.shade700],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            elevation: 4,
            shadowColor: Colors.black26,
          ),
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
                    user?.username ?? 'Tên người dùng',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    user?.email ?? 'Email@gmail.com',
                    style: TextStyle(color: Colors.grey),
                  ),
                  SizedBox(height: 24),
                  ProfileMenuItem(
                    icon: Icons.person_outline,
                    text: 'Thông tin cá nhân',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => MyProfileView()),
                      );
                    },
                  ),
                  ProfileMenuItem(
                    icon: Icons.shopping_bag_outlined,
                    text: 'Hợp đồng của tôi',
                    onTap: () {
                      // Handle My Orders tap
                    },
                  ),
                  ProfileMenuItem(
                    icon: Icons.book,
                    text: 'Danh sách bài đăng của bạn',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => MyPostsView()),
                      );
                    },
                  ),
                  ProfileMenuItem(
                    icon: Icons.comment,
                    text: 'Bình luận gần đây',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => RecentCommentsView()),
                      );
                    },
                  ),
                  ProfileMenuItem(
                    icon: Icons.notifications,
                    text: 'Thông báo',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => NotificationsView()),
                      );
                    },
                  ),
                  ProfileMenuItem(
                    icon: Icons.password,
                    text: 'Thay đổi mật khẩu',
                    onTap: () {
                      // Handle My Cards tap
                    },
                  ),
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
