import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/Widgets/item_menu_profile.dart';
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
  Widget build(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Center(
          child: Text(
            'Hồ sơ người dùng',
            style: TextStyle(color: Colors.black),
          ),
        ),
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
                backgroundImage: NetworkImage(
                    'https://www.gstatic.com/flutter-onestack-prototype/genui/example_1.jpg'), // Replace with your image URL
              ),
              SizedBox(height: 16),
              Text('Ronald Richards',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text('ronaldrichards@gmail.com', style: TextStyle(color: Colors.grey)),
              SizedBox(height: 24),
              ProfileMenuItem(
                icon: Icons.person_outline,
                text: 'Thông tin cá nhân',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => MyProfileView()),
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
                text: 'Danh sách bài viết',
                onTap: () {
                  // Handle My Cards tap
                },
              ),
              ProfileMenuItem(
                icon: Icons.settings_outlined,
                text: 'Cài đặt',
                onTap: () {
                  // Handle Settings tap
                },
              ),
              ProfileMenuItem(
                icon: Icons.logout,
                text: 'Đăng xuất',
                onTap: ()  {
                   authViewModel.logout();
                   if (authViewModel.errorMessage == null) {
                     Navigator.pushReplacement(
                       context,
                       MaterialPageRoute(builder: (context) => const LoginScreen()),
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
  }
}
