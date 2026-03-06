import 'package:flutter/material.dart';
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

class HotAreasList extends StatelessWidget {
  final AnalyticsViewModel viewModel;

  const HotAreasList({Key? key, required this.viewModel}) : super(key: key);

  String _getAreaName(Map<String, dynamic> area) =>
      (area['_id'] ?? area['name'] ?? 'N/A').toString();

  int _getCount(Map<String, dynamic> area) {
    final v = area['count'];
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  double _getAvgPrice(dynamic v) {
    if (v == null) return 0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final hotAreas = viewModel.hotAreas;
    if (hotAreas.isEmpty) return const SizedBox.shrink();

    final totalCount = hotAreas.fold<int>(
        0, (sum, area) => sum + _getCount(area as Map<String, dynamic>));
    final maxCount = hotAreas.isNotEmpty
        ? _getCount(hotAreas.first as Map<String, dynamic>)
        : 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──────────────────────────────────────────
        Row(
          children: [
            const Text('Khu vực nổi bật',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: _C.text)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _C.bg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _C.border),
              ),
              child: Text('$totalCount BĐS',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _C.textSub)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Tỷ lệ % trên tổng số bất động sản',
          style: TextStyle(fontSize: 11, color: _C.muted),
        ),
        const SizedBox(height: 14),

        // ── Card ────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: _C.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _C.border),
          ),
          child: Column(
            children: [
              // Table header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: const BoxDecoration(
                  color: _C.bg,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                  border: Border(bottom: BorderSide(color: _C.border)),
                ),
                child: Row(
                  children: const [
                    SizedBox(width: 32, child: Text('#', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _C.muted))),
                    SizedBox(width: 10),
                    Expanded(child: Text('Khu vực', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _C.muted))),
                    Text('Tỷ lệ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _C.muted)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: _buildHotList(hotAreas, totalCount, maxCount),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHotList(List hotAreas, int totalCount, int maxCount) {
    if (hotAreas.isEmpty) {
      return SizedBox(
        height: 80,
        child: Center(
            child: Text('Chưa có dữ liệu khu vực',
                style: TextStyle(color: _C.muted, fontSize: 13))),
      );
    }

    return Column(
      children: hotAreas.asMap().entries.map((entry) {
        final idx      = entry.key;
        final area     = entry.value as Map<String, dynamic>;
        final count    = _getCount(area);
        final name     = _getAreaName(area);
        final avgPrice = viewModel.formatPrice(_getAvgPrice(area['avgPrice']));
        final pctOfTotal = totalCount > 0 ? count / totalCount : 0.0;
        final pctBar   = maxCount > 0 ? count / maxCount : 0.0;
        final isHot    = count >= 20;

        return _buildCard(
          rank: idx + 1,
          name: name,
          count: count,
          avgPrice: avgPrice,
          pctOfTotal: pctOfTotal,
          pctBar: pctBar,
          isHot: isHot,
        );
      }).toList(),
    );
  }

  Widget _buildCard({
    required int rank,
    required String name,
    required int count,
    required String avgPrice,
    required double pctOfTotal,
    required double pctBar,
    required bool isHot,
  }) {
    final pctText = '${(pctOfTotal * 100).toStringAsFixed(1)}%';
    final isFirst = rank == 1;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isFirst ? const Color(0xFFF0F5FF) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: isFirst ? const Color(0xFFBFD3FF) : _C.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Rank
              SizedBox(
                width: 32,
                child: Text(
                  '$rank',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: rank <= 3 ? _C.accent : _C.muted,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 10),

              // Name + meta
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: _C.text),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        if (isHot) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFFFCD34D)),
                            ),
                            child: const Text('HOT',
                                style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF92400E))),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text('$count BĐS · TB: $avgPrice',
                        style: const TextStyle(
                            fontSize: 11, color: _C.textSub)),
                  ],
                ),
              ),

              // Pct
              Text(pctText,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _C.accent)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: pctBar.clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: _C.border,
              valueColor: AlwaysStoppedAnimation<Color>(
                isFirst ? _C.accent : const Color(0xFF93C5FD),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('So với khu vực dẫn đầu',
                  style: TextStyle(fontSize: 10, color: _C.muted)),
              Text('${(pctBar * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 10, color: _C.muted)),
            ],
          ),
        ],
      ),
    );
  }
}