import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../viewmodels/vm_analytics.dart';

class LocationStatsChart extends StatefulWidget {
  final AnalyticsViewModel viewModel;
  final String? filteredProvince;
  final String? filteredDistrict;
  final String? filteredWard;

  const LocationStatsChart({
    Key? key,
    required this.viewModel,
    this.filteredProvince,
    this.filteredDistrict,
    this.filteredWard,
  }) : super(key: key);

  @override
  State<LocationStatsChart> createState() => _LocationStatsChartState();
}

class _LocationStatsChartState extends State<LocationStatsChart> {
  String selectedTab = 'cities'; // cities, districts, wards

  @override
  Widget build(BuildContext context) {
    final locationStats = widget.viewModel.locationStats;
    final hasFilter = widget.filteredProvince != null ||
        widget.filteredDistrict != null ||
        widget.filteredWard != null;

    debugPrint('📊 LocationStats build: $locationStats');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.location_on, color: Colors.red[700], size: 24),
            const SizedBox(width: 8),
            const Text(
              'Thống kê theo khu vực',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              if (hasFilter) _buildFilterBanner(),
              if (hasFilter) const SizedBox(height: 16),
              _buildTabSelector(),
              const SizedBox(height: 20),
              _buildContent(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterBanner() {
    final filterParts = <String>[];
    if (widget.filteredProvince != null) filterParts.add(widget.filteredProvince!);
    if (widget.filteredDistrict != null) filterParts.add(widget.filteredDistrict!);
    if (widget.filteredWard != null) filterParts.add(widget.filteredWard!);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red[50]!, Colors.orange[50]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.red[100],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(Icons.filter_alt, color: Colors.red[700], size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Đang lọc thông tin địa chỉ đã chọn...',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.red[900],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _getFilterScopeText(),
                  style: TextStyle(fontSize: 11, color: Colors.red[700]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.location_searching, color: Colors.red[600], size: 18),
        ],
      ),
    );
  }

  String _getFilterScopeText() {
    if (widget.filteredWard != null) {
      return 'Dữ liệu trong phường/xã "${widget.filteredWard}"';
    } else if (widget.filteredDistrict != null) {
      return 'Dữ liệu trong quận/huyện "${widget.filteredDistrict}"';
    } else if (widget.filteredProvince != null) {
      return 'Dữ liệu trong tỉnh/thành "${widget.filteredProvince}"';
    }
    return 'Dữ liệu toàn quốc';
  }

  Widget _buildTabSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildTab('Tỉnh/TP', 'cities', Icons.location_city),
          _buildTab('Quận/Huyện', 'districts', Icons.map_outlined),
          _buildTab('Phường/Xã', 'wards', Icons.home_work_outlined),
        ],
      ),
    );
  }

  Widget _buildTab(String label, String value, IconData icon) {
    final isSelected = selectedTab == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => selectedTab = value),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue[700] : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
              BoxShadow(
                color: Colors.blue.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey[600],
                size: 18,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.white : Colors.grey[700],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final locationStats = widget.viewModel.locationStats;

    if (locationStats.isEmpty) {
      return _buildEmptyState('Chưa có dữ liệu thống kê');
    }

    // ✅ Parse backend data structure
    List<Map<String, dynamic>> allLocations = [];
    try {
      final locationsData = locationStats['locations'];
      if (locationsData is List) {
        for (var item in locationsData) {
          if (item is Map) {
            allLocations.add(Map<String, dynamic>.from(item));
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Parse error: $e');
      return _buildEmptyState('Lỗi khi xử lý dữ liệu');
    }

    // ✅ Filter by selected tab and current filters
    final data = _getDataForTab(allLocations);

    if (data.isEmpty) {
      return _buildEmptyState(_getEmptyMessage());
    }

    return _buildChart(data);
  }

  List<_LocationData> _getDataForTab(List<Map<String, dynamic>> allLocations) {
    // Nếu có locations từ backend (filtered data), extract theo type
    if (allLocations.isNotEmpty) {
      return allLocations
          .where((loc) {
        final type = loc['type']?.toString() ?? '';
        switch (selectedTab) {
          case 'cities':
            return type == 'province';
          case 'districts':
            return type == 'district';
          case 'wards':
            return type == 'ward';
          default:
            return false;
        }
      })
          .map((loc) => _LocationData(
        name: loc['name']?.toString() ?? 'N/A',
        count: (loc['count'] is int)
            ? loc['count'] as int
            : ((loc['count'] as num?)?.toInt() ?? 0),
      ))
          .toList();
    }

    // Fallback: extract from old format (backward compatible)
    final locationStats = widget.viewModel.locationStats;
    final List<dynamic>? items = locationStats[selectedTab];

    if (items == null || items.isEmpty) return [];

    return items
        .where((item) {
      final name = item['name'] ?? item['_id'] ?? '';
      if (name.isEmpty || name == 'Việt Nam' || name == 'Vietnam') {
        return false;
      }
      final count = (item['count'] is int
          ? item['count'] as int
          : (item['count'] as double?)?.toInt()) ?? 0;
      return count > 0;
    })
        .take(10)
        .map((item) => _LocationData(
      name: item['name'] ?? item['_id'] ?? 'N/A',
      count: (item['count'] is int
          ? item['count'] as int
          : (item['count'] as double?)?.toInt()) ?? 0,
    ))
        .toList();
  }

  String _getEmptyMessage() {
    String level = '';
    switch (selectedTab) {
      case 'cities':
        level = 'tỉnh/thành';
        break;
      case 'districts':
        level = 'quận/huyện';
        break;
      case 'wards':
        level = 'phường/xã';
        break;
    }

    if (widget.filteredWard != null) {
      return 'Không có dữ liệu $level trong phường/xã "${widget.filteredWard}"';
    } else if (widget.filteredDistrict != null) {
      return 'Không có dữ liệu $level trong quận/huyện "${widget.filteredDistrict}"';
    } else if (widget.filteredProvince != null) {
      return 'Không có dữ liệu $level trong tỉnh/thành "${widget.filteredProvince}"';
    }
    return 'Không có dữ liệu $level';
  }

  Widget _buildEmptyState(String message) {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(List<_LocationData> data) {
    return Column(
      children: [
        // Scope indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 14, color: Colors.blue[700]),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _getScopeText(data.length),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.blue[900],
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Bar Chart
        SizedBox(
          height: 300,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: _getMaxY(data) * 1.2,
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    if (groupIndex >= data.length) return null;
                    return BarTooltipItem(
                      '${data[groupIndex].name}\n${rod.toY.toInt()} bài đăng',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 50,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= data.length) return const SizedBox();
                      final name = data[index].name;
                      final displayName = name.length > 12
                          ? '${name.substring(0, 12)}...'
                          : name;
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          displayName,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        '${value.toInt()}',
                        style: const TextStyle(fontSize: 10),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: _getMaxY(data) / 5,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: Colors.grey[200]!,
                    strokeWidth: 1,
                  );
                },
              ),
              barGroups: data.asMap().entries.map((e) {
                final colors = _getColorForTab();
                return BarChartGroupData(
                  x: e.key,
                  barRods: [
                    BarChartRodData(
                      toY: e.value.count.toDouble(),
                      color: colors[0],
                      width: 20,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                      gradient: LinearGradient(
                        colors: colors,
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Summary
        _buildSummary(data),
      ],
    );
  }

  String _getScopeText(int count) {
    String level = '';
    switch (selectedTab) {
      case 'cities':
        level = 'tỉnh/thành';
        break;
      case 'districts':
        level = 'quận/huyện';
        break;
      case 'wards':
        level = 'phường/xã';
        break;
    }

    if (widget.filteredWard != null && selectedTab == 'wards') {
      return 'Hiển thị $count $level trong "${widget.filteredWard}"';
    } else if (widget.filteredDistrict != null && selectedTab == 'wards') {
      return 'Hiển thị top $count $level trong quận/huyện "${widget.filteredDistrict}"';
    } else if (widget.filteredProvince != null && selectedTab != 'cities') {
      return 'Hiển thị top $count $level trong tỉnh/thành "${widget.filteredProvince}"';
    } else if (widget.filteredProvince != null && selectedTab == 'cities') {
      return 'Hiển thị tỉnh/thành "${widget.filteredProvince}"';
    }
    return 'Hiển thị top $count $level có nhiều BĐS nhất';
  }

  List<Color> _getColorForTab() {
    switch (selectedTab) {
      case 'cities':
        return [Colors.blue[600]!, Colors.blue[400]!];
      case 'districts':
        return [Colors.orange[600]!, Colors.orange[400]!];
      case 'wards':
        return [Colors.green[600]!, Colors.green[400]!];
      default:
        return [Colors.grey[600]!, Colors.grey[400]!];
    }
  }

  double _getMaxY(List<_LocationData> data) {
    if (data.isEmpty) return 100;
    return data.map((e) => e.count.toDouble()).reduce((a, b) => a > b ? a : b);
  }

  Widget _buildSummary(List<_LocationData> data) {
    final total = data.fold<int>(0, (sum, item) => sum + item.count);
    final avg = data.isNotEmpty ? (total / data.length).toStringAsFixed(1) : '0';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem('Tổng bài đăng', total.toString(), Icons.analytics),
          Container(width: 1, height: 30, color: Colors.grey[300]),
          _buildSummaryItem('Số khu vực', data.length.toString(), Icons.location_on),
          Container(width: 1, height: 30, color: Colors.grey[300]),
          _buildSummaryItem('TB/khu vực', avg, Icons.trending_up),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.blue[700], size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _LocationData {
  final String name;
  final int count;
  _LocationData({required this.name, required this.count});
}