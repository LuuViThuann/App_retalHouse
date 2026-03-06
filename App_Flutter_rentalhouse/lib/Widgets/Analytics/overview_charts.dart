import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_rentalhouse/Widgets/Analytics/ChartDetailDropdown.dart';
import '../../viewmodels/vm_analytics.dart';

class _C {
  static const bg      = Color(0xFFF9FAFB);
  static const surface = Colors.white;
  static const border  = Color(0xFFE5E7EB);
  static const text    = Color(0xFF111827);
  static const textSub = Color(0xFF6B7280);
  static const muted   = Color(0xFF9CA3AF);
  static const accent  = Color(0xFF2563EB);
}

class OverviewCharts extends StatelessWidget {
  final AnalyticsViewModel viewModel;
  const OverviewCharts({Key? key, required this.viewModel}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Tổng quan',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _C.text)),
        const SizedBox(height: 16),
        _buildCard(title: 'Thống kê giá', child: _buildPriceChart()),
        const SizedBox(height: 12),
        _buildCard(title: 'Thống kê diện tích', child: _buildAreaChart()),
        const SizedBox(height: 12),
        _buildQuickStats(),
      ],
    );
  }

  Widget _buildCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _C.text)),
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
      _ChartData('TB',   avgPrice, const Color(0xFF2563EB)),
      _ChartData('Cao',  maxPrice, const Color(0xFF0EA5E9)),
      _ChartData('Thấp', minPrice, const Color(0xFF64748B)),
    ];

    return Column(
      children: [
        SizedBox(height: 200, child: _barChart(data, isPrice: true)),
        const SizedBox(height: 12),
        _buildLegend(data, isPrice: true),
        const SizedBox(height: 12),
        ChartDetailDropdown(
          title: 'Chi tiết thống kê giá',
          data: [
            {'label': 'Giá trung bình', 'value': avgPrice},
            {'label': 'Giá cao nhất',   'value': maxPrice},
            {'label': 'Giá thấp nhất',  'value': minPrice},
          ],
          valueKey: 'value',
          labelKey: 'label',
          icon: Icons.attach_money,
          accentColor: _C.accent,
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
      _ChartData('TB',   _toDouble(avgArea), const Color(0xFF7C3AED)),
      _ChartData('Lớn',  _toDouble(maxArea), const Color(0xFF6366F1)),
      _ChartData('Nhỏ',  _toDouble(minArea), const Color(0xFF94A3B8)),
    ];

    return Column(
      children: [
        SizedBox(height: 200, child: _barChart(data, isPrice: false)),
        const SizedBox(height: 12),
        _buildLegend(data, isPrice: false),
      ],
    );
  }

  Widget _barChart(List<_ChartData> data, {required bool isPrice}) {
    final maxY = _getMaxY(data.map((e) => e.value).toList()) * 1.1;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => const Color(0xFF1F2937),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final label = isPrice
                  ? _formatPrice(rod.toY)
                  : '${rod.toY.toStringAsFixed(0)} m²';
              return BarTooltipItem(
                '${data[groupIndex].label}\n$label',
                const TextStyle(color: Colors.white, fontSize: 11,
                    fontWeight: FontWeight.w600),
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
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(data[index].label,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: _C.textSub)),
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
              getTitlesWidget: (value, meta) => Text(
                isPrice ? _formatPriceShort(value) : '${value.toInt()}',
                style: const TextStyle(fontSize: 10, color: _C.muted),
              ),
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 5,
          getDrawingHorizontalLine: (_) =>
          const FlLine(color: Color(0xFFF3F4F6), strokeWidth: 1),
        ),
        barGroups: data.asMap().entries.map((e) {
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: e.value.value,
                color: e.value.color,
                width: 36,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildQuickStats() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A5F),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(child: _statItem('Tổng BĐS',
              viewModel.getTotalRentals().toString())),
          Container(width: 1, height: 40, color: Colors.white24),
          Expanded(child: _statItem('Giá TB',
              _formatPriceShort(viewModel.getAveragePrice()))),
          Container(width: 1, height: 40, color: Colors.white24),
          Expanded(child: _statItem('DT TB',
              '${viewModel.getAverageArea().toStringAsFixed(0)} m²')),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF93C5FD))),
      ],
    );
  }

  Widget _buildLegend(List<_ChartData> data, {required bool isPrice}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: data.map((item) {
        return Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                      color: item.color, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 5),
              Text(
                isPrice
                    ? '${item.label}: ${_formatPrice(item.value)}'
                    : '${item.label}: ${item.value.toStringAsFixed(0)} m²',
                style: const TextStyle(fontSize: 11, color: _C.textSub),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  static String _formatPrice(double p) {
    if (p >= 1e9) return '${(p / 1e9).toStringAsFixed(1)} tỷ';
    if (p >= 1e6) return '${(p / 1e6).toStringAsFixed(0)} tr';
    return p.toStringAsFixed(0);
  }

  static String _formatPriceShort(double p) {
    if (p >= 1e9) return '${(p / 1e9).toStringAsFixed(1)}T';
    if (p >= 1e6) return '${(p / 1e6).toStringAsFixed(0)}M';
    return p.toStringAsFixed(0);
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