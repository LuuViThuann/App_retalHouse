import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_routes.dart';
import '../models/favorite.dart';

class FavoriteViewModel with ChangeNotifier {
  List<Favorite> _favorites = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Favorite> get favorites => _favorites;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  FavoriteViewModel() {
    _loadFavoritesFromPrefs();
  }

  Future<void> _loadFavoritesFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final favoritesJson = prefs.getString('favorites');
    if (favoritesJson != null) {
      final List<dynamic> data = jsonDecode(favoritesJson);
      _favorites = data.map((json) => Favorite.fromJson(json)).toList();
      notifyListeners();
    }
  }

  Future<void> _saveFavoritesToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final favoritesJson = jsonEncode(_favorites.map((f) => f.toJson()).toList());
    await prefs.setString('favorites', favoritesJson);
  }

  Future<void> fetchFavorites(String? token) async {
    if (token == null || token.isEmpty) {
      _errorMessage = 'Không có token để lấy danh sách yêu thích';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse(ApiRoutes.favorites),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _favorites = data.map((json) => Favorite.fromJson({
          'userId': json['userId'],
          'rentalId': json['rentalId']['_id'], // Extract rentalId from populated rental object
        })).toList();
        await _saveFavoritesToPrefs();
      } else {
        _errorMessage = 'Lỗi server: ${response.statusCode} - ${response.body}';
      }
    } catch (e) {
      _errorMessage = 'Lỗi kết nối: $e';
      print('Raw response: ${e.toString()}');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addFavorite(String userId, String rentalId, String? token) async {
    if (token == null || token.isEmpty) {
      _errorMessage = 'Vui lòng đăng nhập để thêm vào yêu thích';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse(ApiRoutes.favorites),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'rentalId': rentalId}),
      );

      if (response.statusCode == 201) {
        final newFavorite = Favorite(userId: userId, rentalId: rentalId);
        _favorites.add(newFavorite);
        await _saveFavoritesToPrefs();
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Lỗi server: ${response.statusCode} - ${response.body}';
        return false;
      }
    } catch (e) {
      _errorMessage = 'Lỗi kết nối: $e';
      print('Raw response: ${e.toString()}');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> removeFavorite(String rentalId, String? token) async {
    if (token == null || token.isEmpty) {
      _errorMessage = 'Vui lòng đăng nhập để xóa khỏi yêu thích';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await http.delete(
        Uri.parse('${ApiRoutes.favorites}/$rentalId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        _favorites.removeWhere((favorite) => favorite.rentalId == rentalId);
        await _saveFavoritesToPrefs();
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Lỗi server: ${response.statusCode} - ${response.body}';
        return false;
      }
    } catch (e) {
      _errorMessage = 'Lỗi kết nối: $e';
      print('Raw response: ${e.toString()}');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> removeMultipleFavorites(List<String> rentalIds, String? token) async {
    if (token == null || token.isEmpty) {
      _errorMessage = 'Vui lòng đăng nhập để xóa nhiều bài yêu thích';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    bool success = true;
    for (String rentalId in rentalIds) {
      try {
        final response = await http.delete(
          Uri.parse('${ApiRoutes.favorites}/$rentalId'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );

        if (response.statusCode == 200) {
          _favorites.removeWhere((favorite) => favorite.rentalId == rentalId);
        } else {
          success = false;
          _errorMessage = 'Lỗi server: ${response.statusCode} - ${response.body}';
        }
      } catch (e) {
        success = false;
        _errorMessage = 'Lỗi kết nối: $e';
      }
    }

    await _saveFavoritesToPrefs();
    _isLoading = false;
    notifyListeners();
    return success;
  }

  bool isFavorite(String rentalId) {
    return _favorites.any((favorite) => favorite.rentalId == rentalId);
  }
}