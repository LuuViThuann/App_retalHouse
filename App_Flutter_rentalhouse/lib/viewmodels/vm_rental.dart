import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../models/rental.dart';

class RentalViewModel extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<Rental> _rentals = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Rental> get rentals => _rentals;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Lấy danh sách bài đăng
  Future<void> fetchRentals() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _rentals = await _apiService.getRentals();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Tạo bài đăng mới
  Future<void> createRental(Rental rental, List<String> imagePaths) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _apiService.createRental(rental, imagePaths);
      await fetchRentals(); // Cập nhật danh sách sau khi tạo
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}