import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../viewmodels/vm_analytics.dart';

class AmenitiesStatsChart extends StatefulWidget {
  final AnalyticsViewModel viewModel;
  const AmenitiesStatsChart({Key? key, required this.viewModel}) : super(key: key);

  @override
  State<AmenitiesStatsChart> createState() => _AmenitiesStatsChartState();
}

class _AmenitiesStatsChartState extends State<AmenitiesStatsChart>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() { if (!_tab.indexIsChanging) setState(() => _selectedTab = _tab.index); });
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final stats = widget.viewModel.amenitiesStats;
    final amenities = (stats['amenities'] as List?) ?? [];
    final furniture = (stats['furniture'] as List?) ?? [];
    final media     = stats['mediaStats'] as Map<String, dynamic>? ?? {};

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.home_outlined, color: Color(0xFF16A34A), size: 20),
        ),
        const SizedBox(width: 10),
        const Text('Tiện nghi & Nội thất',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
      ]),
      const SizedBox(height: 14),

      // Media coverage chips
      if (media.isNotEmpty) ...[
        Row(children: [
          _coverageChip(Icons.photo_library_outlined, '${media['imageCoverage']}%',
              'Có ảnh', const Color(0xFF2563EB)),
          const SizedBox(width: 10),
          _coverageChip(Icons.videocam_outlined, '${media['videoCoverage']}%',
              'Có video', const Color(0xFF7C3AED)),
          const SizedBox(width: 10),
          _coverageChip(Icons.image_outlined, '${media['avgImages']}',
              'Ảnh TB/bài', const Color(0xFF0891B2)),
        ]),
        const SizedBox(height: 14),
      ],

      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(children: [
          // Tab bar
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(10)),
            child: TabBar(
              controller: _tab,
              indicator: BoxDecoration(
                color: _selectedTab == 0 ? const Color(0xFF2563EB) : const Color(0xFF16A34A),
                borderRadius: BorderRadius.circular(8),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey[500],
              labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              unselectedLabelStyle: const TextStyle(fontSize: 12),
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(height: 32, child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.wifi, size: 13), SizedBox(width: 4), Text('Tiện nghi'),
                ])),
                Tab(height: 32, child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.chair, size: 13), SizedBox(width: 4), Text('Nội thất'),
                ])),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _selectedTab == 0
                ? _buildHorizontalBars(amenities, const Color(0xFF2563EB))
                : _buildHorizontalBars(furniture, const Color(0xFF16A34A)),
          ),
        ]),
      ),
    ]);
  }

  Widget _coverageChip(IconData icon, String value, String label, Color color) {
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600]), textAlign: TextAlign.center),
      ]),
    ));
  }

  Widget _buildHorizontalBars(List items, Color color) {
    if (items.isEmpty) return const Padding(
      padding: EdgeInsets.all(24),
      child: Center(child: Text('Chưa có dữ liệu', style: TextStyle(color: Colors.grey))),
    );

    final maxCount = (items.first as Map)['count'] as num;

    return Column(
      children: items.take(8).toList().asMap().entries.map((e) {
        final item = e.value as Map<String, dynamic>;
        final pct  = maxCount > 0 ? (item['count'] as num) / maxCount : 0.0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            Container(
              width: 22, height: 22,
              decoration: BoxDecoration(
                color: e.key < 3 ? color : color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(child: Text('${e.key + 1}',
                  style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.bold,
                    color: e.key < 3 ? Colors.white : color,
                  ))),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Flexible(child: Text(item['name']?.toString() ?? '',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                  Text('${item['count']} (${item['percentage']}%)',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                ]),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct.toDouble(),
                    backgroundColor: const Color(0xFFF3F4F6),
                    valueColor: AlwaysStoppedAnimation<Color>(
                        e.key == 0 ? color : color.withOpacity(0.5 + pct * 0.4)),
                    minHeight: 5,
                  ),
                ),
              ]),
            ),
          ]),
        );
      }).toList(),
    );
  }
}