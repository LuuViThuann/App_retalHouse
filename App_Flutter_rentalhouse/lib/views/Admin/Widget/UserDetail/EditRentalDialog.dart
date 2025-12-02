import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/models/rental.dart';
import 'package:flutter_rentalhouse/views/Admin/ViewModel/admin_viewmodel.dart';
import 'package:provider/provider.dart';

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

  @override
  void initState() {
    super.initState();
    // ===== Basic Info =====
    _titleController = TextEditingController(text: widget.rental.title);
    _priceController =
        TextEditingController(text: widget.rental.price.toString());
    _addressController = TextEditingController(
      text: widget.rental.location['short'] ?? '',
    );
    _propertyTypeController = TextEditingController(
      text: widget.rental.propertyType ?? '',
    );

    // ===== Area =====
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

    // ===== Amenities =====
    _furnitureController = TextEditingController(
      text: widget.rental.furniture.join(', '),
    );
    _amenitiesController = TextEditingController(
      text: widget.rental.amenities.join(', '),
    );
    _surroundingsController = TextEditingController(
      text: widget.rental.surroundings.join(', '),
    );

    // ===== Rental Terms =====
    _minimumLeaseController = TextEditingController(
      text: widget.rental.rentalTerms?['minimumLease'] ?? '',
    );
    _depositController = TextEditingController(
      text: widget.rental.rentalTerms?['deposit'] ?? '',
    );
    _paymentMethodController = TextEditingController(
      text: widget.rental.rentalTerms?['paymentMethod'] ?? '',
    );
    _renewalTermsController = TextEditingController(
      text: widget.rental.rentalTerms?['renewalTerms'] ?? '',
    );

    // ===== Contact Info =====
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

  Future<void> _saveChanges() async {
    if (_titleController.text.isEmpty || _priceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập tiêu đề và giá'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final updateData = {
      // ===== Basic Info =====
      'title': _titleController.text,
      'price': double.tryParse(_priceController.text) ?? widget.rental.price,
      'locationShort': _addressController.text,
      'propertyType': _propertyTypeController.text,
      'status': _selectedStatus,

      // ===== Area =====
      'areaTotal':
          double.tryParse(_areaController.text) ?? widget.rental.area['total'],
      'areaLivingRoom': double.tryParse(_livingRoomController.text) ??
          widget.rental.area['livingRoom'],
      'areaBedrooms': double.tryParse(_bedroomsController.text) ??
          widget.rental.area['bedrooms'],
      'areaBathrooms': double.tryParse(_bathroomsController.text) ??
          widget.rental.area['bathrooms'],

      // ===== Amenities =====
      'furniture': _furnitureController.text,
      'amenities': _amenitiesController.text,
      'surroundings': _surroundingsController.text,

      // ===== Rental Terms =====
      'rentalTermsMinimumLease': _minimumLeaseController.text,
      'rentalTermsDeposit': _depositController.text,
      'rentalTermsPaymentMethod': _paymentMethodController.text,
      'rentalTermsRenewalTerms': _renewalTermsController.text,

      // ===== Contact Info =====
      'contactInfoName': _contactNameController.text,
      'contactInfoPhone': _contactPhoneController.text,
      'contactInfoAvailableHours': _contactHoursController.text,
    };

    final viewModel = context.read<AdminViewModel>();
    final success =
        await viewModel.adminEditRental(widget.rental.id, updateData);

    setState(() => _isLoading = false);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Cập nhật bài viết thành công'),
            backgroundColor: Colors.green[600],
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
        widget.onEditSuccess();
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ${viewModel.error ?? "Cập nhật thất bại"}'),
            backgroundColor: Colors.red[600],
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ===== HEADER =====
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                border: Border(
                    bottom: BorderSide(color: Colors.blue[200]!, width: 1)),
              ),
              child: Column(
                children: [
                  Icon(Icons.edit, size: 40, color: Colors.blue[600]),
                  const SizedBox(height: 12),
                  Text(
                    'Chỉnh sửa bài viết',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.rental.title,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.blue[600],
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // ===== CONTENT =====
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ===== SECTION 1: Thông tin cơ bản =====
                  _buildSectionTitle('📝 Thông tin cơ bản'),
                  _buildTextField(
                    controller: _titleController,
                    label: 'Tiêu đề',
                    hint: 'Nhập tiêu đề',
                  ),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _priceController,
                    label: 'Giá (VNĐ)',
                    hint: 'Nhập giá',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _addressController,
                    label: 'Địa chỉ',
                    hint: 'Nhập địa chỉ',
                  ),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _propertyTypeController,
                    label: 'Loại bất động sản',
                    hint: 'VD: Nhà, Chung cư, Phòng trọ',
                  ),
                  const SizedBox(height: 8),
                  _buildStatusDropdown(),
                  const SizedBox(height: 16),

                  // ===== SECTION 2: Diện tích =====
                  _buildSectionTitle('📐 Diện tích'),
                  _buildTextField(
                    controller: _areaController,
                    label: 'Diện tích tổng (m²)',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _livingRoomController,
                    label: 'Phòng khách (m²)',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _bedroomsController,
                    label: 'Phòng ngủ',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _bathroomsController,
                    label: 'Phòng tắm',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),

                  // ===== SECTION 3: Tiện nghi =====
                  _buildSectionTitle('🏠 Tiện nghi'),
                  _buildTextField(
                    controller: _furnitureController,
                    label: 'Nội thất (cách nhau bằng dấu phẩy)',
                    hint: 'VD: Giường, Tủ quần áo, Bàn',
                    maxLines: 2,
                  ),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _amenitiesController,
                    label: 'Tiện ích (cách nhau bằng dấu phẩy)',
                    hint: 'VD: Wifi, Điều hòa, Nước nóng',
                    maxLines: 2,
                  ),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _surroundingsController,
                    label: 'Xung quanh (cách nhau bằng dấu phẩy)',
                    hint: 'VD: Gần trường học, Gần chợ, Gần bến xe',
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),

                  // ===== SECTION 4: Điều kiện thuê =====
                  _buildSectionTitle('📋 Điều kiện thuê'),
                  _buildTextField(
                    controller: _minimumLeaseController,
                    label: 'Thời hạn tối thiểu',
                    hint: 'VD: 3 tháng, 6 tháng, 1 năm',
                  ),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _depositController,
                    label: 'Tiền cọc',
                    hint: 'VD: 1 tháng tiền nhà, 2 triệu đồng',
                  ),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _paymentMethodController,
                    label: 'Phương thức thanh toán',
                    hint: 'VD: Chuyển khoản, Tiền mặt',
                  ),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _renewalTermsController,
                    label: 'Điều kiện gia hạn',
                    hint: 'VD: Có thể gia hạn hàng năm',
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),

                  // ===== SECTION 5: Thông tin liên hệ =====
                  _buildSectionTitle('📞 Thông tin liên hệ'),
                  _buildTextField(
                    controller: _contactNameController,
                    label: 'Tên liên hệ',
                    hint: 'Nhập tên chủ nhà/người quản lý',
                  ),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _contactPhoneController,
                    label: 'Số điện thoại',
                    hint: 'VD: 0123456789',
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _contactHoursController,
                    label: 'Giờ liên hệ',
                    hint: 'VD: 8:00 - 17:00, Thứ 2-6',
                  ),
                ],
              ),
            ),

            // ===== FOOTER BUTTONS =====
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _isLoading ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: Colors.grey[400]!),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Hủy',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _saveChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.save),
                      label: Text(_isLoading ? 'Đang lưu...' : 'Lưu'),
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

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.blue, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }

  Widget _buildStatusDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Trạng thái',
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700]),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedStatus,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.blue, width: 2),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          items: const [
            DropdownMenuItem(value: 'available', child: Text('✓ Có sẵn')),
            DropdownMenuItem(value: 'rented', child: Text('✗ Đã cho thuê')),
          ],
          onChanged: (value) {
            setState(() => _selectedStatus = value ?? 'available');
          },
        ),
      ],
    );
  }
}
