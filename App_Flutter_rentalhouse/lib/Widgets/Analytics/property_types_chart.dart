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
}

// ─── Palette tối giản 6 màu ──────────────────────────────────────────────────
const _palette = [
  Color(0xFF2563EB), Color(0xFF0EA5E9), Color(0xFF10B981),
  Color(0xFFF59E0B), Color(0xFF8B5CF6), Color(0xFF64748B),
];

// ==================== PRICE DISTRIBUTION ====================
class PriceDistributionChart extends StatelessWidget {
  final AnalyticsViewModel viewModel;
  const PriceDistributionChart({Key? key, required this.viewModel}) : super(key: key);

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

    final chartData = viewModel.priceDistribution.asMap().entries.map((e) {
      final item = e.value;
      return _ChartData(
        label:      (item['label'] ?? '').toString(),
        shortLabel: (item['label'] ?? '').toString().split(' ')[0],
        count:      _toDouble(item['count']),
        percentage: _toDouble(item['percentage']),
        color:      _palette[e.key % _palette.length],
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Phân bố giá',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _C.text)),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _C.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _C.border),
          ),
          child: Column(
            children: [
              SizedBox(height: 240, child: _buildBar(chartData)),
              const SizedBox(height: 14),
              _buildLegend(chartData),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBar(List<_ChartData> chartData) {
    final maxY = chartData.map((e) => e.count).fold(0.0, (a, b) => a > b ? a : b) * 1.15;

    return BarChart(BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: maxY,
      barTouchData: BarTouchData(
        enabled: true,
        touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (_) => const Color(0xFF1F2937),
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            if (groupIndex >= chartData.length) return null;
            final d = chartData[groupIndex];
            return BarTooltipItem(
              '${d.label}\n${rod.toY.toInt()} BĐS (${d.percentage.toStringAsFixed(1)}%)',
              const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
            );
          },
        ),
      ),
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              final i = value.toInt();
              if (i < 0 || i >= chartData.length) return const SizedBox();
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(chartData[i].shortLabel,
                    style: const TextStyle(fontSize: 10, color: _C.textSub)),
              );
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 36,
            getTitlesWidget: (value, meta) => Text('${value.toInt()}',
                style: const TextStyle(fontSize: 9, color: _C.muted)),
          ),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) =>
        const FlLine(color: Color(0xFFF3F4F6), strokeWidth: 1),
      ),
      barGroups: chartData.asMap().entries.map((e) {
        return BarChartGroupData(
          x: e.key,
          barRods: [
            BarChartRodData(
              toY: e.value.count,
              color: e.value.color,
              width: 20,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ],
        );
      }).toList(),
    ));
  }

  Widget _buildLegend(List<_ChartData> data) {
    return Wrap(
      spacing: 10,
      runSpacing: 6,
      children: data.map((item) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                    color: item.color,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 5),
            Text(
              '${item.shortLabel}: ${item.count.toInt()} (${item.percentage.toStringAsFixed(1)}%)',
              style: const TextStyle(fontSize: 11, color: _C.textSub),
            ),
          ],
        );
      }).toList(),
    );
  }
}

// ==================== PROPERTY TYPES ====================
class PropertyTypesChart extends StatelessWidget {
  final AnalyticsViewModel viewModel;
  const PropertyTypesChart({Key? key, required this.viewModel}) : super(key: key);

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

    final chartData = viewModel.propertyTypes.take(6).toList().asMap().entries.map((e) {
      final item = e.value;
      return _ChartData(
        label:      (item['_id'] ?? '?').toString(),
        shortLabel: (item['_id'] ?? '?').toString().length > 8
            ? (item['_id'] ?? '?').toString().substring(0, 8)
            : (item['_id'] ?? '?').toString(),
        count:      _toDouble(item['count']),
        percentage: _toDouble(item['percentage']),
        color:      _palette[e.key % _palette.length],
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Loại bất động sản',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _C.text)),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _C.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _C.border),
          ),
          child: Column(
            children: [
              SizedBox(height: 240, child: _buildBar(chartData)),
              const SizedBox(height: 14),
              _buildSummaryRow(),
              const SizedBox(height: 12),
              ChartDetailDropdown(
                title: 'Chi tiết loại bất động sản',
                data: viewModel.propertyTypes.map<Map<String, dynamic>>((item) => {
                  'label':      item['_id'] ?? '?',
                  'value':      item['count'] ?? 0,
                  'percentage': item['percentage'] ?? 0.0,
                }).toList(),
                valueKey: 'value',
                labelKey: 'label',
                icon: Icons.home_work,
                accentColor: _palette[0],
                formatType: 'count',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBar(List<_ChartData> chartData) {
    final maxY = chartData.map((e) => e.count).fold(0.0, (a, b) => a > b ? a : b) * 1.15;

    return BarChart(BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: maxY,
      barTouchData: BarTouchData(
        enabled: true,
        touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (_) => const Color(0xFF1F2937),
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            if (groupIndex >= chartData.length) return null;
            final d = chartData[groupIndex];
            return BarTooltipItem(
              '${d.label}\n${rod.toY.toInt()} BĐS (${d.percentage.toStringAsFixed(1)}%)',
              const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
            );
          },
        ),
      ),
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              final i = value.toInt();
              if (i < 0 || i >= chartData.length) return const SizedBox();
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(chartData[i].shortLabel,
                    style: const TextStyle(fontSize: 10, color: _C.textSub)),
              );
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 36,
            getTitlesWidget: (value, meta) => Text('${value.toInt()}',
                style: const TextStyle(fontSize: 9, color: _C.muted)),
          ),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) =>
        const FlLine(color: Color(0xFFF3F4F6), strokeWidth: 1),
      ),
      barGroups: chartData.asMap().entries.map((e) {
        return BarChartGroupData(
          x: e.key,
          barRods: [
            BarChartRodData(
              toY: e.value.count,
              color: e.value.color,
              width: 22,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ],
        );
      }).toList(),
    ));
  }

  Widget _buildSummaryRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: viewModel.propertyTypes.asMap().entries.map<Widget>((e) {
          final item  = e.value;
          final count = (item['count'] is int)
              ? item['count'] as int
              : ((item['count'] as double?)?.toInt() ?? 0);
          final pct   = _toDouble(item['percentage']);
          final color = _palette[e.key % _palette.length];

          return Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _C.bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _C.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 8, height: 8,
                    decoration: BoxDecoration(
                        color: color, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 7),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item['_id'] ?? '?',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600,
                            color: _C.text)),
                    Text('$count · ${pct.toStringAsFixed(1)}%',
                        style: const TextStyle(fontSize: 10, color: _C.muted)),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ChartData {
  final String label, shortLabel;
  final double count, percentage;
  final Color color;
  _ChartData({
    required this.label, required this.shortLabel,
    required this.count, required this.percentage,
    required this.color,
  });
}