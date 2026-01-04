import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rentalhouse/models/rental.dart';
import 'package:flutter_rentalhouse/utils/Snackbar_process.dart';
import 'package:flutter_rentalhouse/views/Admin/ViewModel/admin_viewmodel.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class EditRentalDialogComplete extends StatefulWidget {
  final Rental rental;
  final VoidCallback onEditSuccess;

  const EditRentalDialogComplete({
    Key? key,
    required this.rental,
    required this.onEditSuccess,
  }) : super(key: key);

  @override
  State<EditRentalDialogComplete> createState() =>
      _EditRentalDialogCompleteState();
}

class _EditRentalDialogCompleteState extends State<EditRentalDialogComplete> {
  late TextEditingController _titleController;
  late TextEditingController _priceController;
  late TextEditingController _areaController;
  late TextEditingController _bedroomsController;
  late TextEditingController _bathroomsController;
  late TextEditingController _livingRoomController;
  late TextEditingController _addressController;
  late TextEditingController _propertyTypeController;
  late TextEditingController _furnitureController;
  late TextEditingController _amenitiesController;
  late TextEditingController _surroundingsController;
  late TextEditingController _minimumLeaseController;
  late TextEditingController _depositController;
  late TextEditingController _paymentMethodController;
  late TextEditingController _renewalTermsController;
  late TextEditingController _contactNameController;
  late TextEditingController _contactPhoneController;
  late TextEditingController _contactHoursController;

  String _selectedStatus = 'available';
  bool _isLoading = false;

  final _currencyFormatter = NumberFormat('#,###', 'vi_VN');

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.rental.title);
    _priceController = TextEditingController(
      text: _currencyFormatter.format(widget.rental.price),
    );
    _addressController = TextEditingController(
      text: widget.rental.location['short'] ?? '',
    );
    _propertyTypeController = TextEditingController(
      text: widget.rental.propertyType ?? '',
    );
    _areaController = TextEditingController(
      text: widget.rental.area['total']?.toString() ?? '',
    );
    _livingRoomController = TextEditingController(
      text: widget.rental.area['livingRoom']?.toString() ?? '',
    );
    _bedroomsController = TextEditingController(
      text: widget.rental.area['bedrooms']?.toString() ?? '',
    );
    _bathroomsController = TextEditingController(
      text: widget.rental.area['bathrooms']?.toString() ?? '',
    );
    _furnitureController = TextEditingController(
      text: widget.rental.furniture.join(', '),
    );
    _amenitiesController = TextEditingController(
      text: widget.rental.amenities.join(', '),
    );
    _surroundingsController = TextEditingController(
      text: widget.rental.surroundings.join(', '),
    );
    _minimumLeaseController = TextEditingController(
      text: widget.rental.rentalTerms?['minimumLease'] ?? '',
    );

    // Format deposit with currency
    final depositValue = widget.rental.rentalTerms?['deposit'] ?? '';
    final depositNumber = double.tryParse(depositValue.toString().replaceAll(RegExp(r'[^0-9]'), ''));
    _depositController = TextEditingController(
      text: depositNumber != null ? _currencyFormatter.format(depositNumber) : '',
    );

    _paymentMethodController = TextEditingController(
      text: widget.rental.rentalTerms?['paymentMethod'] ?? '',
    );
    _renewalTermsController = TextEditingController(
      text: widget.rental.rentalTerms?['renewalTerms'] ?? '',
    );
    _contactNameController = TextEditingController(
      text: widget.rental.contactInfo?['name'] ?? '',
    );
    _contactPhoneController = TextEditingController(
      text: widget.rental.contactInfo?['phone'] ?? '',
    );
    _contactHoursController = TextEditingController(
      text: widget.rental.contactInfo?['availableHours'] ?? '',
    );
    _selectedStatus = widget.rental.status;

    // Add listeners for currency formatting
    _priceController.addListener(() => _formatCurrency(_priceController));
    _depositController.addListener(() => _formatCurrency(_depositController));
  }

  void _formatCurrency(TextEditingController controller) {
    String text = controller.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (text.isEmpty) return;

    final number = int.tryParse(text);
    if (number != null) {
      final formatted = _currencyFormatter.format(number);
      if (controller.text != formatted) {
        controller.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _areaController.dispose();
    _livingRoomController.dispose();
    _bedroomsController.dispose();
    _bathroomsController.dispose();
    _addressController.dispose();
    _propertyTypeController.dispose();
    _furnitureController.dispose();
    _amenitiesController.dispose();
    _surroundingsController.dispose();
    _minimumLeaseController.dispose();
    _depositController.dispose();
    _paymentMethodController.dispose();
    _renewalTermsController.dispose();
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    _contactHoursController.dispose();
    super.dispose();
  }

  double? _parseCurrency(String text) {
    final cleanText = text.replaceAll(RegExp(r'[^0-9]'), '');
    return cleanText.isEmpty ? null : double.tryParse(cleanText);
  }

  Future<void> _saveChanges() async {
    if (_titleController.text.isEmpty || _priceController.text.isEmpty) {
      AppSnackBar.show(
        context,
        AppSnackBar.warning(message: 'Vui lòng nhập tiêu đề và giá'),
      );
      return;
    }

    setState(() => _isLoading = true);

    final updateData = {
      'title': _titleController.text.trim(),
      'price': _parseCurrency(_priceController.text) ?? widget.rental.price,
      'locationShort': _addressController.text.trim(),
      'propertyType': _propertyTypeController.text.trim(),
      'status': _selectedStatus,
      'areaTotal':
      double.tryParse(_areaController.text) ?? widget.rental.area['total'],
      'areaLivingRoom': double.tryParse(_livingRoomController.text) ??
          widget.rental.area['livingRoom'],
      'areaBedrooms': double.tryParse(_bedroomsController.text) ??
          widget.rental.area['bedrooms'],
      'areaBathrooms': double.tryParse(_bathroomsController.text) ??
          widget.rental.area['bathrooms'],
      'furniture': _furnitureController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .join(','),
      'amenities': _amenitiesController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .join(','),
      'surroundings': _surroundingsController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .join(','),
      'rentalTermsMinimumLease': _minimumLeaseController.text.trim(),
      'rentalTermsDeposit': _depositController.text.replaceAll(RegExp(r'[^0-9]'), ''),
      'rentalTermsPaymentMethod': _paymentMethodController.text.trim(),
      'rentalTermsRenewalTerms': _renewalTermsController.text.trim(),
      'contactInfoName': _contactNameController.text.trim(),
      'contactInfoPhone': _contactPhoneController.text.trim(),
      'contactInfoAvailableHours': _contactHoursController.text.trim(),
    };

    final viewModel = context.read<AdminViewModel>();
    final success = await viewModel.adminEditRental(widget.rental.id, updateData);

    setState(() => _isLoading = false);

    if (mounted) {
      if (success) {
        AppSnackBar.show(
          context,
          AppSnackBar.success(message: 'Cập nhật bài viết thành công'),
        );
        widget.onEditSuccess();
        Navigator.pop(context);
      } else {
        AppSnackBar.show(
          context,
          AppSnackBar.error(
            message: viewModel.error ?? 'Cập nhật thất bại',
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.edit_outlined,
                      size: 24,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Chỉnh sửa bài viết',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.rental.title,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSection(
                      title: 'Thông tin cơ bản',
                      children: [
                        _buildTextField(
                          controller: _titleController,
                          label: 'Tiêu đề',
                          hint: 'Nhập tiêu đề bài viết',
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _priceController,
                                label: 'Giá thuê',
                                hint: '0',
                                keyboardType: TextInputType.number,
                                suffix: 'VNĐ',
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatusDropdown(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _addressController,
                          label: 'Địa chỉ',
                          hint: 'Nhập địa chỉ',
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _propertyTypeController,
                          label: 'Loại hình',
                          hint: 'Nhà riêng, Chung cư, Phòng trọ...',
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    _buildSection(
                      title: 'Diện tích & Phòng',
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _areaController,
                                label: 'Tổng diện tích',
                                hint: '0',
                                keyboardType: TextInputType.number,
                                suffix: 'm²',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTextField(
                                controller: _livingRoomController,
                                label: 'Phòng khách',
                                hint: '0',
                                keyboardType: TextInputType.number,
                                suffix: 'm²',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _bedroomsController,
                                label: 'Phòng ngủ',
                                hint: '0',
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTextField(
                                controller: _bathroomsController,
                                label: 'Phòng tắm',
                                hint: '0',
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    _buildSection(
                      title: 'Tiện nghi',
                      children: [
                        _buildTextField(
                          controller: _furnitureController,
                          label: 'Nội thất',
                          hint: 'Giường, Tủ, Bàn (phân cách bằng dấu phẩy)',
                          maxLines: 2,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _amenitiesController,
                          label: 'Tiện ích',
                          hint: 'Wifi, Điều hòa, Nước nóng...',
                          maxLines: 2,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _surroundingsController,
                          label: 'Xung quanh',
                          hint: 'Gần trường, Gần chợ...',
                          maxLines: 2,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    _buildSection(
                      title: 'Điều kiện thuê',
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _minimumLeaseController,
                                label: 'Thời hạn tối thiểu',
                                hint: '3 tháng',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTextField(
                                controller: _depositController,
                                label: 'Tiền cọc',
                                hint: '0',
                                keyboardType: TextInputType.number,
                                suffix: 'VNĐ',
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _paymentMethodController,
                          label: 'Phương thức thanh toán',
                          hint: 'Chuyển khoản, Tiền mặt...',
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _renewalTermsController,
                          label: 'Điều kiện gia hạn',
                          hint: 'Có thể gia hạn hàng năm',
                          maxLines: 2,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    _buildSection(
                      title: 'Thông tin liên hệ',
                      children: [
                        _buildTextField(
                          controller: _contactNameController,
                          label: 'Tên liên hệ',
                          hint: 'Tên chủ nhà',
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _contactPhoneController,
                                label: 'Số điện thoại',
                                hint: '0123456789',
                                keyboardType: TextInputType.phone,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTextField(
                                controller: _contactHoursController,
                                label: 'Giờ liên hệ',
                                hint: '8:00 - 17:00',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Color(0xFFF1F5F9), width: 1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        foregroundColor: const Color(0xFF64748B),
                      ),
                      child: const Text(
                        'Hủy',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                        disabledBackgroundColor: const Color(0xFFCBD5E1),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                          : const Text(
                        'Lưu thay đổi',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? suffix,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          inputFormatters: inputFormatters,
          style: const TextStyle(
            fontSize: 15,
            color: Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: Color(0xFFCBD5E1),
              fontSize: 15,
            ),
            suffixText: suffix,
            suffixStyle: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF0F172A), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Trạng thái',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedStatus,
          style: const TextStyle(
            fontSize: 15,
            color: Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF0F172A), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          items: const [
            DropdownMenuItem(value: 'available', child: Text('Có sẵn')),
            DropdownMenuItem(value: 'rented', child: Text('Đã thuê')),
            DropdownMenuItem(value: 'unavailable', child: Text('Không khả dụng')),
          ],
          onChanged: (value) {
            setState(() => _selectedStatus = value ?? 'available');
          },
        ),
      ],
    );
  }
}