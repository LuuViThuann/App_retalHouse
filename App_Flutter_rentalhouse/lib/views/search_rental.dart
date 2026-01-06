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

class _SearchScreenState extends State<SearchScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  List<String> _selectedPropertyTypes = [];
  RangeValues _priceRange = const RangeValues(0, 50000000);
  List<String> _searchHistory = [];
  bool _isLoadingHistory = false;
  String? _deletingQuery;
  AnimationController? _animationController;
  Animation<double>? _fadeAnimation;

  final Map<String, String> _propertyTypeMap = {
    'Căn hộ chung cư': 'Apartment',
    'Nhà riêng': 'House',
    'Nhà trọ/Phòng trọ': 'Room',
    'Biệt thự': 'Villa',
    'Văn phòng': 'Office',
    'Mặt bằng kinh doanh': 'Shop',
  };

  final Map<String, IconData> _propertyTypeIcons = {
    'Căn hộ chung cư': Icons.apartment,
    'Nhà riêng': Icons.home,
    'Nhà trọ/Phòng trọ': Icons.meeting_room,
    'Biệt thự': Icons.villa,
    'Văn phòng': Icons.business,
    'Mặt bằng kinh doanh': Icons.store,
  };

  @override
  void initState() {
    super.initState();
    if (widget.initialSearchQuery != null) {
      _searchController.text = widget.initialSearchQuery!;
    }

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController!,
      curve: Curves.easeInOut,
    );

    _animationController!.forward();
    _fetchSearchHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController?.dispose();
    super.dispose();
  }

  Future<void> _fetchSearchHistory() async {
    setState(() => _isLoadingHistory = true);

    final rentalViewModel = Provider.of<RentalViewModel>(context, listen: false);
    try {
      final history = await rentalViewModel.getSearchHistory();

      if (mounted) {
        setState(() {
          _searchHistory = history;
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingHistory = false);

        if (!e.toString().contains('not authenticated')) {
          _showSnackBar('Lỗi tải lịch sử: $e', isError: true);
        }
      }
    }
  }

  Future<void> _deleteSearchHistoryItem(String query) async {
    final rentalViewModel = Provider.of<RentalViewModel>(context, listen: false);

    setState(() => _deletingQuery = query);

    try {
      await rentalViewModel.deleteSearchHistoryItem(query);

      if (mounted) {
        setState(() {
          _searchHistory.removeWhere((item) =>
          item.toLowerCase().trim() == query.toLowerCase().trim());
          _deletingQuery = null;
        });

        _showSnackBar('Đã xóa: "$query"', isError: false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _deletingQuery = null);
        _showSnackBar('Lỗi: $e', isError: true);
      }
    }
  }

  Future<void> _clearSearchHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Xóa lịch sử tìm kiếm?',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        content: const Text(
          'Bạn có chắc chắn muốn xóa toàn bộ lịch sử tìm kiếm?',
          style: TextStyle(fontSize: 14, color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Hủy',
              style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Xóa tất cả'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final rentalViewModel = Provider.of<RentalViewModel>(context, listen: false);

      setState(() => _isLoadingHistory = true);

      try {
        await rentalViewModel.clearSearchHistory();

        if (mounted) {
          setState(() {
            _searchHistory.clear();
            _isLoadingHistory = false;
          });

          _showSnackBar('Đã xóa toàn bộ lịch sử tìm kiếm', isError: false);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoadingHistory = false);
          _showSnackBar('Lỗi: $e', isError: true);
        }
      }
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String formatCurrency(double amount) {
    final formatter = NumberFormat.currency(
        locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
    return formatter.format(amount);
  }

  void _performSearch() {
    final searchText = _searchController.text.trim();

    final backendPropertyTypes = _selectedPropertyTypes.isNotEmpty
        ? _selectedPropertyTypes.map((type) => _propertyTypeMap[type]!).toList()
        : null;

    final bool hasPriceFilter = _priceRange.start > 0 || _priceRange.end < 50000000;
    final double? minPrice = hasPriceFilter ? _priceRange.start : null;
    final double? maxPrice = hasPriceFilter ? _priceRange.end : null;

    if (searchText.isEmpty && backendPropertyTypes == null && !hasPriceFilter) {
      _showSnackBar('Vui lòng nhập từ khóa, chọn loại nhà hoặc khoảng giá!', isError: true);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchResultsPage(
          searchQuery: searchText.isNotEmpty ? searchText : null,
          minPrice: minPrice,
          maxPrice: maxPrice,
          propertyTypes: backendPropertyTypes,
        ),
      ),
    ).then((_) => _fetchSearchHistory());
  }

  @override
  Widget build(BuildContext context) {
    final propertyTypes = _propertyTypeMap.keys.toList();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
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
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 26),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: _fadeAnimation != null
            ? FadeTransition(
          opacity: _fadeAnimation!,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSearchBar(),
                const SizedBox(height: 24),
                if (_searchHistory.isNotEmpty) _buildSearchHistory(),
                _buildPropertyTypeSection(propertyTypes),
                const SizedBox(height: 24),
                _buildPriceRangeSection(),
                const SizedBox(height: 24),
                _buildSearchButton(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        )
            : Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSearchBar(),
              const SizedBox(height: 24),
              if (_searchHistory.isNotEmpty) _buildSearchHistory(),
              _buildPropertyTypeSection(propertyTypes),
              const SizedBox(height: 24),
              _buildPriceRangeSection(),
              const SizedBox(height: 24),
              _buildSearchButton(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Tìm kiếm địa điểm, tiêu đề...',
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
          prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade600, size: 22),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
            icon: Icon(Icons.close, color: Colors.grey.shade400, size: 20),
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
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        ),
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        onSubmitted: (_) => _performSearch(),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildSearchHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Tìm kiếm gần đây',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            TextButton.icon(
              onPressed: _clearSearchHistory,
              icon: Icon(Icons.delete_outline, size: 18, color: Colors.red.shade400),
              label: Text(
                'Xóa tất cả',
                style: TextStyle(fontSize: 13, color: Colors.red.shade400, fontWeight: FontWeight.w500),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isLoadingHistory)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else if (_searchHistory.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Chưa có lịch sử tìm kiếm',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              ),
            ),
          )
        else
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: _searchHistory.map((query) {
              final isDeleting = _deletingQuery == query;

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: isDeleting
                      ? null
                      : () {
                    _searchController.text = query;
                    _performSearch();
                  },
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            query,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: isDeleting ? Colors.grey.shade400 : Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        isDeleting
                            ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.shade400),
                          ),
                        )
                            : InkWell(
                          onTap: () => _deleteSearchHistoryItem(query),
                          child: Icon(Icons.close, size: 16, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildPropertyTypeSection(List<String> propertyTypes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Loại hình',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            if (_selectedPropertyTypes.isNotEmpty)
              TextButton(
                onPressed: () => setState(() => _selectedPropertyTypes.clear()),
                child: Text(
                  'Xóa (${_selectedPropertyTypes.length})',
                  style: TextStyle(fontSize: 13, color: Colors.red.shade400, fontWeight: FontWeight.w500),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10.0,
          runSpacing: 10.0,
          children: propertyTypes.map((type) {
            final isSelected = _selectedPropertyTypes.contains(type);
            final icon = _propertyTypeIcons[type] ?? Icons.home;

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedPropertyTypes.remove(type);
                    } else {
                      _selectedPropertyTypes.add(type);
                    }
                  });
                },
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.blue.shade600 : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? Colors.blue.shade600 : Colors.grey.shade300,
                      width: 1.5,
                    ),
                    boxShadow: isSelected
                        ? [
                      BoxShadow(
                        color: Colors.blue.shade200.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: 18,
                        color: isSelected ? Colors.white : Colors.grey.shade700,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        type,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPriceRangeSection() {
    final hasFilter = _priceRange.start > 0 || _priceRange.end < 50000000;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Khoảng giá',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            if (hasFilter)
              TextButton(
                onPressed: () => setState(() => _priceRange = const RangeValues(0, 50000000)),
                child: Text(
                  'Đặt lại',
                  style: TextStyle(fontSize: 13, color: Colors.red.shade400, fontWeight: FontWeight.w500),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              RangeSlider(
                values: _priceRange,
                min: 0,
                max: 50000000,
                divisions: 50,
                activeColor: Colors.blue.shade600,
                inactiveColor: Colors.grey.shade200,
                onChanged: (RangeValues values) => setState(() => _priceRange = values),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Từ',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formatCurrency(_priceRange.start),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.arrow_forward, size: 16, color: Colors.grey.shade400),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Đến',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formatCurrency(_priceRange.end),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton(
        onPressed: _performSearch,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.blue.shade600,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_rounded, size: 22),
            SizedBox(width: 8),
            Text(
              'Tìm kiếm',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}