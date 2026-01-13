import 'dart:math' as math;
import 'package:flutter/material.dart';

class LazyLoadPOIDialog extends StatefulWidget {
  final List<Map<String, dynamic>> allPOIs;
  final String rentalTitle;

  const LazyLoadPOIDialog({
    required this.allPOIs,
    required this.rentalTitle,
  });

  @override
  State<LazyLoadPOIDialog> createState() => _LazyLoadPOIDialogState();
}

class _LazyLoadPOIDialogState extends State<LazyLoadPOIDialog>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final int _itemsPerPage = 10;
  int _currentPage = 1;
  Map<String, List<Map<String, dynamic>>> _categorizedPOIs = {};
  Map<String, List<Map<String, dynamic>>> _displayedPOIs = {};
  Map<String, bool> _isLoadingMore = {};
  Map<String, bool> _hasMoreData = {};

  late TabController _tabController;
  List<String> _categories = [];
  String _selectedCategory = 'ALL';

  @override
  void initState() {
    super.initState();
    _categorizeData();
    _loadInitialData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _categorizeData() {
    // Phân loại POI theo category
    for (var poi in widget.allPOIs) {
      final category = poi['category'] ?? 'Khác';
      if (!_categorizedPOIs.containsKey(category)) {
        _categorizedPOIs[category] = [];
      }
      _categorizedPOIs[category]!.add(poi);
    }

    // Tạo danh sách categories
    _categories = ['ALL', ..._categorizedPOIs.keys.toList()..sort()];

    // Khởi tạo TabController
    _tabController = TabController(length: _categories.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedCategory = _categories[_tabController.index];
          _currentPage = 1;
        });
        _loadInitialData();
      }
    });

    // Khởi tạo loading states
    for (var category in _categories) {
      _isLoadingMore[category] = false;
      _hasMoreData[category] = true;
    }
  }

  void _loadInitialData() {
    final currentPOIs = _getCurrentPOIs();
    final initialData = currentPOIs.take(_itemsPerPage).toList();

    setState(() {
      _displayedPOIs[_selectedCategory] = initialData;
      _hasMoreData[_selectedCategory] = currentPOIs.length > _itemsPerPage;
      _currentPage = 1;
    });
  }

  List<Map<String, dynamic>> _getCurrentPOIs() {
    if (_selectedCategory == 'ALL') {
      return widget.allPOIs;
    }
    return _categorizedPOIs[_selectedCategory] ?? [];
  }

  List<Map<String, dynamic>> _getCurrentDisplayedPOIs() {
    return _displayedPOIs[_selectedCategory] ?? [];
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      if (!(_isLoadingMore[_selectedCategory] ?? false) &&
          (_hasMoreData[_selectedCategory] ?? false)) {
        _loadMorePOIs();
      }
    }
  }

  Future<void> _loadMorePOIs() async {
    if (_isLoadingMore[_selectedCategory] ?? false) return;
    if (!(_hasMoreData[_selectedCategory] ?? true)) return;

    setState(() {
      _isLoadingMore[_selectedCategory] = true;
    });

    await Future.delayed(const Duration(milliseconds: 500));

    final currentPOIs = _getCurrentPOIs();
    final currentDisplayed = _getCurrentDisplayedPOIs();

    final startIndex = currentDisplayed.length;
    final endIndex = math.min(startIndex + _itemsPerPage, currentPOIs.length);

    if (startIndex >= currentPOIs.length) {
      setState(() {
        _isLoadingMore[_selectedCategory] = false;
        _hasMoreData[_selectedCategory] = false;
      });
      return;
    }

    final newPOIs = currentPOIs.sublist(startIndex, endIndex);

    setState(() {
      _displayedPOIs[_selectedCategory] = [...currentDisplayed, ...newPOIs];
      _isLoadingMore[_selectedCategory] = false;
      _hasMoreData[_selectedCategory] = endIndex < currentPOIs.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentPOIs = _getCurrentPOIs();
    final displayedPOIs = _getCurrentDisplayedPOIs();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            _buildHeader(),

            // Tab Bar - Categories
            if (_categories.length > 1) _buildTabBar(),

            // POI List
            Flexible(
              child: displayedPOIs.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: displayedPOIs.length +
                    ((_hasMoreData[_selectedCategory] ?? false) ? 1 : 0),
                separatorBuilder: (context, index) =>
                const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  if (index == displayedPOIs.length) {
                    return _buildLoadingIndicator();
                  }
                  return _buildPOIItem(displayedPOIs[index], index);
                },
              ),
            ),

            // Progress Footer
            if (displayedPOIs.length < currentPOIs.length)
              _buildProgressFooter(displayedPOIs.length, currentPOIs.length),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(bottom: BorderSide(color: Colors.grey[200]!, width: 1)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.blue[600],
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.location_city, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tiện ích gần đây',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1a1a1a),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${widget.allPOIs.length} địa điểm • ${_categorizedPOIs.length} loại',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.close, color: Colors.grey[700], size: 22),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!, width: 1)),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: Colors.blue[700],
        unselectedLabelColor: Colors.grey[600],
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        indicatorColor: Colors.blue[600],
        indicatorWeight: 3,
        tabs: _categories.map((category) {
          final count = category == 'ALL'
              ? widget.allPOIs.length
              : (_categorizedPOIs[category]?.length ?? 0);

          String displayName = category;
          String icon = '📍';

          if (category == 'ALL') {
            displayName = 'Tất cả';
            icon = '🗺️';
          } else {
            // Lấy icon từ POI đầu tiên của category
            final firstPOI = _categorizedPOIs[category]?.first;
            if (firstPOI != null) {
              icon = firstPOI['icon'] ?? '📍';
            }
          }

          return Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(icon, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text(displayName),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _selectedCategory == category
                        ? Colors.blue[100]
                        : Colors.grey[200],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _selectedCategory == category
                          ? Colors.blue[700]
                          : Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPOIItem(Map<String, dynamic> poi, int index) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                poi['icon'] ?? '📍',
                style: const TextStyle(fontSize: 22),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  poi['name'] ?? 'Không rõ tên',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1a1a1a),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  poi['category'] ?? 'Khác',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.near_me, color: Colors.blue[600], size: 14),
                const SizedBox(width: 4),
                Text(
                  '${poi['distance']} km',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.all(20),
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Đang tải...',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Không có tiện ích',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Không tìm thấy tiện ích nào trong danh mục này',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressFooter(int displayed, int total) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
        border: Border(top: BorderSide(color: Colors.grey[200]!, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: displayed / total,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
                minHeight: 6,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$displayed/$total',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}