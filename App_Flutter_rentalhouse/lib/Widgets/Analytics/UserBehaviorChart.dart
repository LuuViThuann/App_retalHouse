import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../viewmodels/vm_analytics.dart';

class UserBehaviorChart extends StatelessWidget {
  final AnalyticsViewModel viewModel;
  const UserBehaviorChart({Key? key, required this.viewModel}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final data   = viewModel.userBehavior;
    final stats  = data['interactionStats'] as Map<String, dynamic>? ?? {};
    final topRentals  = (data['topViewedRentals'] as List?) ?? [];
    final byHour = (data['behaviorByHour']   as List?) ?? [];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.people_alt_outlined, color: Color(0xFFEA580C), size: 20),
        ),
        const SizedBox(width: 10),
        const Text('Hành vi người dùng',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
      ]),
      const SizedBox(height: 14),

      // Summary chips
      Row(children: [
        _statChip(Icons.visibility_outlined, _fmt(stats['totalViews']),     'Lượt xem',    const Color(0xFF2563EB)),
        const SizedBox(width: 8),
        _statChip(Icons.favorite_outline,    _fmt(stats['totalFavorites']), 'Yêu thích',   const Color(0xFFDC2626)),
        const SizedBox(width: 8),
        _statChip(Icons.phone_outlined,      _fmt(stats['totalContacts']),  'Liên hệ',     const Color(0xFF16A34A)),
        const SizedBox(width: 8),
        _statChip(Icons.trending_up,         '${stats['conversionRate'] ?? 0}%', 'Tỷ lệ',  const Color(0xFFD97706)),
      ]),
      const SizedBox(height: 16),

      // Hourly chart
      if (byHour.isNotEmpty)
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Hoạt động theo giờ trong ngày',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey[700])),
            const SizedBox(height: 12),
            SizedBox(height: 160, child: _buildHourlyChart(byHour)),
          ]),
        ),
      const SizedBox(height: 16),

      // Top viewed
      if (topRentals.isNotEmpty)
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.local_fire_department, color: Color(0xFFEA580C), size: 18),
              const SizedBox(width: 6),
              Text('Top bài xem nhiều nhất',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.grey[800])),
            ]),
            const SizedBox(height: 12),
            ...topRentals.asMap().entries.map((e) => _buildTopRentalRow(e.key + 1, e.value as Map)),
          ]),
        ),
    ]);
  }

  Widget _statChip(IconData icon, String value, String label, Color color) {
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 17),
        const SizedBox(height: 3),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 9, color: Colors.grey[600]), textAlign: TextAlign.center),
      ]),
    ));
  }

  Widget _buildHourlyChart(List byHour) {
    // Tạo full 24h
    final Map<int, int> hourMap = { for (final h in byHour) (h['hour'] as num).toInt(): (h['count'] as num).toInt() };
    final allHours = List.generate(24, (i) => {'hour': i, 'count': hourMap[i] ?? 0});
    final maxY = allHours.map((h) => (h['count'] as int).toDouble()).fold(0.0, (a, b) => b > a ? b : a);

    return BarChart(BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: maxY * 1.3 + 1,
      barTouchData: BarTouchData(enabled: true,
        touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (_) => const Color(0xFF1F2937),
          getTooltipItem: (group, groupIndex, rod, _) => BarTooltipItem(
            '${group.x}h\n${rod.toY.toInt()}',
            const TextStyle(color: Colors.white, fontSize: 11),
          ),
        ),
      ),
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, reservedSize: 20,
          getTitlesWidget: (v, _) {
            final h = v.toInt();
            if (h % 6 != 0) return const SizedBox();
            return Text('${h}h', style: TextStyle(fontSize: 9, color: Colors.grey[500]));
          },
        )),
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      gridData: FlGridData(show: false),
      barGroups: allHours.map((h) {
        final hour  = h['hour'] as int;
        final count = (h['count'] as int).toDouble();
        // Giờ cao điểm: 7-9h, 11-13h, 19-22h
        final isPeak = (hour >= 7 && hour <= 9) || (hour >= 11 && hour <= 13) || (hour >= 19 && hour <= 22);
        return BarChartGroupData(x: hour, barRods: [
          BarChartRodData(
            toY: count,
            width: 7,
            color: isPeak ? const Color(0xFFEA580C) : const Color(0xFF93C5FD),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
          ),
        ]);
      }).toList(),
    ));
  }

  Widget _buildTopRentalRow(int rank, Map item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: rank == 1 ? const Color(0xFFFFF7ED) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: rank == 1 ? const Color(0xFFFED7AA) : const Color(0xFFE5E7EB)),
      ),
      child: Row(children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: rank <= 3 ? const Color(0xFFEA580C) : Colors.grey[300],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(child: Text('$rank',
              style: TextStyle(
                color: rank <= 3 ? Colors.white : Colors.grey[600],
                fontWeight: FontWeight.bold, fontSize: 12,
              ))),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item['title']?.toString() ?? 'N/A',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(item['location']?.toString() ?? '',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(_fmt(item['views']),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
          Text('lượt xem', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
        ]),
      ]),
    );
  }

  String _fmt(dynamic v) {
    final n = v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}