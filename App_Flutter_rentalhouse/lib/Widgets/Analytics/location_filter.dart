import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../config/api_routes.dart';

class LocationFilter extends StatefulWidget {
  final String? selectedProvince;
  final String? selectedDistrict;
  final String? selectedWard;
  final Function({String? province, String? district, String? ward}) onLocationChanged;
  final VoidCallback onClear;
  final VoidCallback onApply; // ✅ NEW: Callback khi nhấn Áp dụng

  const LocationFilter({
    Key? key,
    this.selectedProvince,
    this.selectedDistrict,
    this.selectedWard,
    required this.onLocationChanged,
    required this.onClear,
    required this.onApply, // ✅ NEW
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

  // ✅ NEW: Temporary selections (chưa apply)
  String? tempProvince;
  String? tempDistrict;
  String? tempWard;

  bool isLoading = false;
  bool hasChanges = false; // ✅ NEW: Track nếu có thay đổi

  @override
  void initState() {
    super.initState();
    _fetchProvinces();
    // Initialize temp values
    tempProvince = widget.selectedProvince;
    tempDistrict = widget.selectedDistrict;
    tempWard = widget.selectedWard;
  }

  @override
  void didUpdateWidget(LocationFilter oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update temp values when widget updates
    if (widget.selectedProvince != oldWidget.selectedProvince ||
        widget.selectedDistrict != oldWidget.selectedDistrict ||
        widget.selectedWard != oldWidget.selectedWard) {
      setState(() {
        tempProvince = widget.selectedProvince;
        tempDistrict = widget.selectedDistrict;
        tempWard = widget.selectedWard;
        hasChanges = false;
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

  // ✅ NEW: Check if there are changes
  void _checkChanges() {
    setState(() {
      hasChanges = tempProvince != widget.selectedProvince ||
          tempDistrict != widget.selectedDistrict ||
          tempWard != widget.selectedWard;
    });
  }

  // ✅ NEW: Apply filter
  void _applyFilter() {
    widget.onLocationChanged(
      province: tempProvince,
      district: tempDistrict,
      ward: tempWard,
    );
    setState(() {
      hasChanges = false;
    });
    widget.onApply(); // Trigger refresh analytics
  }

  // ✅ NEW: Clear all filters
  void _clearAllFilters() {
    setState(() {
      tempProvince = null;
      tempDistrict = null;
      tempWard = null;
      selectedProvinceCode = null;
      selectedDistrictCode = null;
      districts = [];
      wards = [];
      hasChanges = false;
    });
    widget.onClear();
  }

  @override
  Widget build(BuildContext context) {
    final hasFilter = tempProvince != null ||
        tempDistrict != null ||
        tempWard != null;

    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.filter_list_rounded, color: Colors.blue[700], size: 24),
              const SizedBox(width: 8),
              const Text(
                'Lọc theo khu vực',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (hasFilter)
                TextButton.icon(
                  onPressed: _clearAllFilters,
                  icon: const Icon(Icons.clear, size: 18),
                  label: const Text('Xóa bộ lọc'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red[400],
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Filter Chips
          Row(
            children: [
              Expanded(
                child: _buildFilterChip(
                  label: tempProvince ?? 'Tỉnh/TP',
                  icon: Icons.location_city,
                  isSelected: tempProvince != null,
                  onTap: () => _selectProvince(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFilterChip(
                  label: tempDistrict ?? 'Quận/Huyện',
                  icon: Icons.map_outlined,
                  isSelected: tempDistrict != null,
                  onTap: tempProvince == null
                      ? null
                      : () => _selectDistrict(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFilterChip(
                  label: tempWard ?? 'Phường/Xã',
                  icon: Icons.location_on_outlined,
                  isSelected: tempWard != null,
                  onTap: tempDistrict == null
                      ? null
                      : () => _selectWard(context),
                ),
              ),
            ],
          ),

          // ✅ NEW: Apply Button (show when hasChanges)
          if (hasChanges) ...[
            const SizedBox(height: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _applyFilter,
                      icon: const Icon(Icons.check_circle, size: 20),
                      label: const Text(
                        'Áp dụng bộ lọc',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ✅ NEW: Current Filter Info (when applied)
          if (!hasChanges && hasFilter) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Đang lọc thông tin địa chỉ đã chọn...',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[900],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(Icons.check_circle, color: Colors.green[600], size: 18),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ✅ NEW: Get filter text
  String _getFilterText() {
    final parts = <String>[];
    if (tempProvince != null) parts.add(tempProvince!);
    if (tempDistrict != null) parts.add(tempDistrict!);
    if (tempWard != null) parts.add(tempWard!);
    return parts.join(' → ');
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[700] : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blue[700]! : Colors.grey[300]!,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey[600],
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : Colors.grey[700],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
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
        title: 'Chọn Tỉnh/Thành phố',
        items: provinces,
        currentSelection: tempProvince,
      ),
    );

    if (selected != null && mounted) {
      selectedProvinceCode = selected['code'].toString();
      await _fetchDistricts(selectedProvinceCode!);
      setState(() {
        tempProvince = selected['name'];
        tempDistrict = null;
        tempWard = null;
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
        title: 'Chọn Quận/Huyện',
        items: districts,
        displayKey: 'name',
        currentSelection: tempDistrict,
      ),
    );

    if (selected != null && mounted) {
      selectedDistrictCode = selected['code'].toString();
      await _fetchWards(selectedDistrictCode!);
      setState(() {
        tempDistrict = selected['name'];
        tempWard = null;
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
        title: 'Chọn Phường/Xã',
        items: wards,
        displayKey: 'name',
        currentSelection: tempWard,
      ),
    );

    if (selected != null && mounted) {
      setState(() {
        tempWard = selected['name'];
      });
      _checkChanges();
    }
  }
}

class _BottomSheetSelector extends StatelessWidget {
  final String title;
  final List items;
  final String displayKey;
  final String? currentSelection; // ✅ NEW: Highlight current selection

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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Huỷ'),
                ),
                Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: items.length,
              itemBuilder: (_, i) {
                final item = items[i];
                final displayText = item is Map
                    ? item[displayKey] ?? item['name'] ?? ''
                    : item.toString();

                // ✅ NEW: Check if this is current selection
                final isSelected = displayText == currentSelection;

                return ListTile(
                  title: Text(
                    displayText,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.blue[700] : Colors.black,
                    ),
                  ),
                  onTap: () => Navigator.pop(context, item),
                  trailing: isSelected
                      ? Icon(Icons.check_circle, color: Colors.blue[700])
                      : const Icon(Icons.chevron_right),
                  tileColor: isSelected ? Colors.blue[50] : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}