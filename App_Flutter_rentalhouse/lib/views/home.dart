import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_rental.dart';
import 'package:flutter_rentalhouse/views/create_rental_view.dart';
import 'package:flutter_rentalhouse/views/favorite_view.dart';
import 'package:flutter_rentalhouse/views/main_list_cart_home.dart';
import 'package:flutter_rentalhouse/views/message_view.dart';
import 'package:flutter_rentalhouse/views/profile_view.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../viewmodels/vm_auth.dart';
import '../viewmodels/vm_favorite.dart';
import '../views/login_view.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const HomeContent(),
    const FavoriteView(),
    const SizedBox(), // Placeholder cho nút tạo bài đăng
    const MessageView(),
    const ProfileView(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final rentalViewModel = Provider.of<RentalViewModel>(context, listen: false);
      final favoriteViewModel = Provider.of<FavoriteViewModel>(context, listen: false);
      final authViewModel = Provider.of<AuthViewModel>(context, listen: false);

      rentalViewModel.fetchRentals();

      // Tải danh sách yêu thích nếu người dùng đã đăng nhập
      if (authViewModel.currentUser != null) {
        favoriteViewModel.fetchFavorites(authViewModel.currentUser!.token ?? '');
      }
    });
  }

  void _onItemTapped(int index) {
    if (index == 2) {
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const CreateRentalScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1), // Từ dưới lên
                end: Offset.zero,
              ).animate(animation),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 200),
        ),
      ).then((_) {
        setState(() {
          _selectedIndex = 0; // Quay lại tab Trang chính
        });
      });
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  String formatCurrency(double amount) {
    final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
    return formatter.format(amount);
  }

  @override
  Widget build(BuildContext context) {
    final favoriteViewModel = Provider.of<FavoriteViewModel>(context);

    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        backgroundColor: Colors.white,
        selectedItemColor: Colors.blue[700],
        unselectedItemColor: Colors.grey[600],
        selectedIconTheme: const IconThemeData(size: 24, color: Colors.blue),
        unselectedIconTheme: const IconThemeData(size: 20, color: Colors.grey),
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Trang chính'),
          BottomNavigationBarItem(
            icon: Stack(
              clipBehavior: Clip.none, // khắc phục bị che khi hiển thông báo trong bottom dạng Badge
              children: [
                const Icon(Icons.favorite),
                if (favoriteViewModel.favorites.isNotEmpty)
                  Positioned(
                    left: 10, // Đặt badge ở góc phải
                    bottom: 6,   // Đặt badge ở góc trên
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18), // Tăng kích thước một chút
                      child: Text(
                        '${favoriteViewModel.favorites.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            label: 'Yêu thích',
          ),
          BottomNavigationBarItem(
            icon: Container(
              width: 50,
              height: 50,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.add, color: Colors.white),
            ),
            label: '',
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Nhắn tin'),
          const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Hồ sơ'),
        ],
      ),
    );
  }
}

class HomeContent extends StatelessWidget {
  const HomeContent({super.key});

  @override
  Widget build(BuildContext context) {
    final rentalViewModel = Provider.of<RentalViewModel>(context);
    final authViewModel = Provider.of<AuthViewModel>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Danh Sách Bài Đăng', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        actions: [
          if (authViewModel.currentUser != null)
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.black),
              onPressed: () async {
                await authViewModel.logout();
                if (authViewModel.errorMessage == null) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(authViewModel.errorMessage ?? 'Lỗi đăng xuất'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            ),
        ],
      ),
      body: rentalViewModel.isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blue))
          : rentalViewModel.errorMessage != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('Lỗi: ${rentalViewModel.errorMessage}', style: const TextStyle(color: Colors.red, fontSize: 16)),
        ),
      )
          : rentalViewModel.rentals.isEmpty
          ? const Center(child: Text('Không có bài đăng nào!', style: TextStyle(fontSize: 16, color: Colors.grey)))
          : ListView.separated(
        padding: const EdgeInsets.all(8.0),
        itemCount: rentalViewModel.rentals.length,
        separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.grey),
        itemBuilder: (context, index) {
          final rental = rentalViewModel.rentals[index];
          return RentalItemWidget(rental: rental);
        },
      ),
    );
  }
}