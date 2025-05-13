import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_rental.dart';
import 'package:flutter_rentalhouse/views/create_rental_view.dart';
import 'package:flutter_rentalhouse/views/favorite_view.dart';
import 'package:flutter_rentalhouse/views/main_list_cart_home.dart'; // Đảm bảo import này đúng
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
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 200),
        ),
      ).then((_) {
        setState(() {
          _selectedIndex = 0;
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
      body: IndexedStack( // Sử dụng IndexedStack để giữ trạng thái của các màn hình
        index: _selectedIndex,
        children: _screens,
      ),
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
          const BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Trang chính'),
          BottomNavigationBarItem(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.favorite_border),
                if (favoriteViewModel.favorites.isNotEmpty)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        '${favoriteViewModel.favorites.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            activeIcon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.favorite),
                if (favoriteViewModel.favorites.isNotEmpty)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        '${favoriteViewModel.favorites.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
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
              width: 48, // Giảm kích thước một chút để phù hợp hơn
              height: 40, // Giảm kích thước một chút
              margin: const EdgeInsets.only(top: 0), // Điều chỉnh margin nếu cần
              decoration: BoxDecoration(
                color: Colors.blueAccent, // Màu sắc có thể điều chỉnh
                borderRadius: BorderRadius.circular(12), // Bo tròn góc
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 28),
            ),
            label: '', // Không có label cho nút này
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), activeIcon: Icon(Icons.chat_bubble) ,label: 'Nhắn tin'),
          const BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Hồ sơ'),
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

    // Lấy kích thước màn hình để điều chỉnh layout
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      // AppBar đã được xóa bỏ
      body: SafeArea( // Sử dụng SafeArea để tránh nội dung bị che bởi notch hoặc thanh trạng thái
        child: SingleChildScrollView( // Cho phép cuộn nếu nội dung dài hơn màn hình
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Phần Header: Location và Avatar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.location_on, color: Colors.blue[700], size: 28),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Vị trí của bạn',
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            ),
                            const Text(
                              'Nguyễn văn cừ nối dài - TP - Cần thơ', // Dữ liệu mẫu
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    // Thay thế bằng CircleAvatar với ảnh người dùng
                    authViewModel.currentUser != null && authViewModel.currentUser!.avatarUrl != null
                        ? CircleAvatar(
                      radius: 24,
                      backgroundImage: CachedNetworkImageProvider(authViewModel.currentUser!.avatarUrl!),
                    )
                        : const CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.grey, // Màu placeholder
                      child: Icon(Icons.person, color: Colors.white), // Icon placeholder
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Thanh tìm kiếm
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Nhập thông tin tìm kiếm...',
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                    suffixIcon: Container( // Icon filter bên phải
                      margin: const EdgeInsets.all(4.0),
                      padding: const EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        color: Colors.teal[50], // Màu nền cho icon filter
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.tune, color: Colors.blue[700]), // Icon filter (thay thế bằng ảnh của bạn)
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14.0),
                  ),
                ),
                const SizedBox(height: 25),

                // Banner "Featured Property"
                Container(
                  height: screenHeight * 0.22, // Chiều cao tương đối
                  width: double.infinity,
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15.0),
                      image: DecorationImage(
                        image: AssetImage('assets/img/banner.jpg'), // Ví dụ
                        fit: BoxFit.cover,
                      ),
                      gradient: LinearGradient( // Gradient mẫu nếu không có ảnh
                        colors: [Colors.teal.shade300, Colors.teal.shade600],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.3),
                          spreadRadius: 2,
                          blurRadius: 6,
                          offset: const Offset(0, 4),
                        )
                      ]
                  ),
                  child: Stack(
                    children: [
                      // Nội dung trên banner
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 25),

                // Danh mục (Villa, Penthouse, ...)
                SizedBox(
                  height: 50, // Chiều cao cố định cho danh mục
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildCategoryItem(Icons.apartment, 'Căn hộ chung cư', true, context),
                      _buildCategoryItem(Icons.house, 'Nhà riêng', false, context),
                      _buildCategoryItem(Icons.meeting_room, 'Nhà trọ/Phòng trọ', false, context),
                      _buildCategoryItem(Icons.villa, 'Biệt thự', false, context),
                      _buildCategoryItem(Icons.business, 'Văn phòng', false, context),
                      _buildCategoryItem(Icons.storefront, 'Mặt bằng kinh doanh', false, context),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Tiêu đề "Danh Sách Bài Đăng"
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Bài Đăng Mới Nhất',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    TextButton(
                      onPressed: () {
                        // TODO: Xử lý sự kiện xem tất cả
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Xem tất cả',
                            style: TextStyle(fontSize: 14, color: Colors.blue[700]),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward,
                            size: 14,
                            color: Colors.blue[700],
                          ),
                        ],
                      ),
                    ),

                  ],
                ),
                const SizedBox(height: 10),


                // Danh sách bài đăng
                if (authViewModel.currentUser == null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 30.0),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock_outline, size: 50, color: Colors.grey[400]),
                          const SizedBox(height: 10),
                          const Text(
                            'Vui lòng đăng nhập để xem bài đăng.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[700],
                                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                                textStyle: const TextStyle(fontSize: 16)
                            ),
                            onPressed: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (context) => const LoginScreen()),
                              );
                            },
                            child: const Text('Đăng Nhập Ngay', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (rentalViewModel.isLoading)
                  const Center(child: Padding(
                    padding: EdgeInsets.all(30.0),
                    child: CircularProgressIndicator(color: Colors.blue),
                  ))
                else if (rentalViewModel.errorMessage != null)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text('Lỗi: ${rentalViewModel.errorMessage}', style: const TextStyle(color: Colors.red, fontSize: 16)),
                      ),
                    )
                  else if (rentalViewModel.rentals.isEmpty)
                      const Center(child: Padding(
                        padding: EdgeInsets.all(30.0),
                        child: Text('Không có bài đăng nào!', style: TextStyle(fontSize: 16, color: Colors.grey)),
                      ))
                    else
                      ListView.separated(
                        shrinkWrap: true, // Quan trọng khi ListView trong SingleChildScrollView
                        physics: const NeverScrollableScrollPhysics(), // Tắt cuộn của ListView này
                        itemCount: rentalViewModel.rentals.length > 5 ? 5 : rentalViewModel.rentals.length, // Giới hạn số lượng hiển thị ban đầu
                        separatorBuilder: (context, index) => const SizedBox(height: 12), // Khoảng cách giữa các item
                        itemBuilder: (context, index) {
                          final rental = rentalViewModel.rentals[index];
                          // Giả sử bạn có RentalItemWidget đã được thiết kế
                          // Đây là nơi bạn sẽ sử dụng lại widget item bài đăng của mình
                          return RentalItemWidget(rental: rental);
                        },
                      ),
                const SizedBox(height: 20), // Khoảng đệm cuối trang
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Widget con cho ảnh nhỏ trong banner
  Widget _buildMiniPropertyImage(String imagePath, String line1, String line2, String line3, double screenHeight) {
    // Vì không có ảnh thực, sử dụng Placeholder
    return Container(
      width: screenHeight * 0.1, // Kích thước tương đối
      height: screenHeight * 0.18,
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey[300], // Màu placeholder
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 5,
                offset: const Offset(2,2)
            )
          ]
        // image: DecorationImage(
        //   image: AssetImage(imagePath), // Sử dụng khi có ảnh
        //   fit: BoxFit.cover,
        // ),
      ),
      child: Stack(
        children: [
          ClipRRect( // Để bo tròn ảnh nếu có
            borderRadius: BorderRadius.circular(12),
            // child: Image.asset(imagePath, fit: BoxFit.cover, width: double.infinity, height: double.infinity), //Khi có ảnh
            child: Center(child: Icon(Icons.house, size: 30, color: Colors.grey[700])), // Placeholder Icon
          ),
          Positioned(
            bottom: 5,
            left: 5,
            right: 5,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(5)
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(line1, style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold)),
                  Text(line2, style: const TextStyle(color: Colors.white, fontSize: 6)),
                  Text(line3, style: const TextStyle(color: Colors.white, fontSize: 6)),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }


  // Widget con cho từng mục trong danh mục (Villa, Penthouse, ...)
  Widget _buildCategoryItem(IconData icon, String label, bool isSelected, BuildContext context) {
    return GestureDetector(
      onTap: () {
        // TODO: Xử lý khi nhấn vào category
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Selected: $label')),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(right: 12.0),
        padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[400] : Colors.grey[100],
          borderRadius: BorderRadius.circular(10.0),
          border: isSelected ? null : Border.all(color: Colors.grey.shade300) ,
          boxShadow: isSelected ? [
            BoxShadow(
                color: Colors.teal.withOpacity(0.3),
                blurRadius: 5,
                offset: const Offset(0,2)
            )
          ] : [],
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.grey[700], size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[800],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

