import 'package:flutter/material.dart';

class InfoChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;

  const InfoChip({
    super.key,
    required this.label,
    required this.value,
    this.icon,
  });

  // Hàm để chọn icon dựa trên label
  IconData _getIconForLabel(String label) {
    switch (label.toLowerCase()) {
      case 'loại chỗ ở':
        return Icons.home;
      case 'phong cách':
        return Icons.brush;
      case 'chi phí':
        return Icons.account_balance_wallet;
      case 'hợp đồng':
        return Icons.description;
      default:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIcon = icon ?? _getIconForLabel(label);

    return InkWell(
      onTap: () {}, // Có thể thêm hành động khi nhấn
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(

          borderRadius: BorderRadius.circular(20),

          border: Border.all(color: Colors.blue.shade100.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: 1.0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade600.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  selectedIcon,
                  size: 22,
                  color: Colors.blue.shade700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.blue.shade800,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
