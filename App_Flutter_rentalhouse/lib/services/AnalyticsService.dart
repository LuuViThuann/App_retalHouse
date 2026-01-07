import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../config/api_routes.dart';

class AnalyticsService {
  /// ✅ Helper: Build query parameters from filters
  String _buildQueryParams(Map<String, String?>? filters) {
    if (filters == null || filters.isEmpty) return '';

    final params = filters.entries
        .where((e) => e.value != null && e.value!.isNotEmpty)
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value!)}')
        .join('&');

    return params.isEmpty ? '' : '?$params';
  }

  /// Lấy tổng quan thống kê
  Future<Map<String, dynamic>> fetchOverview({Map<String, String?>? filters}) async {
    try {
      final queryParams = _buildQueryParams(filters);
      final response = await http.get(
        Uri.parse('${ApiRoutes.analyticsOverview}$queryParams'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Timeout: Không thể tải tổng quan'),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Không thể tải tổng quan: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error fetching overview: $e');
      throw Exception('Lỗi tải tổng quan: $e');
    }
  }

  /// Lấy phân bố giá
  Future<List<dynamic>> fetchPriceDistribution({Map<String, String?>? filters}) async {
    try {
      final queryParams = _buildQueryParams(filters);
      final response = await http.get(
        Uri.parse('${ApiRoutes.analyticsPriceDistribution}$queryParams'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Timeout: Không thể tải phân bố giá'),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Không thể tải phân bố giá: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error fetching price distribution: $e');
      throw Exception('Lỗi tải phân bố giá: $e');
    }
  }

  /// Lấy dữ liệu timeline bài đăng
  Future<Map<String, dynamic>> fetchPostsTimeline({
    String period = 'day',
    Map<String, String?>? filters,
  }) async {
    try {
      final baseUrl = ApiRoutes.analyticsPostsTimeline(period: period);
      final queryParams = _buildQueryParams(filters);
      final separator = baseUrl.contains('?') ? '&' : '?';
      final url = queryParams.isEmpty ? baseUrl : '$baseUrl$separator${queryParams.substring(1)}';

      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Timeout: Không thể tải timeline'),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Không thể tải timeline: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error fetching timeline: $e');
      throw Exception('Lỗi tải timeline: $e');
    }
  }

  /// Lấy thống kê theo khu vực
  Future<Map<String, dynamic>> fetchLocationStats({Map<String, String?>? filters}) async {
    try {
      final queryParams = _buildQueryParams(filters);
      final response = await http.get(
        Uri.parse('${ApiRoutes.analyticsLocationStats}$queryParams'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Timeout: Không thể tải thống kê khu vực'),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Không thể tải thống kê khu vực: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error fetching location stats: $e');
      throw Exception('Lỗi tải thống kê khu vực: $e');
    }
  }

  /// Lấy khu vực có nhiều BĐS nhất
  Future<List<dynamic>> fetchHottestAreas({
    int days = 7,
    Map<String, String?>? filters,
  }) async {
    try {
      final baseUrl = ApiRoutes.analyticsHottestAreas(days: days);
      final queryParams = _buildQueryParams(filters);
      final separator = baseUrl.contains('?') ? '&' : '?';
      final url = queryParams.isEmpty ? baseUrl : '$baseUrl$separator${queryParams.substring(1)}';

      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Timeout: Không thể tải khu vực nóng'),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Không thể tải khu vực nóng: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error fetching hottest areas: $e');
      throw Exception('Lỗi tải khu vực nóng: $e');
    }
  }

  /// Lấy khu vực đang "trending"
  Future<List<dynamic>> fetchTrendingAreas({
    int days = 7,
    Map<String, String?>? filters,
  }) async {
    try {
      final baseUrl = ApiRoutes.analyticsTrendingAreas(days: days);
      final queryParams = _buildQueryParams(filters);
      final separator = baseUrl.contains('?') ? '&' : '?';
      final url = queryParams.isEmpty ? baseUrl : '$baseUrl$separator${queryParams.substring(1)}';

      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Timeout: Không thể tải khu vực trending'),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Không thể tải khu vực trending: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error fetching trending areas: $e');
      throw Exception('Lỗi tải khu vực trending: $e');
    }
  }

  /// Lấy thống kê loại nhà
  Future<List<dynamic>> fetchPropertyTypes({Map<String, String?>? filters}) async {
    try {
      final queryParams = _buildQueryParams(filters);
      final response = await http.get(
        Uri.parse('${ApiRoutes.analyticsPropertyTypes}$queryParams'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Timeout: Không thể tải loại nhà'),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Không thể tải loại nhà: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error fetching property types: $e');
      throw Exception('Lỗi tải loại nhà: $e');
    }
  }

  // ==================== HELPER METHODS ====================

  /// Format giá tiền
  String formatPrice(dynamic price) {
    if (price == null) return '0 VNĐ';
    final p = price is num ? price.toDouble() : 0.0;

    if (p >= 1000000000) {
      return '${(p / 1000000000).toStringAsFixed(1)} tỷ VNĐ';
    } else if (p >= 1000000) {
      return '${(p / 1000000).toStringAsFixed(0)} triệu VNĐ';
    } else if (p >= 1000) {
      return '${(p / 1000).toStringAsFixed(0)} nghìn VNĐ';
    }
    return '${p.toStringAsFixed(0)} VNĐ';
  }

  /// Format giá rút gọn (cho chart)
  String formatPriceShort(dynamic price) {
    if (price == null) return '0';
    final p = price is num ? price.toDouble() : 0.0;

    if (p >= 1000000000) {
      return '${(p / 1000000000).toStringAsFixed(1)}T';
    } else if (p >= 1000000) {
      return '${(p / 1000000).toStringAsFixed(0)}M';
    } else if (p >= 1000) {
      return '${(p / 1000).toStringAsFixed(0)}K';
    }
    return p.toStringAsFixed(0);
  }

  /// Tính phần trăm
  double calculatePercentage(int value, int total) {
    if (total == 0) return 0;
    return (value / total) * 100;
  }

  /// Parse thời gian từ string
  String parseDateTime(String dateString, {bool isCompact = false}) {
    try {
      final date = DateTime.parse(dateString);
      if (isCompact) {
        return '${date.day}/${date.month}';
      }
      return '${date.day}-${date.month}-${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  /// Lấy top N items từ list
  List<T> getTopN<T>(List<T> items, int n) {
    return items.take(n).toList();
  }

  /// Sắp xếp items theo count (giảm dần)
  List<Map<String, dynamic>> sortByCount(List<dynamic> items) {
    final list = items.cast<Map<String, dynamic>>().toList();
    list.sort((a, b) => (b['count'] ?? 0).compareTo(a['count'] ?? 0));
    return list;
  }

  /// Lấy màu theo index
  Color getColorByIndex(int index) {
    final colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
    ];
    return colors[index % colors.length];
  }

  /// Tính giới hạn tối đa cho chart
  double getChartMaxValue(List<dynamic> data, String key) {
    if (data.isEmpty) return 100;
    final values = data.map((item) => (item[key] ?? 0) as num).toList();
    final max = values.reduce((a, b) => a > b ? a : b);
    return (max.toDouble() * 1.2); // Thêm 20% margin
  }
}