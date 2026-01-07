import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rentalhouse/utils/Snackbar_process.dart';
import 'package:intl/intl.dart';

class FilterDialogWidget extends StatefulWidget {
  final double initialRadius;
  final double? initialMinPrice;
  final double? initialMaxPrice;
  final Function(double radius, double? minPrice, double? maxPrice) onApply;
  final VoidCallback onReset;

  const FilterDialogWidget({
    Key? key,
    required this.initialRadius,
    this.initialMinPrice,
    this.initialMaxPrice,
    required this.onApply,
    required this.onReset,
  }) : super(key: key);

  @override
  State<FilterDialogWidget> createState() => _FilterDialogWidgetState();
}

class _FilterDialogWidgetState extends State<FilterDialogWidget>
    with SingleTickerProviderStateMixin {
  late double _selectedRadius;
  final TextEditingController _minPriceController = TextEditingController();
  final TextEditingController _maxPriceController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _selectedRadius = widget.initialRadius;
    // 🔥 CẬP NHẬT: Format initial prices để hiển thị đúng
    if (widget.initialMinPrice != null && widget.initialMinPrice! > 0) {
      final formatter = NumberFormat.currency(
        locale: 'vi_VN',
        symbol: '',
        decimalDigits: 0,
      );
      _minPriceController.text = formatter.format(widget.initialMinPrice!.toInt());
    }

    if (widget.initialMaxPrice != null && widget.initialMaxPrice! > 0) {
      final formatter = NumberFormat.currency(
        locale: 'vi_VN',
        symbol: '',
        decimalDigits: 0,
      );
      _maxPriceController.text = formatter.format(widget.initialMaxPrice!.toInt());
    }


    // Setup animation
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _minPriceController.dispose();
    _maxPriceController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _closeDialog() async {
    await _animationController.reverse();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  final _currencyFormat = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: Colors.white,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: 500,
              maxHeight: MediaQuery
                  .of(context)
                  .size
                  .height * 0.85,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                _buildHeader(),

                // Content - Scrollable
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Radius section
                        _buildSectionTitle(
                          icon: Icons.my_location_rounded,
                          title: 'Bán kính tìm kiếm',
                          color: Colors.blue,
                        ),
                        const SizedBox(height: 16),
                        _buildRadiusSelector(),
                        const SizedBox(height: 32),

                        // Price range section
                        _buildSectionTitle(
                          icon: Icons.payments_rounded,
                          title: 'Khoảng giá',
                          color: Colors.green,
                        ),
                        const SizedBox(height: 16),
                        _buildPriceInputs(),
                      ],
                    ),
                  ),
                ),

                // Footer actions
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.tune_rounded,
              color: Colors.blue[700],
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bộ lọc tìm kiếm',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Tùy chỉnh kết quả theo nhu cầu',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _closeDialog,
            icon: Icon(
              Icons.close_rounded,
              color: Colors.grey[600],
            ),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                widget.onReset();
                _minPriceController.clear();
                _maxPriceController.clear();
                setState(() {
                  _selectedRadius = 10.0;
                });
              },
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: const Text(
                'Đặt lại',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey[700],
                side: BorderSide(color: Colors.grey[300]!),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _handleApply,
              icon: const Icon(Icons.check_rounded, size: 20),
              label: const Text(
                'Áp dụng bộ lọc',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle({
    required IconData icon,
    required String title,
    required MaterialColor color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color[50],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color[700], size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildRadiusSelector() {
    final radiusOptions = [5.0, 10.0, 15.0, 20.0, 30.0];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: radiusOptions.map((radius) {
            final isSelected = _selectedRadius == radius;
            return InkWell(
              onTap: () {
                setState(() {
                  _selectedRadius = radius;
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blue[700] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? Colors.blue[700]! : Colors.grey[300]!,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Text(
                  '${radius.toStringAsFixed(0)} km',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tìm kiếm trong bán kính ${_selectedRadius.toStringAsFixed(
                      0)} km từ vị trí hiện tại',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue[900],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPriceInputs() {
    return Column(
      children: [
        _buildPriceTextField(
          controller: _minPriceController,
          label: 'Giá tối thiểu',
          hint: 'Nhập giá tối thiểu',
          icon: Icons.arrow_downward_rounded,
        ),
        const SizedBox(height: 16),
        _buildPriceTextField(
          controller: _maxPriceController,
          label: 'Giá tối đa',
          hint: 'Nhập giá tối đa',
          icon: Icons.arrow_upward_rounded,
        ),
      ],
    );
  }

  Widget _buildPriceTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            TextInputFormatter.withFunction((oldValue, newValue) {
              if (newValue.text.isEmpty) {
                return newValue;
              }

              final newText = newValue.text.replaceAll('.', '');
              final formatted = _currencyFormat.format(int.parse(newText));

              return newValue.copyWith(
                text: formatted,
                selection: TextSelection.collapsed(offset: formatted.length),
              );
            }),
          ],
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
            prefixIcon: Icon(icon, color: Colors.green[700], size: 20),
            suffixText: 'VNĐ',
            suffixStyle: TextStyle(
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.blue[700]!, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }

  void _handleApply() {
    // 🔥 CẬP NHẬT: Parse giá từ chuỗi định dạng (loại bỏ dấu phân cách)
    double? minPrice;
    double? maxPrice;

    // Parse min price
    if (_minPriceController.text.isNotEmpty) {
      final cleanedText = _minPriceController.text.replaceAll(
          RegExp(r'[^\d]'), '');
      if (cleanedText.isNotEmpty) {
        minPrice = double.tryParse(cleanedText);
        debugPrint('✅ Min price parsed: $minPrice');
      }
    }

    // Parse max price
    if (_maxPriceController.text.isNotEmpty) {
      final cleanedText = _maxPriceController.text.replaceAll(
          RegExp(r'[^\d]'), '');
      if (cleanedText.isNotEmpty) {
        maxPrice = double.tryParse(cleanedText);
        debugPrint('✅ Max price parsed: $maxPrice');
      }
    }

    // Validation
    if (minPrice == null && maxPrice == null) {
      AppSnackBar.show(
        context,
        AppSnackBar.error(
          message: 'Vui lòng nhập ít nhất một khoảng giá',
          seconds: 3,
        ),
      );
      return;
    }

    if (minPrice != null && maxPrice != null && minPrice > maxPrice) {
      AppSnackBar.show(
        context,
        AppSnackBar.error(
          message: 'Giá tối thiểu không được lớn hơn giá tối đa',
          seconds: 3,
        ),
      );
      return;
    }

    debugPrint('🔥 Applying filter:');
    debugPrint('   Radius: $_selectedRadius km');
    debugPrint('   MinPrice: $minPrice');
    debugPrint('   MaxPrice: $maxPrice');

    // Gọi callback onApply
    widget.onApply(_selectedRadius, minPrice, maxPrice);

    AppSnackBar.show(
      context,
      AppSnackBar.success(
        message: 'Đã áp dụng bộ lọc thành công',
        seconds: 2,
      ),
    );
    _closeDialog();
  }
}

// Helper function to show the dialog with animation
Future<void> showFilterDialog({
  required BuildContext context,
  required double initialRadius,
  double? initialMinPrice,
  double? initialMaxPrice,
  required Function(double radius, double? minPrice, double? maxPrice) onApply,
  required VoidCallback onReset,
}) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black54,
    builder: (context) => FilterDialogWidget(
      initialRadius: initialRadius,
      initialMinPrice: initialMinPrice,
      initialMaxPrice: initialMaxPrice,
      onApply: onApply,
      onReset: onReset,
    ),
  );
}