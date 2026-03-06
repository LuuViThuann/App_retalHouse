import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../viewmodels/vm_analytics.dart';

class GrowthStatsChart extends StatefulWidget {
  final AnalyticsViewModel viewModel;
  const GrowthStatsChart({Key? key, required this.viewModel}) : super(key: key);

  @override
  State<GrowthStatsChart> createState() => _GrowthStatsChartState();
}

class _GrowthStatsChartState extends State<GrowthStatsChart>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _tab.addListener(() { if (!_tab.indexIsChanging) setState(() => _selectedTab = _tab.index); });
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final data       = widget.viewModel.growthStats;
    final postGrowth = (data['postGrowth']    as List?) ?? [];
    final userGrowth = (data['userGrowth']    as List?) ?? [];
    final revenue    = (data['revenueGrowth'] as List?) ?? [];
    final status     = (data['statusStats']   as List?) ?? [];
    final rating     = data['ratingStats']    as Map<String, dynamic>? ?? {};

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.trending_up_rounded, color: Color(0xFF16A34A), size: 20),
        ),
        const SizedBox(width: 10),
        const Text('Tăng trưởng & Đánh giá',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
      ]),
      const SizedBox(height: 14),

      // Status stats
      if (status.isNotEmpty) ...[
        _buildStatusRow(status),
        const SizedBox(height: 14),
      ],

      // Growth charts
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(children: [
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(10)),
            child: TabBar(
              controller: _tab,
              indicator: BoxDecoration(
                color: [const Color(0xFF2563EB), const Color(0xFF7C3AED), const Color(0xFF16A34A)][_selectedTab],
                borderRadius: BorderRadius.circular(8),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey[500],
              labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
              unselectedLabelStyle: const TextStyle(fontSize: 11),
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(height: 32, child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.article_outlined, size: 12), SizedBox(width: 3), Text('Bài đăng'),
                ])),
                Tab(height: 32, child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.person_outline, size: 12), SizedBox(width: 3), Text('Người dùng'),
                ])),
                Tab(height: 32, child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.attach_money, size: 12), SizedBox(width: 3), Text('Doanh thu'),
                ])),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(children: [
              if (_selectedTab == 0) _buildLineChart(postGrowth, 'count', const Color(0xFF2563EB), 'bài'),
              if (_selectedTab == 1) _buildLineChart(userGrowth, 'count', const Color(0xFF7C3AED), 'người'),
              if (_selectedTab == 2) _buildRevenueChart(revenue),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 16),

      // Rating
      if (rating.isNotEmpty && (rating['total'] ?? 0) > 0)
        _buildRatingCard(rating),
    ]);
  }

  Widget _buildStatusRow(List status) {
    final colors = {
      'available': const Color(0xFF16A34A),
      'rented':    const Color(0xFF2563EB),
      'hidden':    Colors.grey,
    };
    final labels = {
      'available': 'Đang hiển thị',
      'rented':    'Đã cho thuê',
      'hidden':    'Đã ẩn',
    };
    return Row(
      children: status.map((s) {
        final m     = s as Map<String, dynamic>;
        final st    = m['status']?.toString() ?? '';
        final color = colors[st] ?? Colors.grey;
        return Expanded(child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Column(children: [
            Text('${m['count']}',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            Text(labels[st] ?? st,
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                textAlign: TextAlign.center),
          ]),
        ));
      }).toList(),
    );
  }

  Widget _buildLineChart(List data, String key, Color color, String unit) {
    if (data.isEmpty) return _emptyState();
    final spots = data.asMap().entries.map((e) {
      final v = (e.value as Map)[key] as num? ?? 0;
      return FlSpot(e.key.toDouble(), v.toDouble());
    }).toList();
    final maxY = spots.map((s) => s.y).fold(0.0, (a, b) => b > a ? b : a);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${data.length} tháng gần nhất',
          style: TextStyle(fontSize: 12, color: Colors.grey[500])),
      const SizedBox(height: 10),
      SizedBox(height: 180, child: LineChart(LineChartData(
        minY: 0, maxY: maxY * 1.3 + 1,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => const Color(0xFF1F2937),
            getTooltipItems: (spots) => spots.map((s) {
              final label = (data[s.x.toInt()] as Map)['_id']?.toString() ?? '';
              return LineTooltipItem('$label\n${s.y.toInt()} $unit',
                  const TextStyle(color: Colors.white, fontSize: 11));
            }).toList(),
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true, reservedSize: 22,
            getTitlesWidget: (v, _) {
              final i = v.toInt();
              if (i < 0 || i >= data.length) return const SizedBox();
              final label = (data[i] as Map)['_id']?.toString() ?? '';
              final parts = label.split('-');
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(parts.length >= 2 ? parts[1] : label,
                    style: TextStyle(fontSize: 9, color: Colors.grey[500])),
              );
            },
          )),
          leftTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true, reservedSize: 32,
            getTitlesWidget: (v, _) => Text('${v.toInt()}',
                style: TextStyle(fontSize: 9, color: Colors.grey[500])),
          )),
          topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey[100]!, strokeWidth: 1),
        ),
        lineBarsData: [LineChartBarData(
          spots: spots,
          isCurved: true,
          color: color,
          barWidth: 2.5,
          dotData: FlDotData(getDotPainter: (spot, pct, bar, idx) =>
              FlDotCirclePainter(radius: 3.5, color: color, strokeWidth: 1.5, strokeColor: Colors.white)),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [color.withOpacity(0.15), color.withOpacity(0.01)],
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
            ),
          ),
        )],
      ))),
    ]);
  }

  Widget _buildRevenueChart(List data) {
    if (data.isEmpty) return _emptyState();
    final maxY = data.map((d) => ((d as Map)['revenue'] as num?)?.toDouble() ?? 0.0)
        .fold(0.0, (a, b) => b > a ? b : a);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${data.length} tháng gần nhất',
          style: TextStyle(fontSize: 12, color: Colors.grey[500])),
      const SizedBox(height: 10),
      SizedBox(height: 180, child: BarChart(BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY * 1.3 + 1,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => const Color(0xFF1F2937),
            getTooltipItem: (group, groupIndex, rod, _) {
              final m = data[groupIndex] as Map;
              return BarTooltipItem(
                '${m['_id']}\n${_fmtRevenue(m['revenue'])}\n${m['count']} giao dịch',
                const TextStyle(color: Colors.white, fontSize: 11),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true, reservedSize: 22,
            getTitlesWidget: (v, _) {
              final i = v.toInt();
              if (i < 0 || i >= data.length) return const SizedBox();
              final label = (data[i] as Map)['_id']?.toString() ?? '';
              final parts = label.split('-');
              return Padding(padding: const EdgeInsets.only(top: 4),
                  child: Text(parts.length >= 2 ? parts[1] : label,
                      style: TextStyle(fontSize: 9, color: Colors.grey[500])));
            },
          )),
          leftTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true, reservedSize: 40,
            getTitlesWidget: (v, _) => Text(_fmtRevenue(v),
                style: TextStyle(fontSize: 9, color: Colors.grey[500])),
          )),
          topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey[100]!, strokeWidth: 1)),
        barGroups: data.asMap().entries.map((e) {
          final val = ((e.value as Map)['revenue'] as num?)?.toDouble() ?? 0;
          return BarChartGroupData(x: e.key, barRods: [
            BarChartRodData(
              toY: val,
              width: 18,
              color: const Color(0xFF16A34A),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
            ),
          ]);
        }).toList(),
      ))),
    ]);
  }

  Widget _buildRatingCard(Map<String, dynamic> rating) {
    final avg   = (rating['avgRating'] as num?)?.toDouble() ?? 0.0;
    final total = (rating['total'] as num?)?.toInt() ?? 0;
    final bars  = [
      {'label': '5★', 'count': rating['fiveStar']  ?? 0, 'color': const Color(0xFF16A34A)},
      {'label': '4★', 'count': rating['fourStar']  ?? 0, 'color': const Color(0xFF65A30D)},
      {'label': '3★', 'count': rating['threeStar'] ?? 0, 'color': const Color(0xFFF59E0B)},
      {'label': '2★', 'count': rating['twoStar']   ?? 0, 'color': const Color(0xFFEA580C)},
      {'label': '1★', 'count': rating['oneStar']   ?? 0, 'color': const Color(0xFFDC2626)},
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 18),
          const SizedBox(width: 6),
          Text('Đánh giá từ người dùng',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.grey[800])),
        ]),
        const SizedBox(height: 14),
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Column(children: [
            Text(avg.toStringAsFixed(1),
                style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
            Row(children: List.generate(5, (i) => Icon(
              i < avg.round() ? Icons.star_rounded : Icons.star_outline_rounded,
              color: const Color(0xFFF59E0B), size: 16,
            ))),
            const SizedBox(height: 4),
            Text('$total đánh giá',
                style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          ]),
          const SizedBox(width: 20),
          Expanded(child: Column(
            children: bars.map((b) {
              final count = (b['count'] as num).toInt();
              final pct   = total > 0 ? count / total : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(children: [
                  Text(b['label'] as String,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                  const SizedBox(width: 6),
                  Expanded(child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      backgroundColor: const Color(0xFFF3F4F6),
                      valueColor: AlwaysStoppedAnimation<Color>(b['color'] as Color),
                      minHeight: 8,
                    ),
                  )),
                  const SizedBox(width: 6),
                  Text('$count', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                ]),
              );
            }).toList(),
          )),
        ]),
      ]),
    );
  }

  Widget _emptyState() => const Padding(
    padding: EdgeInsets.all(24),
    child: Center(child: Text('Chưa có dữ liệu', style: TextStyle(color: Colors.grey))),
  );

  String _fmtRevenue(dynamic v) {
    final n = v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;
    if (n >= 1e9) return '${(n / 1e9).toStringAsFixed(1)}T';
    if (n >= 1e6) return '${(n / 1e6).toStringAsFixed(0)}M';
    if (n >= 1e3) return '${(n / 1e3).toStringAsFixed(0)}K';
    return n.toStringAsFixed(0);
  }
}