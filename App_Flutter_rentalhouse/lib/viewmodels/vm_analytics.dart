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

  // Thêm state variables:
  List<dynamic> _areaDistribution = [];
  Map<String, dynamic> _amenitiesStats = {};
  Map<String, dynamic> _userBehavior = {};
  Map<String, dynamic> _growthStats = {};

// Thêm getters:
  List<dynamic> get areaDistribution => _areaDistribution;
  Map<String, dynamic> get amenitiesStats => _amenitiesStats;
  Map<String, dynamic> get userBehavior => _userBehavior;
  Map<String, dynamic> get growthStats => _growthStats;

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

  // ============ INTERNAL SAFE HELPERS ============

  /// Convert any numeric type safely to double
  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  /// Convert any numeric type safely to int
  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  /// Get string from dynamic safely
  String _toStr(dynamic v, {String fallback = 'N/A'}) {
    if (v == null) return fallback;
    final s = v.toString().trim();
    return s.isEmpty ? fallback : s;
  }

  // ============ FETCH METHODS ============

  Future<void> fetchOverview({Map<String, String?>? filters}) async {
    try {
      _overviewData = await _analyticsService.fetchOverview(filters: filters);
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('Error fetching overview: $e');
      notifyListeners();
    }
  }

  Future<void> fetchPriceDistribution({Map<String, String?>? filters}) async {
    try {
      _priceDistribution = await _analyticsService.fetchPriceDistribution(filters: filters);
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('Error fetching price distribution: $e');
      notifyListeners();
    }
  }

  Future<void> fetchPostsTimeline({String period = 'day', Map<String, String?>? filters}) async {
    try {
      _timelineData = await _analyticsService.fetchPostsTimeline(
        period: period,
        filters: filters,
      );
      _selectedPeriod = period;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('Error fetching timeline: $e');
      notifyListeners();
    }
  }

  Future<void> fetchLocationStats({Map<String, String?>? filters}) async {
    try {
      _locationStats = await _analyticsService.fetchLocationStats(filters: filters);
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('Error fetching location stats: $e');
      notifyListeners();
    }
  }

  Future<void> fetchHottestAreas({int days = 7, Map<String, String?>? filters}) async {
    try {
      _hotAreas = await _analyticsService.fetchHottestAreas(
        days: days,
        filters: filters,
      );
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('Error fetching hottest areas: $e');
      notifyListeners();
    }
  }

  Future<void> fetchTrendingAreas({int days = 7, Map<String, String?>? filters}) async {
    try {
      _trendingAreas = await _analyticsService.fetchTrendingAreas(
        days: days,
        filters: filters,
      );
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('Error fetching trending areas: $e');
      notifyListeners();
    }
  }

  Future<void> fetchPropertyTypes({Map<String, String?>? filters}) async {
    try {
      _propertyTypes = await _analyticsService.fetchPropertyTypes(filters: filters);
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('Error fetching property types: $e');
      notifyListeners();
    }
  }

  Future<void> fetchFilteredAnalytics(Map<String, String?> filters) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await Future.wait([
        fetchOverview(filters: filters),
        fetchPriceDistribution(filters: filters),
        fetchPostsTimeline(filters: filters),
        fetchLocationStats(filters: filters),
        fetchHottestAreas(filters: filters),
        fetchTrendingAreas(filters: filters),
        fetchPropertyTypes(filters: filters),
      ]);
      debugPrint('✅ Filtered analytics loaded successfully');
    } catch (e) {
      _errorMessage = 'Lỗi tải dữ liệu lọc: $e';
      debugPrint('❌ Error loading filtered analytics: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

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

        fetchAreaDistribution(),
        fetchAmenitiesStats(),
        fetchUserBehavior(),
        fetchGrowthStats(),
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
// Thêm fetch methods:
  Future<void> fetchAreaDistribution({Map<String, String?>? filters}) async {
    try {
      _areaDistribution = await _analyticsService.fetchAreaDistribution(filters: filters);
      notifyListeners();
    } catch (e) { debugPrint('Error: $e'); }
  }

  Future<void> fetchAmenitiesStats({Map<String, String?>? filters}) async {
    try {
      _amenitiesStats = await _analyticsService.fetchAmenitiesStats(filters: filters);
      notifyListeners();
    } catch (e) { debugPrint('Error: $e'); }
  }

  Future<void> fetchUserBehavior({int days = 30}) async {
    try {
      _userBehavior = await _analyticsService.fetchUserBehavior(days: days);
      notifyListeners();
    } catch (e) { debugPrint('Error: $e'); }
  }

  Future<void> fetchGrowthStats({int months = 6}) async {
    try {
      _growthStats = await _analyticsService.fetchGrowthStats(months: months);
      notifyListeners();
    } catch (e) { debugPrint('Error: $e'); }
  }
  // ============ HELPER METHODS ============

  String formatPrice(dynamic price) {
    return _analyticsService.formatPrice(price);
  }

  double calculatePercentage(int value, int total) {
    return _analyticsService.calculatePercentage(value, total);
  }

  // ── Overview stats ────────────────────────────────────────

  double getAveragePrice() {
    return _toDouble(_overviewData['priceStats']?['avgPrice']);
  }

  double getMaxPrice() {
    return _toDouble(_overviewData['priceStats']?['maxPrice']);
  }

  double getMinPrice() {
    return _toDouble(_overviewData['priceStats']?['minPrice']);
  }

  double getAverageArea() {
    return _toDouble(_overviewData['areaStats']?['avgArea']);
  }

  int getTotalRentals() {
    return _toInt(_overviewData['totalRentals']);
  }

  // ── Hottest area ──────────────────────────────────────────

  /// FIX: Backend aggregate trả _id = tên khu vực, KHÔNG phải 'name'
  String getHottestArea() {
    if (_hotAreas.isEmpty) return 'Chưa có dữ liệu';
    final area = _hotAreas.first as Map<String, dynamic>;
    // Thử _id trước (aggregate result), fallback name
    return _toStr(area['_id'] ?? area['name'], fallback: 'Chưa có dữ liệu');
  }

  /// FIX: Safe int cast – tránh lỗi khi MongoDB trả double
  int getHottestAreaCount() {
    if (_hotAreas.isEmpty) return 0;
    final area = _hotAreas.first as Map<String, dynamic>;
    return _toInt(area['count']);
  }

  // ── Trending area ─────────────────────────────────────────

  String getTrendingArea() {
    if (_trendingAreas.isEmpty) return 'Chưa có dữ liệu';
    final area = _trendingAreas.first as Map<String, dynamic>;
    return _toStr(area['_id'] ?? area['name'], fallback: 'Chưa có dữ liệu');
  }

  int getTrendingAreaViews() {
    if (_trendingAreas.isEmpty) return 0;
    final area = _trendingAreas.first as Map<String, dynamic>;
    return _toInt(area['totalViews']);
  }

  // ── Misc ──────────────────────────────────────────────────

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

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