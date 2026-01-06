import 'package:flutter/foundation.dart';

import '../services/AnalyticsService.dart';


class AnalyticsViewModel extends ChangeNotifier {
  final AnalyticsService _analyticsService = AnalyticsService();

  // State variables
  bool _isLoading = false;
  String? _errorMessage;
  String _selectedPeriod = 'day';

  // Data variables
  Map<String, dynamic> _overviewData = {};
  List<dynamic> _priceDistribution = [];
  Map<String, dynamic> _timelineData = {};
  Map<String, dynamic> _locationStats = {};
  List<dynamic> _hotAreas = [];
  List<dynamic> _trendingAreas = [];
  List<dynamic> _propertyTypes = [];

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get selectedPeriod => _selectedPeriod;

  Map<String, dynamic> get overviewData => _overviewData;
  List<dynamic> get priceDistribution => _priceDistribution;
  Map<String, dynamic> get timelineData => _timelineData;
  Map<String, dynamic> get locationStats => _locationStats;
  List<dynamic> get hotAreas => _hotAreas;
  List<dynamic> get trendingAreas => _trendingAreas;
  List<dynamic> get propertyTypes => _propertyTypes;

  // ============ FETCH METHODS ============

  /// Tải tổng quan
  Future<void> fetchOverview() async {
    try {
      _overviewData = await _analyticsService.fetchOverview();
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('Error fetching overview: $e');
      notifyListeners();
    }
  }

  /// Tải phân bố giá
  Future<void> fetchPriceDistribution() async {
    try {
      _priceDistribution = await _analyticsService.fetchPriceDistribution();
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('Error fetching price distribution: $e');
      notifyListeners();
    }
  }

  /// Tải timeline
  Future<void> fetchPostsTimeline({String period = 'day'}) async {
    try {
      _timelineData = await _analyticsService.fetchPostsTimeline(period: period);
      _selectedPeriod = period;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('Error fetching timeline: $e');
      notifyListeners();
    }
  }

  /// Tải thống kê khu vực
  Future<void> fetchLocationStats() async {
    try {
      _locationStats = await _analyticsService.fetchLocationStats();
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('Error fetching location stats: $e');
      notifyListeners();
    }
  }

  /// Tải khu vực nóng
  Future<void> fetchHottestAreas({int days = 7}) async {
    try {
      _hotAreas = await _analyticsService.fetchHottestAreas(days: days);
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('Error fetching hottest areas: $e');
      notifyListeners();
    }
  }

  /// Tải khu vực trending
  Future<void> fetchTrendingAreas({int days = 7}) async {
    try {
      _trendingAreas = await _analyticsService.fetchTrendingAreas(days: days);
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('Error fetching trending areas: $e');
      notifyListeners();
    }
  }

  /// Tải loại nhà
  Future<void> fetchPropertyTypes() async {
    try {
      _propertyTypes = await _analyticsService.fetchPropertyTypes();
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('Error fetching property types: $e');
      notifyListeners();
    }
  }

  /// Tải tất cả dữ liệu
  Future<void> fetchAllAnalytics() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await Future.wait([
        fetchOverview(),
        fetchPriceDistribution(),
        fetchPostsTimeline(),
        fetchLocationStats(),
        fetchHottestAreas(),
        fetchTrendingAreas(),
        fetchPropertyTypes(),
      ]);

      debugPrint('✅ All analytics loaded successfully');
    } catch (e) {
      _errorMessage = 'Lỗi tải dữ liệu: $e';
      debugPrint('❌ Error loading analytics: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ============ HELPER METHODS ============

  /// Format giá
  String formatPrice(dynamic price) {
    return _analyticsService.formatPrice(price);
  }

  /// Tính phần trăm
  double calculatePercentage(int value, int total) {
    return _analyticsService.calculatePercentage(value, total);
  }

  /// Lấy giá trung bình
  double getAveragePrice() {
    return (_overviewData['priceStats']?['avgPrice'] ?? 0.0).toDouble();
  }

  /// Lấy giá cao nhất
  double getMaxPrice() {
    return (_overviewData['priceStats']?['maxPrice'] ?? 0.0).toDouble();
  }

  /// Lấy giá thấp nhất
  double getMinPrice() {
    return (_overviewData['priceStats']?['minPrice'] ?? 0.0).toDouble();
  }

  /// Lấy diện tích trung bình
  double getAverageArea() {
    return (_overviewData['areaStats']?['avgArea'] ?? 0.0).toDouble();
  }

  /// Lấy tổng số BĐS
  int getTotalRentals() {
    return _overviewData['totalRentals'] ?? 0;
  }

  /// Lấy tổng BĐS nóng nhất (top area)
  String getHottestArea() {
    if (_hotAreas.isEmpty) return 'N/A';
    return _hotAreas.first['_id'] ?? 'N/A';
  }

  /// Lấy số BĐS ở khu vực nóng nhất
  int getHottestAreaCount() {
    if (_hotAreas.isEmpty) return 0;
    return _hotAreas.first['count'] ?? 0;
  }

  /// Lấy khu vực trending nhất
  String getTrendingArea() {
    if (_trendingAreas.isEmpty) return 'N/A';
    return _trendingAreas.first['_id'] ?? 'N/A';
  }

  /// Lấy lượt xem khu vực trending nhất
  int getTrendingAreaViews() {
    if (_trendingAreas.isEmpty) return 0;
    return _trendingAreas.first['totalViews'] ?? 0;
  }

  /// Xóa lỗi
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Reset tất cả dữ liệu
  void resetData() {
    _overviewData = {};
    _priceDistribution = [];
    _timelineData = {};
    _locationStats = {};
    _hotAreas = [];
    _trendingAreas = [];
    _propertyTypes = [];
    _errorMessage = null;
    notifyListeners();
  }
}