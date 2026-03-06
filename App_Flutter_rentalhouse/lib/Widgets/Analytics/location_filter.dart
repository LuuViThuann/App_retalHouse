import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../config/api_routes.dart';

class _C {
  static const bg      = Color(0xFFF9FAFB);
  static const surface = Colors.white;
  static const border  = Color(0xFFE5E7EB);
  static const text    = Color(0xFF111827);
  static const textSub = Color(0xFF6B7280);
  static const muted   = Color(0xFF9CA3AF);
  static const accent  = Color(0xFF2563EB);
}

class LocationFilter extends StatefulWidget {
  final String? selectedProvince;
  final String? selectedDistrict;
  final String? selectedWard;
  final Function({String? province, String? district, String? ward}) onLocationChanged;
  final VoidCallback onClear;
  final VoidCallback onApply;

  const LocationFilter({
    Key? key,
    this.selectedProvince,
    this.selectedDistrict,
    this.selectedWard,
    required this.onLocationChanged,
    required this.onClear,
    required this.onApply,
  }) : super(key: key);

  @override
  State<LocationFilter> createState() => _LocationFilterState();
}

class _LocationFilterState extends State<LocationFilter> {
  List<dynamic> provinces = [];
  List<Map<String, dynamic>> districts = [];
  List<dynamic> wards = [];

  String? selectedProvinceCode;
  String? selectedDistrictCode;
  String? tempProvince;
  String? tempDistrict;
  String? tempWard;

  bool isLoading = false;
  bool hasChanges = false;

  @override
  void initState() {
    super.initState();
    _fetchProvinces();
    tempProvince = widget.selectedProvince;
    tempDistrict = widget.selectedDistrict;
    tempWard     = widget.selectedWard;
  }

  @override
  void didUpdateWidget(LocationFilter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedProvince != oldWidget.selectedProvince ||
        widget.selectedDistrict != oldWidget.selectedDistrict ||
        widget.selectedWard     != oldWidget.selectedWard) {
      setState(() {
        tempProvince = widget.selectedProvince;
        tempDistrict = widget.selectedDistrict;
        tempWard     = widget.selectedWard;
        hasChanges   = false;
      });
    }
  }

  Future<void> _fetchProvinces() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(ApiRoutes.provinces);
      if (response.statusCode == 200 && mounted) {
        setState(() {
          provinces = json.decode(utf8.decode(response.bodyBytes));
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _fetchDistricts(String provinceCode) async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(ApiRoutes.getDistricts(provinceCode));
      if (response.statusCode == 200 && mounted) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          districts = List<Map<String, dynamic>>.from(data['districts'] ?? []);
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _fetchWards(String districtCode) async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(ApiRoutes.getWards(districtCode));
      if (response.statusCode == 200 && mounted) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          wards = List<dynamic>.from(data['wards'] ?? []);
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _checkChanges() {
    setState(() {
      hasChanges = tempProvince != widget.selectedProvince ||
          tempDistrict != widget.selectedDistrict ||
          tempWard     != widget.selectedWard;
    });
  }

  void _applyFilter() {
    widget.onLocationChanged(
        province: tempProvince, district: tempDistrict, ward: tempWard);
    setState(() => hasChanges = false);
    widget.onApply();
  }

  void _clearAllFilters() {
    setState(() {
      tempProvince = tempDistrict = tempWard = null;
      selectedProvinceCode = selectedDistrictCode = null;
      districts = [];
      wards     = [];
      hasChanges = false;
    });
    widget.onClear();
  }

  @override
  Widget build(BuildContext context) {
    final hasFilter =
        tempProvince != null || tempDistrict != null || tempWard != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Lọc khu vực',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _C.text)),
              const Spacer(),
              if (hasFilter)
                GestureDetector(
                  onTap: _clearAllFilters,
                  child: const Text('Xóa',
                      style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFEF4444),
                          fontWeight: FontWeight.w500)),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Filter chips
          Row(
            children: [
              Expanded(
                child: _buildChip(
                  label: tempProvince ?? 'Tỉnh/TP',
                  isSelected: tempProvince != null,
                  onTap: () => _selectProvince(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildChip(
                  label: tempDistrict ?? 'Quận/Huyện',
                  isSelected: tempDistrict != null,
                  onTap: tempProvince == null ? null : () => _selectDistrict(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildChip(
                  label: tempWard ?? 'Phường/Xã',
                  isSelected: tempWard != null,
                  onTap: tempDistrict == null ? null : () => _selectWard(context),
                ),
              ),
            ],
          ),

          // Apply button
          if (hasChanges) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _applyFilter,
                style: TextButton.styleFrom(
                  backgroundColor: _C.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Áp dụng',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ),
          ],

          // Applied state info
          if (!hasChanges && hasFilter) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.check_circle_outline,
                    size: 14, color: Color(0xFF10B981)),
                const SizedBox(width: 6),
                Text(
                  [
                    if (tempProvince != null) tempProvince!,
                    if (tempDistrict != null) tempDistrict!,
                    if (tempWard     != null) tempWard!,
                  ].join(' › '),
                  style: const TextStyle(
                      fontSize: 12,
                      color: _C.textSub,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required bool isSelected,
    required VoidCallback? onTap,
  }) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? _C.accent : (disabled ? _C.bg : Colors.white),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? _C.accent
                : (disabled ? _C.border : _C.border),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected
                ? Colors.white
                : (disabled ? _C.muted : _C.textSub),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Future<void> _selectProvince(BuildContext ctx) async {
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BottomSheetSelector(
          title: 'Tỉnh / Thành phố',
          items: provinces,
          currentSelection: tempProvince),
    );
    if (selected != null && mounted) {
      selectedProvinceCode = selected['code'].toString();
      await _fetchDistricts(selectedProvinceCode!);
      setState(() {
        tempProvince = selected['name'];
        tempDistrict = tempWard = null;
        selectedDistrictCode = null;
        wards = [];
      });
      _checkChanges();
    }
  }

  Future<void> _selectDistrict(BuildContext ctx) async {
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BottomSheetSelector(
          title: 'Quận / Huyện',
          items: districts,
          displayKey: 'name',
          currentSelection: tempDistrict),
    );
    if (selected != null && mounted) {
      selectedDistrictCode = selected['code'].toString();
      await _fetchWards(selectedDistrictCode!);
      setState(() {
        tempDistrict = selected['name'];
        tempWard     = null;
      });
      _checkChanges();
    }
  }

  Future<void> _selectWard(BuildContext ctx) async {
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BottomSheetSelector(
          title: 'Phường / Xã',
          items: wards,
          displayKey: 'name',
          currentSelection: tempWard),
    );
    if (selected != null && mounted) {
      setState(() => tempWard = selected['name']);
      _checkChanges();
    }
  }
}

class _BottomSheetSelector extends StatelessWidget {
  final String title;
  final List items;
  final String displayKey;
  final String? currentSelection;

  const _BottomSheetSelector({
    required this.title,
    required this.items,
    this.displayKey = 'name',
    this.currentSelection,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Text('Huỷ',
                      style: TextStyle(
                          fontSize: 14, color: Color(0xFF6B7280))),
                ),
                Expanded(
                  child: Text(title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827))),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (_, i) {
                final item = items[i];
                final displayText = item is Map
                    ? item[displayKey] ?? item['name'] ?? ''
                    : item.toString();
                final isSelected = displayText == currentSelection;

                return ListTile(
                  dense: true,
                  title: Text(displayText,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: isSelected
                              ? const Color(0xFF2563EB)
                              : const Color(0xFF111827))),
                  trailing: isSelected
                      ? const Icon(Icons.check,
                      color: Color(0xFF2563EB), size: 18)
                      : null,
                  tileColor: isSelected
                      ? const Color(0xFFF0F5FF)
                      : null,
                  onTap: () => Navigator.pop(context, item),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}