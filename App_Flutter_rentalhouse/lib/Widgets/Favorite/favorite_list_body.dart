import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/Widgets/Favorite/favorite_item_shimmer.dart';
import 'package:flutter_rentalhouse/Widgets/Favorite/favorite_rental.dart';
import 'package:flutter_rentalhouse/models/rental.dart';
import 'package:flutter_rentalhouse/services/rental_service.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_auth.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_favorite.dart';
import 'package:flutter_rentalhouse/views/rental_detail_view.dart';

class FavoriteListBody extends StatelessWidget {
  final FavoriteViewModel favoriteViewModel;
  final AuthViewModel authViewModel;
  final Set<String> selectedFavorites;
  final Function(String, bool) onSelectChanged;

  const FavoriteListBody({
    super.key,
    required this.favoriteViewModel,
    required this.authViewModel,
    required this.selectedFavorites,
    required this.onSelectChanged,
  });

  @override
  Widget build(BuildContext context) {
    // ==================== KIỂM TRA ĐĂNG NHẬP ====================
    if (authViewModel.currentUser == null ||
        authViewModel.currentUser!.token == null ||
        authViewModel.currentUser!.token!.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.login, size: 60, color: Colors.grey),
            SizedBox(height: 16),
            Text('Vui lòng đăng nhập',
                style: TextStyle(fontSize: 17, color: Colors.grey)),
            Text('Để xem danh sách yêu thích của bạn.',
                style: TextStyle(fontSize: 15, color: Colors.grey)),
          ],
        ),
      );
    }

    // ==================== LOADING ====================
    if (favoriteViewModel.isListLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // ==================== LỖI ====================
    if (favoriteViewModel.errorMessage != null &&
        favoriteViewModel.favorites.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 60, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text(
                'Lỗi: ${favoriteViewModel.errorMessage}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 16),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  favoriteViewModel.fetchFavorites(
                    authViewModel.currentUser!.token!,
                  );
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ==================== DANH SÁCH TRỐNG ====================
    if (favoriteViewModel.favorites.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border_outlined, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text('Danh sách yêu thích trống',
                style: TextStyle(fontSize: 17, color: Colors.grey)),
            SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Hãy khám phá và thêm nhà/phòng bạn thích nhé.',
                style: TextStyle(fontSize: 15, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    // ==================== DANH SÁCH FAVORITES ====================
    return RefreshIndicator(
      onRefresh: () async {
        await favoriteViewModel.fetchFavorites(
          authViewModel.currentUser!.token!,
        );
      },
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
        itemCount: favoriteViewModel.favorites.length,
        itemBuilder: (context, index) {
          final favorite = favoriteViewModel.favorites[index];
          return KeyedSubtree(
            key: ValueKey(favorite.rentalId),
            child: FutureBuilder<Rental?>(
              future: RentalService().fetchRentalById(
                rentalId: favorite.rentalId,
                token: authViewModel.currentUser?.token,
              ),
              builder: (context, snapshot) {
                // Loading
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const RentalItemShimmer();
                }

                // Error hoặc không có data
                if (snapshot.hasError ||
                    !snapshot.hasData ||
                    snapshot.data == null) {
                  return Container(
                    margin: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 8,
                    ),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline,
                            color: Colors.red[300], size: 30),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Không tải được thông tin',
                                style: TextStyle(
                                  color: Colors.red[700],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'ID: ${favorite.rentalId}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Nút xóa favorite lỗi
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          color: Colors.red[400],
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Xóa khỏi yêu thích?'),
                                content: const Text(
                                  'Bài viết này không thể tải được. Bạn có muốn xóa khỏi danh sách yêu thích?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('Hủy'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text(
                                      'Xóa',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true && context.mounted) {
                              await favoriteViewModel.removeFavorite(
                                favorite.rentalId,
                                authViewModel.currentUser!.token!,
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  );
                }

                // Success - Hiển thị rental
                final rental = snapshot.data!;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            RentalDetailScreen(rental: rental),
                      ),
                    );
                  },
                  child: RentalFavoriteWidget(
                    key: ValueKey(rental.id),
                    rental: rental,
                    showFavoriteButton: true,
                    showCheckbox: selectedFavorites.isNotEmpty,
                    isSelected: selectedFavorites.contains(rental.id),
                    onSelectChanged: (isSelected) {
                      onSelectChanged(rental.id!, isSelected);
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}