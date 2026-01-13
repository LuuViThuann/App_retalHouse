import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_rentalhouse/services/rental_service.dart';
import '../models/poi.dart';
import '../services/api_service.dart';
import '../models/rental.dart';
import '../services/auth_service.dart';
import '../services/poi_service.dart';

class RentalViewModel extends ChangeNotifier {
  // Các thông tin gọi  =========================================================

  bool _isAIRecommendation = false;
  String? _aiRecommendationMessage;

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

  // CÁC BIẾN CHO POI ==========================================================
  final POIService _poiService = POIService();
  List<POICategory> _poiCategories = [];
  List<POI> _nearbyPOIs = [];
  List<String> _selectedPOICategories = [];

  // Thêm các thuộc tính cho bộ lọc nearby rentals và trạng thái =========================================================
  double _currentRadius = 10.0;
  double? _currentMinPrice;
  double? _currentMaxPrice;

  // Debounce timer for search =========================================================
  Timer? _debounceTimer;

  //  Cancellation tokens for ongoing requests =========================================================
  bool _isFetchingNearby = false;

  bool get isAIRecommendation => _isAIRecommendation;
  String? get aiRecommendationMessage => _aiRecommendationMessage;

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

  // POI getters =========================================================
  List<POICategory> get poiCategories => _poiCategories;
  List<POI> get nearbyPOIs => _nearbyPOIs;
  List<String> get selectedPOICategories => _selectedPOICategories;

  // ============================================
  //  LIFECYCLE METHODS
  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  // Safe notifyListeners to avoid calling during loading state ============================================================
  void _safeNotifyListeners() {
    if (!_isLoading) {
      try {
        notifyListeners();
      } catch (e) {
        debugPrint(' Error notifying listeners: $e');
      }
    }
  }

// ============================================
  // FETCH RENTALS METHODS
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

  //Fetch tất cả rentals từ API (dùng cho refresh real-time) =========================================================
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

      debugPrint(' RentalViewModel: Fetched ${_rentals.length} rentals');
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint(' RentalViewModel: Error fetching rentals: $e');
    } finally {
      _isLoading = false;
      _safeNotifyListeners();
    }
  }
  // ============================================
  // SEARCH RENTALS METHODS
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

  // =====================================================================================================
  //  CREATE RENTAL WITH PAYMENT INTEGRATION
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
      debugPrint(' RentalViewModel: Creating rental...');

      //  Kiểm tra payment transaction code
      if (rental.paymentTransactionCode == null ||
          rental.paymentTransactionCode!.isEmpty) {
        throw Exception('Thiếu mã thanh toán. Vui lòng thanh toán trước khi đăng bài.');
      }

      debugPrint(' Payment transaction code: ${rental.paymentTransactionCode}');
      debugPrint(' Uploading ${imagePaths.length} images and ${videoPaths.length} videos');

      // Call API service - giờ trả về Rental object
      final createdRental = await _apiService.createRental(
        rental,
        imagePaths,
        videoPaths: videoPaths,
      );
      // Refresh all rentals để cập nhật danh sách
      await fetchAllRentals();

      _errorMessage = null;

      debugPrint(' RentalViewModel: Create rental completed successfully');
    } on PaymentRequiredException catch (e) {
      //  Xử lý trường hợp chưa thanh toán
      debugPrint(' Payment required: ${e.message}');
      _errorMessage = e.message;

      // Log payment info nếu có
      if (e.paymentInfo != null) {
        debugPrint(' Payment info: ${e.paymentInfo}');
      }
    } catch (e) {
      debugPrint(' Error creating rental: $e');

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

      debugPrint(' User-friendly error message: $_errorMessage');
    } finally {
      _isLoading = false;
      _safeNotifyListeners();
    }
  }
// ============================================
  // SEARCH HISTORY METHODS
  Future<List<String>> getSearchHistory() async {
    try {
      return await _apiService.getSearchHistory();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      throw Exception('Không thể tải lịch sử tìm kiếm: $e');
    }
  }

  // Delete a specific search history item =========================================================
  Future<void> deleteSearchHistoryItem(String query) async {
    try {
      await _apiService.deleteSearchHistoryItem(query);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      throw Exception('Không thể xóa mục lịch sử tìm kiếm: $e');
    }
  }

  // Clear all search history =========================================================
  Future<void> clearSearchHistory() async {
    try {
      await _apiService.clearSearchHistory();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      throw Exception('Không thể xóa toàn bộ lịch sử tìm kiếm: $e');
    }
  }

  // ============================================
  // FETCH NEARBY RENTALS METHODS
  Future<void> fetchNearbyRentals(
      String rentalId, {
        double? radius,
        double? minPrice,
        double? maxPrice,
        double? latitude,
        double? longitude,
      }) async {
    // Cancel if already fetching
    if (_isFetchingNearby) {
      debugPrint(' Already fetching nearby rentals, skipping...');
      return;
    }

    _isFetchingNearby = true;
    _isLoading = true;
    _errorMessage = null;
    _warningMessage = null;
    _safeNotifyListeners();

    //  VALIDATE COORDINATES
    if (latitude != null && longitude != null) {
      if (latitude.abs() > 90 || longitude.abs() > 180) {
        _errorMessage = 'Tọa độ không hợp lệ (lat: [-90,90], lon: [-180,180])';
        _isLoading = false;
        _isFetchingNearby = false;
        _safeNotifyListeners();
        return;
      }
    }

    // Update filters
    if (radius != null) _currentRadius = radius;
    if (minPrice != null) _currentMinPrice = minPrice;
    if (maxPrice != null) _currentMaxPrice = maxPrice;

    debugPrint(' fetchNearbyRentals called with:');
    debugPrint('   Rental ID: $rentalId');
    debugPrint('   Radius: $_currentRadius km');
    debugPrint('   MinPrice: $_currentMinPrice');
    debugPrint('   MaxPrice: $_currentMaxPrice');

    if (latitude != null && longitude != null) {
      debugPrint('   Coordinates: ($latitude, $longitude)');
    }

    try {
      Map<String, dynamic> result;

      //DECIDE WHICH ENDPOINT TO USE
      if (rentalId.startsWith('current_location_') && latitude != null && longitude != null) {
        debugPrint(' Using fetchNearbyFromLocation (current location view)');

        result = await _rentalService.fetchNearbyFromLocation(
          latitude: latitude,
          longitude: longitude,
          radius: _currentRadius,
          minPrice: _currentMinPrice,
          maxPrice: _currentMaxPrice,
          limit: 20,
        );
      } else {
        debugPrint(' Using fetchNearbyRentals (rental post view)');

        //  Validate rentalId
        if (rentalId.isEmpty || rentalId.startsWith('current_location_')) {
          throw Exception(
              'Invalid rental ID: $rentalId. Use location coordinates instead.'
          );
        }

        result = await _rentalService.fetchNearbyRentals(
          rentalId: rentalId,
          radius: _currentRadius,
          minPrice: _currentMinPrice,
          maxPrice: _currentMaxPrice,
          limit: 20,
        );
      }

      if (_isFetchingNearby) {
        _nearbyRentals = result['rentals'] ?? [];
        _warningMessage = result['warning'];

        debugPrint(' Fetched ${_nearbyRentals.length} nearby rentals');
        if (_warningMessage != null) {
          debugPrint(' Warning: $_warningMessage');
        }
      }
    } catch (e) {
      if (_isFetchingNearby) {
        //  USER-FRIENDLY ERROR MESSAGES
        String errorMsg = e.toString();

        if (errorMsg.contains('Invalid coordinates')) {
          _errorMessage = 'Tọa độ không hợp lệ. Vui lòng thử lại.';
        } else if (errorMsg.contains('Invalid rental ID')) {
          _errorMessage = 'ID bài đăng không hợp lệ.';
        } else if (errorMsg.contains('Bài đăng không tìm thấy')) {
          _errorMessage = 'Bài đăng không tìm thấy.';
        } else if (errorMsg.contains('timeout')) {
          _errorMessage = 'Quá thời gian chờ. Vui lòng thử lại với bán kính nhỏ hơn.';
        } else if (errorMsg.contains('Lỗi kết nối')) {
          _errorMessage = 'Lỗi kết nối mạng. Vui lòng kiểm tra internet.';
        } else if (errorMsg.contains('Lỗi máy chủ')) {
          _errorMessage = 'Lỗi máy chủ. Vui lòng thử lại sau.';
        } else {
          _errorMessage = 'Không thể tải dữ liệu gần đây';
        }

        debugPrint(' Error in fetchNearbyRentals: $_errorMessage');
        debugPrint('   Original error: $e');
      }
    } finally {
      _isFetchingNearby = false;
      _isLoading = false;
      _safeNotifyListeners();
    }
  }
  //  Cancel ongoing nearby fetch =========================================================
  void cancelNearbyFetch() {
    _isFetchingNearby = false;
    debugPrint('🚫 Cancelled nearby rentals fetch');
  }
  // Refresh tất cả dữ liệu rental (gọi khi có cập nhật từ MyPostsView/EditRentalScreen) =========================================================
  Future<void> refreshAllRentals() async {
    try {
      debugPrint(' RentalViewModel: Refreshing all rentals...');
      _isLoading = true;
      _safeNotifyListeners();

      await fetchAllRentals();

      debugPrint(' RentalViewModel: Rentals refreshed successfully');
    } catch (e) {
      debugPrint(' RentalViewModel: Error refreshing rentals: $e');
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

  //Xóa bài đăng khỏi danh sách cục bộ (cập nhật UI ngay lập tức) =========================================================
  void removeRentalLocally(String rentalId) {
    try {
      _rentals.removeWhere((rental) => rental.id == rentalId);
      debugPrint(' RentalViewModel: Rental $rentalId removed locally');
      _safeNotifyListeners();
    } catch (e) {
      debugPrint(' Error removing rental locally: $e');
    }
  }

  //Cập nhật bài đăng trong danh sách cục bộ =========================================================
  void updateRentalLocally(String rentalId, Rental updatedRental) {
    try {
      final index = _rentals.indexWhere((rental) => rental.id == rentalId);
      if (index != -1) {
        _rentals[index] = updatedRental;
        debugPrint(' RentalViewModel: Rental $rentalId updated locally');
        _safeNotifyListeners();
      }
    } catch (e) {
      debugPrint(' Error updating rental locally: $e');
    }
  }

  // Xóa bài đăng khỏi danh sách nearby rentals =========================================================
  void removeNearbyRentalLocally(String rentalId) {
    try {
      _nearbyRentals.removeWhere((rental) => rental.id == rentalId);
      debugPrint(' RentalViewModel: Nearby rental $rentalId removed locally');
      _safeNotifyListeners();
    } catch (e) {
      debugPrint(' Error removing nearby rental locally: $e');
    }
  }

  //Cập nhật bài đăng trong danh sách nearby rentals =========================================================
  void updateNearbyRentalLocally(String rentalId, Rental updatedRental) {
    try {
      final index = _nearbyRentals.indexWhere((rental) => rental.id == rentalId);
      if (index != -1) {
        _nearbyRentals[index] = updatedRental;
        debugPrint(' RentalViewModel: Nearby rental $rentalId updated locally');
        _safeNotifyListeners();
      }
    } catch (e) {
      debugPrint(' Error updating nearby rental locally: $e');
    }
  }

  //Cập nhật search results (sau khi edit/delete) =========================================================
  void removeFromSearchResults(String rentalId) {
    try {
      _searchResults.removeWhere((rental) => rental.id == rentalId);
      _total = (_total > 0) ? _total - 1 : 0;
      debugPrint('✅ RentalViewModel: Rental $rentalId removed from search results');
      notifyListeners();
    } catch (e) {
      debugPrint(' Error removing from search results: $e');
    }
  }
  // Cập nhật bài đăng trong search results =========================================================
  void updateInSearchResults(String rentalId, Rental updatedRental) {
    try {
      final index = _searchResults.indexWhere((rental) => rental.id == rentalId);
      if (index != -1) {
        _searchResults[index] = updatedRental;
        debugPrint('✅ RentalViewModel: Rental $rentalId updated in search results');
        notifyListeners();
      }
    } catch (e) {
      debugPrint(' Error updating search results: $e');
    }
  }
  // ============================================
  // Reset bộ lọc
  void resetNearbyFilters() {
    _currentRadius = 10.0;
    _currentMinPrice = null;
    _currentMaxPrice = null;
    notifyListeners();
  }

  // ============================================
  //Clear tất cả error messages
  void clearErrors() {
    _errorMessage = null;
    _warningMessage = null;
    _safeNotifyListeners();
  }

  // ============================================
  //  PAYMENT HELPER METHODS
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

  // =====================================================================================================
  // THÊM CÁC PHƯƠNG THỨC LIÊN QUAN ĐẾN AI RECOMMENDATIONS
  Future<void> fetchAIRecommendations({
    required double latitude,
    required double longitude,
    double? radius,
    double? minPrice,
    double? maxPrice,
  }) async {
    // Cancel if already fetching
    if (_isFetchingNearby) {
      debugPrint('⚠️ Already fetching, skipping AI recommendations...');
      return;
    }

    _isFetchingNearby = true;
    _isLoading = true;
    _errorMessage = null;
    _warningMessage = null;
    _isAIRecommendation = false;
    _aiRecommendationMessage = null;
    notifyListeners();

    // Validate coordinates
    if (latitude.abs() > 90 || longitude.abs() > 180) {
      _errorMessage = 'Tọa độ không hợp lệ (lat: [-90,90], lon: [-180,180])';
      _isLoading = false;
      _isFetchingNearby = false;
      notifyListeners();
      return;
    }

    // Update filters
    if (radius != null) _currentRadius = radius;
    if (minPrice != null) _currentMinPrice = minPrice;
    if (maxPrice != null) _currentMaxPrice = maxPrice;

    try {
      final token = await AuthService().getIdToken();

      if (token == null) {
        throw Exception('Vui lòng đăng nhập để xem gợi ý AI');
      }

      final result = await _rentalService.fetchAIRecommendations(
        latitude: latitude,
        longitude: longitude,
        radius: _currentRadius,
        minPrice: _currentMinPrice,
        maxPrice: _currentMaxPrice,
        limit: 20,
        token: token,
      );

      if (_isFetchingNearby) {

        _nearbyRentals = [];
        _nearbyRentals = result['rentals'] ?? [];
        _isAIRecommendation = result['isAIRecommendation'] ?? false;
        _aiRecommendationMessage = result['message'] ?? 'Gợi ý';

        debugPrint('✅ [AI-RECOMMENDATIONS] Success');
        debugPrint('   Found: ${_nearbyRentals.length} rentals');
        debugPrint('   Is AI: $_isAIRecommendation');
        debugPrint('   Message: $_aiRecommendationMessage');


        notifyListeners();
      }
    } catch (e) {
      if (_isFetchingNearby) {
        String errorMsg = e.toString();

        if (errorMsg.contains('Invalid coordinates')) {
          _errorMessage = 'Tọa độ không hợp lệ. Vui lòng thử lại.';
        } else if (errorMsg.contains('đăng nhập')) {
          _errorMessage = errorMsg.replaceAll('Exception: ', '');
        } else if (errorMsg.contains('401')) {
          _errorMessage = 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
        } else if (errorMsg.contains('timeout')) {
          _errorMessage = 'Quá thời gian chờ. Vui lòng thử lại.';
        } else if (errorMsg.contains('Lỗi kết nối')) {
          _errorMessage = 'Lỗi kết nối mạng. Vui lòng kiểm tra internet.';
        } else if (errorMsg.contains('Lỗi máy chủ')) {
          _errorMessage = 'Lỗi máy chủ. Vui lòng thử lại sau.';
        } else {
          _errorMessage = 'Không thể tải gợi ý AI';
        }

        debugPrint('❌ [AI-RECOMMENDATIONS] Error: $_errorMessage');
        debugPrint('   Original: $e');

        // Fallback to empty list
        _nearbyRentals = [];
        _isAIRecommendation = false;

        notifyListeners();
      }
    } finally {
      _isFetchingNearby = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  // =====================================================================================================
  /// Fetch AI-powered nearby recommendations for a specific rental
  Future<void> fetchAINearbyRecommendations({
    required String rentalId,
    double? radius,
  }) async {
    // Cancel if already fetching
    if (_isFetchingNearby) {
      return;
    }

    _isFetchingNearby = true;
    _isLoading = true;
    _errorMessage = null;
    _warningMessage = null;
    _isAIRecommendation = false;
    _aiRecommendationMessage = null;
    notifyListeners();

    // Validate rentalId
    if (rentalId.isEmpty || rentalId.startsWith('current_location_')) {
      _errorMessage = 'ID bài đăng không hợp lệ.';
      _isLoading = false;
      _isFetchingNearby = false;
      notifyListeners();
      return;
    }

    // Update radius if provided
    if (radius != null) _currentRadius = radius;

    try {
      final token = await AuthService().getIdToken();

      if (token == null) {
        throw Exception('Vui lòng đăng nhập để xem gợi ý AI');
      }

      debugPrint(' Got authentication token');

      final result = await _rentalService.fetchAINearbyRecommendations(
        rentalId: rentalId,
        radius: _currentRadius,
        limit: 20,
        token: token,
      );

      if (_isFetchingNearby) {
        //  Cập nhật dữ liệu rõ ràng
        _nearbyRentals = [];
        _nearbyRentals = result['rentals'] ?? [];
        _isAIRecommendation = result['isAIRecommendation'] ?? false;
        _aiRecommendationMessage = result['message'] ?? 'Gợi ý gần đây';

        //  Notify ngay sau khi update dữ liệu
        notifyListeners();
      }
    } catch (e) {
      if (_isFetchingNearby) {
        String errorMsg = e.toString();

        if (errorMsg.contains('Rental not found')) {
          _errorMessage = 'Bài đăng không tìm thấy.';
        } else if (errorMsg.contains('Invalid rental ID')) {
          _errorMessage = 'ID bài đăng không hợp lệ.';
        } else if (errorMsg.contains('đăng nhập')) {
          _errorMessage = errorMsg.replaceAll('Exception: ', '');
        } else if (errorMsg.contains('401')) {
          _errorMessage = 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
        } else if (errorMsg.contains('timeout')) {
          _errorMessage = 'Quá thời gian chờ. Vui lòng thử lại.';
        } else if (errorMsg.contains('Lỗi kết nối')) {
          _errorMessage = 'Lỗi kết nối mạng. Vui lòng kiểm tra internet.';
        } else {
          _errorMessage = 'Không thể tải gợi ý AI';
        }

        // Fallback to empty list
        _nearbyRentals = [];
        _isAIRecommendation = false;

        notifyListeners();
      }
    } finally {
      _isFetchingNearby = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch POI categories
  Future<void> fetchPOICategories() async {
    try {
      _poiCategories = await _poiService.getCategories();
      debugPrint('✅ Loaded ${_poiCategories.length} POI categories');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error fetching POI categories: $e');
    }
  }

  /// Fetch POIs near location
  Future<void> fetchPOIsNearLocation({
    required double latitude,
    required double longitude,
    String? category,
    double radius = 5.0,
  }) async {
    try {
      _nearbyPOIs = await _poiService.getPOIsNearby(
        latitude: latitude,
        longitude: longitude,
        category: category,
        radius: radius,
      );

      debugPrint('✅ Found ${_nearbyPOIs.length} POIs');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error fetching POIs: $e');
      _errorMessage = 'Không thể tải danh sách tiện ích: $e';
      notifyListeners();
    }
  }

  /// Toggle POI category selection
  void togglePOICategory(String categoryId) {
    if (_selectedPOICategories.contains(categoryId)) {
      _selectedPOICategories.remove(categoryId);
    } else {
      _selectedPOICategories.add(categoryId);
    }
    notifyListeners();
  }

  /// Clear POI selections
  void clearPOISelections() {
    _selectedPOICategories.clear();
    notifyListeners();
  }

  /// Fetch AI + POI combined recommendations
  Future<void> fetchAIPOIRecommendations({
    required double latitude,
    required double longitude,
    double? radius,
    double? minPrice,
    double? maxPrice,
  }) async {
    if (_isFetchingNearby) {
      debugPrint('⚠️ Already fetching');
      return;
    }

    _isFetchingNearby = true;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _poiService.getAIPOIRecommendations(
        latitude: latitude,
        longitude: longitude,
        selectedCategories: _selectedPOICategories,
        radius: radius ?? _currentRadius,
        minPrice: minPrice ?? _currentMinPrice,
        maxPrice: maxPrice ?? _currentMaxPrice,
        limit: 20,
      );

      if (_isFetchingNearby) {
        _nearbyRentals = [];
        _nearbyRentals = result['rentals'] ?? [];
        _isAIRecommendation = result['isAIRecommendation'] ?? false;
        _aiRecommendationMessage = result['message'] ?? '';

        debugPrint('✅ AI+POI: ${_nearbyRentals.length} rentals');
        notifyListeners();
      }
    } catch (e) {
      if (_isFetchingNearby) {
        _errorMessage = 'Không thể tải gợi ý AI+POI: $e';
        _nearbyRentals = [];
        _isAIRecommendation = false;
        notifyListeners();
      }
    } finally {
      _isFetchingNearby = false;
      _isLoading = false;
      notifyListeners();
    }
  }

}