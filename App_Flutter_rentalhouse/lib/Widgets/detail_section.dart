import 'package:flutter/material.dart';

class DetailSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<String> items;

  const DetailSection({
    super.key,
    required this.title,
    required this.icon,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: Colors.blue[700]),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...items.map(
              (item) => Padding(
            padding: const EdgeInsets.only(left: 28.0, bottom: 4.0),
            child: Text(
              item,
              style: const TextStyle(fontSize: 16, color: Colors.black54),
            ),
          ),
        ),
      ],
    );
  }
}