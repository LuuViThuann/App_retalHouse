import 'package:flutter/material.dart';

class _C {
  static const bg       = Color(0xFFF9FAFB);
  static const surface  = Colors.white;
  static const border   = Color(0xFFE5E7EB);
  static const text     = Color(0xFF111827);
  static const textSub  = Color(0xFF6B7280);
  static const muted    = Color(0xFF9CA3AF);
  static const accent   = Color(0xFF2563EB);
}

class ChartDetailDropdown extends StatefulWidget {
  final String title;
  final List<Map<String, dynamic>> data;
  final String valueKey;
  final String labelKey;
  final IconData icon;
  final Color accentColor;
  final String? formatType;

  const ChartDetailDropdown({
    Key? key,
    required this.title,
    required this.data,
    required this.valueKey,
    required this.labelKey,
    required this.icon,
    this.accentColor = _C.accent,
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
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      _isExpanded ? _animationController.forward() : _animationController.reverse();
    });
  }

  String _formatValue(dynamic value) {
    if (widget.formatType == null) return value.toString();
    final v = _toDouble(value);
    switch (widget.formatType) {
      case 'price':      return _fmtPrice(v);
      case 'area':       return '${v.toStringAsFixed(0)} m²';
      case 'percentage': return '${v.toStringAsFixed(1)}%';
      case 'count':      return v.toStringAsFixed(0);
      default:           return v.toString();
    }
  }

  String _fmtPrice(double p) {
    if (p >= 1e9) return '${(p / 1e9).toStringAsFixed(2)} tỷ';
    if (p >= 1e6) return '${(p / 1e6).toStringAsFixed(0)} triệu';
    return '${p.toStringAsFixed(0)} đ';
  }

  double _toDouble(dynamic v) {
    if (v is int) return v.toDouble();
    if (v is double) return v;
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _C.border),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: _toggleExpanded,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                children: [
                  Icon(widget.icon, color: _C.textSub, size: 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(widget.title,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600, color: _C.text)),
                  ),
                  Text('${widget.data.length} mục',
                      style: const TextStyle(fontSize: 11, color: _C.muted)),
                  const SizedBox(width: 8),
                  RotationTransition(
                    turns: Tween(begin: 0.0, end: 0.5).animate(_expandAnimation),
                    child: const Icon(Icons.keyboard_arrow_down, color: _C.muted, size: 18),
                  ),
                ],
              ),
            ),
          ),
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: Column(
              children: [
                const Divider(height: 1, color: _C.border),
                Container(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(10),
                    itemCount: widget.data.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, i) {
                      final item  = widget.data[i];
                      final label = item[widget.labelKey]?.toString() ?? 'N/A';
                      final value = item[widget.valueKey];
                      return _buildRow(index: i + 1, label: label,
                          value: _formatValue(value), item: item);
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

  Widget _buildRow({
    required int index,
    required String label,
    required String value,
    required Map<String, dynamic> item,
  }) {
    final isTop = index <= 3;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: isTop ? _C.bg : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _C.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Text('$index',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isTop ? _C.accent : _C.muted),
                textAlign: TextAlign.center),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500, color: _C.text),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                if (item['percentage'] != null) ...[
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: (_toDouble(item['percentage']) / 100).clamp(0.0, 1.0),
                            minHeight: 3,
                            backgroundColor: _C.border,
                            valueColor: const AlwaysStoppedAnimation(_C.accent),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('${_toDouble(item['percentage']).toStringAsFixed(1)}%',
                          style: const TextStyle(fontSize: 10, color: _C.muted)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(value,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: _C.text)),
        ],
      ),
    );
  }
}