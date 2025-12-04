class RentalFilter {
  final dynamic selectedProvince; // null hoặc Map của tỉnh
  final String? selectedAreaRange; // label diện tích
  final String? selectedPriceRange; // label mức giá
  final String selectedPropertyType; // loại nhà

  // ==================== CÁC TÙY CHỌN CỐ ĐỊNH ====================
  static const List<Map<String, dynamic>> areaOptions = [
    {'label': 'Dưới 30m²', 'min': 0, 'max': 30},
    {'label': '30 - 50m²', 'min': 30, 'max': 50},
    {'label': '50 - 80m²', 'min': 50, 'max': 80},
    {'label': 'Trên 80m²', 'min': 80, 'max': 9999},
  ];

  static const List<Map<String, dynamic>> priceOptions = [
    {'label': 'Dưới 2 triệu', 'max': 2000000},
    {'label': '2 - 5 triệu', 'min': 2000000, 'max': 5000000},
    {'label': '5 - 10 triệu', 'min': 5000000, 'max': 10000000},
    {'label': 'Trên 10 triệu', 'min': 10000000},
  ];

  static const List<String> propertyTypes = [
    'Tất cả',
    'Nhà riêng',
    'Nhà trọ/Phòng trọ',
    'Căn hộ chung cư',
    'Biệt thự',
    'Văn phòng',
    'Mặt bằng',
  ];


  const RentalFilter({
    this.selectedProvince,
    this.selectedAreaRange,
    this.selectedPriceRange,
    this.selectedPropertyType = 'Tất cả',
  });

  /// Áp dụng toàn bộ bộ lọc lên danh sách rentals
  List<dynamic> apply({
    required List<dynamic> rentals,
    String? overridePropertyType, // dùng khi vào từ màn "Nhà riêng", "Căn hộ"…
  }) {
    var list = List<dynamic>.from(rentals);

    // 1. Loại nhà
    final String type = overridePropertyType ?? selectedPropertyType;
    if (type != 'Tất cả') {
      list = list.where((r) => r.propertyType.contains(type)).toList();
    }

    // 2. Tỉnh/thành phố
    if (selectedProvince != null) {
      final String name = (selectedProvince['name'] as String).toLowerCase();
      list = list.where((r) {
        final String addr =
            (r.location['fullAddress'] as String? ?? '').toLowerCase();
        return addr.contains(name) ||
            addr.contains('thành phố $name') ||
            addr.contains('tp. $name');
      }).toList();
    }

    // 3. Diện tích – an toàn với num
    if (selectedAreaRange != null) {
      final option =
          areaOptions.firstWhere((e) => e['label'] == selectedAreaRange);
      final int min = option['min'] as int;
      final int max = option['max'] as int;

      list = list.where((r) {
        final double area = (r.area['total'] as num?)?.toDouble() ?? 0.0;
        return area >= min && (max >= 9999 || area < max);
      }).toList();
    }

    // 4. GIÁ
    if (selectedPriceRange != null) {
      final option =
          priceOptions.firstWhere((e) => e['label'] == selectedPriceRange);
      final int? minPrice = option['min'] as int?;
      final int? maxPrice = option['max'] as int?;

      list = list.where((r) {
        // Lấy price một cách cực kỳ an toàn
        final dynamic rawPrice = r.price;
        double price = 0.0;

        if (rawPrice is num) {
          price = rawPrice.toDouble(); // int → double hoặc double → double
        } else if (rawPrice is String) {
          price = double.tryParse(rawPrice) ?? 0.0; // trường hợp hiếm
        }
        // Nếu không phải số → price = 0 → sẽ bị lọc ra nếu có minPrice

        if (minPrice != null && price < minPrice) return false;
        if (maxPrice != null && price > maxPrice) return false;
        return true;
      }).toList();
    }

    return list;
  }

  /// Kiểm tra có bộ lọc nào đang hoạt động không (để hiện nút Xóa và chấm tròn)
  bool get hasActiveFilter =>
      selectedProvince != null ||
      selectedAreaRange != null ||
      selectedPriceRange != null ||
      selectedPropertyType != 'Tất cả';

  /// Tạo bản sao với một số giá trị mới
  RentalFilter copyWith({
    dynamic selectedProvince,
    String? selectedAreaRange,
    String? selectedPriceRange,
    String? selectedPropertyType,
  }) {
    return RentalFilter(
      selectedProvince: selectedProvince ?? this.selectedProvince,
      selectedAreaRange: selectedAreaRange ?? this.selectedAreaRange,
      selectedPriceRange: selectedPriceRange ?? this.selectedPriceRange,
      selectedPropertyType: selectedPropertyType ?? this.selectedPropertyType,
    );
  }

  /// Xóa toàn bộ bộ lọc (giữ lại tỉnh mặc định nếu muốn)
  RentalFilter clear({dynamic defaultProvince}) {
    return RentalFilter(
      selectedProvince: defaultProvince,
      selectedPropertyType: 'Tất cả',
    );
  }
}
