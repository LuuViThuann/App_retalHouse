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

    if (favoriteViewModel.isLoading("")) {
      return const Center(child: CircularProgressIndicator());
    }

    if (favoriteViewModel.errorMessage != null &&
        favoriteViewModel.favorites.isEmpty) {
      return Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Lỗi: ${favoriteViewModel.errorMessage}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 16)),
          ));
    }

    if (favoriteViewModel.favorites.isEmpty) {
      return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.favorite_border_outlined, size: 80, color: Colors.grey),
              SizedBox(height: 16),
              Text('Danh sách yêu thích trống',
                  style: TextStyle(fontSize: 17, color: Colors.grey)),
              Text('Hãy khám phá và thêm nhà/phòng bạn thích nhé.',
                  style: TextStyle(fontSize: 15, color: Colors.grey),
                  textAlign: TextAlign.center),
            ],
          ));
    }

    return ListView.builder(
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
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const RentalItemShimmer();
              }
              if (snapshot.hasError ||
                  !snapshot.hasData ||
                  snapshot.data == null) {
                return Container(
                  margin:
                  const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      border:
                      Border(bottom: BorderSide(color: Colors.grey[200]!))),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          color: Colors.red[300], size: 30),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Không tải được thông tin',
                                style: TextStyle(
                                    color: Colors.red[700],
                                    fontWeight: FontWeight.bold)),
                            Text('ID: ${favorite.rentalId}',
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }
              final rental = snapshot.data!;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RentalDetailScreen(rental: rental),
                    ),
                  );
                },
                child: RentalFavoriteWidget(
                  key: ValueKey(rental.id),
                  rental: rental,
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
    );
  }
}