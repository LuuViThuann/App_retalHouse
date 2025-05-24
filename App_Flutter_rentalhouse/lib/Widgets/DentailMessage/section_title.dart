import 'package:flutter/material.dart';

class SectionTitle extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Color color;

  const SectionTitle({
    super.key,
    required this.title,
    this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData currentTheme = Theme.of(context);
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
        ],
        Text(
          title,
          style: currentTheme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: currentTheme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
