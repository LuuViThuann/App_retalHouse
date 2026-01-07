import 'package:flutter/material.dart';

class ChartDetailDropdown extends StatefulWidget {
  final String title;
  final List<Map<String, dynamic>> data;
  final String valueKey;
  final String labelKey;
  final IconData icon;
  final Color accentColor;
  final String? formatType; // 'price', 'area', 'count', 'percentage'

  const ChartDetailDropdown({
    Key? key,
    required this.title,
    required this.data,
    required this.valueKey,
    required this.labelKey,
    required this.icon,
    this.accentColor = Colors.blue,
    this.formatType,
  }) : super(key: key);

  @override
  State<ChartDetailDropdown> createState() => _ChartDetailDropdownState();
}

class _ChartDetailDropdownState extends State<ChartDetailDropdown>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  String _formatValue(dynamic value) {
    if (widget.formatType == null) return value.toString();

    final numValue = _toDouble(value);

    switch (widget.formatType) {
      case 'price':
        return _formatPrice(numValue);
      case 'area':
        return '${numValue.toStringAsFixed(0)} m²';
      case 'percentage':
        return '${numValue.toStringAsFixed(1)}%';
      case 'count':
        return numValue.toStringAsFixed(0);
      default:
        return numValue.toString();
    }
  }

  String _formatPrice(double price) {
    if (price >= 1000000000) {
      return '${(price / 1000000000).toStringAsFixed(2)} tỷ';
    } else if (price >= 1000000) {
      return '${(price / 1000000).toStringAsFixed(0)} triệu';
    }
    return '${price.toStringAsFixed(0)} đ';
  }

  double _toDouble(dynamic value) {
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: _toggleExpanded,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: widget.accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      widget.icon,
                      color: widget.accentColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: widget.accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${widget.data.length} mục',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: widget.accentColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  RotationTransition(
                    turns: Tween(begin: 0.0, end: 0.5).animate(_expandAnimation),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expandable Content
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: Column(
              children: [
                const Divider(height: 1),
                Container(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(12),
                    itemCount: widget.data.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = widget.data[index];
                      final label = item[widget.labelKey]?.toString() ?? 'N/A';
                      final value = item[widget.valueKey];

                      return _buildDetailItem(
                        index: index + 1,
                        label: label,
                        value: _formatValue(value),
                        item: item,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem({
    required int index,
    required String label,
    required String value,
    required Map<String, dynamic> item,
  }) {
    // Gradient colors for top 3
    Color? gradientColor;
    if (index == 1) {
      gradientColor = Colors.amber[100];
    } else if (index == 2) {
      gradientColor = Colors.grey[200];
    } else if (index == 3) {
      gradientColor = Colors.orange[100];
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: gradientColor != null
            ? LinearGradient(
          colors: [gradientColor, Colors.white],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        )
            : null,
        color: gradientColor == null ? Colors.grey[50] : null,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: index <= 3 ? widget.accentColor.withOpacity(0.3) : Colors.grey[200]!,
        ),
      ),
      child: Row(
        children: [
          // Rank
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: index <= 3
                  ? widget.accentColor.withOpacity(0.2)
                  : Colors.grey[300],
              shape: BoxShape.circle,
              border: Border.all(
                color: index <= 3 ? widget.accentColor : Colors.grey[400]!,
                width: 2,
              ),
            ),
            child: Center(
              child: index <= 3
                  ? Icon(
                Icons.emoji_events,
                size: 18,
                color: widget.accentColor,
              )
                  : Text(
                '$index',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Label
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item['percentage'] != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        height: 4,
                        width: 40,
                        decoration: BoxDecoration(
                          color: widget.accentColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: (_toDouble(item['percentage']) / 100).clamp(0.0, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: widget.accentColor,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${_toDouble(item['percentage']).toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Value
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: widget.accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: widget.accentColor.withOpacity(0.3),
              ),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: widget.accentColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}