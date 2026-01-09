import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/Widgets/Profile/enter_new_address.dart';
import 'package:flutter_rentalhouse/config/api_routes.dart';
import 'package:flutter_rentalhouse/models/rental.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_auth.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_rental.dart';
import 'package:flutter_rentalhouse/views/change_address_profile.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../utils/ImageUrlHelper.dart';
import 'image_rental_edit.dart';
import 'full_image_edit_rental.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

class EditRentalScreen extends StatefulWidget {
  final Rental rental;
  const EditRentalScreen({required this.rental, super.key});

  @override
  _EditRentalScreenState createState() => _EditRentalScreenState();
}

class _EditRentalScreenState extends State<EditRentalScreen> {
  final _formKey = GlobalKey<FormState>();
  Map<String, dynamic> _updatedData = {};

  List<File> _newImages = [];
  List<File> _newVideos = [];
  List<String> _removedMediaUrls = [];

  final ValueNotifier<List<File>> _imagesNotifier = ValueNotifier<List<File>>([]);
  final ValueNotifier<List<File>> _videosNotifier = ValueNotifier<List<File>>([]);

  Map<String, bool> _isEditing = {
    'title': false, 'price': false, 'areaTotal': false, 'areaLivingRoom': false,
    'areaBedrooms': false, 'areaBathrooms': false, 'locationShort': false,
    'locationFullAddress': false, 'propertyType': false, 'furniture': false,
    'amenities': false, 'surroundings': false, 'rentalTermsMinimumLease': false,
    'rentalTermsDeposit': false, 'rentalTermsPaymentMethod': false,
    'rentalTermsRenewalTerms': false, 'contactInfoName': false,
    'contactInfoPhone': false, 'contactInfoAvailableHours': false, 'status': false,
  };

  late TextEditingController _titleController, _priceController, _areaTotalController,
      _areaLivingRoomController, _areaBedroomsController, _areaBathroomsController,
      _locationShortController, _locationFullAddressController, _propertyTypeController,
      _furnitureController, _amenitiesController, _surroundingsController,
      _minimumLeaseController, _depositController, _paymentMethodController,
      _renewalTermsController, _contactNameController, _contactPhoneController,
      _availableHoursController;

  String? _selectedStatus;
  List<String> _furnitureList = [], _amenitiesList = [], _surroundingsList = [];
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'vi_VN', symbol: 'VNĐ', decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _imagesNotifier.addListener(() => _newImages = _imagesNotifier.value);
    _videosNotifier.addListener(() => _newVideos = _videosNotifier.value);
  }

  void _initializeControllers() {
    _titleController = TextEditingController(text: widget.rental.title ?? '');
    _priceController = TextEditingController(
      text: widget.rental.price != null ? _currencyFormat.format(widget.rental.price) : '',
    );
    _areaTotalController = TextEditingController(
      text: widget.rental.area['total']?.toString() ?? '',
    );
    _areaLivingRoomController = TextEditingController(
      text: widget.rental.area['livingRoom']?.toString() ?? '',
    );
    _areaBedroomsController = TextEditingController(
      text: widget.rental.area['bedrooms']?.toString() ?? '',
    );
    _areaBathroomsController = TextEditingController(
      text: widget.rental.area['bathrooms']?.toString() ?? '',
    );
    _locationShortController = TextEditingController(
      text: widget.rental.location['short'] ?? '',
    );
    _locationFullAddressController = TextEditingController(
      text: widget.rental.location['fullAddress'] ?? '',
    );
    _propertyTypeController = TextEditingController(
      text: widget.rental.propertyType ?? '',
    );
    _furnitureController = TextEditingController();
    _amenitiesController = TextEditingController();
    _surroundingsController = TextEditingController();
    _minimumLeaseController = TextEditingController(
      text: widget.rental.rentalTerms?['minimumLease'] ?? '',
    );
    _depositController = TextEditingController(
      text: widget.rental.rentalTerms?['deposit'] != null
          ? _currencyFormat.format(double.parse(
          widget.rental.rentalTerms?['deposit']?.toString() ?? '0'))
          : '',
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
    _availableHoursController = TextEditingController(
      text: widget.rental.contactInfo?['availableHours'] ?? '',
    );
    _selectedStatus = widget.rental.status ?? 'available';
    _furnitureList = List<String>.from(widget.rental.furniture ?? []);
    _amenitiesList = List<String>.from(widget.rental.amenities ?? []);
    _surroundingsList = List<String>.from(widget.rental.surroundings ?? []);
  }

  @override
  void dispose() {
    [_titleController, _priceController, _areaTotalController, _areaLivingRoomController,
      _areaBedroomsController, _areaBathroomsController, _locationShortController,
      _locationFullAddressController, _propertyTypeController, _furnitureController,
      _amenitiesController, _surroundingsController, _minimumLeaseController,
      _depositController, _paymentMethodController, _renewalTermsController,
      _contactNameController, _contactPhoneController, _availableHoursController]
        .forEach((controller) => controller.dispose());
    _imagesNotifier.dispose();
    _videosNotifier.dispose();
    super.dispose();
  }

  void _toggleEditField(String field) {
    setState(() => _isEditing[field] = !(_isEditing[field] ?? false));
  }

  void _updateField(String field, dynamic value) {
    setState(() {
      if (field == 'price' || field == 'rentalTermsDeposit') {
        String cleanValue = value.replaceAll(RegExp(r'[^0-9]'), '');
        _updatedData[field] = cleanValue.isNotEmpty ? cleanValue : '0';
      } else {
        _updatedData[field] = value;
      }
    });
  }

  void _addListItem(String field, String value) {
    if (value.isNotEmpty) {
      setState(() {
        if (field == 'furniture') {
          _furnitureList.add(value);
          _furnitureController.clear();
        } else if (field == 'amenities') {
          _amenitiesList.add(value);
          _amenitiesController.clear();
        } else if (field == 'surroundings') {
          _surroundingsList.add(value);
          _surroundingsController.clear();
        }
        _updateField(field, field == 'furniture' ? _furnitureList
            : field == 'amenities' ? _amenitiesList : _surroundingsList);
      });
    }
  }

  void _removeListItem(String field, String value) {
    setState(() {
      if (field == 'furniture') _furnitureList.remove(value);
      else if (field == 'amenities') _amenitiesList.remove(value);
      else if (field == 'surroundings') _surroundingsList.remove(value);
      _updateField(field, field == 'furniture' ? _furnitureList
          : field == 'amenities' ? _amenitiesList : _surroundingsList);
    });
  }
//  Hàm chọn video từ thư viện
  Future<void> _pickVideosFromGallery() async {
    try {
      final XFile? video = await ImagePicker().pickVideo(source: ImageSource.gallery);
      if (video != null) {
        // Kiểm tra kích thước file
        final file = File(video.path);
        final fileSize = await file.length();
        if (fileSize > 100 * 1024 * 1024) {
          _showSnackBar('Video không được vượt quá 100MB', Colors.red);
          return;
        }

        setState(() {
          _newVideos.add(file);
          _videosNotifier.value = _newVideos;
        });
      }
    } catch (e) {
      print('Error picking video: $e');
      _showSnackBar('Lỗi khi chọn video: $e', Colors.red);
    }
  }

  //  Hàm quay video từ camera
  Future<void> _pickVideoFromCamera() async {
    try {
      final XFile? video = await ImagePicker().pickVideo(source: ImageSource.camera);
      if (video != null) {
        // Kiểm tra kích thước file
        final file = File(video.path);
        final fileSize = await file.length();
        if (fileSize > 100 * 1024 * 1024) {
          _showSnackBar('Video không được vượt quá 100MB', Colors.red);
          return;
        }

        setState(() {
          _newVideos.add(file);
          _videosNotifier.value = _newVideos;
        });
      }
    } catch (e) {
      print('Error picking video from camera: $e');
      _showSnackBar('Lỗi khi quay video: $e', Colors.red);
    }
  }

  Future<void> _submitChanges() async {
    if (!_formKey.currentState!.validate()) {
      _showSnackBar('Vui lòng kiểm tra lại thông tin', Colors.red);
      return;
    }

    // Kiểm tra xem có thay đổi nào không

    if (_updatedData.isEmpty && _newImages.isEmpty && _newVideos.isEmpty && _removedMediaUrls.isEmpty) {
      _showSnackBar('Không có thay đổi để lưu', Colors.orange);
      return;
    }

    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final rentalViewModel = Provider.of<RentalViewModel>(context, listen: false);

    try {
      final updatedData = _buildUpdatedData();

      print('🔵 Submitting changes:');
      print('   rentalId: ${widget.rental.id}');
      print('   updatedData: $updatedData');
      print('   newImages: ${_newImages.length}');
      print('   newVideos: ${_newVideos.length}');
      print('   removedMediaUrls: $_removedMediaUrls');

// Gửi URLs cần xóa về backend
      if (_removedMediaUrls.isNotEmpty) {
        updatedData['removedMedia'] = jsonEncode(_removedMediaUrls);
      }

      await authViewModel.updateRental(
        rentalId: widget.rental.id!,
        updatedData: updatedData,
        imagePaths: _newImages.map((file) => file.path).toList(),
        videoPaths: _newVideos.map((file) => file.path).toList(),
        removedImages: _removedMediaUrls,
      );

      // 🔥 Cập nhật danh sách rental toàn cục
      await rentalViewModel.refreshAllRentals();

      _showSnackBar('Cập nhật bài đăng thành công', Colors.green);

      if (mounted) {
        Navigator.pop(context, true); // Truyền true để báo hiệu có cập nhật
      }
    } catch (e) {
      print('❌ Submit error: $e');
      _showSnackBar('Cập nhật thất bại: $e', Colors.red);
    }
  }

  Map<String, dynamic> _buildUpdatedData() {
    final result = <String, dynamic>{};

    // Thêm title nếu thay đổi
    if (_updatedData.containsKey('title') && _updatedData['title']?.isNotEmpty == true) {
      result['title'] = _updatedData['title'];
    }

    // Thêm price nếu thay đổi - làm sạch và chuyển đổi
    if (_updatedData.containsKey('price') && _updatedData['price']?.isNotEmpty == true) {
      final priceStr = _updatedData['price'].toString().replaceAll(RegExp(r'[^0-9]'), '');
      final price = double.tryParse(priceStr) ?? widget.rental.price;
      result['price'] = price.toString();
    }

    // Thêm area nếu có thay đổi
    if (_isAreaUpdated()) {
      result['areaTotal'] = (double.tryParse(_updatedData['areaTotal']?.toString() ?? widget.rental.area['total']?.toString() ?? '0') ?? 0).toString();
      result['areaLivingRoom'] = (double.tryParse(_updatedData['areaLivingRoom']?.toString() ?? widget.rental.area['livingRoom']?.toString() ?? '0') ?? 0).toString();
      result['areaBedrooms'] = (double.tryParse(_updatedData['areaBedrooms']?.toString() ?? widget.rental.area['bedrooms']?.toString() ?? '0') ?? 0).toString();
      result['areaBathrooms'] = (double.tryParse(_updatedData['areaBathrooms']?.toString() ?? widget.rental.area['bathrooms']?.toString() ?? '0') ?? 0).toString();
    }

    // Thêm location nếu có thay đổi
    if (_isLocationUpdated()) {
      result['locationShort'] = _updatedData['locationShort']?.toString() ?? widget.rental.location['short']?.toString() ?? '';
      result['locationFullAddress'] = _updatedData['locationFullAddress']?.toString() ?? widget.rental.location['fullAddress']?.toString() ?? '';
    }

    // Thêm propertyType
    if (_updatedData.containsKey('propertyType') && _updatedData['propertyType']?.isNotEmpty == true) {
      result['propertyType'] = _updatedData['propertyType'];
    }

    // Thêm furniture, amenities, surroundings
    if (_updatedData.containsKey('furniture') && _furnitureList.isNotEmpty) {
      result['furniture'] = _furnitureList.join(',');
    }
    if (_updatedData.containsKey('amenities') && _amenitiesList.isNotEmpty) {
      result['amenities'] = _amenitiesList.join(',');
    }
    if (_updatedData.containsKey('surroundings') && _surroundingsList.isNotEmpty) {
      result['surroundings'] = _surroundingsList.join(',');
    }

    // Thêm rental terms
    if (_isRentalTermsUpdated()) {
      result['rentalTermsMinimumLease'] = _updatedData['rentalTermsMinimumLease']?.toString() ?? widget.rental.rentalTerms?['minimumLease']?.toString() ?? '';

      final depositStr = (_updatedData['rentalTermsDeposit']?.toString() ?? widget.rental.rentalTerms?['deposit']?.toString() ?? '0')
          .replaceAll(RegExp(r'[^0-9]'), '');
      result['rentalTermsDeposit'] = depositStr;

      result['rentalTermsPaymentMethod'] = _updatedData['rentalTermsPaymentMethod']?.toString() ?? widget.rental.rentalTerms?['paymentMethod']?.toString() ?? '';
      result['rentalTermsRenewalTerms'] = _updatedData['rentalTermsRenewalTerms']?.toString() ?? widget.rental.rentalTerms?['renewalTerms']?.toString() ?? '';
    }

    // Thêm contact info
    if (_isContactInfoUpdated()) {
      result['contactInfoName'] = _updatedData['contactInfoName']?.toString() ?? widget.rental.contactInfo?['name']?.toString() ?? '';
      result['contactInfoPhone'] = _updatedData['contactInfoPhone']?.toString() ?? widget.rental.contactInfo?['phone']?.toString() ?? '';
      result['contactInfoAvailableHours'] = _updatedData['contactInfoAvailableHours']?.toString() ?? widget.rental.contactInfo?['availableHours']?.toString() ?? '';
    }

    // Thêm status
    if (_updatedData.containsKey('status')) {
      result['status'] = _updatedData['status'] ?? _selectedStatus ?? 'available';
    }

    print('✅ Updated data to send: $result');
    return result;
  }
  bool _isAreaUpdated() => _updatedData.containsKey('areaTotal') ||
      _updatedData.containsKey('areaLivingRoom') ||
      _updatedData.containsKey('areaBedrooms') ||
      _updatedData.containsKey('areaBathrooms');

  Map<String, dynamic> _buildAreaData() => {
    'total': double.tryParse(_updatedData['areaTotal'] ??
        widget.rental.area['total']?.toString() ?? '0') ?? 0,
    'livingRoom': double.tryParse(_updatedData['areaLivingRoom'] ??
        widget.rental.area['livingRoom']?.toString() ?? '0') ?? 0,
    'bedrooms': double.tryParse(_updatedData['areaBedrooms'] ??
        widget.rental.area['bedrooms']?.toString() ?? '0') ?? 0,
    'bathrooms': double.tryParse(_updatedData['areaBathrooms'] ??
        widget.rental.area['bathrooms']?.toString() ?? '0') ?? 0,
  };

  bool _isLocationUpdated() => _updatedData.containsKey('locationShort') ||
      _updatedData.containsKey('locationFullAddress');

  Map<String, dynamic> _buildLocationData() => {
    'short': _updatedData['locationShort'] ??
        widget.rental.location['short']?.toString() ?? '',
    'fullAddress': _updatedData['locationFullAddress'] ??
        widget.rental.location['fullAddress']?.toString() ?? '',
  };

  bool _isRentalTermsUpdated() => _updatedData.containsKey('rentalTermsMinimumLease') ||
      _updatedData.containsKey('rentalTermsDeposit') ||
      _updatedData.containsKey('rentalTermsPaymentMethod') ||
      _updatedData.containsKey('rentalTermsRenewalTerms');

  Map<String, dynamic> _buildRentalTermsData() => {
    'minimumLease': _updatedData['rentalTermsMinimumLease'] ??
        widget.rental.rentalTerms?['minimumLease'] ?? '',
    'deposit': _updatedData['rentalTermsDeposit']
        ?.replaceAll(RegExp(r'[^0-9]'), '') ??
        widget.rental.rentalTerms?['deposit']?.toString() ?? '',
    'paymentMethod': _updatedData['rentalTermsPaymentMethod'] ??
        widget.rental.rentalTerms?['paymentMethod'] ?? '',
    'renewalTerms': _updatedData['rentalTermsRenewalTerms'] ??
        widget.rental.rentalTerms?['renewalTerms'] ?? '',
  };

  bool _isContactInfoUpdated() => _updatedData.containsKey('contactInfoName') ||
      _updatedData.containsKey('contactInfoPhone') ||
      _updatedData.containsKey('contactInfoAvailableHours');

  Map<String, dynamic> _buildContactInfoData() => {
    'name': _updatedData['contactInfoName'] ??
        widget.rental.contactInfo?['name'] ?? '',
    'phone': _updatedData['contactInfoPhone'] ??
        widget.rental.contactInfo?['phone'] ?? '',
    'availableHours': _updatedData['contactInfoAvailableHours'] ??
        widget.rental.contactInfo?['availableHours'] ?? '',
  };

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }
  Widget _buildAddressOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF3B82F6), size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
  void _showLocationPickerBottomSheet(String field) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Chọn nhanh địa chỉ',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 24),
            _buildAddressOption(
              icon: Icons.map_outlined,
              title: 'Chọn từ bản đồ',
              subtitle: 'Định vị chính xác trên bản đồ',
              onTap: () {
                Navigator.pop(context);
                _pickLocationFromMap(field);
              },
            ),
            const SizedBox(height: 12),
            _buildAddressOption(
              icon: Icons.edit_location_alt_outlined,
              title: 'Nhập địa chỉ',
              subtitle: 'Nhập thủ công địa chỉ của bạn',
              onTap: () {
                Navigator.pop(context);
                _pickLocationManually(field);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }



  Future<void> _pickLocationFromMap(String field) async {
    final selectedAddress = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ChangeAddressView()),
    );

    if (selectedAddress != null && selectedAddress is String && mounted) {
      setState(() {
        _locationFullAddressController.text = selectedAddress;
        _updateField('locationFullAddress', selectedAddress);
      });
    }
  }

  Future<void> _pickLocationManually(String field) async {
    final selectedAddress = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => NewAddressPage()),
    );

    if (selectedAddress != null && selectedAddress is String && mounted) {
      setState(() {
        _locationFullAddressController.text = selectedAddress;
        _updateField('locationFullAddress', selectedAddress);
      });
    }
  }
  Widget _buildPropertyTypeDropdown() {
    // Lấy giá trị hiện tại từ controller hoặc rental data
    String? currentPropertyType = _updatedData['propertyType'] as String? ??
        widget.rental.propertyType;

    // Danh sách các loại bất động sản
    final propertyTypes = [
      {'value': 'Nhà riêng', 'label': 'Nhà riêng'},
      {'value': 'Nhà trọ/Phòng trọ', 'label': 'Nhà trọ/Phòng trọ'},
      {'value': 'Căn hộ chung cư', 'label': 'Căn hộ chung cư'},
      {'value': 'Biệt thự', 'label': 'Biệt thự'},
      {'value': 'Văn phòng', 'label': 'Văn phòng'},
      {'value': 'Mặt bằng', 'label': 'Mặt bằng'},
      {'value': 'Đất nền', 'label': 'Đất nền'},
    ];

    // Kiểm tra nếu giá trị hiện tại không có trong danh sách, set về null
    if (currentPropertyType != null &&
        !propertyTypes.any((type) => type['value'] == currentPropertyType)) {
      currentPropertyType = null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Loại bất động sản',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Color(0xFF6C7280),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: currentPropertyType,
              isExpanded: true,
              hint: Text(
                'Chọn loại bất động sản',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                ),
              ),
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF3B82F6),
              ),
              style: const TextStyle(
                color: Color(0xFF1F2937),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(12),
              items: propertyTypes
                  .map((item) => DropdownMenuItem(
                value: item['value'] as String,
                child: Text(item['label'] as String),
              ))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _propertyTypeController.text = value;
                    _updateField('propertyType', value);
                  });
                }
              },
            ),
          ),
        ),
      ],
    );
  }
  Widget _buildEditableField({
    required String label,
    required String field,
    required TextEditingController controller,
    bool isNumeric = false,
    String? hintText,
    bool isLocation = false, // Thêm tham số này
  }) {
    String displayText = controller.text.isEmpty ? 'Chưa cập nhật'
        : (field == 'price' || field == 'rentalTermsDeposit')
        ? _currencyFormat.format(
        double.tryParse(controller.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        : controller.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w500,
              color: Color(0xFF6C7280),
            )),
            if (_isEditing[field] ?? false)
              Text('Chỉnh sửa', style: TextStyle(
                fontSize: 12, color: Colors.blue[600], fontWeight: FontWeight.w600,
              )),
          ],
        ),
        const SizedBox(height: 8),
        if (_isEditing[field] ?? false)
          isLocation
              ? GestureDetector(
            onTap: () {
              _showLocationPickerBottomSheet(field);
              // Cập nhật dữ liệu khi người dùng chọn xong
              _updateField(field, controller.text);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey[300]!, width: 1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      displayText,
                      style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500,
                        color: displayText == 'Chưa cập nhật' ? Colors.grey[500] : Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
                ],
              ),
            ),
          )
              : TextField(
            controller: controller,
            keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
            inputFormatters: (field == 'price' || field == 'rentalTermsDeposit')
                ? [TextInputFormatter.withFunction((oldValue, newValue) {
              String cleanText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
              if (cleanText.isEmpty) return newValue;
              String formattedText = _currencyFormat.format(double.parse(cleanText));
              return TextEditingValue(
                text: formattedText,
                selection: TextSelection.collapsed(offset: formattedText.length),
              );
            })]
                : null,
            onChanged: (value) => _updateField(field, value),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.blue, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          )
        else
          GestureDetector(
            onTap: () => _toggleEditField(field),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey[200]!, width: 1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      displayText,
                      style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500,
                        color: displayText == 'Chưa cập nhật' ? Colors.grey[500] : Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.edit, size: 16, color: Colors.blue[600]),
                ],
              ),
            ),
          ),
        if (_isEditing[field] ?? false)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _toggleEditField(field),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Xác nhận', style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13,
                )),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildListField({
    required String label,
    required String field,
    required TextEditingController controller,
    required List<String> items,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: ExpansionTile(
        title: Text(label, style: const TextStyle(
          fontWeight: FontWeight.w600, fontSize: 15, color: Colors.black87,
        )),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: 'Thêm mục mới',
                      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      filled: true, fillColor: Colors.grey[50],
                    ),
                    onSubmitted: (value) => _addListItem(field, value),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      Colors.blue,
                      Colors.blue.withOpacity(0.8),
                    ]),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.add, color: Colors.white, size: 20),
                    onPressed: () {
                      if (controller.text.isNotEmpty) {
                        _addListItem(field, controller.text);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          if (items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: items.map((item) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    border: Border.all(color: Colors.blue[200]!, width: 1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(item, style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87,
                      )),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => _removeListItem(field, item),
                        child: Icon(Icons.close, size: 16, color: Colors.blue),
                      ),
                    ],
                  ),
                )).toList(),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Chưa có mục nào', style: TextStyle(
                color: Colors.grey[500], fontSize: 13, fontStyle: FontStyle.italic,
              )),
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildStatusDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Trạng thái', style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF6C7280),
        )),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedStatus,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.blue, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            filled: true, fillColor: Colors.grey[50],
          ),
          items: [
            DropdownMenuItem(value: 'available', child: const Text('Đang cho thuê')),
            DropdownMenuItem(value: 'rented', child: const Text('Đã thuê')),
            DropdownMenuItem(value: 'unavailable', child: const Text('Không hoạt động')),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _selectedStatus = value;
                _updateField('status', value);
              });
            }
          },
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87),
        ),
      ],
    );
  }

  void _showImagePickerBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 24,
          bottom: 24 + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Chọn hình ảnh',
              style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 24),
            _buildImagePickerOption(
              icon: Icons.photo_library_outlined,
              title: 'Chọn từ thư viện',
              subtitle: 'Chọn ảnh từ thiết bị của bạn',
              onTap: () {
                Navigator.pop(context);
                _pickImagesFromGallery();
              },
            ),
            const SizedBox(height: 12),
            _buildImagePickerOption(
              icon: Icons.camera_alt_outlined,
              title: 'Chụp ảnh',
              subtitle: 'Chụp ảnh mới bằng camera',
              onTap: () {
                Navigator.pop(context);
                _pickImageFromCamera();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePickerOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.blue, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  )),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(
                    fontSize: 13, color: Colors.grey[600],
                  )),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImagesFromGallery() async {
    try {
      final List<XFile> images = await ImagePicker().pickMultiImage();
      if (images.isNotEmpty) {
        setState(() {
          _newImages.addAll(images.map((xFile) => File(xFile.path)));
          _imagesNotifier.value = _newImages;
        });
      }
    } catch (e) {
      print('Error picking images: $e');
    }
  }

  Future<void> _pickImageFromCamera() async {
    try {
      final XFile? image = await ImagePicker().pickImage(source: ImageSource.camera);
      if (image != null) {
        setState(() {
          _newImages.add(File(image.path));
          _imagesNotifier.value = _newImages;
        });
      }
    } catch (e) {
      print('Error picking image from camera: $e');
    }
  }
  void _showMediaPickerBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 24,
          bottom: 24 + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Chọn ảnh hoặc video',
              style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 24),
            _buildMediaPickerOption(
              icon: Icons.photo_library_outlined,
              title: 'Chọn ảnh từ thư viện',
              subtitle: 'Chọn nhiều ảnh từ thiết bị',
              onTap: () {
                Navigator.pop(context);
                _pickImagesFromGallery();
              },
            ),
            const SizedBox(height: 12),
            _buildMediaPickerOption(
              icon: Icons.camera_alt_outlined,
              title: 'Chụp ảnh',
              subtitle: 'Chụp ảnh mới bằng camera',
              onTap: () {
                Navigator.pop(context);
                _pickImageFromCamera();
              },
            ),
            const SizedBox(height: 12),
            _buildMediaPickerOption(
              icon: Icons.videocam_outlined,
              title: 'Chọn video từ thư viện',
              subtitle: 'Tối đa 100MB',
              onTap: () {
                Navigator.pop(context);
                _pickVideosFromGallery();
              },
            ),
            const SizedBox(height: 12),
            _buildMediaPickerOption(
              icon: Icons.video_call_outlined,
              title: 'Quay video',
              subtitle: 'Quay video mới bằng camera',
              onTap: () {
                Navigator.pop(context);
                _pickVideoFromCamera();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

// 9. Widget option cho media picker
  Widget _buildMediaPickerOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.blue, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  )),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(
                    fontSize: 13, color: Colors.grey[600],
                  )),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ==================== ẢNH HIỆN TẠI ====================
        if (widget.rental.images.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Ảnh hiện tại', style: TextStyle(
                fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87,
              )),
              const SizedBox(height: 12),
              SizedBox(
                height: 110,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.rental.images.length,
                  itemBuilder: (context, index) {
                    final imageUrl = widget.rental.images[index];

                    if (_removedMediaUrls.contains(imageUrl)) {
                      return const SizedBox.shrink();
                    }

                    final displayUrl = ImageUrlHelper.getImageUrl(imageUrl);

                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Stack(
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(
                                builder: (context) => FullImageEditRental(
                                  imageUrl: displayUrl,
                                  isNetworkImage: true,
                                ),
                              ));
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [BoxShadow(
                                  color: Colors.grey.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                )],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  displayUrl,
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Container(
                                      width: 100,
                                      height: 100,
                                      color: Colors.grey[200],
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          value: loadingProgress.expectedTotalBytes != null
                                              ? loadingProgress.cumulativeBytesLoaded /
                                              loadingProgress.expectedTotalBytes!
                                              : null,
                                        ),
                                      ),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    print('❌ Error loading image:');
                                    print('   Original URL: $imageUrl');
                                    print('   Display URL: $displayUrl');
                                    print('   Error: $error');

                                    return Container(
                                      width: 100,
                                      height: 100,
                                      color: Colors.grey[200],
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.broken_image_outlined,
                                              color: Colors.grey[400], size: 30),
                                          const SizedBox(height: 4),
                                          Text('Lỗi tải ảnh',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey[600],
                                              )),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),

                          Positioned(
                            right: 0,
                            top: 0,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _removedMediaUrls.add(imageUrl);
                                  print('🗑️ Marked for removal: $imageUrl');
                                });
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                  boxShadow: [BoxShadow(
                                    color: Colors.red.withOpacity(0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  )],
                                ),
                                padding: const EdgeInsets.all(6),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),

        // ==================== VIDEO HIỆN TẠI ====================
        if (widget.rental.videos.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Video hiện tại', style: TextStyle(
                fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87,
              )),
              const SizedBox(height: 12),
              SizedBox(
                height: 110,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.rental.videos.length,
                  itemBuilder: (context, index) {
                    final videoUrl = widget.rental.videos[index];

                    if (_removedMediaUrls.contains(videoUrl)) {
                      return const SizedBox.shrink();
                    }

                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Stack(
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [BoxShadow(
                                color: Colors.grey.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              )],
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    videoUrl,
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: Colors.grey[800],
                                        child: Icon(Icons.video_library,
                                            color: Colors.grey[400], size: 40),
                                      );
                                    },
                                  ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                const Icon(
                                  Icons.play_circle_outline,
                                  color: Colors.white,
                                  size: 40,
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            right: 0,
                            top: 0,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _removedMediaUrls.add(videoUrl);
                                  print('🗑️ Marked video for removal: $videoUrl');
                                });
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                  boxShadow: [BoxShadow(
                                    color: Colors.red.withOpacity(0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  )],
                                ),
                                padding: const EdgeInsets.all(6),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 8,
                            bottom: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.videocam, color: Colors.white, size: 12),
                                  SizedBox(width: 4),
                                  Text(
                                    'VIDEO',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),

        // ==================== ẢNH MỚI ====================
        if (_newImages.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Ảnh mới', style: TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87,
                  )),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Text(
                      '${_newImages.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 110,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _newImages.length,
                  itemBuilder: (context, index) {
                    final file = _newImages[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Stack(
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(
                                builder: (context) => FullImageEditRental(
                                  imageUrl: file.path,
                                  isNetworkImage: false,
                                ),
                              ));
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [BoxShadow(
                                  color: Colors.grey.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                )],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  file,
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            top: 0,
                            child: GestureDetector(
                              onTap: () => setState(() => _newImages.removeAt(index)),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                  boxShadow: [BoxShadow(
                                    color: Colors.red.withOpacity(0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  )],
                                ),
                                padding: const EdgeInsets.all(6),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),

        // ==================== VIDEO MỚI ====================
        if (_newVideos.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Video mới', style: TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87,
                  )),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber[200]!),
                    ),
                    child: Text(
                      '${_newVideos.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber[700],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 110,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _newVideos.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Stack(
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [BoxShadow(
                                color: Colors.grey.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              )],
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Icon(Icons.videocam_outlined,
                                      color: Colors.grey[400], size: 40),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                const Icon(
                                  Icons.play_circle_outline,
                                  color: Colors.white,
                                  size: 40,
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            right: 0,
                            top: 0,
                            child: GestureDetector(
                              onTap: () => setState(() => _newVideos.removeAt(index)),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                  boxShadow: [BoxShadow(
                                    color: Colors.red.withOpacity(0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  )],
                                ),
                                padding: const EdgeInsets.all(6),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 8,
                            bottom: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.videocam, color: Colors.white, size: 12),
                                  SizedBox(width: 4),
                                  Text(
                                    'VIDEO',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),

        // ==================== NÚT THÊM ẢNH/VIDEO ====================
        GestureDetector(
          onTap: _showMediaPickerBottomSheet,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!, width: 1.5),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add_photo_alternate_outlined,
                      color: Colors.blue, size: 36),
                ),
                const SizedBox(height: 16),
                const Text('Thêm ảnh hoặc video', style: TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 16,
                  color: Colors.black87,
                )),
                const SizedBox(height: 6),
                Text('Chọn từ thư viện hoặc quay/chụp mới',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                const SizedBox(height: 4),
                Text('Hỗ trợ tải lên nhiều ảnh và video (tối đa 100MB/video)',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500],
                        fontStyle: FontStyle.italic)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // === PHẦN TIÊU ĐỀ FULL WIDTH ===
          Container(
            width: double.infinity, // quan trọng: full chiều ngang
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(
                bottom: BorderSide(color: Colors.grey[200]!, width: 1),
              ),
            ),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          // === NỘI DUNG ===
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: children
                  .asMap()
                  .entries
                  .map((entry) {
                final widget = entry.value;
                final isLast = entry.key == children.length - 1;
                return Column(
                  children: [
                    widget,
                    if (!isLast) const SizedBox(height: 16),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context);
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.blue[700],
        elevation: 0,
        title: Text(
          "Chỉnh sửa bài đăng",
          style: const TextStyle(
              fontWeight: FontWeight.bold, color: Colors.white, fontSize: 19),
        ),
        leading: const BackButton(color: Colors.white),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: authViewModel.errorMessage != null
          ? Center(
        child: Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red[200]!, width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 40),
              const SizedBox(height: 16),
              Text(authViewModel.errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      )
          : Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSection(
                title: 'Thông tin cơ bản',
                children: [
                  _buildEditableField(
                    label: 'Tiêu đề bài đăng',
                    field: 'title',
                    controller: _titleController,
                    hintText: 'Nhập tiêu đề',
                  ),
                  _buildEditableField(
                    label: 'Giá thuê (VNĐ/tháng)',
                    field: 'price',
                    controller: _priceController,
                    isNumeric: true,
                  ),
                  _buildPropertyTypeDropdown(),
                  _buildStatusDropdown(),
                ],
              ),
              const SizedBox(height: 16),
              _buildSection(
                title: 'Diện tích',
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildEditableField(
                          label: 'Tổng cộng (m²)',
                          field: 'areaTotal',
                          controller: _areaTotalController,
                          isNumeric: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildEditableField(
                          label: 'Phòng khách (m²)',
                          field: 'areaLivingRoom',
                          controller: _areaLivingRoomController,
                          isNumeric: true,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _buildEditableField(
                          label: 'Phòng ngủ (m²)',
                          field: 'areaBedrooms',
                          controller: _areaBedroomsController,
                          isNumeric: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildEditableField(
                          label: 'Phòng tắm (m²)',
                          field: 'areaBathrooms',
                          controller: _areaBathroomsController,
                          isNumeric: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSection(
                title: 'Vị trí',
                children: [
                  _buildEditableField(
                    label: 'Vị trí ngắn gọn',
                    field: 'locationShort',
                    controller: _locationShortController,
                    hintText: 'Quận 1, TP.HCM',
                  ),
                  _buildEditableField(
                    label: 'Địa chỉ đầy đủ',
                    field: 'locationFullAddress',
                    controller: _locationFullAddressController,
                    hintText: 'Số nhà, đường, quận/huyện...',
                    isLocation: true,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSection(
                title: 'Nội thất & Tiện ích',
                children: [
                  _buildListField(
                    label: 'Nội thất',
                    field: 'furniture',
                    controller: _furnitureController,
                    items: _furnitureList,
                  ),
                  const SizedBox(height: 12),
                  _buildListField(
                    label: 'Tiện ích',
                    field: 'amenities',
                    controller: _amenitiesController,
                    items: _amenitiesList,
                  ),
                  const SizedBox(height: 12),
                  _buildListField(
                    label: 'Khu vực xung quanh',
                    field: 'surroundings',
                    controller: _surroundingsController,
                    items: _surroundingsList,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSection(
                title: 'Điều khoản thuê',
                children: [
                  _buildEditableField(
                    label: 'Thời hạn tối thiểu',
                    field: 'rentalTermsMinimumLease',
                    controller: _minimumLeaseController,
                    hintText: '6 tháng, 1 năm...',
                  ),
                  _buildEditableField(
                    label: 'Tiền cọc (VNĐ)',
                    field: 'rentalTermsDeposit',
                    controller: _depositController,
                    isNumeric: true,
                  ),
                  _buildEditableField(
                    label: 'Phương thức thanh toán',
                    field: 'rentalTermsPaymentMethod',
                    controller: _paymentMethodController,
                    hintText: 'Chuyển khoản, Tiền mặt...',
                  ),
                  _buildEditableField(
                    label: 'Điều khoản gia hạn',
                    field: 'rentalTermsRenewalTerms',
                    controller: _renewalTermsController,
                    hintText: 'Thỏa thuận với chủ nhà',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSection(
                title: 'Thông tin liên hệ',
                children: [
                  _buildEditableField(
                    label: 'Tên liên hệ',
                    field: 'contactInfoName',
                    controller: _contactNameController,
                    hintText: 'Họ và tên',
                  ),
                  _buildEditableField(
                    label: 'Số điện thoại',
                    field: 'contactInfoPhone',
                    controller: _contactPhoneController,
                    hintText: '0xxxxxxxxx',
                  ),
                  _buildEditableField(
                    label: 'Giờ liên hệ',
                    field: 'contactInfoAvailableHours',
                    controller: _availableHoursController,
                    hintText: '8:00 - 20:00',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSection(
                title: 'Hình ảnh & Video',
                children: [
                  _buildImageSection(),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey[200]!, width: 1)),
          boxShadow: [BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10, offset: const Offset(0, -2),
          )],
        ),
        padding: EdgeInsets.only(
          left: 16, right: 16, top: 12, bottom: 12 + MediaQuery.of(context).padding.bottom,
        ),
        child: SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: authViewModel.isLoading ? null : _submitChanges,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              disabledBackgroundColor: Colors.grey[300],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: authViewModel.isLoading
                ? const SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2, color: Colors.white,
              ),
            )
                : const Text('LƯU THAY ĐỔI',
              style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}