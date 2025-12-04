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

  /// 🔥 Fetch tất cả rentals từ API (dùng cho refresh real-time)
  Future<void> fetchAllRentals() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _rentals = await _apiService.getRentals();
      _total = _rentals.length;
      _page = 1;
      _pages = 1;
      _errorMessage = null;

      debugPrint('✅ RentalViewModel: Fetched ${_rentals.length} rentals');
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('❌ RentalViewModel: Error fetching rentals: $e');
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
      await fetchAllRentals();
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

  ///  Refresh tất cả dữ liệu rental (gọi khi có cập nhật từ MyPostsView/EditRentalScreen)
  Future<void> refreshAllRentals() async {
    try {
      debugPrint('🔄 RentalViewModel: Refreshing all rentals...');

      _isLoading = true;
      notifyListeners();

      // Fetch lại từ API
      await fetchAllRentals();

      debugPrint('✅ RentalViewModel: Rentals refreshed successfully');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ RentalViewModel: Error refreshing rentals: $e');
      _errorMessage = 'Lỗi cập nhật dữ liệu: $e';
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  ///  Xóa bài đăng khỏi danh sách cục bộ (cập nhật UI ngay lập tức)
  void removeRentalLocally(String rentalId) {
    try {
      _rentals.removeWhere((rental) => rental.id == rentalId);
      debugPrint('✅ RentalViewModel: Rental $rentalId removed locally');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error removing rental locally: $e');
    }
  }

  ///  Cập nhật bài đăng trong danh sách cục bộ
  void updateRentalLocally(String rentalId, Rental updatedRental) {
    try {
      final index = _rentals.indexWhere((rental) => rental.id == rentalId);
      if (index != -1) {
        _rentals[index] = updatedRental;
        debugPrint('✅ RentalViewModel: Rental $rentalId updated locally');
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ Error updating rental locally: $e');
    }
  }

  ///  Xóa bài đăng khỏi danh sách nearby rentals
  void removeNearbyRentalLocally(String rentalId) {
    try {
      _nearbyRentals.removeWhere((rental) => rental.id == rentalId);
      debugPrint('✅ RentalViewModel: Nearby rental $rentalId removed locally');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error removing nearby rental locally: $e');
    }
  }

  ///  Cập nhật bài đăng trong danh sách nearby rentals
  void updateNearbyRentalLocally(String rentalId, Rental updatedRental) {
    try {
      final index = _nearbyRentals.indexWhere((rental) => rental.id == rentalId);
      if (index != -1) {
        _nearbyRentals[index] = updatedRental;
        debugPrint('✅ RentalViewModel: Nearby rental $rentalId updated locally');
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ Error updating nearby rental locally: $e');
    }
  }

  ///  Cập nhật search results (sau khi edit/delete)
  void removeFromSearchResults(String rentalId) {
    try {
      _searchResults.removeWhere((rental) => rental.id == rentalId);
      _total = (_total > 0) ? _total - 1 : 0;
      debugPrint('✅ RentalViewModel: Rental $rentalId removed from search results');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error removing from search results: $e');
    }
  }

  void updateInSearchResults(String rentalId, Rental updatedRental) {
    try {
      final index = _searchResults.indexWhere((rental) => rental.id == rentalId);
      if (index != -1) {
        _searchResults[index] = updatedRental;
        debugPrint('✅ RentalViewModel: Rental $rentalId updated in search results');
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ Error updating search results: $e');
    }
  }

  // Reset bộ lọc
  void resetNearbyFilters() {
    _currentRadius = 10.0;
    _currentMinPrice = null;
    _currentMaxPrice = null;
    notifyListeners();
  }

  /// 🔥 Clear tất cả error messages
  void clearErrors() {
    _errorMessage = null;
    _warningMessage = null;
    notifyListeners();
  }
}