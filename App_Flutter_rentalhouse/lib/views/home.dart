import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:flutter_rentalhouse/viewmodels/vm_rental.dart';
import 'package:flutter_rentalhouse/views/create_rental_view.dart';
import 'package:flutter_rentalhouse/views/favorite_view.dart';
import 'package:flutter_rentalhouse/views/home_content.dart';
import 'package:flutter_rentalhouse/views/message_view.dart';
import 'package:flutter_rentalhouse/views/profile_view.dart';
import '../viewmodels/vm_auth.dart';
import '../viewmodels/vm_favorite.dart';
import '../viewmodels/vm_chat.dart';

// -----------------------------------------------------------------------------
// 1. WIDGET RIÊNG: NÚT ADD GRADIENT CÓ ANIMATION
// -----------------------------------------------------------------------------
class AnimatedGradientButton extends StatefulWidget {
  const AnimatedGradientButton({super.key});

  @override
  _AnimatedGradientButtonState createState() => _AnimatedGradientButtonState();
}

class _AnimatedGradientButtonState extends State<AnimatedGradientButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    // Tạo animation lặp lại (hiệu ứng nhịp thở)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        width: 56, // Kích thước tiêu chuẩn của FAB
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF42A5F5), // Xanh dương sáng
              Color(0xFF1565C0), // Xanh dương đậm
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
              spreadRadius: 1,
            ),
          ],
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 32),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 2. MÀN HÌNH CHÍNH (HOME SCREEN)
// -----------------------------------------------------------------------------
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
    const SizedBox(), // Placeholder vị trí nút Add
    const ConversationsScreen(),
    const ProfileView(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final rentalViewModel =
      Provider.of<RentalViewModel>(context, listen: false);
      final favoriteViewModel =
      Provider.of<FavoriteViewModel>(context, listen: false);
      final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
      final chatViewModel = Provider.of<ChatViewModel>(context, listen: false);

      rentalViewModel.fetchRentals();

      if (authViewModel.currentUser != null) {
        favoriteViewModel
            .fetchFavorites(authViewModel.currentUser!.token ?? '');
        chatViewModel
            .fetchConversations(authViewModel.currentUser!.token ?? '');
        authViewModel.fetchNotifications(page: 1);
      }
    });
  }

  void _onItemTapped(int index) {
    // Logic nút Add (Index = 2)
    if (index == 2) {
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
          const CreateRentalScreen(),
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

      });
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  // Helper tạo từng tab item để code gọn hơn
  Widget _buildTabItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int badgeCount,
  }) {
    final isSelected = _selectedIndex == index;
    final color = isSelected ? Colors.blue[800] : Colors.grey[600];

    return Expanded(
      child: InkWell(
        onTap: () => _onItemTapped(index),
        highlightColor: Colors.transparent,
        splashColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(isSelected ? activeIcon : icon, color: color, size: 26),
                if (badgeCount > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        badgeCount > 99 ? '99+' : '$badgeCount',
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
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Giữ nguyên body
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),

      // 1. VỊ TRÍ NÚT ADD (FLOATING ACTION BUTTON)
      floatingActionButton: FloatingActionButton(
        onPressed: () => _onItemTapped(2),
        elevation: 0,
        backgroundColor: Colors.transparent, // Trong suốt để hiện Gradient bên trong
        shape: const CircleBorder(),
        child: const AnimatedGradientButton(),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // 2. THANH BAR DƯỚI CÙNG (BOTTOM APP BAR)
      bottomNavigationBar: Consumer3<FavoriteViewModel, ChatViewModel, AuthViewModel>(
        builder: (context, favoriteViewModel, chatViewModel, authViewModel, child) {
          final unreadNotifCount = authViewModel.notifications
              .where((notification) => !notification.read)
              .length;

          return BottomAppBar(
            shape: const CircularNotchedRectangle(), // TẠO ĐƯỜNG CONG
            notchMargin: 8.0, // Khoảng cách giữa nút và đường cong
            color: Colors.white,
            elevation: 10,
            padding: EdgeInsets.zero, // Reset padding
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              height: 65,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Tab 0: Trang chủ
                  _buildTabItem(
                    index: 0,
                    icon: Icons.home_outlined,
                    activeIcon: Icons.home,
                    label: 'Trang chủ',
                    badgeCount: 0,
                  ),

                  // Tab 1: Yêu thích
                  _buildTabItem(
                    index: 1,
                    icon: Icons.favorite_border,
                    activeIcon: Icons.favorite,
                    label: 'Yêu thích',
                    badgeCount: favoriteViewModel.favorites.length,
                  ),

                  // KHOẢNG TRỐNG Ở GIỮA CHO NÚT ADD
                  const SizedBox(width: 48),

                  // Tab 3: Nhắn tin (Index nhảy cóc qua 2)
                  _buildTabItem(
                    index: 3,
                    icon: Icons.chat_bubble_outline,
                    activeIcon: Icons.chat_bubble,
                    label: 'Nhắn tin',
                    badgeCount: chatViewModel.totalUnreadCount,
                  ),

                  // Tab 4: Hồ sơ
                  _buildTabItem(
                    index: 4,
                    icon: Icons.person_outline,
                    activeIcon: Icons.person,
                    label: 'Hồ sơ',
                    badgeCount: unreadNotifCount,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}