import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rentalhouse/models/rental.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_auth.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_rental.dart';
import 'package:flutter_rentalhouse/views/login_view.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../Widgets/full_screen_image.dart';
import '../Widgets/thousand_format.dart';

class CreateRentalScreen extends StatefulWidget {
  const CreateRentalScreen({super.key});

  @override
  _CreateRentalScreenState createState() => _CreateRentalScreenState();
}

class _CreateRentalScreenState extends State<CreateRentalScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers for TextFormFields
  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _areaTotalController = TextEditingController();
  final _areaLivingRoomController = TextEditingController();
  final _areaBedroomsController = TextEditingController();
  final _areaBathroomsController = TextEditingController();
  final _locationShortController = TextEditingController();
  final _locationFullAddressController = TextEditingController();
  final _propertyTypeController = TextEditingController();
  final _furnitureController = TextEditingController();
  final _amenitiesController = TextEditingController();
  final _surroundingsController = TextEditingController();
  final _rentalTermsMinimumLeaseController = TextEditingController();
  final _rentalTermsDepositController = TextEditingController();
  final _rentalTermsPaymentMethodController = TextEditingController();
  final _rentalTermsRenewalTermsController = TextEditingController();
  final _contactInfoNameController = TextEditingController();
  final _contactInfoPhoneController = TextEditingController();
  final _contactInfoAvailableHoursController = TextEditingController();

  String? _selectedPropertyType;
  String _selectedStatus = 'Đang hoạt động'; // Sử dụng giá trị hiển thị tiếng Việt
  final List<String> _propertyTypes = [
    'Căn hộ chung cư',
    'Nhà riêng',
    'Nhà trọ/Phòng trọ',
    'Biệt thự',
    'Văn phòng',
    'Mặt bằng kinh doanh',
    'Khác'
  ];
  final List<String> _statusOptionsVietnamese = ['Đang hoạt động', 'Đã được thuê'];

  List<File> _images = [];

  // Hàm ánh xạ từ tiếng Việt về giá trị gốc
  String _mapVietnameseToStatus(String vietnameseStatus) {
    return vietnameseStatus == 'Đang hoạt động' ? 'available' : 'rented';
  }

  @override
  void initState() {
    super.initState();
    // Pre-fill contact info with the authenticated user's details
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    if (authViewModel.currentUser != null) {
      _contactInfoNameController.text = authViewModel.currentUser!.username ?? '';
      _contactInfoPhoneController.text = authViewModel.currentUser!.phoneNumber ?? '';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _areaTotalController.dispose();
    _areaLivingRoomController.dispose();
    _areaBedroomsController.dispose();
    _areaBathroomsController.dispose();
    _locationShortController.dispose();
    _locationFullAddressController.dispose();
    _propertyTypeController.dispose();
    _furnitureController.dispose();
    _amenitiesController.dispose();
    _surroundingsController.dispose();
    _rentalTermsMinimumLeaseController.dispose();
    _rentalTermsDepositController.dispose();
    _rentalTermsPaymentMethodController.dispose();
    _rentalTermsRenewalTermsController.dispose();
    _contactInfoNameController.dispose();
    _contactInfoPhoneController.dispose();
    _contactInfoAvailableHoursController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    try {
      final List<XFile> pickedFiles = await picker.pickMultiImage(
        imageQuality: 80,
      );

      if (pickedFiles.isNotEmpty) {
        setState(() {
          _images.addAll(pickedFiles.map((file) => File(file.path)));
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi chọn ảnh: $e')),
      );
    }
  }

  void _showFullScreenImage(File imageFile) {
    if (imageFile != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FullScreenImageScreen(imageUrl: imageFile.path),
        ),
      );
    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    String? hintText,
    IconData? prefixIcon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
    int minLines = 1,
    int maxLines = 1,
    String? suffixText,
    bool isRequired = false,
    bool showClearButton = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: isRequired ? '$labelText *' : labelText,
          hintText: hintText,
          prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: Theme.of(context).primaryColor.withOpacity(0.8)) : null,
          suffixIcon: showClearButton && controller.text.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.clear, color: Colors.grey),
            onPressed: () {
              controller.clear();
              setState(() {});
            },
          )
              : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: BorderSide(color: Colors.grey[400]!, width: 1.0),
          ),
          floatingLabelBehavior: FloatingLabelBehavior.auto,
          suffixText: suffixText,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        keyboardType: keyboardType,
        validator: validator,
        inputFormatters: inputFormatters,
        minLines: minLines,
        maxLines: maxLines,
        textCapitalization: TextCapitalization.sentences,
        onChanged: (value) {
          setState(() {}); // Update the UI to show/hide the clear button
        },
      ),
    );
  }

  Widget _buildDropdownField({
    required String? value,
    required String labelText,
    required List<String> items,
    required IconData prefixIcon,
    required void Function(String?)? onChanged,
    String? Function(String?)? validator,
    bool isRequired = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: isRequired ? '$labelText *' : labelText,
          prefixIcon: Icon(prefixIcon, color: Theme.of(context).primaryColor.withOpacity(0.8)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: BorderSide(color: Colors.grey[400]!, width: 1.0),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        items: items.map((String item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(item),
          );
        }).toList(),
        onChanged: onChanged,
        validator: validator,
        isExpanded: true,
      ),
    );
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
      final rentalViewModel = Provider.of<RentalViewModel>(context, listen: false);

      if (authViewModel.currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng đăng nhập để tạo bài đăng.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
              (Route<dynamic> route) => false,
        );
        return;
      }

      if (_images.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng chọn ít nhất một ảnh minh họa.'),
            backgroundColor: Colors.orangeAccent,
          ),
        );
        return;
      }

      final rawPrice = _priceController.text.replaceAll(RegExp(r'[^\d]'), '');
      final rawDeposit = _rentalTermsDepositController.text.replaceAll(RegExp(r'[^\d]'), '');

      final rental = Rental(
        id: '',
        title: _titleController.text.trim(),
        price: double.tryParse(rawPrice) ?? 0.0,
        area: {
          'total': double.tryParse(_areaTotalController.text.trim()) ?? 0.0,
          'livingRoom': _areaLivingRoomController.text.trim().isEmpty ? 0.0 : double.tryParse(_areaLivingRoomController.text.trim()) ?? 0.0,
          'bedrooms': _areaBedroomsController.text.trim().isEmpty ? 0.0 : double.tryParse(_areaBedroomsController.text.trim()) ?? 0.0,
          'bathrooms': _areaBathroomsController.text.trim().isEmpty ? 0.0 : double.tryParse(_areaBathroomsController.text.trim()) ?? 0.0,
        },
        location: {
          'short': _locationShortController.text.trim(),
          'fullAddress': _locationFullAddressController.text.trim(),
        },
        propertyType: _selectedPropertyType ?? 'Khác',
        furniture: _furnitureController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
        amenities: _amenitiesController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
        surroundings: _surroundingsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
        rentalTerms: {
          'minimumLease': _rentalTermsMinimumLeaseController.text.trim(),
          'deposit': rawDeposit,
          'paymentMethod': _rentalTermsPaymentMethodController.text.trim(),
          'renewalTerms': _rentalTermsRenewalTermsController.text.trim(),
        },
        contactInfo: {
          'name': _contactInfoNameController.text.trim(),
          'phone': _contactInfoPhoneController.text.trim(),
          'availableHours': _contactInfoAvailableHoursController.text.trim(),
        },
        userId: authViewModel.currentUser!.id,
        images: [],
        status: _mapVietnameseToStatus(_selectedStatus),
        createdAt: DateTime.now(),
        landlord: authViewModel.currentUser!.id,
      );

      final imagePaths = _images.map((file) => file.path).toList();
      await rentalViewModel.createRental(rental, imagePaths);

      if (mounted) {
        if (rentalViewModel.errorMessage == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tạo bài đăng thành công!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi: ${rentalViewModel.errorMessage!}'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thông tin chưa hợp lệ. Vui lòng kiểm tra lại các trường được đánh dấu *'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final rentalViewModel = Provider.of<RentalViewModel>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Tạo Bài Đăng Mới'),
        elevation: 1.5,
        backgroundColor: Colors.white,
        foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildSectionTitle("Thông tin cơ bản"),
              _buildTextField(
                controller: _titleController,
                labelText: 'Tiêu đề bài đăng',
                hintText: 'VD: Cho thuê căn hộ 2PN full nội thất gần trung tâm',
                prefixIcon: Icons.text_fields_rounded,
                isRequired: true,
                validator: (value) => (value == null || value.isEmpty) ? 'Vui lòng nhập tiêu đề' : null,
              ),
              _buildTextField(
                controller: _priceController,
                labelText: 'Giá thuê',
                hintText: 'Nhập số tiền, ví dụ: 5000000',
                prefixIcon: Icons.monetization_on_outlined,
                suffixText: "VNĐ/tháng",
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, ThousandsFormatter()],
                isRequired: true,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Vui lòng nhập giá thuê';
                  final numericValue = value.replaceAll(RegExp(r'[^\d]'), '');
                  if (double.tryParse(numericValue) == null || double.parse(numericValue) <= 0) {
                    return 'Giá thuê không hợp lệ';
                  }
                  return null;
                },
              ),

              _buildSectionTitle("Trạng thái bài đăng"),
              _buildDropdownField(
                value: _selectedStatus,
                labelText: 'Trạng thái',
                items: _statusOptionsVietnamese,
                prefixIcon: Icons.info_outline,
                isRequired: true,
                onChanged: (newValue) {
                  setState(() {
                    _selectedStatus = newValue ?? 'Đang hoạt động';
                    print('Selected status: $_selectedStatus (mapped to: ${_mapVietnameseToStatus(_selectedStatus)})');
                  });
                },
                validator: (value) => value == null ? 'Vui lòng chọn trạng thái' : null,
              ),

              _buildSectionTitle("Diện tích (m²)"),
              _buildTextField(
                controller: _areaTotalController,
                labelText: 'Tổng diện tích',
                prefixIcon: Icons.square_foot_outlined,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                isRequired: true,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Vui lòng nhập tổng diện tích';
                  if (double.tryParse(value) == null || double.parse(value) <= 0) return 'Diện tích không hợp lệ';
                  return null;
                },
              ),
              _buildTextField(
                controller: _areaLivingRoomController,
                labelText: 'Diện tích phòng khách (nếu có)',
                prefixIcon: Icons.living_outlined,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                validator: (value) {
                  if (value != null && value.isNotEmpty && (double.tryParse(value) == null || double.parse(value) < 0)) {
                    return 'Diện tích không hợp lệ';
                  }
                  return null;
                },
              ),
              _buildTextField(
                controller: _areaBedroomsController,
                labelText: 'Diện tích phòng ngủ (nếu có)',
                prefixIcon: Icons.bed_outlined,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                validator: (value) {
                  if (value != null && value.isNotEmpty && (double.tryParse(value) == null || double.parse(value) < 0)) {
                    return 'Diện tích không hợp lệ';
                  }
                  return null;
                },
              ),
              _buildTextField(
                controller: _areaBathroomsController,
                labelText: 'Diện tích phòng tắm (nếu có)',
                prefixIcon: Icons.bathtub_outlined,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                validator: (value) {
                  if (value != null && value.isNotEmpty && (double.tryParse(value) == null || double.parse(value) < 0)) {
                    return 'Diện tích không hợp lệ';
                  }
                  return null;
                },
              ),

              _buildSectionTitle("Vị trí"),
              _buildTextField(
                controller: _locationShortController,
                labelText: 'Vị trí ngắn gọn',
                hintText: 'VD: Đường Nguyễn Văn Cừ, Quận Ninh Kiều',
                prefixIcon: Icons.location_on_outlined,
                isRequired: true,
                validator: (value) => (value == null || value.isEmpty) ? 'Vui lòng nhập vị trí' : null,
              ),
              _buildTextField(
                controller: _locationFullAddressController,
                labelText: 'Địa chỉ đầy đủ',
                hintText: 'Số nhà, tên đường, phường/xã, quận/huyện, tỉnh/thành phố',
                prefixIcon: Icons.maps_home_work_outlined,
                minLines: 2,
                maxLines: 4,
                isRequired: true,
                validator: (value) => (value == null || value.isEmpty) ? 'Vui lòng nhập địa chỉ đầy đủ' : null,
              ),

              _buildSectionTitle("Chi tiết bất động sản"),
              _buildDropdownField(
                value: _selectedPropertyType,
                labelText: 'Loại hình bất động sản',
                items: _propertyTypes,
                prefixIcon: Icons.business_outlined,
                isRequired: true,
                onChanged: (newValue) {
                  setState(() {
                    _selectedPropertyType = newValue;
                    _propertyTypeController.text = newValue ?? 'Khác';
                    print('Selected propertyType: $newValue');
                  });
                },
                validator: (value) => value == null ? 'Vui lòng chọn loại hình' : null,
              ),
              _buildTextField(
                controller: _furnitureController,
                labelText: 'Nội thất',
                hintText: 'Liệt kê các nội thất, mỗi mục cách nhau bằng dấu phẩy (,)\nVD: Giường, tủ, máy lạnh, bàn ghế',
                prefixIcon: Icons.chair_outlined,
                minLines: 2,
                maxLines: 4,
                isRequired: true,
                validator: (value) => (value == null || value.isEmpty) ? 'Vui lòng mô tả nội thất' : null,
              ),
              _buildTextField(
                controller: _amenitiesController,
                labelText: 'Tiện ích',
                hintText: 'Liệt kê các tiện ích, mỗi mục cách nhau bằng dấu phẩy (,)\nVD: Wifi, Chỗ để xe, Thang máy, An ninh 24/7',
                prefixIcon: Icons.widgets_outlined,
                minLines: 2,
                maxLines: 4,
                isRequired: true,
                validator: (value) => (value == null || value.isEmpty) ? 'Vui lòng mô tả tiện ích' : null,
              ),
              _buildTextField(
                controller: _surroundingsController,
                labelText: 'Môi trường xung quanh',
                hintText: 'Liệt kê các đặc điểm xung quanh, mỗi mục cách nhau bằng dấu phẩy (,)\nVD: Gần chợ, siêu thị, trường học, công viên',
                prefixIcon: Icons.nature_people_outlined,
                minLines: 2,
                maxLines: 4,
                isRequired: true,
                validator: (value) => (value == null || value.isEmpty) ? 'Vui lòng mô tả môi trường xung quanh' : null,
              ),

              _buildSectionTitle("Điều khoản thuê"),
              _buildTextField(
                controller: _rentalTermsMinimumLeaseController,
                labelText: 'Thời hạn thuê tối thiểu',
                hintText: 'VD: 6 tháng, 1 năm',
                prefixIcon: Icons.timer_outlined,
                isRequired: true,
                validator: (value) => (value == null || value.isEmpty) ? 'Vui lòng nhập thời hạn thuê' : null,
              ),
              _buildTextField(
                controller: _rentalTermsDepositController,
                labelText: 'Tiền cọc',
                hintText: 'Nhập số tiền, ví dụ: 10000000',
                prefixIcon: Icons.security_outlined,
                suffixText: "VNĐ",
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, ThousandsFormatter(allowZero: true)],
                isRequired: true,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Vui lòng nhập tiền cọc';
                  final numericValue = value.replaceAll(RegExp(r'[^\d]'), '');
                  if (double.tryParse(numericValue) == null || double.parse(numericValue) < 0) {
                    return 'Tiền cọc không hợp lệ';
                  }
                  return null;
                },
              ),
              _buildTextField(
                controller: _rentalTermsPaymentMethodController,
                labelText: 'Phương thức thanh toán',
                hintText: 'VD: Tiền mặt, Chuyển khoản',
                prefixIcon: Icons.payment_outlined,
                isRequired: true,
                validator: (value) => (value == null || value.isEmpty) ? 'Vui lòng nhập phương thức thanh toán' : null,
              ),
              _buildTextField(
                controller: _rentalTermsRenewalTermsController,
                labelText: 'Điều khoản gia hạn (nếu có)',
                hintText: 'Mô tả điều kiện, quy trình gia hạn hợp đồng',
                prefixIcon: Icons.autorenew_outlined,
                minLines: 2,
                maxLines: 3,
              ),

              _buildSectionTitle("Thông tin liên hệ"),
              _buildTextField(
                controller: _contactInfoNameController,
                labelText: 'Tên người liên hệ',
                prefixIcon: Icons.person_outline,
                isRequired: true,
                showClearButton: true,
                validator: (value) => (value == null || value.isEmpty) ? 'Vui lòng nhập tên người liên hệ' : null,
              ),
              _buildTextField(
                controller: _contactInfoPhoneController,
                labelText: 'Số điện thoại/Zalo',
                prefixIcon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                isRequired: true,
                showClearButton: true,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Vui lòng nhập số điện thoại';
                  if (!RegExp(r'^(0|\+84)[0-9]{9,10}$').hasMatch(value)) return 'Số điện thoại không hợp lệ';
                  return null;
                },
              ),
              _buildTextField(
                controller: _contactInfoAvailableHoursController,
                labelText: 'Giờ liên hệ thuận tiện',
                hintText: 'VD: 9:00 - 20:00, hoặc ghi chú cụ thể',
                prefixIcon: Icons.access_time_outlined,
                isRequired: true,
                validator: (value) => (value == null || value.isEmpty) ? 'Vui lòng nhập giờ liên hệ' : null,
              ),

              _buildSectionTitle("Hình ảnh minh họa (${_images.length})"),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey[350]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_images.isNotEmpty)
                      SizedBox(
                        height: 110,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _images.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Stack(
                                alignment: Alignment.topRight,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8.0),
                                    child: GestureDetector(
                                      onTap: () => _showFullScreenImage(_images[index]),
                                      child: Hero(
                                        tag: _images[index].path,
                                        child: Image.file(
                                          _images[index],
                                          width: 90,
                                          height: 110,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => Container(
                                            width: 90,
                                            height: 110,
                                            color: Colors.grey[200],
                                            child: Icon(Icons.broken_image, color: Colors.grey[400]),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () {
                                      setState(() {
                                        _images.removeAt(index);
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.65),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close, color: Colors.white, size: 15),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      )
                    else
                      Container(
                        height: 110,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            'Chưa có ảnh nào được chọn',
                            style: TextStyle(color: Colors.grey[500], fontStyle: FontStyle.italic),
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                        label: Text('Thêm Ảnh (${_images.length})', style: const TextStyle(fontWeight: FontWeight.normal)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          side: BorderSide(color: Theme.of(context).primaryColor.withOpacity(0.7)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          foregroundColor: Theme.of(context).primaryColor,
                        ),
                        onPressed: _pickImages,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Mẹo: Chọn ảnh rõ nét, đủ sáng. Ảnh đầu tiên sẽ là ảnh đại diện.',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),
              if (rentalViewModel.isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                ElevatedButton.icon(
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: const Text('Đăng Bài'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _submitForm,
                ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}