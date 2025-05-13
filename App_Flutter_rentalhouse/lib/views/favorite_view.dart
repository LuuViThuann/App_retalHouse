import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/models/rental.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_auth.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_favorite.dart';
import 'package:provider/provider.dart';
import 'package:flutter_rentalhouse/views/main_list_cart_home.dart';

import '../config/api_routes.dart';

class FavoriteView extends StatefulWidget {
  const FavoriteView({super.key});

  @override
  _FavoriteViewState createState() => _FavoriteViewState();
}

class _FavoriteViewState extends State<FavoriteView> {
  final Set<String> _selectedFavorites = {};

  @override
  Widget build(BuildContext context) {
    final favoriteViewModel = Provider.of<FavoriteViewModel>(context);
    final authViewModel = Provider.of<AuthViewModel>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Danh Sách Yêu Thích', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        actions: [
          if (_selectedFavorites.isNotEmpty)
            TextButton(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Xác nhận xóa'),
                    content: Text('Bạn có chắc muốn xóa ${_selectedFavorites.length} bài yêu thích?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Hủy'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Xóa', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );

                if (confirm == true && authViewModel.currentUser != null) {
                  final success = await favoriteViewModel.removeMultipleFavorites(
                    _selectedFavorites.toList(),
                    authViewModel.currentUser!.token,
                  );

                  if (success) {
                    setState(() {
                      _selectedFavorites.clear();
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Đã xóa các bài yêu thích!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(favoriteViewModel.errorMessage ?? 'Lỗi không xác định'),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                }
              },
              child: Text(
                'Xóa (${_selectedFavorites.length})',
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: favoriteViewModel.isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blue))
          : favoriteViewModel.errorMessage != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('Lỗi: ${favoriteViewModel.errorMessage}', style: const TextStyle(color: Colors.red, fontSize: 16)),
        ),
      )
          : favoriteViewModel.favorites.isEmpty
          ? const Center(child: Text('Chưa có bài yêu thích nào!', style: TextStyle(fontSize: 16, color: Colors.grey)))
          : ListView.separated(
        padding: const EdgeInsets.all(8.0),
        itemCount: favoriteViewModel.favorites.length,
        separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.grey),
        itemBuilder: (context, index) {
          final favorite = favoriteViewModel.favorites[index];
          // Since we need a Rental object for RentalItemWidget, we'll fetch it dynamically or adjust the widget
          return FutureBuilder<Rental?>(
            future: _fetchRental(favorite.rentalId, authViewModel.currentUser?.token),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return const Center(child: Text('Lỗi tải bài đăng', style: TextStyle(color: Colors.red)));
              }
              final rental = snapshot.data!;
              return RentalItemWidget(
                rental: rental,
                showCheckbox: true,
                isSelected: _selectedFavorites.contains(rental.id),
                onSelect: () {
                  setState(() {
                    _selectedFavorites.add(rental.id ?? '');
                  });
                },
                onDeselect: () {
                  setState(() {
                    _selectedFavorites.remove(rental.id);
                  });
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<Rental?> _fetchRental(String rentalId, String? token) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiRoutes.baseUrl}/rentals/$rentalId'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return Rental.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}