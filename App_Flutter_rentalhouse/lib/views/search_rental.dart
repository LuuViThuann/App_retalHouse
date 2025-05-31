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
        SnackBar(content: Text('Lỗi: $e')),
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Tìm kiếm bài viết',
          style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue, Colors.blueAccent.shade700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Bar
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Nhập từ khóa (địa điểm, tiêu đề)...',
                hintStyle: TextStyle(color: Colors.grey[500]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 14.0),
              ),
              onSubmitted: (_) => _performSearch(),
            ),
            const SizedBox(height: 20),
            // Search History
            if (_searchHistory.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Lịch sử tìm kiếm',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8.0,
                    children: _searchHistory.map((query) {
                      return ActionChip(
                        label: Text(query),
                        backgroundColor: Colors.blue[50],
                        onPressed: () {
                          _searchController.text = query;
                          _performSearch();
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            // Property Type Selection
            const Text(
              'Loại nhà',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: propertyTypes.map((type) {
                return ChoiceChip(
                  backgroundColor: Colors.white,
                  label: Text(type),
                  selected: _selectedPropertyTypes.contains(type),
                  selectedColor: Colors.blue[700],
                  labelStyle: TextStyle(
                    color: _selectedPropertyTypes.contains(type)
                        ? Colors.white
                        : Colors.black,
                  ),
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
            const SizedBox(height: 20),
            // Price Range Slider
            const Text(
              'Khoảng giá lựa chọn',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            RangeSlider(
              values: _priceRange,
              min: 0,
              max: 50000000,
              divisions: 50,
              labels: RangeLabels(
                formatCurrency(_priceRange.start),
                formatCurrency(_priceRange.end),
              ),
              activeColor: Colors.blue[700],
              onChanged: (RangeValues values) {
                setState(() {
                  _priceRange = values;
                });
              },
            ),
            Text(
              'Giá: ${formatCurrency(_priceRange.start)} - ${formatCurrency(_priceRange.end)}',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 20),
            // Search Button
            Center(
              child: ElevatedButton(
                onPressed: _performSearch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 5,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min, // Giúp căn giữa nội dung
                  children: const [
                    Icon(Icons.search, color: Colors.white),
                    SizedBox(width: 8), // khoảng cách giữa icon và text
                    Text(
                      'Tìm kiếm',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
