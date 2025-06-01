import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../config/api_routes.dart';
import '../models/rental.dart';
import '../services/auth_service.dart';
import '../viewmodels/vm_auth.dart';

class RentalService {
  Future<List<Rental>> fetchRentals() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiRoutes.baseUrl}/rentals'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Rental.fromJson(json)).toList();
      } else {
        throw Exception(
            'Failed to fetch rentals: ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e) {
      print('Exception fetching rentals: $e');
      throw Exception('Error fetching rentals: $e');
    }
  }

  Future<void> fetchRentalDetails({
    required Rental rental,
    required Function(double, int) onSuccess,
    required Function(String) onError,
    required BuildContext context,
  }) async {
    try {
      final response =
          await http.get(Uri.parse('${ApiRoutes.rentals}/${rental.id}'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final averageRating =
            (data['averageRating'] as num?)?.toDouble() ?? 0.0;
        final reviewCount = (data['comments'] as List<dynamic>?)?.length ?? 0;
        onSuccess(averageRating, reviewCount);
      } else {
        onError('Không thể tải thông tin: ${response.statusCode}');
      }
    } catch (e) {
      onError('Lỗi khi tải thông tin: $e');
    }
  }

  Future<void> checkFavoriteStatus({
    required Rental rental,
    required Function(bool) onSuccess,
    required Function(String) onError,
    required BuildContext context,
  }) async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    if (authViewModel.currentUser == null) {
      onSuccess(false);
      return;
    }

    try {
      final token = await AuthService().getIdToken();
      if (token == null) {
        onSuccess(false);
        return;
      }

      final response = await http.get(
        Uri.parse('${ApiRoutes.baseUrl}/favorites'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> favorites = jsonDecode(response.body);
        final isFavorited = favorites
            .any((favorite) => favorite['rentalId']['_id'] == rental.id);
        onSuccess(isFavorited);
      } else {
        onError('Không thể tải trạng thái yêu thích: ${response.statusCode}');
        onSuccess(false);
      }
    } catch (e) {
      onError('Lỗi khi kiểm tra trạng thái yêu thích: $e');
      onSuccess(false);
    }
  }

  Future<void> toggleFavorite({
    required Rental rental,
    required bool isFavorite,
    required Function(bool) onSuccess,
    required Function(String) onError,
    required BuildContext context,
  }) async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    if (authViewModel.currentUser == null) {
      onError('Vui lòng đăng nhập để thêm vào yêu thích');
      return;
    }

    try {
      final token = await AuthService().getIdToken();
      if (token == null) throw Exception('No valid token found');

      final url = isFavorite
          ? '${ApiRoutes.baseUrl}/favorites/${rental.id}'
          : '${ApiRoutes.baseUrl}/favorites';
      final response = isFavorite
          ? await http.delete(
              Uri.parse(url),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
            )
          : await http.post(
              Uri.parse(url),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
              body: jsonEncode({'rentalId': rental.id}),
            );

      if (response.statusCode == 200 || response.statusCode == 201) {
        onSuccess(!isFavorite);
      } else {
        throw Exception('Failed to toggle favorite: ${response.body}');
      }
    } catch (e) {
      onError('Lỗi khi cập nhật yêu thích: $e');
    }
  }

  Future<Rental?> fetchRentalById({
    required String rentalId,
    required String? token,
  }) async {
    if (token == null || token.isEmpty) {
      print('Fetch rental $rentalId failed: No token provided.');
      return null;
    }
    try {
      final response = await http.get(
        Uri.parse('${ApiRoutes.baseUrl}/rentals/$rentalId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        return Rental.fromJson(jsonDecode(response.body));
      } else {
        print(
            'Error fetching rental $rentalId: Status ${response.statusCode}, Body: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Exception fetching rental $rentalId: $e');
      return null;
    }
  }
}
