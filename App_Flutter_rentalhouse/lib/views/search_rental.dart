import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/views/result_search_rental.dart';
import 'package:provider/provider.dart';
import '../viewmodels/vm_rental.dart';
import 'package:intl/intl.dart';

class SearchScreen extends StatefulWidget {
  final String? initialSearchQuery;

  const SearchScreen({super.key, this.initialSearchQuery});

  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<String> _selectedPropertyTypes = [];
  RangeValues _priceRange = const RangeValues(0, 10000000);
  List<String> _searchHistory = [];

  final Map<String, String> _propertyTypeMap = {
    'Căn hộ chung cư': 'Apartment',
    'Nhà riêng': 'House',
    'Nhà trọ/Phòng trọ': 'Room',
    'Biệt thự': 'Villa',
    'Văn phòng': 'Office',
    'Mặt bằng kinh doanh': 'Shop',
  };

  @override
  void initState() {
    super.initState();
    if (widget.initialSearchQuery != null) {
      _searchController.text = widget.initialSearchQuery!;
    }
    _fetchSearchHistory();
  }

  Future<void> _fetchSearchHistory() async {
    final rentalViewModel =
        Provider.of<RentalViewModel>(context, listen: false);
    try {
      final history = await rentalViewModel.getSearchHistory();
      setState(() {
        _searchHistory = history;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String formatCurrency(double amount) {
    final formatter =
        NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
    return formatter.format(amount);
  }

  void _performSearch() {
    final backendPropertyTypes =
        _selectedPropertyTypes.map((type) => _propertyTypeMap[type]!).toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchResultsPage(
          searchQuery:
              _searchController.text.isNotEmpty ? _searchController.text : null,
          minPrice: _priceRange.start,
          maxPrice: _priceRange.end,
          propertyTypes: backendPropertyTypes,
        ),
      ),
    ).then((_) => _fetchSearchHistory());
  }

  @override
  Widget build(BuildContext context) {
    final propertyTypes = _propertyTypeMap.keys.toList();

    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade700, Colors.blue.shade900],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(24),
            ),
          ),
        ),
        title: const Text(
          'Tìm kiếm bài viết',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 20,
            letterSpacing: 0.2,
          ),
        ),
        leading: IconButton(
          icon: AnimatedScale(
            scale: 1.0,
            duration: const Duration(milliseconds: 200),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 26),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade50, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search Bar
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.shade100.withOpacity(0.2),
                            blurRadius: 8,
                            spreadRadius: 1,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Nhập từ khóa (địa điểm, tiêu đề)...',
                          hintStyle: TextStyle(
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w400,
                          ),
                          prefixIcon: AnimatedScale(
                            scale: 1.0,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(Icons.search,
                                color: Colors.blue.shade700, size: 24),
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: AnimatedScale(
                                    scale: 1.0,
                                    duration: const Duration(milliseconds: 200),
                                    child: Icon(Icons.clear,
                                        color: Colors.grey.shade600, size: 22),
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                                color: Colors.blue.shade700, width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.transparent,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 16,
                          ),
                        ),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                        onSubmitted: (_) => _performSearch(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Search History
                    if (_searchHistory.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lịch sử tìm kiếm',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.blue.shade800,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8.0,
                            runSpacing: 8.0,
                            children: _searchHistory.map((query) {
                              return InkWell(
                                onTap: () {
                                  _searchController.text = query;
                                  _performSearch();
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.blue.shade50,
                                        Colors.white
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.blue.shade100
                                            .withOpacity(0.2),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                    border: Border.all(
                                      color:
                                          Colors.blue.shade100.withOpacity(0.5),
                                    ),
                                  ),
                                  child: Text(
                                    query,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    // Property Type Selection
                    Text(
                      'Loại nhà',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.blue.shade800,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: propertyTypes.map((type) {
                        return ChoiceChip(
                          backgroundColor: Colors.white,
                          selectedColor: Colors.blue.shade700,
                          label: Text(
                            type,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _selectedPropertyTypes.contains(type)
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                          ),
                          selected: _selectedPropertyTypes.contains(type),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: _selectedPropertyTypes.contains(type)
                                  ? Colors.blue.shade700
                                  : Colors.blue.shade100.withOpacity(0.5),
                            ),
                          ),
                          elevation:
                              _selectedPropertyTypes.contains(type) ? 4 : 0,
                          shadowColor: Colors.blue.shade100.withOpacity(0.3),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedPropertyTypes.add(type);
                              } else {
                                _selectedPropertyTypes.remove(type);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    // Price Range Slider
                    Text(
                      'Khoảng giá lựa chọn',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.blue.shade800,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.shade100.withOpacity(0.2),
                            blurRadius: 8,
                            spreadRadius: 1,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: RangeSlider(
                        values: _priceRange,
                        min: 0,
                        max: 50000000,
                        divisions: 50,
                        labels: RangeLabels(
                          formatCurrency(_priceRange.start),
                          formatCurrency(_priceRange.end),
                        ),
                        activeColor: Colors.blue.shade700,
                        inactiveColor: Colors.blue.shade100,
                        onChanged: (RangeValues values) {
                          setState(() {
                            _priceRange = values;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Giá: ${formatCurrency(_priceRange.start)} - ${formatCurrency(_priceRange.end)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Search Button
                    Center(
                      child: InkWell(
                        onTap: _performSearch,
                        borderRadius: BorderRadius.circular(16),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 40, vertical: 16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.blue.shade700,
                                Colors.blue.shade900
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.shade300.withOpacity(0.4),
                                blurRadius: 8,
                                spreadRadius: 2,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedScale(
                                scale: 1.0,
                                duration: const Duration(milliseconds: 200),
                                child: Icon(Icons.search,
                                    color: Colors.white, size: 24),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Tìm kiếm',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20), // Ensure padding at the bottom
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
