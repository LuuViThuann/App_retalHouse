import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
// 1. WIDGET NÚT ADD GRADIENT CÓ ANIMATION
// BUG FIX: Dùng nullable + khởi tạo an toàn thay vì `late`
// -----------------------------------------------------------------------------
class AnimatedGradientButton extends StatefulWidget {
  const AnimatedGradientButton({super.key});

  @override
  _AnimatedGradientButtonState createState() => _AnimatedGradientButtonState();
}

class _AnimatedGradientButtonState extends State<AnimatedGradientButton>
    with SingleTickerProviderStateMixin {
  // FIX: Dùng nullable thay vì late để tránh LateInitializationError
  AnimationController? _controller;
  Animation<double>? _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _controller!, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // FIX: Guard null - nếu animation chưa sẵn sàng thì render tĩnh
    if (_scaleAnimation == null) {
      return _buildButtonContent(scale: 1.0);
    }

    return AnimatedBuilder(
      animation: _scaleAnimation!,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation!.value,
          child: child,
        );
      },
      child: _buildButtonContent(scale: 1.0),
    );
  }

  Widget _buildButtonContent({required double scale}) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF42A5F5),
            Color(0xFF1565C0),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.45),
            blurRadius: 14,
            offset: const Offset(0, 5),
            spreadRadius: 1,
          ),
        ],
      ),
      child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
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

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  int _previousIndex = 0;

  // FIX: Dùng nullable thay vì late — tránh LateInitializationError hoàn toàn
  List<AnimationController>? _tabControllers;
  List<Animation<double>>? _tabScaleAnimations;

  final List<Widget> _screens = [
    const HomeContent(),
    const FavoriteView(),
    const SizedBox(),
    const ConversationsScreen(),
    const ProfileView(),
  ];

  // Định nghĩa tabs (bỏ qua index 2 là nút Add)
  static const _tabs = [
    _TabData(index: 0, icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Trang chủ'),
    _TabData(index: 1, icon: Icons.favorite_border_rounded, activeIcon: Icons.favorite_rounded, label: 'Yêu thích'),
    _TabData(index: 3, icon: Icons.chat_bubble_outline_rounded, activeIcon: Icons.chat_bubble_rounded, label: 'Nhắn tin'),
    _TabData(index: 4, icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Hồ sơ'),
  ];

  @override
  void initState() {
    super.initState();

    // FIX: dùng local variable sau khi gán — Dart không tự suy ra non-null từ field nullable
    final controllers = List.generate(
      4,
          (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 300),
      ),
    );
    _tabControllers = controllers;

    _tabScaleAnimations = controllers
        .map(
          (c) => Tween<double>(begin: 1.0, end: 1.25).animate(
        CurvedAnimation(parent: c, curve: Curves.elasticOut),
      ),
    )
        .toList();

    // Trigger animation cho tab đầu tiên
    controllers[0].forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final rentalViewModel = Provider.of<RentalViewModel>(context, listen: false);
      final favoriteViewModel = Provider.of<FavoriteViewModel>(context, listen: false);
      final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
      final chatViewModel = Provider.of<ChatViewModel>(context, listen: false);

      rentalViewModel.fetchRentals();

      if (authViewModel.currentUser != null) {
        favoriteViewModel.fetchFavorites(authViewModel.currentUser!.token ?? '');
        chatViewModel.fetchConversations(authViewModel.currentUser!.token ?? '');
        authViewModel.fetchNotifications(page: 1);
      }
    });
  }

  @override
  void dispose() {
    _tabControllers?.forEach((c) => c.dispose());
    super.dispose();
  }

  // Chuyển screen index → tab animation index (bỏ qua slot 2)
  int _screenToTabIndex(int screenIndex) {
    if (screenIndex <= 1) return screenIndex;
    return screenIndex - 1; // 3 → 2, 4 → 3
  }

  void _onItemTapped(int screenIndex) {
    if (screenIndex == 2) {
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, animation, __) => const CreateRentalScreen(),
          transitionsBuilder: (_, animation, __, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          transitionDuration: const Duration(milliseconds: 280),
        ),
      );
      return;
    }

    if (_selectedIndex == screenIndex) return;

    final prevTabIdx = _screenToTabIndex(_previousIndex);
    final newTabIdx = _screenToTabIndex(screenIndex);

    // Null-safe: chỉ trigger nếu controllers đã sẵn sàng
    _tabControllers?[prevTabIdx].reverse();
    _tabControllers?[newTabIdx].forward(from: 0.0);

    setState(() {
      _previousIndex = _selectedIndex;
      _selectedIndex = screenIndex;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _onItemTapped(2),
        elevation: 0,
        backgroundColor: Colors.transparent,
        shape: const CircleBorder(),
        child: const AnimatedGradientButton(),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: Consumer3<FavoriteViewModel, ChatViewModel, AuthViewModel>(
        builder: (context, favoriteVm, chatVm, authVm, _) {
          final unreadNotifCount =
              authVm.notifications.where((n) => !n.read).length;

          final badgeCounts = [0, favoriteVm.favorites.length, chatVm.totalUnreadCount, unreadNotifCount];

          // Null guard: nếu animations chưa sẵn sàng thì render placeholder
          final animations = _tabScaleAnimations;
          if (animations == null) return const SizedBox(height: 68);

          return _ProBottomBar(
            tabs: _tabs,
            selectedScreenIndex: _selectedIndex,
            badgeCounts: badgeCounts,
            tabScaleAnimations: animations,
            onTabTapped: _onItemTapped,
          );
        },
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 3. BOTTOM BAR CHUYÊN NGHIỆP (tách thành widget riêng)
// -----------------------------------------------------------------------------
class _TabData {
  final int index;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _TabData({
    required this.index,
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

class _ProBottomBar extends StatelessWidget {
  final List<_TabData> tabs;
  final int selectedScreenIndex;
  final List<int> badgeCounts;
  final List<Animation<double>> tabScaleAnimations; // non-nullable, đã guard ở trên
  final ValueChanged<int> onTabTapped;

  const _ProBottomBar({
    required this.tabs,
    required this.selectedScreenIndex,
    required this.badgeCounts,
    required this.tabScaleAnimations,
    required this.onTabTapped,
  });

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 10.0,
      color: Colors.white,
      elevation: 16,
      shadowColor: Colors.black.withOpacity(0.12),
      padding: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Container(
        height: 68,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Color(0xFFEEEEEE), width: 1),
          ),
        ),
        child: Row(
          children: [
            // Tab 0, 1
            ...tabs.take(2).toList().asMap().entries.map(
                  (e) => _buildTabItem(
                tab: e.value,
                tabAnimIndex: e.key,
                badgeCount: badgeCounts[e.key],
              ),
            ),

            // Khoảng trống giữa cho FAB
            const SizedBox(width: 72),

            // Tab 3, 4 (screen index 3, 4)
            ...tabs.skip(2).toList().asMap().entries.map(
                  (e) => _buildTabItem(
                tab: e.value,
                tabAnimIndex: e.key + 2,
                badgeCount: badgeCounts[e.key + 2],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem({
    required _TabData tab,
    required int tabAnimIndex,
    required int badgeCount,
  }) {
    final isSelected = selectedScreenIndex == tab.index;

    return Expanded(
      child: GestureDetector(
        onTap: () => onTabTapped(tab.index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: tabScaleAnimations[tabAnimIndex],
          builder: (context, child) {
            return SizedBox(
              height: 68,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon với scale animation + indicator dot
                  Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      // Highlight pill khi active
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        width: isSelected ? 44 : 0,
                        height: isSelected ? 32 : 0,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF1565C0).withOpacity(0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      // Icon với scale
                      Transform.scale(
                        scale: isSelected
                            ? tabScaleAnimations[tabAnimIndex].value
                            : 1.0,
                        child: Icon(
                          isSelected ? tab.activeIcon : tab.icon,
                          color: isSelected
                              ? const Color(0xFF1565C0)
                              : const Color(0xFF9E9E9E),
                          size: 24,
                        ),
                      ),
                      // Badge
                      if (badgeCount > 0)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: _Badge(count: badgeCount),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Label với animated color
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      color: isSelected
                          ? const Color(0xFF1565C0)
                          : const Color(0xFF9E9E9E),
                      fontSize: 10.5,
                      fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.w400,
                      letterSpacing: isSelected ? 0.2 : 0,
                    ),
                    child: Text(tab.label),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// Badge widget
class _Badge extends StatelessWidget {
  final int count;
  const _Badge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
      decoration: BoxDecoration(
        color: const Color(0xFFE53935),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}