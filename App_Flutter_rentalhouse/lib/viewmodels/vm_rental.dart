import 'package:flutter/material.dart';
import '../models/rental.dart';
import '../services/api_service.dart';
import 'dart:io';

class RentalViewModel extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<Rental> _rentals = [];
  String? _errorMessage;
  bool _isLoading = false;

  List<Rental> get rentals => _rentals;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;

  Future<void> fetchRentals() async {
    _setLoading(true);
    try {
      _rentals = await _apiService.getRentals();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    }
    _setLoading(false);
  }

  Future<void> createRental({
    required String title,
    required String description,
    required double price,
    required String location,
    required String userId,
    required List<File> images,
  }) async {
    _setLoading(true);
    try {
      final rental = Rental(
        title: title,
        description: description,
        price: price,
        location: location,
        userId: userId,
        images: [],
        createdAt: DateTime.now(),
      );
      await _apiService.createRental(rental, images.map((file) => file.path).toList());
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    }
    _setLoading(false);
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}