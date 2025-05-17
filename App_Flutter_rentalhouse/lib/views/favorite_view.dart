import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_auth.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_favorite.dart';
import 'package:flutter_rentalhouse/widgets/favorite_list_body.dart';
import 'package:provider/provider.dart';

class FavoriteView extends StatefulWidget {
  const FavoriteView({super.key});

  @override
  _FavoriteViewState createState() => _FavoriteViewState();
}

class _FavoriteViewState extends State<FavoriteView> {
  final Set<String> _selectedFavorites = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
      if (authViewModel.currentUser != null &&
          authViewModel.currentUser!.token != null &&
          authViewModel.currentUser!.token!.isNotEmpty) {
        Provider.of<FavoriteViewModel>(context, listen: false)
            .fetchFavorites(authViewModel.currentUser!.token!);
      } else {
        Provider.of<FavoriteViewModel>(context, listen: false)
            .clearFavoritesLocally();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final favoriteViewModel = Provider.of<FavoriteViewModel>(context);
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text('Danh Sách Yêu Thích',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                fontSize: 18)),
        actions: [
          if (_selectedFavorites.isNotEmpty)
            Padding(
              padding:
              const EdgeInsets.only(right: 12.0, top: 8.0, bottom: 8.0),
              child: TextButton.icon(
                icon: Icon(Icons.delete_outline,
                    color: Colors.red[700], size: 20),
                label: Text(
                  'Xóa (${_selectedFavorites.length})',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red[700],
                      fontSize: 13),
                ),
                style: TextButton.styleFrom(
                    backgroundColor: Colors.red[50],
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20))),
                onPressed: () async {
                  if (authViewModel.currentUser == null ||
                      authViewModel.currentUser!.token == null ||
                      authViewModel.currentUser!.token!.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text(
                            'Vui lòng đăng nhập để thực hiện thao tác này')));
                    return;
                  }

                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Xác nhận xóa'),
                      content: Text(
                          'Bạn có chắc muốn xóa ${_selectedFavorites.length} mục yêu thích đã chọn?'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Hủy')),
                        TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: Text('Xóa',
                                style: TextStyle(
                                    color: Colors.red[700],
                                    fontWeight: FontWeight.bold))),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    final success = await favoriteViewModel
                        .removeMultipleFavorites(_selectedFavorites.toList(),
                        authViewModel.currentUser!.token!);
                    if (success) {
                      setState(() => _selectedFavorites.clear());
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Đã xóa các mục yêu thích!'),
                                backgroundColor: Colors.green));
                      }
                    } else {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(favoriteViewModel.errorMessage ??
                                'Lỗi không xác định khi xóa'),
                            backgroundColor: Colors.redAccent));
                      }
                    }
                  }
                },
              ),
            ),
        ],
      ),
      body: FavoriteListBody(
        favoriteViewModel: favoriteViewModel,
        authViewModel: authViewModel,
        selectedFavorites: _selectedFavorites,
        onSelectChanged: (rentalId, isSelected) {
          setState(() {
            if (isSelected) {
              _selectedFavorites.add(rentalId);
            } else {
              _selectedFavorites.remove(rentalId);
            }
          });
        },
      ),
    );
  }
}