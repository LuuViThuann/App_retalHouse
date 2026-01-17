import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/config/api_routes.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_rental.dart';
import 'package:flutter_rentalhouse/views/main_list_cart_home.dart';
import 'package:flutter_rentalhouse/utils/rental_filter.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:location/location.dart' as loc;

import '../../config/loading.dart';

class AllAIRecommendationsScreen extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final double initialRadius;

  const AllAIRecommendationsScreen({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.initialRadius = 10.0,
  });

  @override
  State<AllAIRecommendationsScreen> createState() => _AllAIRecommendationsScreenState();
}

class _AllAIRecommendationsScreenState extends State<AllAIRecommendationsScreen> {
  int _displayLimit = 10;

  List<dynamic> provinces = [];
  bool isLoadingProvinces = true;

  RentalFilter filter = const RentalFilter();

  double? _currentLatitude;
  double? _currentLongitude;
  double _currentRadius = 10.0;

  bool _isLoadingLocation = false;

  @override
  void initState() {
    super.initState();
    _currentLatitude = widget.initialLatitude;
    _currentLongitude = widget.initialLongitude;
    _currentRadius = widget.initialRadius;

    fetchProvinces();

    // Nếu chưa có tọa độ, lấy vị trí hiện tại
    if (_currentLatitude == null || _currentLongitude == null) {
      _getCurrentLocation();
    } else {
      _loadAIRecommendations();
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      final location = loc.Location();

      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Dịch vụ GPS chưa được bật'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
      }

      var permissionGranted = await location.hasPermission();
      if (permissionGranted == loc.PermissionStatus.denied) {
        permissionGranted = await location.requestPermission();
        if (permissionGranted != loc.PermissionStatus.granted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Vui lòng cấp quyền truy cập vị trí'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
      }

      final currentLocation = await location.getLocation();

      if (currentLocation.latitude != null && currentLocation.longitude != null) {
        setState(() {
          _currentLatitude = currentLocation.latitude;
          _currentLongitude = currentLocation.longitude;
        });

        _loadAIRecommendations();
      }
    } catch (e) {
      debugPrint('❌ Error getting location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi lấy vị trí: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _loadAIRecommendations() async {
    if (_currentLatitude == null || _currentLongitude == null) return;

    final rentalViewModel = Provider.of<RentalViewModel>(context, listen: false);

    // Get min/max price from selected price range
    double? minPrice;
    double? maxPrice;

    if (filter.selectedPriceRange != null) {
      final option = RentalFilter.priceOptions.firstWhere(
            (e) => e['label'] == filter.selectedPriceRange,
      );
      minPrice = (option['min'] as int?)?.toDouble();
      maxPrice = (option['max'] as int?)?.toDouble();
    }

    await rentalViewModel.fetchAIRecommendations(
      latitude: _currentLatitude!,
      longitude: _currentLongitude!,
      radius: _currentRadius,
      minPrice: minPrice,
      maxPrice: maxPrice,
    );
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
    _loadAIRecommendations();
  }

  @override
  Widget build(BuildContext context) {
    final rentalVM = Provider.of<RentalViewModel>(context, listen: true);

    // Lọc kết quả AI theo bộ lọc
    final aiRentals = rentalVM.nearbyRentals;
    final filteredRentals = filter.apply(rentals: aiRentals);

    final displayRentals = filteredRentals.take(_displayLimit).toList();
    final hasMorePosts = _displayLimit < filteredRentals.length;
    final hasActiveFilter = filter.hasActiveFilter;

    final isAIRecommendation = rentalVM.isAIRecommendation;
    final aiMessage = rentalVM.aiRecommendationMessage;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.blue[700],
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [

                const Text(
                  'Gợi ý AI cho bạn',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            if (isAIRecommendation && aiMessage != null)
              Text(
                aiMessage,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                ),
              ),
          ],
        ),
        leading: const BackButton(color: Colors.white),
        actions: [
          if (hasActiveFilter)
            TextButton(
              onPressed: clearAllFilters,
              child: const Text(
                'Xóa',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadAIRecommendations,
            tooltip: 'Làm mới gợi ý',
          ),
        ],
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: Column(
        children: [
          // Thanh bộ lọc
          Container(
            width: double.infinity,
            color: Colors.grey[50],
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
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
                        const Icon(Icons.tune_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          "Bộ lọc",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            letterSpacing: 0.5,
                          ),
                        ),
                        if (hasActiveFilter) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              "●",
                              style: TextStyle(color: Colors.white, fontSize: 10),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildFilterChip(
                    icon: Icons.location_on_outlined,
                    title: 'Tỉnh/Thành phố',
                    value: filter.selectedProvince?['name'] ?? 'Tỉnh/TP',
                    color: Colors.indigo,
                    onTap: () => _showFilterSheet('province', 'Chọn Tỉnh/Thành phố'),
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

          // Danh sách bài đăng
          Expanded(
            child: _isLoadingLocation
                ?  Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Lottie.asset(
                    AssetsConfig.loadingLottie,
                    width: 80,
                    height: 80,
                    fit: BoxFit.fill,
                  ),
                  SizedBox(height: 16),
                  Text('Đang lấy vị trí của bạn...'),
                ],
              ),
            )
                : rentalVM.isLoading
                ? Center(
              child:  Lottie.asset(
                AssetsConfig.loadingLottie,
                width: 80,
                height: 80,
                fit: BoxFit.fill,
              ),
            )
                : filteredRentals.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off,
                    size: 90,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Không tìm thấy gợi ý phù hợp',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (hasActiveFilter)
                    const Text(
                      'Thử thay đổi bộ lọc nhé!',
                      style: TextStyle(color: Colors.grey),
                    ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _loadAIRecommendations,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Làm mới gợi ý'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            )
                : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: displayRentals.length + (hasMorePosts ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                if (hasMorePosts && index == displayRentals.length) {
                  return Center(
                    child: TextButton(
                      onPressed: () => setState(() => _displayLimit += 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Xem thêm bài đăng',
                            style: TextStyle(color: Colors.blue[700]),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward,
                            size: 18,
                            color: Colors.blue[700],
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final rental = displayRentals[index];

                return Stack(
                  children: [
                    RentalItemWidget(rental: rental),

                    // AI Badge
                    if (rental.isAIRecommended)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF1E88E5),
                                Color(0xFF42A5F5),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.auto_awesome,
                                color: Colors.white,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                rental.aiScore != null
                                    ? 'AI ${(rental.aiScore! * 100).toStringAsFixed(0)}%'
                                    : 'AI Gợi ý',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

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
            color: isSelected ? color : Colors.grey.shade300,
            width: 1.5,
          ),
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


  void _showFilterSheet(String type, String sheetTitle) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          builder: (_, controller) => Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Container(
                      width: 50,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          sheetTitle,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
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
                        (type == 'area' && filter.selectedAreaRange == display) ||
                        (type == 'price' && filter.selectedPriceRange == display);

                    return ListTile(
                      leading: isSelected
                          ? const Icon(Icons.check_circle, color: Colors.blue)
                          : const Icon(Icons.circle_outlined),
                      title: Text(display, style: const TextStyle(fontSize: 16)),
                      onTap: () {
                        setState(() {
                          if (type == 'province') {
                            filter = filter.copyWith(selectedProvince: item);
                          } else if (type == 'property') {
                            filter = filter.copyWith(selectedPropertyType: display);
                          } else if (type == 'area') {
                            filter = filter.copyWith(selectedAreaRange: display);
                          } else if (type == 'price') {
                            filter = filter.copyWith(selectedPriceRange: display);
                          }
                        });
                        Navigator.pop(context);
                        _loadAIRecommendations();
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