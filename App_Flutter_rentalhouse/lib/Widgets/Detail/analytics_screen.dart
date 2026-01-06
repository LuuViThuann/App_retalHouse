import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../config/api_routes.dart';
import '../../services/AnalyticsService.dart';


class AnalyticsScreen extends StatefulWidget {
  final String? initialRadiusKm;

  const AnalyticsScreen({Key? key, this.initialRadiusKm}) : super(key: key);

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final AnalyticsService _analyticsService = AnalyticsService();

  bool _isLoading = true;
  String? _selectedPeriod = 'day';
  Map<String, dynamic> _overviewData = {};
  List<dynamic> _priceDistribution = [];
  Map<String, dynamic> _timelineData = {};
  Map<String, dynamic> _locationStats = {};
  List<dynamic> _hotAreas = [];
  List<dynamic> _trendingAreas = [];
  List<dynamic> _propertyTypes = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchAllAnalytics();
  }

  Future<void> _fetchAllAnalytics() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await Future.wait([
        _fetchOverview(),
        _fetchPriceDistribution(),
        _fetchTimeline(),
        _fetchLocationStats(),
        _fetchHotAreas(),
        _fetchTrendingAreas(),
        _fetchPropertyTypes(),
      ]);
    } catch (e) {
      setState(() {
        _errorMessage = 'Lỗi tải dữ liệu: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchOverview() async {
    try {
      final response = await http.get(
        Uri.parse(ApiRoutes.analyticsOverview),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        setState(() {
          _overviewData = jsonDecode(response.body);
        });
      }
    } catch (e) {
      debugPrint('Error fetching overview: $e');
    }
  }

  Future<void> _fetchPriceDistribution() async {
    try {
      final response = await http.get(
        Uri.parse(ApiRoutes.analyticsPriceDistribution),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        setState(() {
          _priceDistribution = jsonDecode(response.body);
        });
      }
    } catch (e) {
      debugPrint('Error fetching price distribution: $e');
    }
  }

  Future<void> _fetchTimeline() async {
    try {
      final response = await http.get(
        Uri.parse(ApiRoutes.analyticsPostsTimeline(period: _selectedPeriod ?? 'day')),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        setState(() {
          _timelineData = jsonDecode(response.body);
        });
      }
    } catch (e) {
      debugPrint('Error fetching timeline: $e');
    }
  }

  Future<void> _fetchLocationStats() async {
    try {
      final response = await http.get(
        Uri.parse(ApiRoutes.analyticsLocationStats),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        setState(() {
          _locationStats = jsonDecode(response.body);
        });
      }
    } catch (e) {
      debugPrint('Error fetching location stats: $e');
    }
  }

  Future<void> _fetchHotAreas() async {
    try {
      final response = await http.get(
        Uri.parse(ApiRoutes.analyticsHottestAreas(days: 7)),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        setState(() {
          _hotAreas = jsonDecode(response.body);
        });
      }
    } catch (e) {
      debugPrint('Error fetching hot areas: $e');
    }
  }

  Future<void> _fetchTrendingAreas() async {
    try {
      final response = await http.get(
        Uri.parse(ApiRoutes.analyticsTrendingAreas(days: 7)),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        setState(() {
          _trendingAreas = jsonDecode(response.body);
        });
      }
    } catch (e) {
      debugPrint('Error fetching trending areas: $e');
    }
  }

  Future<void> _fetchPropertyTypes() async {
    try {
      final response = await http.get(
        Uri.parse(ApiRoutes.analyticsPropertyTypes),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        setState(() {
          _propertyTypes = jsonDecode(response.body);
        });
      }
    } catch (e) {
      debugPrint('Error fetching property types: $e');
    }
  }

  String _formatPrice(dynamic price) {
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

  // ==================== WIDGETS ====================

  Widget _buildOverviewCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tổng quan',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: [
            _buildStatCard(
              title: 'Tổng BĐS',
              value: (_overviewData['totalRentals'] ?? 0).toString(),
              icon: Icons.home,
              color: Colors.blue,
            ),
            _buildStatCard(
              title: 'Giá TB',
              value: _formatPrice(_overviewData['priceStats']?['avgPrice']),
              icon: Icons.attach_money,
              color: Colors.green,
            ),
            _buildStatCard(
              title: 'Giá cao nhất',
              value: _formatPrice(_overviewData['priceStats']?['maxPrice']),
              icon: Icons.trending_up,
              color: Colors.orange,
            ),
            _buildStatCard(
              title: 'Giá thấp nhất',
              value: _formatPrice(_overviewData['priceStats']?['minPrice']),
              icon: Icons.trending_down,
              color: Colors.red,
            ),
            _buildStatCard(
              title: 'Diện tích TB',
              value: '${(_overviewData['areaStats']?['avgArea'] ?? 0).toStringAsFixed(0)} m²',
              icon: Icons.square_foot,
              color: Colors.purple,
            ),
            _buildStatCard(
              title: 'Lớn nhất',
              value: '${(_overviewData['areaStats']?['maxArea'] ?? 0).toStringAsFixed(0)} m²',
              icon: Icons.expand,
              color: Colors.cyan,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ==================== PRICE DISTRIBUTION CHART ====================

  Widget _buildPriceDistributionChart() {
    if (_priceDistribution.isEmpty) {
      return const SizedBox.shrink();
    }

    final chartData = _priceDistribution.map((item) {
      return (
      label: (item['label'] ?? '').toString().substring(0, 3),
      count: (item['count'] ?? 0).toDouble(),
      fullLabel: item['label'] ?? '',
      color: _parseColor(item['color'] ?? '#4CAF50'),
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          '💰 Phân bố giá',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            children: [
              // Bar Chart
              SizedBox(
                height: 280,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: _getChartMaxValue(chartData.map((e) => e.count).cast<double>().toList()),
                    barTouchData: BarTouchData(enabled: true),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index < 0 || index >= chartData.length) {
                              return const SizedBox();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                chartData[index].label,
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              '${value.toInt()}',
                              style: const TextStyle(fontSize: 10),
                            );
                          },
                          reservedSize: 40,
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: chartData.asMap().entries.map((e) {
                      return BarChartGroupData(
                        x: e.key,
                        barRods: [
                          BarChartRodData(
                            toY: e.value.count,
                            color: e.value.color,
                            width: 12,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Legend
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: chartData.map((item) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: item.color,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item.fullLabel,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              // Statistics
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _priceDistribution.map<Widget>((item) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '${item['count']} bài',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${item['percentage']}%',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _parseColor(String colorStr) {
    final hex = colorStr.replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  double _getChartMaxValue(List<double> values) {
    if (values.isEmpty) return 100;
    final max = values.reduce((a, b) => a > b ? a : b);
    return max * 1.2;
  }

  // ==================== PROPERTY TYPES BAR CHART ====================

  Widget _buildPropertyTypesChart() {
    if (_propertyTypes.isEmpty) return const SizedBox.shrink();

    final chartData = _propertyTypes.take(6).map((item) {
      return (
      name: (item['_id'] ?? '?').toString().substring(0, 8),
      count: (item['count'] ?? 0).toDouble(),
      fullName: item['_id'] ?? '?',
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          '🏠 Loại bất động sản',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            children: [
              SizedBox(
                height: 280,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: _getChartMaxValue(chartData.map((e) => e.count).cast<double>().toList()),
                    barTouchData: BarTouchData(enabled: true),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index < 0 || index >= chartData.length) {
                              return const SizedBox();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                chartData[index].name,
                                style: const TextStyle(fontSize: 9),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              '${value.toInt()}',
                              style: const TextStyle(fontSize: 10),
                            );
                          },
                          reservedSize: 40,
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: chartData.asMap().entries.map((e) {
                      final colors = [
                        Colors.blue,
                        Colors.green,
                        Colors.orange,
                        Colors.red,
                        Colors.purple,
                        Colors.teal,
                      ];
                      return BarChartGroupData(
                        x: e.key,
                        barRods: [
                          BarChartRodData(
                            toY: e.value.count,
                            color: colors[e.key % colors.length],
                            width: 14,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _propertyTypes.map<Widget>((item) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['_id'] ?? '?',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${item['count']} • ${item['percentage']}%',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== HOTTEST AREAS LIST ====================

  Widget _buildHotAreas() {
    if (_hotAreas.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          '🔥 Khu vực có nhiều BĐS nhất',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            children: _hotAreas.asMap().entries.map((e) {
              final index = e.key;
              final area = e.value;
              final isHot = (area['count'] ?? 0) >= 20;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isHot ? Colors.red[50] : Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isHot ? Colors.red[300]! : Colors.grey[200]!,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${index + 1}. ${area['_id'] ?? 'N/A'}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Giá TB: ${_formatPrice(area['avgPrice'])}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isHot ? Colors.red[600] : Colors.grey[400],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${area['count']} bài',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Thống kê & Phân tích',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _fetchAllAnalytics,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(_errorMessage!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchAllAnalytics,
              child: const Text('Thử lại'),
            ),
          ],
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOverviewCards(),
            _buildPriceDistributionChart(),
            _buildPropertyTypesChart(),
            _buildHotAreas(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}