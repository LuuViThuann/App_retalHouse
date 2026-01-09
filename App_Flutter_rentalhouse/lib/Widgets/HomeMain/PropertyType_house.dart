import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/config/api_routes.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_rental.dart';
import 'package:flutter_rentalhouse/views/main_list_cart_home.dart';
import 'package:flutter_rentalhouse/utils/rental_filter.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

class PropertyTypeScreen extends StatefulWidget {
  final String propertyType;
  const PropertyTypeScreen({super.key, required this.propertyType});

  @override
  State<PropertyTypeScreen> createState() => _PropertyTypeScreenState();
}

class _PropertyTypeScreenState extends State<PropertyTypeScreen> {
  List<dynamic> provinces = [];
  bool isLoadingProvinces = true;

  // ĐÃ KHỞI TẠO NGAY TỪ ĐẦU → KHÔNG BAO GIỜ BỊ LATE ERROR
  RentalFilter filter = const RentalFilter();

  @override
  void initState() {
    super.initState();

    // Gán đúng loại nhà ngay từ đầu (ví dụ: "Nhà riêng", "Căn hộ chung cư"...)
    filter = RentalFilter(
      selectedPropertyType:
          widget.propertyType == 'Tất cả' ? 'Tất cả' : widget.propertyType,
    );

    fetchProvinces();
  }

  Future<void> fetchProvinces() async {
    try {
      final response = await http.get(ApiRoutes.provinces);
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes)) as List;
        setState(() {
          provinces = data;
          isLoadingProvinces = false;

          final canTho = data.firstWhere(
            (p) => p['name'] == 'Cần Thơ',
            orElse: () => null,
          );

          if (canTho != null) {
            filter = filter.copyWith(selectedProvince: canTho);
          }
        });
      }
    } catch (e) {
      setState(() => isLoadingProvinces = false);
    }
  }

  void clearAllFilters() {
    final canTho = provinces.firstWhere(
      (p) => p['name'] == 'Cần Thơ',
      orElse: () => null,
    );
    setState(() {
      filter = filter.clear(defaultProvince: canTho);
    });
  }

  @override
  Widget build(BuildContext context) {
    final rentalVM = Provider.of<RentalViewModel>(context, listen: true);
    final filteredRentals = filter.apply(
      rentals: rentalVM.rentals,
      // Chỉ ép loại nhà khi người dùng CHƯA chọn gì trong bộ lọc loại nhà ==============
      overridePropertyType: (widget.propertyType != 'Tất cả' &&
              filter.selectedPropertyType == 'Tất cả')
          ? widget.propertyType
          : null,
    );

    final hasActiveFilter = filter.hasActiveFilter;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.blue[700],
        elevation: 0,
        title: Text(
          widget.propertyType == 'Tất cả'
              ? 'Tất cả nhà cho thuê'
              : widget.propertyType,
          style: const TextStyle(
              fontWeight: FontWeight.bold, color: Colors.white, fontSize: 19),
        ),
        leading: const BackButton(color: Colors.white),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        actions: [
          if (hasActiveFilter)
            TextButton(
              onPressed: clearAllFilters,
              child: const Text('Xóa',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: Column(
        children: [
          // Thanh bộ lọc ngang
          Container(
            width: double.infinity,
            color: Colors.grey[50],
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  // Nút Bộ lọc chính
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue[600]!, Colors.blue[800]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.tune_rounded,
                            color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        const Text("Bộ lọc",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                        if (hasActiveFilter) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(10)),
                            child: const Text("●",
                                style: TextStyle(
                                    color: Colors.white, fontSize: 10)),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  _buildFilterChip(
                    icon: Icons.location_on_outlined,
                    title: 'Tỉnh/Thành phố',
                    value: filter.selectedProvince?['name'] ?? 'Tỉnh/TP',
                    color: Colors.indigo,
                    onTap: () =>
                        _showFilterSheet('province', 'Chọn Tỉnh/Thành phố'),
                  ),
                  const SizedBox(width: 12),
                  _buildFilterChip(
                    icon: Icons.home_outlined,
                    title: 'Loại nhà',
                    value: filter.selectedPropertyType,
                    color: Colors.teal,
                    onTap: () => _showFilterSheet('property', 'Chọn Loại nhà'),
                  ),
                  const SizedBox(width: 12),
                  _buildFilterChip(
                    icon: Icons.space_dashboard_outlined,
                    title: 'Diện tích',
                    value: filter.selectedAreaRange ?? 'Diện tích',
                    color: Colors.orange,
                    onTap: () => _showFilterSheet('area', 'Chọn Diện tích'),
                  ),
                  const SizedBox(width: 12),
                  _buildFilterChip(
                    icon: Icons.attach_money_outlined,
                    title: 'Mức giá',
                    value: filter.selectedPriceRange ?? 'Mức giá',
                    color: Colors.green,
                    onTap: () => _showFilterSheet('price', 'Chọn Mức giá'),
                  ),
                ],
              ),
            ),
          ),

          // Danh sách kết quả
          Expanded(
            child: rentalVM.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.blue))
                : filteredRentals.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off,
                                size: 90, color: Colors.grey[400]),
                            const SizedBox(height: 20),
                            const Text('Không tìm thấy thông tin phù hợp',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w600)),
                            if (hasActiveFilter)
                              const Text('Thử thay đổi bộ lọc nhé!',
                                  style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredRentals.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (context, index) =>
                            RentalItemWidget(rental: filteredRentals[index]),
                      ),
          ),
        ],
      ),
    );
  }

  // Chip lọc
  Widget _buildFilterChip({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required VoidCallback onTap,
  }) {
    final bool isSelected = value != title &&
        value != 'Tỉnh/TP' &&
        value != 'Diện tích' &&
        value != 'Mức giá' &&
        value != 'Tất cả';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.grey[50],
          border: Border.all(
              color: isSelected ? color : Colors.grey.shade300, width: 1.5),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: isSelected ? color : Colors.grey[700]),
            const SizedBox(width: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? color : Colors.grey[800],
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: color),
            ],
          ],
        ),
      ),
    );
  }

  // Bottom Sheet chọn bộ lọc
  void _showFilterSheet(String type, String sheetTitle) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          builder: (_, controller) => Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Container(
                        width: 50,
                        height: 5,
                        decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(10))),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(sheetTitle,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                        IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context)),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Danh sách
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  itemCount: type == 'province'
                      ? provinces.length
                      : type == 'property'
                          ? RentalFilter.propertyTypes.length
                          : type == 'area'
                              ? RentalFilter.areaOptions.length
                              : RentalFilter.priceOptions.length,
                  itemBuilder: (context, index) {
                    dynamic item;
                    String display;

                    if (type == 'province') {
                      item = provinces[index];
                      display = item['name'];
                    } else if (type == 'property') {
                      item = RentalFilter.propertyTypes[index];
                      display = item;
                    } else if (type == 'area') {
                      item = RentalFilter.areaOptions[index];
                      display = item['label'];
                    } else {
                      item = RentalFilter.priceOptions[index];
                      display = item['label'];
                    }

                    final bool isSelected = (type == 'province' &&
                            filter.selectedProvince?['name'] == display) ||
                        (type == 'property' &&
                            filter.selectedPropertyType == display) ||
                        (type == 'area' &&
                            filter.selectedAreaRange == display) ||
                        (type == 'price' &&
                            filter.selectedPriceRange == display);

                    return ListTile(
                      leading: isSelected
                          ? const Icon(Icons.check_circle, color: Colors.blue)
                          : const Icon(Icons.circle_outlined),
                      title:
                          Text(display, style: const TextStyle(fontSize: 16)),
                      onTap: () {
                        setState(() {
                          if (type == 'province') {
                            filter = filter.copyWith(selectedProvince: item);
                          } else if (type == 'property') {
                            filter =
                                filter.copyWith(selectedPropertyType: display);
                          } else if (type == 'area') {
                            filter =
                                filter.copyWith(selectedAreaRange: display);
                          } else if (type == 'price') {
                            filter =
                                filter.copyWith(selectedPriceRange: display);
                          }
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
