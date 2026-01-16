import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_rentalhouse/services/rental_service.dart';
import '../models/poi.dart';
import '../services/ai_service.dart';
import '../services/api_service.dart';
import '../models/rental.dart';
import '../services/auth_service.dart';
import '../services/poi_service.dart';



/// Class lưu trữ AI explanation data
class AIExplanation {
  final Map<String, double> scores;
  final Map<String, String> reasons;
  final Rental? rental;
  final String? rawExplanation;

  // 🔥 NEW: Store full explanation data for UI
  Map<String, dynamic>? explanation;

  AIExplanation({
    required this.scores,
    required this.reasons,
    this.rental,
    this.rawExplanation,
    this.explanation,
  });

  String getPrimaryReason() {
    if (reasons.isEmpty) return 'Phù hợp với tiêu chí của bạn';
    return reasons.values.first;
  }

  String getFormattedReasons() {
    return reasons.entries
        .map((e) => '• ${_formatReasonLabel(e.key)}: ${e.value}')
        .join('\n');
  }

  // 🔥 NEW: Get insights count
  int getInsightsCount() {
    if (explanation == null) return 0;
    final insights = explanation!['insights'] as List?;
    return insights?.length ?? 0;
  }

  // 🔥 NEW: Get confidence level text
  String getConfidenceLevel() {
    final confidence = scores['confidence'] ?? 0.5;
    if (confidence >= 0.8) return 'Rất cao';
    if (confidence >= 0.6) return 'Cao';
    if (confidence >= 0.4) return 'Trung bình';
    return 'Thấp';
  }

  // 🔥 NEW: Get score summary
  String getScoreSummary() {
    final priceMatch = ((scores['price_match'] ?? 0) * 100).toInt();
    final locationMatch = ((scores['location_match'] ?? 0) * 100).toInt();
    final typeMatch = ((scores['property_type_match'] ?? 0) * 100).toInt();

    return 'Giá: $priceMatch% • Vị trí: $locationMatch% • Loại: $typeMatch%';
  }

  String _formatReasonLabel(String key) {
    const labels = {
      'collaborative': 'Người dùng tương tự',
      'location': 'Vị trí',
      'price': 'Giá',
      'property_type': 'Loại BĐS',
      'amenities': 'Tiện ích',
      'timing': 'Thời điểm',
      'engagement': 'Quan tâm',
    };

    return labels[key] ?? key
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}

/// Class lưu trữ user preferences
class UserPreferences {
  final String userId;
  final int totalInteractions;
  final double avgPrice;
  final String priceRange;
  final String favoritePropertyType;
  final List<LocationCount> topLocations;
  final Map<String, dynamic> detailed;

  UserPreferences({
    required this.userId,
    required this.totalInteractions,
    required this.avgPrice,
    required this.priceRange,
    required this.favoritePropertyType,
    required this.topLocations,
    required this.detailed,
  });

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] as Map<String, dynamic>;

    final topLocations = (summary['topLocations'] as List?)
        ?.map((loc) {
      if (loc is Map) {
        return LocationCount(
          location: loc['location'] as String? ?? '',
          count: loc['count'] as int? ?? 0,
        );
      }
      return LocationCount(location: '', count: 0);
    })
        .toList() ?? [];

    return UserPreferences(
      userId: json['userId'] ?? '',
      totalInteractions: summary['totalInteractions'] as int? ?? 0,
      avgPrice: (summary['avgPrice'] as num?)?.toDouble() ?? 0.0,
      priceRange: summary['priceRange'] as String? ?? 'Unknown',
      favoritePropertyType: summary['favoritePropertyType'] as String? ?? 'Unknown',
      topLocations: topLocations,
      detailed: json['detailed'] as Map<String, dynamic>? ?? {},
    );
  }
}

class LocationCount {
  final String location;
  final int count;

  LocationCount({required this.location, required this.count});
}

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

  // ==================== AI EXPLANATION STATE ====================
  AIExplanation? _currentExplanation;
  bool _isLoadingExplanation = false;
  String? _explanationError;

  // ==================== USER PREFERENCES STATE ====================
  UserPreferences? _userPreferences;
  bool _isLoadingPreferences = false;
  String? _preferencesError;

  // ==================== AI SERVICE ==========
  final AIService _aiService = AIService();



  //  ========================================================= =========================================================
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

  // ==================== AI EXPLANATION GETTERS ====================
  AIExplanation? get currentExplanation => _currentExplanation;
  bool get isLoadingExplanation => _isLoadingExplanation;
  String? get explanationError => _explanationError;

  // ==================== USER PREFERENCES GETTERS ====================
  UserPreferences? get userPreferences => _userPreferences;
  bool get isLoadingPreferences => _isLoadingPreferences;
  String? get preferencesError => _preferencesError;

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

  // ==================== FETCH AI EXPLANATION ====================
  Future<void> fetchAIExplanation({
    required String userId,
    required String rentalId,
  }) async {
    _isLoadingExplanation = true;
    _explanationError = null;
    notifyListeners();

    int retryCount = 0;
    const maxRetries = 3;  // 🔥 Tăng lên 3 lần retry

    while (retryCount <= maxRetries) {
      try {
        final token = await AuthService().getIdToken();
        if (token == null) {
          throw Exception('Vui lòng đăng nhập');
        }

        debugPrint('🤔 [EXPLANATION] Attempt ${retryCount + 1}/${maxRetries + 1} for rental: $rentalId');

        // 🔥 Tăng timeout dần dần: 30s -> 45s -> 60s
        final timeoutDuration = Duration(seconds: 30 + (retryCount * 15));

        final result = await _aiService.fetchAIExplanation(
          userId: userId,
          rentalId: rentalId,
          token: token,
        ).timeout(timeoutDuration);

        if (result['success'] != null && result['success'] == true) {
          final explanation = result['explanation'] as Map<String, dynamic>;

          // 🔥 PARSE SCORES with better error handling
          final rawScores = (explanation['scores'] as Map?);
          final Map<String, double> scores = {};

          if (rawScores != null) {
            rawScores.forEach((key, value) {
              if (value is double) {
                scores[key] = value;
              } else if (value is int) {
                scores[key] = value.toDouble();
              } else if (value is String) {
                scores[key] = double.tryParse(value) ?? 0.0;
              } else {
                scores[key] = 0.0;
              }
            });
          }

          // 🔥 PARSE REASONS with better error handling
          final rawReasons = (explanation['reasons'] as Map?);
          final Map<String, String> reasons = {};

          if (rawReasons != null) {
            rawReasons.forEach((key, value) {
              reasons[key] = value?.toString() ?? '';
            });
          }

          // Parse rental data if available
          final rentalData = explanation['rental_features'] as Map<String, dynamic>?;
          final rental = rentalData != null && rentalData.containsKey('_id')
              ? Rental.fromJson(rentalData)
              : null;

          _currentExplanation = AIExplanation(
            scores: scores,
            reasons: reasons,
            rental: rental,
            rawExplanation: explanation.toString(),
          );

          // 🔥 Store full explanation data for UI
          if (_currentExplanation != null) {
            _currentExplanation!.explanation = explanation;
          }

          debugPrint('✅ [EXPLANATION] Loaded successfully on attempt ${retryCount + 1}');
          debugPrint('   Confidence: ${scores['confidence']}');
          debugPrint('   Reasons: ${reasons.length}');
          debugPrint('   Insights: ${explanation['insights']?.length ?? 0}');

          _isLoadingExplanation = false;
          notifyListeners();
          return;  // ✅ Success - exit loop
        } else {
          throw Exception('Không thể tải giải thích');
        }
      } catch (e) {
        final errorMsg = e.toString();

        // 🔥 Check error types
        final isTimeoutError = errorMsg.contains('TimeoutException') ||
            errorMsg.contains('timeout');
        final isNetworkError = errorMsg.contains('SocketException') ||
            errorMsg.contains('Failed host lookup');
        final is404Error = errorMsg.contains('404') ||
            errorMsg.contains('Not Found');

        debugPrint('❌ [EXPLANATION] Error on attempt ${retryCount + 1}: $errorMsg');

        // 🔥 Retry logic
        if ((isTimeoutError || isNetworkError) && retryCount < maxRetries) {
          debugPrint('🔄 [EXPLANATION] Retrying... (${retryCount + 1}/${maxRetries})');
          retryCount++;

          // Exponential backoff: 1s -> 2s -> 4s
          final waitTime = Duration(seconds: 1 << retryCount);
          debugPrint('⏳ Waiting ${waitTime.inSeconds}s before retry...');
          await Future.delayed(waitTime);
          continue;  // 🔥 Retry
        }

        // 🔥 Set user-friendly error message
        if (is404Error) {
          _explanationError = 'Bài đăng này chưa có giải thích. Có thể chưa được AI phân tích.';
        } else if (isTimeoutError) {
          _explanationError = 'Kết nối chậm. Vui lòng thử lại sau.';
        } else if (isNetworkError) {
          _explanationError = 'Lỗi kết nối mạng. Vui lòng kiểm tra internet.';
        } else if (errorMsg.contains('đăng nhập')) {
          _explanationError = 'Vui lòng đăng nhập để xem giải thích';
        } else {
          _explanationError = errorMsg.replaceAll('Exception: ', '');
        }

        _isLoadingExplanation = false;
        notifyListeners();
        return;  // ❌ Exit loop
      }
    }

    // 🔥 If we reach here, all retries failed
    _explanationError = 'Không thể tải giải thích sau ${maxRetries + 1} lần thử. Vui lòng thử lại sau.';
    _isLoadingExplanation = false;
    notifyListeners();
  }

  // ==================== FETCH USER PREFERENCES ====================
  Future<void> fetchUserPreferences({required String userId}) async {
    _isLoadingPreferences = true;
    _preferencesError = null;
    notifyListeners();

    try {
      final token = await AuthService().getIdToken();
      if (token == null) {
        throw Exception('Vui lòng đăng nhập');
      }

      final result = await _aiService.fetchUserPreferences(
        userId: userId,
        token: token,
      );

      if (result['success'] == true && result['preferences'] != null) {
        _userPreferences = UserPreferences.fromJson(result['preferences']);

        debugPrint('✅ [USER-PREFS] Loaded successfully');
        debugPrint('   Total interactions: ${_userPreferences!.totalInteractions}');
        debugPrint('   Avg price: ${_userPreferences!.avgPrice}');
        debugPrint('   Favorite type: ${_userPreferences!.favoritePropertyType}');
      } else {
        debugPrint('⚠️ [USER-PREFS] No preferences found');
        _preferencesError = result['message'] as String?;
      }
    } catch (e) {
      _preferencesError = e.toString().replaceAll('Exception: ', '');
      debugPrint('❌ [USER-PREFS] Error: $_preferencesError');
    } finally {
      _isLoadingPreferences = false;
      notifyListeners();
    }
  }

  // ==================== FETCH AI RECOMMENDATIONS WITH CONTEXT ====================
  Future<void> fetchAIRecommendationsWithContext({
    required double latitude,
    required double longitude,
    double radius = 10.0,
    int zoomLevel = 15,
    String timeOfDay = 'morning',
    String deviceType = 'mobile',
    List<String> impressions = const [],
    double scrollDepth = 0.5,
  }) async {
    if (_isFetchingNearby) {
      debugPrint('⚠️ Already fetching, skipping...');
      return;
    }

    _isFetchingNearby = true;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    if (latitude.abs() > 90 || longitude.abs() > 180) {
      _errorMessage = 'Tọa độ không hợp lệ';
      _isLoading = false;
      _isFetchingNearby = false;
      notifyListeners();
      return;
    }

    try {
      final token = await AuthService().getIdToken();
      if (token == null) {
        throw Exception('Vui lòng đăng nhập để xem gợi ý AI');
      }

      debugPrint('🎯 [AI-CONTEXT] Fetching with context:');
      debugPrint('   Coords: ($latitude, $longitude)');
      debugPrint('   Zoom: $zoomLevel, Time: $timeOfDay');
      debugPrint('   Impressions: ${impressions.length}');

      final result = await _aiService.fetchAIRecommendationsWithContext(
        latitude: latitude,
        longitude: longitude,
        radius: radius,
        zoomLevel: zoomLevel,
        timeOfDay: timeOfDay,
        deviceType: deviceType,
        limit: 20,
        impressions: impressions,
        scrollDepth: scrollDepth,
        minPrice: _currentMinPrice,
        maxPrice: _currentMaxPrice,
        token: token,
      );

      if (_isFetchingNearby && result['success'] == true) {
        _nearbyRentals = result['rentals'] as List<Rental>? ?? [];
        _isAIRecommendation = true;
        _aiRecommendationMessage = 'Gợi ý được cá nhân hóa từ trợ lý AI';

        debugPrint('✅ [AI-CONTEXT] Success: ${_nearbyRentals.length} rentals');

        if (result['personalization'] != null) {
          final personalization = result['personalization'];
          debugPrint('   Avg Confidence: ${personalization['avgConfidence']}');
          debugPrint('   Avg Marker Size: ${personalization['avgMarkerSize']}');
        }

        notifyListeners();
      }
    } catch (e) {
      if (_isFetchingNearby) {
        String errorMsg = e.toString();

        if (errorMsg.contains('đăng nhập')) {
          _errorMessage = 'Vui lòng đăng nhập để sử dụng gợi ý AI';
        } else if (errorMsg.contains('Invalid coordinates')) {
          _errorMessage = 'Tọa độ không hợp lệ';
        } else if (errorMsg.contains('timeout')) {
          _errorMessage = 'Quá thời gian chờ. Vui lòng thử lại.';
        } else {
          _errorMessage = 'Không thể tải gợi ý AI';
        }

        debugPrint('❌ [AI-CONTEXT] Error: $_errorMessage');

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

  // ==================== HELPER METHODS ====================

  void clearAIData() {
    _currentExplanation = null;
    _userPreferences = null;
    _explanationError = null;
    _preferencesError = null;
    notifyListeners();
  }

  String getPreferencesSummary() {
    if (_userPreferences == null) return 'Chưa tải preferences';

    final prefs = _userPreferences!;
    return '${prefs.priceRange} • ${prefs.favoritePropertyType} • ${prefs.topLocations.isNotEmpty ? prefs.topLocations.first.location : 'Không xác định'}';
  }

  String getExplanationSummary() {
    if (_currentExplanation == null) return 'Chưa có giải thích';

    final exp = _currentExplanation!;
    final confidence = (exp.scores['confidence'] ?? 0) * 100;
    final reason = exp.getPrimaryReason();

    return 'Tự tin ${confidence.toStringAsFixed(0)}% • $reason';
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