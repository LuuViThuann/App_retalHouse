import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_rentalhouse/Widgets/Analytics/ChartDetailDropdown.dart';
import '../../viewmodels/vm_analytics.dart';

class OverviewCharts extends StatelessWidget {
  final AnalyticsViewModel viewModel;

  const OverviewCharts({Key? key, required this.viewModel}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.dashboard_outlined, color: Colors.blue[700], size: 24),
            const SizedBox(width: 8),
            const Text(
              'Tổng quan',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Price Chart
        _buildChartCard(
          title: 'Thống kê giá',
          icon: Icons.attach_money,
          color: Colors.green,
          child: _buildPriceChart(),
        ),
        const SizedBox(height: 16),

        // Area Chart
        _buildChartCard(
          title: 'Thống kê diện tích',
          icon: Icons.square_foot,
          color: Colors.purple,
          child: _buildAreaChart(),
        ),
        const SizedBox(height: 16),

        // Quick Stats
        _buildQuickStats(),
      ],
    );
  }

  Widget _buildChartCard({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
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
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildPriceChart() {
    final avgPrice = viewModel.getAveragePrice();
    final maxPrice = viewModel.getMaxPrice();
    final minPrice = viewModel.getMinPrice();

    final data = [
      _ChartData('TB', avgPrice, Colors.green[600]!),
      _ChartData('Cao', maxPrice, Colors.orange[600]!),
      _ChartData('Thấp', minPrice, Colors.blue[600]!),
    ];

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: _getMaxY(data.map((e) => e.value).toList()) * 1.1,
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    return BarTooltipItem(
                      '${data[groupIndex].label}\n${_formatPrice(rod.toY)}',
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
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index >= 0 && index < data.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            data[index].label,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }
                      return const SizedBox();
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 60,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        _formatPriceShort(value),
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
                horizontalInterval: _getMaxY(data.map((e) => e.value).toList()) / 5,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: Colors.grey[200]!,
                    strokeWidth: 1,
                  );
                },
              ),
              barGroups: data.asMap().entries.map((e) {
                return BarChartGroupData(
                  x: e.key,
                  barRods: [
                    BarChartRodData(
                      toY: e.value.value,
                      color: e.value.color,
                      width: 40,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildLegend(data),
        const SizedBox(height: 12),
        ChartDetailDropdown(
          title: 'Chi tiết thống kê giá',
          data: [
            {'label': 'Giá trung bình', 'value': avgPrice},
            {'label': 'Giá cao nhất', 'value': maxPrice},
            {'label': 'Giá thấp nhất', 'value': minPrice},
          ],
          valueKey: 'value',
          labelKey: 'label',
          icon: Icons.attach_money,
          accentColor: Colors.green,
          formatType: 'price',
        ),
      ],
    );

  }
  double _toDouble(dynamic value) {
    if (value is int) return value.toDouble();
    if (value is double) return value;
    return 0.0;
  }
  Widget _buildAreaChart() {
    final avgArea = viewModel.getAverageArea();

    final maxArea = (viewModel.overviewData['areaStats']?['maxArea'] is int
        ? (viewModel.overviewData['areaStats']?['maxArea'] as int).toDouble()
        : viewModel.overviewData['areaStats']?['maxArea']?.toDouble()) ?? 0.0;

    final minArea = (viewModel.overviewData['areaStats']?['minArea'] is int
        ? (viewModel.overviewData['areaStats']?['minArea'] as int).toDouble()
        : viewModel.overviewData['areaStats']?['minArea']?.toDouble()) ?? 0.0;

    final data = [
      _ChartData('TB', _toDouble(avgArea), Colors.purple[600]!),
      _ChartData('Lớn', _toDouble(maxArea), Colors.indigo[600]!),
      _ChartData('Nhỏ', _toDouble(minArea), Colors.cyan[600]!),
    ];

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: _getMaxY(data.map((e) => e.value).toList()) * 1.1,
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    return BarTooltipItem(
                      '${data[groupIndex].label}\n${rod.toY.toStringAsFixed(0)} m²',
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
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index >= 0 && index < data.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            data[index].label,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }
                      return const SizedBox();
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
                horizontalInterval: _getMaxY(data.map((e) => e.value).toList()) / 5,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: Colors.grey[200]!,
                    strokeWidth: 1,
                  );
                },
              ),
              barGroups: data.asMap().entries.map((e) {
                return BarChartGroupData(
                  x: e.key,
                  barRods: [
                    BarChartRodData(
                      toY: e.value.value,
                      color: e.value.color,
                      width: 40,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildLegend(data),
      ],
    );
  }

  Widget _buildQuickStats() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[700],
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              icon: Icons.home,
              label: 'Tổng BĐS',
              value: viewModel.getTotalRentals().toString(),
            ),
          ),
          Container(width: 1, height: 50, color: Colors.white24),
          Expanded(
            child: _buildStatItem(
              icon: Icons.attach_money,
              label: 'Giá TB',
              value: _formatPriceShort(viewModel.getAveragePrice()),
            ),
          ),
          Container(width: 1, height: 50, color: Colors.white24),
          Expanded(
            child: _buildStatItem(
              icon: Icons.square_foot,
              label: 'DT TB',
              value: '${viewModel.getAverageArea().toStringAsFixed(0)}m²',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildLegend(List<_ChartData> data) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: data.map((item) {
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
            const SizedBox(width: 6),
            Text(
              '${item.label}: ${item.value >= 1000000 ? _formatPrice(item.value) : '${item.value.toStringAsFixed(0)} m²'}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        );
      }).toList(),
    );
  }

  String _formatPrice(double price) {
    if (price >= 1000000000) {
      return '${(price / 1000000000).toStringAsFixed(1)} tỷ';
    } else if (price >= 1000000) {
      return '${(price / 1000000).toStringAsFixed(0)} tr';
    }
    return '${price.toStringAsFixed(0)}';
  }

  String _formatPriceShort(double price) {
    if (price >= 1000000000) {
      return '${(price / 1000000000).toStringAsFixed(1)}T';
    } else if (price >= 1000000) {
      return '${(price / 1000000).toStringAsFixed(0)}M';
    }
    return '${price.toStringAsFixed(0)}';
  }

  double _getMaxY(List<double> values) {
    if (values.isEmpty) return 100;
    return values.reduce((a, b) => a > b ? a : b);
  }
}

class _ChartData {
  final String label;
  final double value;
  final Color color;

  _ChartData(this.label, this.value, this.color);
}