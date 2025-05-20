import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_auth.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_favorite.dart';
import 'package:provider/provider.dart';

import '../Widgets/Favorite/favorite_list_body.dart';

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
        title: Row(
          children: [
            Icon(
              Icons.favorite,
              color: Colors.white,
            ),
            SizedBox(width: 8),
            Text(
              'Danh Sách Yêu Thích',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: Colors.white,
              ),
            ),
          ],
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue, Colors.blueAccent.shade700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 4,
        shadowColor: Colors.black26,
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