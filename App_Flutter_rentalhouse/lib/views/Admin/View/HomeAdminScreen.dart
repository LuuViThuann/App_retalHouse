import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/models/user.dart';
import 'package:flutter_rentalhouse/views/Admin/View/AdminDashboardScreen.dart';
import 'package:flutter_rentalhouse/views/Admin/View/AdminProfileScreen.dart';
import 'package:flutter_rentalhouse/views/Admin/View/AdminTransactionScreen.dart';
import 'package:provider/provider.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_auth.dart';

class HomeAdminScreen extends StatefulWidget {
  const HomeAdminScreen({super.key});

  @override
  State<HomeAdminScreen> createState() => _HomeAdminScreenState();
}

class _HomeAdminScreenState extends State<HomeAdminScreen> {
  int _selectedIndex = 0;

  final Color _primaryColor = const Color(0xFF2563EB);
  final Color _backgroundColor = const Color(0xFFF5F7FA);

  @override
  Widget build(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context);
    final user = authViewModel.currentUser;

    final List<Widget> _pages = [
      const AdminDashboardScreen(),
      AdminProfileScreen(user: user),
      const AdminTransactionScreen(),
    ];

    return Scaffold(
      backgroundColor: _backgroundColor,
      body: _pages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  index: 0,
                  icon: Icons.dashboard_rounded,
                  label: 'Tổng quan',
                ),
                _buildNavItem(
                  index: 1,
                  icon: Icons.admin_panel_settings_rounded,
                  label: 'Quản lý',
                ),
                _buildNavItem(
                  index: 2,
                  icon: Icons.trending_up_rounded,
                  label: 'Doanh thu',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    bool isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300), // Thời gian animation
        curve: Curves.easeOutQuad, // Hiệu ứng chuyển động mượt
        padding: EdgeInsets.symmetric(
            horizontal: isSelected ? 20 : 12,
            vertical: 10
        ),
        decoration: BoxDecoration(

          color: isSelected ? _primaryColor.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? _primaryColor : Colors.grey[500],
              size: 26,
            ),

            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              width: isSelected ? null : 0,
              child: ClipRect(
                child: Row(
                  children: [
                    if (isSelected) const SizedBox(width: 8),
                    if (isSelected)
                      Text(
                        label,
                        style: TextStyle(
                          color: _primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}