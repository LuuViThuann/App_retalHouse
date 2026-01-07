import 'package:flutter/material.dart';
import '../../viewmodels/vm_analytics.dart';

class HotAreasList extends StatelessWidget {
  final AnalyticsViewModel viewModel;

  const HotAreasList({Key? key, required this.viewModel}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (viewModel.hotAreas.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.whatshot, color: Colors.orange[700], size: 24),
            const SizedBox(width: 8),
            const Text(
              'Khu vực có nhiều BĐS nhất',
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
            children: viewModel.hotAreas.asMap().entries.map((entry) {
              final index = entry.key;
              final area = entry.value;
              final count = area['count'] ?? 0;
              final isHot = count >= 20;
              final avgPrice = viewModel.formatPrice(area['avgPrice']);

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildAreaCard(
                  rank: index + 1,
                  name: area['_id'] ?? 'N/A',
                  count: count,
                  avgPrice: avgPrice,
                  isHot: isHot,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildAreaCard({
    required int rank,
    required String name,
    required int count,
    required String avgPrice,
    required bool isHot,
  }) {
    IconData rankIcon;
    Color rankColor;

    if (rank == 1) {
      rankIcon = Icons.emoji_events;
      rankColor = Colors.amber[700]!;
    } else if (rank == 2) {
      rankIcon = Icons.emoji_events;
      rankColor = Colors.grey[400]!;
    } else if (rank == 3) {
      rankIcon = Icons.emoji_events;
      rankColor = Colors.orange[700]!;
    } else {
      rankIcon = Icons.circle;
      rankColor = Colors.grey[400]!;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isHot
              ? [Colors.red[50]!, Colors.orange[50]!]
              : [Colors.grey[50]!, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHot ? Colors.red[300]! : Colors.grey[200]!,
          width: isHot ? 2 : 1,
        ),
        boxShadow: isHot
            ? [
          BoxShadow(
            color: Colors.red.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ]
            : null,
      ),
      child: Row(
        children: [
          // Rank Badge
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: rankColor.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: rankColor, width: 2),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(rankIcon, color: rankColor, size: rank <= 3 ? 28 : 16),
                if (rank > 3)
                  Text(
                    '$rank',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: rankColor,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isHot)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red[600],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.local_fire_department, color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text(
                              'HOT',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.home, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      '$count BĐS',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.attach_money, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'TB: $avgPrice',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Arrow
          Icon(
            Icons.chevron_right,
            color: Colors.grey[400],
            size: 24,
          ),
        ],
      ),
    );
  }
}