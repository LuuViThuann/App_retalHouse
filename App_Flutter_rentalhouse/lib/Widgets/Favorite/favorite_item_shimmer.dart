import 'package:flutter/material.dart';

// code biểu thị state loading

class RentalItemShimmer extends StatelessWidget {
  const RentalItemShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Colors.grey[200]!))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 90,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                    width: 80,
                    height: 12,
                    decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 6),
                Container(
                    width: 60,
                    height: 12,
                    decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 8),
                Container(
                    width: double.infinity,
                    height: 14,
                    decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 4),
                Container(
                    width: double.infinity,
                    height: 14,
                    decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 8),
                Container(
                    width: 120,
                    height: 12,
                    decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                        width: 30,
                        height: 16,
                        decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(4))),
                    const SizedBox(width: 5),
                    Container(
                        width: 90,
                        height: 16,
                        decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(4))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}