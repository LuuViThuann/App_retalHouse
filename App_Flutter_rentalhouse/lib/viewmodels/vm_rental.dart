import 'package:flutter/foundation.dart';
import 'package:flutter_rentalhouse/services/rental_service.dart';
import '../services/api_service.dart';
import '../models/rental.dart';

class RentalViewModel extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final RentalService _rentalService = RentalService();
  List<Rental> _rentals = [];
  List<Rental> _searchResults = [];
  List<Rental> _nearbyRentals = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _warningMessage;
  int _total = 0;
  int _page = 1;
  int _pages = 1;

  // Thêm các thuộc tính cho bộ lọc nearby rentals
  double _currentRadius = 10.0;
  double? _currentMinPrice;
  double? _currentMaxPrice;

  List<Rental> get rentals => _rentals;
  List<Rental> get searchResults => _searchResults;
  List<Rental> get nearbyRentals => _nearbyRentals;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get warningMessage => _warningMessage;
  int get total => _total;
  int get page => _page;
  int get pages => _pages;

  double get currentRadius => _currentRadius;
  double? get currentMinPrice => _currentMinPrice;
  double? get currentMaxPrice => _currentMaxPrice;

  Future<void> fetchRentals() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _rentals = await _apiService.getRentals();
      _total = _rentals.length;
      _page = 1;
      _pages = 1;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> searchRentals({
    String? search,
    double? minPrice,
    double? maxPrice,
    List<String>? propertyTypes,
    String? status,
    int page = 1,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _apiService.searchRentals(
        search: search,
        minPrice: minPrice,
        maxPrice: maxPrice,
        propertyTypes: propertyTypes,
        status: status,
        page: page,
      );
      _searchResults = (result['rentals'] as List<dynamic>).cast<Rental>();
      _total = result['total'] as int;
      _page = result['page'] as int;
      _pages = result['pages'] as int;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createRental(Rental rental, List<String> imagePaths) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _apiService.createRental(rental, imagePaths);
      await fetchRentals();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<String>> getSearchHistory() async {
    try {
      return await _apiService.getSearchHistory();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      throw Exception('Không thể tải lịch sử tìm kiếm: $e');
    }
  }

  Future<void> deleteSearchHistoryItem(String query) async {
    try {
      await _apiService.deleteSearchHistoryItem(query);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      throw Exception('Không thể xóa mục lịch sử tìm kiếm: $e');
    }
  }

  Future<void> clearSearchHistory() async {
    try {
      await _apiService.clearSearchHistory();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      throw Exception('Không thể xóa toàn bộ lịch sử tìm kiếm: $e');
    }
  }

  // Cập nhật method fetchNearbyRentals trong RentalViewModel
  Future<void> fetchNearbyRentals(String rentalId,
      {double? radius, double? minPrice, double? maxPrice}) async {
    _isLoading = true;
    _errorMessage = null;
    _warningMessage = null;
    notifyListeners();

    // Cập nhật bộ lọc nếu được cung cấp
    if (radius != null) _currentRadius = radius;
    if (minPrice != null) _currentMinPrice = minPrice;
    if (maxPrice != null) _currentMaxPrice = maxPrice;

    try {
      final result = await _rentalService.fetchNearbyRentals(
        rentalId: rentalId,
        radius: _currentRadius,
        minPrice: _currentMinPrice,
        maxPrice: _currentMaxPrice,
      );

      _nearbyRentals = result['rentals'] ?? [];
      _warningMessage = result['warning'];

      // Log thông tin để debug
      debugPrint('Fetched ${_nearbyRentals.length} nearby rentals');
      debugPrint('Search method: ${result['searchMethod']}');
      if (_warningMessage != null) {
        debugPrint('Warning: $_warningMessage');
      }
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('Error in fetchNearbyRentals: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Method để reset bộ lọc
  void resetNearbyFilters() {
    _currentRadius = 10.0;
    _currentMinPrice = null;
    _currentMaxPrice = null;
    notifyListeners();
  }
  // new -------
}
