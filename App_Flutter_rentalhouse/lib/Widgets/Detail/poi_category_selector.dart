import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/poi.dart';
import '../../viewmodels/vm_rental.dart';

class POICategorySelector extends StatefulWidget {
  final Function(List<String> selectedCategories) onApply;
  final VoidCallback? onClose;
  final ScaffoldMessengerState? scaffoldMessenger;

  const POICategorySelector({
    Key? key,
    required this.onApply,
    this.onClose,
    this.scaffoldMessenger,
  }) : super(key: key);

  @override
  State<POICategorySelector> createState() => _POICategorySelectorState();
}

class _POICategorySelectorState extends State<POICategorySelector> {
  bool _isLoading = false;
  String? _errorMessage;
  static const int MAX_SELECTIONS = 2;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final viewModel = Provider.of<RentalViewModel>(context, listen: false);
      if (viewModel.poiCategories.isEmpty) {
        await viewModel.fetchPOICategories();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Không thể tải danh mục: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<RentalViewModel>(context);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          _buildHeader(viewModel),

          // Content Area
          Flexible(
            child: _buildContent(viewModel),
          ),

          // Action buttons
          _buildActionButtons(viewModel),
        ],
      ),
    );
  }

  Widget _buildHeader(RentalViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue[100],
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.location_city, color: Colors.blue[700]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tìm gần tiện ích',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[900],
                  ),
                ),
                Text(
                  'Chọn các tiện ích bạn quan tâm',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
          ),
          if (viewModel.selectedPOICategories.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue[700],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${viewModel.selectedPOICategories.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          IconButton(
            onPressed: widget.onClose,
            icon: const Icon(Icons.close),
            color: Colors.grey[700],
          ),
        ],
      ),
    );
  }

  Widget _buildContent(RentalViewModel viewModel) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Đang tải danh mục...',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadCategories,
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (viewModel.poiCategories.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Không có danh mục nào',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selection info banner
          if (viewModel.selectedPOICategories.isNotEmpty)
            _buildSelectionBanner(viewModel),

          // Categories grid
          _buildCategoriesGrid(viewModel),
        ],
      ),
    );
  }

  Widget _buildSelectionBanner(RentalViewModel viewModel) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green[700], size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Đã chọn ${viewModel.selectedPOICategories.length} tiện ích',
              style: TextStyle(
                color: Colors.green[800],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              viewModel.clearPOISelections();
            },
            child: Text(
              'Xóa tất cả',
              style: TextStyle(
                color: Colors.red[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesGrid(RentalViewModel viewModel) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.5,
      ),
      itemCount: viewModel.poiCategories.length,
      itemBuilder: (context, index) {
        final category = viewModel.poiCategories[index];
        final isSelected = viewModel.selectedPOICategories.contains(category.id);

        return _buildCategoryCard(
          context,
          category,
          isSelected,
              () {
            viewModel.togglePOICategory(category.id);
          },
        );
      },
    );
  }

  Widget _buildCategoryCard(
      BuildContext context,
      POICategory category,
      bool isSelected,
      VoidCallback onTap,
      ) {
    final viewModel = Provider.of<RentalViewModel>(context, listen: false);
    final canSelect = isSelected || viewModel.selectedPOICategories.length < MAX_SELECTIONS;

    return Material(
        color: isSelected ? Colors.blue[50] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: canSelect ? onTap : () {
            // 🔥 HIỂN THỊ THÔNG BÁO KHI ĐÃ ĐẦY
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Chỉ được chọn tối đa $MAX_SELECTIONS tiện ích'),
                backgroundColor: Colors.orange[700],
                duration: const Duration(seconds: 2),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Opacity(
            opacity: canSelect ? 1.0 : 0.5, // 🔥 LÀM MỜ KHI KHÔNG THỂ CHỌN
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected ? Colors.blue[400]! : Colors.grey[300]!,
                  width: isSelected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blue[100] : Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    category.icon,
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Name
              Text(
                category.name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.blue[900] : Colors.grey[800],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              // Selection indicator
              if (isSelected)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue[700],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildActionButtons(RentalViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                viewModel.clearPOISelections();
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: Colors.grey[400]!),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Đặt lại',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: viewModel.selectedPOICategories.isEmpty
                  ? null
                  : () {
                widget.onApply(viewModel.selectedPOICategories);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                disabledBackgroundColor: Colors.grey[300],
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.search, size: 20, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    viewModel.selectedPOICategories.isEmpty
                        ? 'Chọn ít nhất 1 tiện ích'
                        : 'Tìm kiếm (${viewModel.selectedPOICategories.length}/$MAX_SELECTIONS)', // 🔥 HIỂN THỊ X/2
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.white
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}