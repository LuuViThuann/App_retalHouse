import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_rentalhouse/Widgets/Analytics/ChartDetailDropdown.dart';
import '../../viewmodels/vm_analytics.dart';

// ==================== PRICE DISTRIBUTION CHART ====================
class PriceDistributionChart extends StatelessWidget {
  final AnalyticsViewModel viewModel;

  const PriceDistributionChart({Key? key, required this.viewModel}) : super(key: key);

  // ✅ Helper method để convert safely
  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    if (viewModel.priceDistribution.isEmpty) return const SizedBox.shrink();

    final chartData = viewModel.priceDistribution.map((item) {
      return _ChartData(
        label: (item['label'] ?? '').toString(),
        shortLabel: (item['label'] ?? '').toString().split(' ')[0],
        count: _toDouble(item['count']),           // ✅ FIXED
        percentage: _toDouble(item['percentage']), // ✅ FIXED
        color: _parseColor(item['color'] ?? '#4CAF50'),
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.account_balance_wallet, color: Colors.green[700], size: 24),
            const SizedBox(width: 8),
            const Text(
              'Phân bố giá',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
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
              SizedBox(
                height: 280,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: _getMaxY(chartData.map((e) => e.count).toList()) * 1.1,
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          if (groupIndex >= chartData.length) return null;
                          return BarTooltipItem(
                            '${chartData[groupIndex].label}\n${rod.toY.toInt()} BĐS (${chartData[groupIndex].percentage.toStringAsFixed(1)}%)',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
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
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index < 0 || index >= chartData.length) {
                              return const SizedBox();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                chartData[index].shortLabel,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
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
                      getDrawingHorizontalLine: (value) {
                        return FlLine(color: Colors.grey[200]!, strokeWidth: 1);
                      },
                    ),
                    barGroups: chartData.asMap().entries.map((e) {
                      return BarChartGroupData(
                        x: e.key,
                        barRods: [
                          BarChartRodData(
                            toY: e.value.count,
                            color: e.value.color,
                            width: 18,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6),
                            ),
                            gradient: LinearGradient(
                              colors: [
                                e.value.color,
                                e.value.color.withOpacity(0.7),
                              ],
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

              // Legend
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: chartData.map((item) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: item.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: item.color.withOpacity(0.3)),
                    ),
                    child: Row(
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
                        const SizedBox(width: 6),
                        Text(
                          '${item.label}: ${item.count.toInt()} (${item.percentage.toStringAsFixed(1)}%)',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  );
                }).toList(),
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

  double _getMaxY(List<double> values) {
    if (values.isEmpty) return 100;
    return values.reduce((a, b) => a > b ? a : b);
  }
}

// ==================== PROPERTY TYPES CHART ====================
class PropertyTypesChart extends StatelessWidget {
  final AnalyticsViewModel viewModel;

  const PropertyTypesChart({Key? key, required this.viewModel}) : super(key: key);

  // ✅ Helper method để convert safely
  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    if (viewModel.propertyTypes.isEmpty) return const SizedBox.shrink();

    final chartData = viewModel.propertyTypes.take(6).map((item) {
      return _ChartData(
        label: (item['_id'] ?? '?').toString(),
        shortLabel: (item['_id'] ?? '?').toString().length > 8
            ? (item['_id'] ?? '?').toString().substring(0, 8)
            : (item['_id'] ?? '?').toString(),
        count: _toDouble(item['count']),           // ✅ FIXED
        percentage: _toDouble(item['percentage']), // ✅ FIXED
        color: Colors.blue,
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.home_work, color: Colors.indigo[700], size: 24),
            const SizedBox(width: 8),
            const Text(
              'Loại bất động sản',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
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
              SizedBox(
                height: 280,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: _getMaxY(chartData.map((e) => e.count).toList()) * 1.1,
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          if (groupIndex >= chartData.length) return null;
                          return BarTooltipItem(
                            '${chartData[groupIndex].label}\n${rod.toY.toInt()} BĐS (${chartData[groupIndex].percentage.toStringAsFixed(1)}%)',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
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
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index < 0 || index >= chartData.length) {
                              return const SizedBox();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                chartData[index].shortLabel,
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
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
                      getDrawingHorizontalLine: (value) {
                        return FlLine(color: Colors.grey[200]!, strokeWidth: 1);
                      },
                    ),
                    barGroups: chartData.asMap().entries.map((e) {
                      final colors = [
                        Colors.blue[600]!,
                        Colors.green[600]!,
                        Colors.orange[600]!,
                        Colors.red[600]!,
                        Colors.purple[600]!,
                        Colors.teal[600]!,
                      ];
                      final color = colors[e.key % colors.length];
                      return BarChartGroupData(
                        x: e.key,
                        barRods: [
                          BarChartRodData(
                            toY: e.value.count,
                            color: color,
                            width: 20,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6),
                            ),
                            gradient: LinearGradient(
                              colors: [color, color.withOpacity(0.7)],
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

              // Stats Summary - ✅ FIXED
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: viewModel.propertyTypes.map<Widget>((item) {
                    // ✅ Convert safely
                    final count = (item['count'] is int)
                        ? item['count'] as int
                        : ((item['count'] as double?)?.toInt() ?? 0);

                    final percentage = _toDouble(item['percentage']);

                    return Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.grey[100]!, Colors.grey[50]!],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['_id'] ?? '?',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$count BĐS • ${percentage.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
              ChartDetailDropdown(
                title: 'Chi tiết loại bất động sản',
                data: viewModel.propertyTypes.map<Map<String, dynamic>>((item) => {
                  'label': item['_id'] ?? '?',
                  'value': item['count'] ?? 0,
                  'percentage': item['percentage'] ?? 0.0,
                }).toList(),
                valueKey: 'value',
                labelKey: 'label',
                icon: Icons.home_work,
                accentColor: Colors.indigo,
                formatType: 'count',
              ),
            ],
          ),
        ),
      ],
    );
  }

  double _getMaxY(List<double> values) {
    if (values.isEmpty) return 100;
    return values.reduce((a, b) => a > b ? a : b);
  }
}

class _ChartData {
  final String label;
  final String shortLabel;
  final double count;
  final double percentage;
  final Color color;

  _ChartData({
    required this.label,
    required this.shortLabel,
    required this.count,
    required this.percentage,
    required this.color,
  });
}