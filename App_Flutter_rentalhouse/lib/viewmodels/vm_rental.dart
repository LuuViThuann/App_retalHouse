import 'dart:async';

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

  // Debounce timer for search
  Timer? _debounceTimer;

  //  Cancellation tokens for ongoing requests
  bool _isFetchingNearby = false;

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

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _safeNotifyListeners() {
    if (!_isLoading) {
      try {
        notifyListeners();
      } catch (e) {
        debugPrint('⚠️ Error notifying listeners: $e');
      }
    }
  }


  Future<void> fetchRentals() async {
    _isLoading = true;
    _errorMessage = null;
    _safeNotifyListeners();

    try {
      _rentals = await _apiService.getRentals();
      _total = _rentals.length;
      _page = 1;
      _pages = 1;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

  /// 🔥 Fetch tất cả rentals từ API (dùng cho refresh real-time)
  Future<void> fetchAllRentals() async {
    _isLoading = true;
    _errorMessage = null;
    _safeNotifyListeners();

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
      _safeNotifyListeners();
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

  // ============================================
  // 🔥 CREATE RENTAL WITH PAYMENT INTEGRATION
  // ============================================
  Future<void> createRental(
      Rental rental,
      List<String> imagePaths, {
        List<String> videoPaths = const [],
      }) async {
    _isLoading = true;
    _errorMessage = null;
    _safeNotifyListeners();

    try {
      debugPrint('🚀 RentalViewModel: Creating rental...');

      // 🔥 Kiểm tra payment transaction code
      if (rental.paymentTransactionCode == null ||
          rental.paymentTransactionCode!.isEmpty) {
        throw Exception('Thiếu mã thanh toán. Vui lòng thanh toán trước khi đăng bài.');
      }

      debugPrint('💳 Payment transaction code: ${rental.paymentTransactionCode}');
      debugPrint('📤 Uploading ${imagePaths.length} images and ${videoPaths.length} videos');

      // Call API service - giờ trả về Rental object
      final createdRental = await _apiService.createRental(
        rental,
        imagePaths,
        videoPaths: videoPaths,
      );
      // Refresh all rentals để cập nhật danh sách
      await fetchAllRentals();

      _errorMessage = null;

      debugPrint('✅ RentalViewModel: Create rental completed successfully');
    } on PaymentRequiredException catch (e) {
      // 🔥 Xử lý trường hợp chưa thanh toán
      debugPrint('⚠️ Payment required: ${e.message}');
      _errorMessage = e.message;

      // Log payment info nếu có
      if (e.paymentInfo != null) {
        debugPrint('📋 Payment info: ${e.paymentInfo}');
      }
    } catch (e) {
      debugPrint('❌ Error creating rental: $e');

      // Parse error message để hiển thị user-friendly
      String errorMsg = e.toString();

      // Xử lý các loại lỗi cụ thể
      if (errorMsg.contains('Failed to geocode address')) {
        _errorMessage = 'Địa chỉ không hợp lệ. Vui lòng kiểm tra lại hoặc chọn từ bản đồ.';
      } else if (errorMsg.contains('thanh toán') || errorMsg.contains('payment')) {
        _errorMessage = errorMsg.replaceAll('Exception: ', '');
      } else if (errorMsg.contains('token')) {
        _errorMessage = 'Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.';
      } else if (errorMsg.contains('network') || errorMsg.contains('connection')) {
        _errorMessage = 'Lỗi kết nối mạng. Vui lòng kiểm tra kết nối internet.';
      } else {
        _errorMessage = errorMsg.replaceAll('Exception: ', '');
      }

      debugPrint('📝 User-friendly error message: $_errorMessage');
    } finally {
      _isLoading = false;
      _safeNotifyListeners();
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

  Future<void> fetchNearbyRentals(
      String rentalId, {
        double? radius,
        double? minPrice,
        double? maxPrice,
      }) async {
    // Cancel if already fetching
    if (_isFetchingNearby) {
      debugPrint('⚠️ Already fetching nearby rentals, skipping...');
      return;
    }

    _isFetchingNearby = true;
    _isLoading = true;
    _errorMessage = null;
    _warningMessage = null;
    _safeNotifyListeners();

    // Update filters
    if (radius != null) _currentRadius = radius;
    if (minPrice != null) _currentMinPrice = minPrice;
    if (maxPrice != null) _currentMaxPrice = maxPrice;

    debugPrint('🔥 fetchNearbyRentals called with:');
    debugPrint('   Radius: $_currentRadius km');
    debugPrint('   MinPrice: $_currentMinPrice');
    debugPrint('   MaxPrice: $_currentMaxPrice');

    try {
      debugPrint('🔍 Fetching nearby rentals for $rentalId (radius: $_currentRadius km)');
      debugPrint('💰 Price filter: min=$_currentMinPrice, max=$_currentMaxPrice');

      final result = await _rentalService.fetchNearbyRentals(
        rentalId: rentalId,
        radius: _currentRadius,
        minPrice: _currentMinPrice, // 🔥 Truyền minPrice (có thể null)
        maxPrice: _currentMaxPrice, // 🔥 Truyền maxPrice (có thể null)
        limit: 20,
      );

      // Only update if still relevant (not cancelled)
      if (_isFetchingNearby) {
        _nearbyRentals = result['rentals'] ?? [];
        _warningMessage = result['warning'];

        final appliedFilters = result['appliedFilters'];

        debugPrint('✅ Fetched ${_nearbyRentals.length} nearby rentals');
        debugPrint('📍 Search method: ${result['searchMethod']}');
        debugPrint('💰 Applied filters: $appliedFilters');

        if (_warningMessage != null) {
          debugPrint('⚠️ Warning: $_warningMessage');
        }
      }
    } catch (e) {
      if (_isFetchingNearby) {
        _errorMessage = e.toString();
        debugPrint('❌ Error in fetchNearbyRentals: $_errorMessage');
      }
    } finally {
      _isFetchingNearby = false;
      _isLoading = false;
      _safeNotifyListeners();
    }
  }
  // ✅ Cancel ongoing nearby fetch
  void cancelNearbyFetch() {
    _isFetchingNearby = false;
    debugPrint('🚫 Cancelled nearby rentals fetch');
  }
  /// 🔥 Refresh tất cả dữ liệu rental (gọi khi có cập nhật từ MyPostsView/EditRentalScreen)
  Future<void> refreshAllRentals() async {
    try {
      debugPrint('🔄 RentalViewModel: Refreshing all rentals...');
      _isLoading = true;
      _safeNotifyListeners();

      await fetchAllRentals();

      debugPrint('✅ RentalViewModel: Rentals refreshed successfully');
    } catch (e) {
      debugPrint('❌ RentalViewModel: Error refreshing rentals: $e');
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

  /// 🔥 Xóa bài đăng khỏi danh sách cục bộ (cập nhật UI ngay lập tức)
  void removeRentalLocally(String rentalId) {
    try {
      _rentals.removeWhere((rental) => rental.id == rentalId);
      debugPrint('✅ RentalViewModel: Rental $rentalId removed locally');
      _safeNotifyListeners();
    } catch (e) {
      debugPrint('❌ Error removing rental locally: $e');
    }
  }

  /// 🔥 Cập nhật bài đăng trong danh sách cục bộ
  void updateRentalLocally(String rentalId, Rental updatedRental) {
    try {
      final index = _rentals.indexWhere((rental) => rental.id == rentalId);
      if (index != -1) {
        _rentals[index] = updatedRental;
        debugPrint('✅ RentalViewModel: Rental $rentalId updated locally');
        _safeNotifyListeners();
      }
    } catch (e) {
      debugPrint('❌ Error updating rental locally: $e');
    }
  }

  /// 🔥 Xóa bài đăng khỏi danh sách nearby rentals
  void removeNearbyRentalLocally(String rentalId) {
    try {
      _nearbyRentals.removeWhere((rental) => rental.id == rentalId);
      debugPrint('✅ RentalViewModel: Nearby rental $rentalId removed locally');
      _safeNotifyListeners();
    } catch (e) {
      debugPrint('❌ Error removing nearby rental locally: $e');
    }
  }

  /// 🔥 Cập nhật bài đăng trong danh sách nearby rentals
  void updateNearbyRentalLocally(String rentalId, Rental updatedRental) {
    try {
      final index = _nearbyRentals.indexWhere((rental) => rental.id == rentalId);
      if (index != -1) {
        _nearbyRentals[index] = updatedRental;
        debugPrint('✅ RentalViewModel: Nearby rental $rentalId updated locally');
        _safeNotifyListeners();
      }
    } catch (e) {
      debugPrint('❌ Error updating nearby rental locally: $e');
    }
  }

  /// 🔥 Cập nhật search results (sau khi edit/delete)
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
    _safeNotifyListeners();
  }

  // ============================================
  // 🔥 PAYMENT HELPER METHODS
  // ============================================

  /// Check if a rental requires payment
  bool rentalRequiresPayment(Rental rental) {
    return rental.requiresPayment;
  }

  /// Get payment display info for a rental
  String getRentalPaymentDisplay(Rental rental) {
    return rental.getPaymentInfoDisplay();
  }

  /// Check if rental is newly published
  bool isRentalNew(Rental rental) {
    return rental.isNew();
  }

  /// Get formatted published date
  String getRentalPublishedDate(Rental rental) {
    return rental.getPublishedDateFormatted();
  }

  /// Get all unpaid rentals
  List<Rental> getUnpaidRentals() {
    return _rentals.where((rental) => rental.requiresPayment).toList();
  }

  /// Get all published rentals
  List<Rental> getPublishedRentals() {
    return _rentals.where((rental) => rental.isPublished).toList();
  }

  /// Get rental statistics
  Map<String, dynamic> getRentalStats() {
    final total = _rentals.length;
    final published = _rentals.where((r) => r.isPublished).length;
    final unpaid = _rentals.where((r) => r.requiresPayment).length;
    final newRentals = _rentals.where((r) => r.isNew()).length;

    return {
      'total': total,
      'published': published,
      'unpaid': unpaid,
      'new': newRentals,
      'publishedRate': total > 0 ? (published / total * 100).toStringAsFixed(1) : '0.0',
    };
  }
}