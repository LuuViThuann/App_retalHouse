import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../viewmodels/vm_analytics.dart';

class AreaDistributionChart extends StatefulWidget {
  final AnalyticsViewModel viewModel;
  const AreaDistributionChart({Key? key, required this.viewModel}) : super(key: key);

  @override
  State<AreaDistributionChart> createState() => _AreaDistributionChartState();
}

class _AreaDistributionChartState extends State<AreaDistributionChart> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final data = widget.viewModel.areaDistribution;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.square_foot_rounded, color: Color(0xFF2563EB), size: 20),
          ),
          const SizedBox(width: 10),
          const Text('Phân bố diện tích',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
        ]),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          padding: const EdgeInsets.all(16),
          child: data.isEmpty
              ? _buildEmpty()
              : Column(children: [
            SizedBox(
              height: 220,
              child: PieChart(PieChartData(
                pieTouchData: PieTouchData(
                  touchCallback: (e, response) {
                    setState(() {
                      touchedIndex = (response?.touchedSection != null &&
                          e is! FlTapUpEvent)
                          ? response!.touchedSection!.touchedSectionIndex
                          : -1;
                    });
                  },
                ),
                borderData: FlBorderData(show: false),
                sectionsSpace: 2,
                centerSpaceRadius: 50,
                sections: data.asMap().entries.map((e) {
                  final item = e.value as Map<String, dynamic>;
                  final isTouched = e.key == touchedIndex;
                  final color = Color(int.parse(
                      (item['color'] as String).replaceFirst('#', '0xFF')));
                  return PieChartSectionData(
                    color: color,
                    value: (item['count'] as num).toDouble(),
                    title: '${item['percentage']}%',
                    radius: isTouched ? 70 : 58,
                    titleStyle: TextStyle(
                      fontSize: isTouched ? 13 : 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  );
                }).toList(),
              )),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: data.map((item) {
                final m = item as Map<String, dynamic>;
                final color = Color(int.parse(
                    (m['color'] as String).replaceFirst('#', '0xFF')));
                return Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 10, height: 10,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  Text('${m['label']} (${m['count']})',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                ]);
              }).toList(),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _buildEmpty() => const SizedBox(height: 120,
      child: Center(child: Text('Chưa có dữ liệu', style: TextStyle(color: Colors.grey))));
}