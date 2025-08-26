import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/config/api_routes.dart';
import 'package:flutter_rentalhouse/models/rental.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_auth.dart';
import 'package:provider/provider.dart';
import 'dart:io';
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
  List<String> _removedImages = [];
  final ValueNotifier<List<File>> _imagesNotifier =
      ValueNotifier<List<File>>([]);
  Map<String, bool> _isEditing = {
    'title': false,
    'price': false,
    'areaTotal': false,
    'areaLivingRoom': false,
    'areaBedrooms': false,
    'areaBathrooms': false,
    'locationShort': false,
    'locationFullAddress': false,
    'propertyType': false,
    'furniture': false,
    'amenities': false,
    'surroundings': false,
    'rentalTermsMinimumLease': false,
    'rentalTermsDeposit': false,
    'rentalTermsPaymentMethod': false,
    'rentalTermsRenewalTerms': false,
    'contactInfoName': false,
    'contactInfoPhone': false,
    'contactInfoAvailableHours': false,
    'status': false,
  };
  late TextEditingController _titleController;
  late TextEditingController _priceController;
  late TextEditingController _areaTotalController;
  late TextEditingController _areaLivingRoomController;
  late TextEditingController _areaBedroomsController;
  late TextEditingController _areaBathroomsController;
  late TextEditingController _locationShortController;
  late TextEditingController _locationFullAddressController;
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
  late TextEditingController _availableHoursController;
  String? _selectedStatus;
  List<String> _furnitureList = [];
  List<String> _amenitiesList = [];
  List<String> _surroundingsList = [];
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: 'VNĐ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.rental.title ?? '');
    _priceController = TextEditingController(
        text: widget.rental.price != null
            ? _currencyFormat.format(widget.rental.price)
            : '');
    _areaTotalController = TextEditingController(
        text: widget.rental.area['total']?.toString() ?? '');
    _areaLivingRoomController = TextEditingController(
        text: widget.rental.area['livingRoom']?.toString() ?? '');
    _areaBedroomsController = TextEditingController(
        text: widget.rental.area['bedrooms']?.toString() ?? '');
    _areaBathroomsController = TextEditingController(
        text: widget.rental.area['bathrooms']?.toString() ?? '');
    _locationShortController =
        TextEditingController(text: widget.rental.location['short'] ?? '');
    _locationFullAddressController = TextEditingController(
        text: widget.rental.location['fullAddress'] ?? '');
    _propertyTypeController =
        TextEditingController(text: widget.rental.propertyType ?? '');
    _furnitureController = TextEditingController();
    _amenitiesController = TextEditingController();
    _surroundingsController = TextEditingController();
    _minimumLeaseController = TextEditingController(
        text: widget.rental.rentalTerms?['minimumLease'] ?? '');
    _depositController = TextEditingController(
        text: widget.rental.rentalTerms?['deposit'] != null
            ? _currencyFormat.format(double.parse(
                widget.rental.rentalTerms?['deposit']?.toString() ?? '0'))
            : '');
    _paymentMethodController = TextEditingController(
        text: widget.rental.rentalTerms?['paymentMethod'] ?? '');
    _renewalTermsController = TextEditingController(
        text: widget.rental.rentalTerms?['renewalTerms'] ?? '');
    _contactNameController =
        TextEditingController(text: widget.rental.contactInfo?['name'] ?? '');
    _contactPhoneController =
        TextEditingController(text: widget.rental.contactInfo?['phone'] ?? '');
    _availableHoursController = TextEditingController(
        text: widget.rental.contactInfo?['availableHours'] ?? '');
    _selectedStatus = widget.rental.status ?? 'available';
    _furnitureList = List<String>.from(widget.rental.furniture ?? []);
    _amenitiesList = List<String>.from(widget.rental.amenities ?? []);
    _surroundingsList = List<String>.from(widget.rental.surroundings ?? []);
    _imagesNotifier.addListener(() {
      _newImages = _imagesNotifier.value;
    });
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
    _minimumLeaseController.dispose();
    _depositController.dispose();
    _paymentMethodController.dispose();
    _renewalTermsController.dispose();
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    _availableHoursController.dispose();
    _imagesNotifier.dispose();
    super.dispose();
  }

  void _toggleEditField(String field) {
    setState(() {
      _isEditing[field] = !(_isEditing[field] ?? false);
    });
  }

  void _updateField(String field, dynamic value) {
    setState(() {
      if (field == 'price' || field == 'rentalTermsDeposit') {
        // Loại bỏ ký tự không phải số
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
        _updateField(
          field,
          field == 'furniture'
              ? _furnitureList
              : field == 'amenities'
                  ? _amenitiesList
                  : _surroundingsList,
        );
      });
    }
  }

  void _removeListItem(String field, String value) {
    setState(() {
      if (field == 'furniture') {
        _furnitureList.remove(value);
      } else if (field == 'amenities') {
        _amenitiesList.remove(value);
      } else if (field == 'surroundings') {
        _surroundingsList.remove(value);
      }
      _updateField(
        field,
        field == 'furniture'
            ? _furnitureList
            : field == 'amenities'
                ? _amenitiesList
                : _surroundingsList,
      );
    });
  }

  Future<void> _submitChanges() async {
    if (!_formKey.currentState!.validate()) {
      print('EditRentalScreen: Form validation failed');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng kiểm tra lại thông tin'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (_updatedData.isEmpty && _newImages.isEmpty && _removedImages.isEmpty) {
      print('EditRentalScreen: No changes made');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không có thay đổi để lưu'),
            backgroundColor: Colors.yellow,
          ),
        );
      }
      return;
    }

    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    try {
      final updatedData = {
        if (_updatedData.containsKey('title')) 'title': _updatedData['title'],
        if (_updatedData.containsKey('price'))
          'price': double.tryParse(
                  _updatedData['price']?.replaceAll(RegExp(r'[^0-9]'), '') ??
                      '0') ??
              widget.rental.price,
        if (_updatedData.containsKey('areaTotal') ||
            _updatedData.containsKey('areaLivingRoom') ||
            _updatedData.containsKey('areaBedrooms') ||
            _updatedData.containsKey('areaBathrooms'))
          'area': {
            'total': double.tryParse(_updatedData['areaTotal'] ??
                    widget.rental.area['total']?.toString() ??
                    '0') ??
                0,
            'livingRoom': double.tryParse(_updatedData['areaLivingRoom'] ??
                    widget.rental.area['livingRoom']?.toString() ??
                    '0') ??
                0,
            'bedrooms': double.tryParse(_updatedData['areaBedrooms'] ??
                    widget.rental.area['bedrooms']?.toString() ??
                    '0') ??
                0,
            'bathrooms': double.tryParse(_updatedData['areaBathrooms'] ??
                    widget.rental.area['bathrooms']?.toString() ??
                    '0') ??
                0,
          },
        if (_updatedData.containsKey('locationShort') ||
            _updatedData.containsKey('locationFullAddress'))
          'location': {
            'short': _updatedData['locationShort'] ??
                widget.rental.location['short']?.toString() ??
                '',
            'fullAddress': _updatedData['locationFullAddress'] ??
                widget.rental.location['fullAddress']?.toString() ??
                '',
          },
        if (_updatedData.containsKey('propertyType'))
          'propertyType': _updatedData['propertyType'],
        if (_updatedData.containsKey('furniture')) 'furniture': _furnitureList,
        if (_updatedData.containsKey('amenities')) 'amenities': _amenitiesList,
        if (_updatedData.containsKey('surroundings'))
          'surroundings': _surroundingsList,
        if (_updatedData.containsKey('rentalTermsMinimumLease') ||
            _updatedData.containsKey('rentalTermsDeposit') ||
            _updatedData.containsKey('rentalTermsPaymentMethod') ||
            _updatedData.containsKey('rentalTermsRenewalTerms'))
          'rentalTerms': {
            'minimumLease': _updatedData['rentalTermsMinimumLease'] ??
                widget.rental.rentalTerms?['minimumLease'] ??
                '',
            'deposit': _updatedData['rentalTermsDeposit']
                    ?.replaceAll(RegExp(r'[^0-9]'), '') ??
                widget.rental.rentalTerms?['deposit']?.toString() ??
                '',
            'paymentMethod': _updatedData['rentalTermsPaymentMethod'] ??
                widget.rental.rentalTerms?['paymentMethod'] ??
                '',
            'renewalTerms': _updatedData['rentalTermsRenewalTerms'] ??
                widget.rental.rentalTerms?['renewalTerms'] ??
                '',
          },
        if (_updatedData.containsKey('contactInfoName') ||
            _updatedData.containsKey('contactInfoPhone') ||
            _updatedData.containsKey('contactInfoAvailableHours'))
          'contactInfo': {
            'name': _updatedData['contactInfoName'] ??
                widget.rental.contactInfo?['name'] ??
                '',
            'phone': _updatedData['contactInfoPhone'] ??
                widget.rental.contactInfo?['phone'] ??
                '',
            'availableHours': _updatedData['contactInfoAvailableHours'] ??
                widget.rental.contactInfo?['availableHours'] ??
                '',
          },
        if (_updatedData.containsKey('status'))
          'status': _updatedData['status'],
      };

      if (_removedImages.isNotEmpty) {
        print('Removed images to send: $_removedImages');
        updatedData['removedImages'] = jsonEncode(_removedImages);
      }

      await authViewModel.updateRental(
        rentalId: widget.rental.id!,
        updatedData: updatedData,
        imagePaths: _newImages.map((file) => file.path).toList(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cập nhật bài đăng thành công'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print('EditRentalScreen: Update error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cập nhật thất bại: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                iconColor.withOpacity(0.1),
                iconColor.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: iconColor.withOpacity(0.2),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: iconColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.grey.withOpacity(0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: children,
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
  }) {
    String displayText = controller.text.isEmpty
        ? 'Chưa có thông tin'
        : (field == 'price' || field == 'rentalTermsDeposit')
            ? _currencyFormat.format(double.tryParse(
                    controller.text.replaceAll(RegExp(r'[^0-9]'), '')) ??
                0)
            : controller.text;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              field.contains('title')
                  ? Icons.title
                  : field.contains('price') || field.contains('deposit')
                      ? Icons.attach_money
                      : field.contains('area')
                          ? Icons.square_foot
                          : field.contains('location')
                              ? Icons.location_on
                              : field.contains('propertyType')
                                  ? Icons.category
                                  : field.contains('contact')
                                      ? Icons.person
                                      : field.contains('rentalTerms')
                                          ? Icons.description
                                          : Icons.info,
              size: 18,
              color: Colors.blueAccent,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 160,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF616161),
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: _isEditing[field] ?? false
                ? TextFormField(
                    controller: controller,
                    keyboardType:
                        isNumeric ? TextInputType.number : TextInputType.text,
                    inputFormatters:
                        field == 'price' || field == 'rentalTermsDeposit'
                            ? [
                                TextInputFormatter.withFunction(
                                    (oldValue, newValue) {
                                  String cleanText = newValue.text
                                      .replaceAll(RegExp(r'[^0-9]'), '');
                                  if (cleanText.isEmpty) return newValue;
                                  String formattedText = _currencyFormat
                                      .format(double.parse(cleanText));
                                  return TextEditingValue(
                                    text: formattedText,
                                    selection: TextSelection.collapsed(
                                        offset: formattedText.length),
                                  );
                                }),
                              ]
                            : null,
                    decoration: InputDecoration(
                      hintText: hintText,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                            color: Colors.blueAccent.withOpacity(0.3)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                    validator: (value) =>
                        value!.isEmpty ? 'Vui lòng nhập $label' : null,
                    onChanged: (value) => _updateField(field, value),
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: Color(0xFF424242),
                    ),
                  )
                : Text(
                    displayText,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: Color(0xFF424242),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
          IconButton(
            icon: Icon(
              _isEditing[field] ?? false ? Icons.check : Icons.edit,
              color: Colors.blueAccent,
            ),
            onPressed: () => _toggleEditField(field),
          ),
        ],
      ),
    );
  }

  Widget _buildListField({
    required String label,
    required String field,
    required TextEditingController controller,
    required List<String> items,
  }) {
    return ExpansionTile(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              field == 'furniture'
                  ? Icons.chair
                  : field == 'amenities'
                      ? Icons.emoji_emotions
                      : Icons.nature_people,
              color: Colors.blueAccent,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: Color(0xFF424242),
            ),
          ),
        ],
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: 'Thêm $label',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          BorderSide(color: Colors.blueAccent.withOpacity(0.3)),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onSubmitted: (value) => _addListItem(field, value),
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    color: Color(0xFF424242),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.blueAccent,
                      Colors.blueAccent.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blueAccent.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.add, color: Colors.white),
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
        ...items.map((item) => Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF424242),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _removeListItem(field, item),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildStatusDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.info_outline,
              size: 18,
              color: Colors.blueAccent,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 160,
            child: const Text(
              'Trạng thái:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF616161),
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _selectedStatus,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      BorderSide(color: Colors.blueAccent.withOpacity(0.3)),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: ['available', 'rented', 'unavailable'].map((status) {
                return DropdownMenuItem<String>(
                  value: status,
                  child: Text(
                    status == 'available'
                        ? 'Đang cho thuê'
                        : status == 'rented'
                            ? 'Đã thuê'
                            : 'Không hoạt động',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: Color(0xFF424242),
                    ),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedStatus = value;
                    _updateField('status', value);
                  });
                }
              },
              validator: (value) =>
                  value == null ? 'Vui lòng chọn trạng thái' : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSection() {
    return ExpansionTile(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.image,
              color: Colors.blueAccent,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Hình ảnh',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: Color(0xFF424242),
            ),
          ),
        ],
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.rental.images.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ảnh hiện tại:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Color(0xFF424242),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: widget.rental.images
                          .where((image) => !_removedImages.contains(image))
                          .map((image) => Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Stack(
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                FullImageEditRental(
                                              imageUrl:
                                                  '${ApiRoutes.baseUrl}$image',
                                              isNetworkImage: true,
                                            ),
                                          ),
                                        );
                                      },
                                      child: ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(8.0),
                                        child: Image.network(
                                          '${ApiRoutes.baseUrl}$image',
                                          width: 100,
                                          height: 100,
                                          fit: BoxFit.cover,
                                          loadingBuilder: (context, child,
                                              loadingProgress) {
                                            if (loadingProgress == null)
                                              return child;
                                            return Container(
                                              width: 100,
                                              height: 100,
                                              color: Colors.grey[200],
                                              child: const Center(
                                                  child:
                                                      CircularProgressIndicator(
                                                strokeWidth: 2,
                                              )),
                                            );
                                          },
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                            print(
                                                'Image load error: $error for URL: ${ApiRoutes.baseUrl}$image');
                                            return Container(
                                              width: 100,
                                              height: 100,
                                              color: Colors.grey[200],
                                              child: Icon(
                                                Icons.image_not_supported,
                                                color: Colors.grey[400],
                                                size: 30,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.8),
                                          shape: BoxShape.circle,
                                        ),
                                        child: IconButton(
                                          icon: const Icon(
                                            Icons.delete,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _removedImages.add(image);
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ImageRentalEdit(
                imagesNotifier: _imagesNotifier,
                onImageTap: (File file) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FullImageEditRental(
                        imageUrl: file.path,
                        isNetworkImage: false,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.blueAccent,
        elevation: 0,
        title: const Text(
          'Chỉnh sửa bài đăng',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
      ),
      body: authViewModel.errorMessage != null
          ? Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Text(
                  authViewModel.errorMessage!,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            )
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSection(
                      title: 'Thông tin cơ bản',
                      icon: Icons.home_outlined,
                      iconColor: Colors.blueAccent,
                      children: [
                        _buildEditableField(
                          label: 'Tiêu đề',
                          field: 'title',
                          controller: _titleController,
                          hintText: 'Nhập tiêu đề',
                        ),
                        _buildEditableField(
                          label: 'Giá thuê',
                          field: 'price',
                          controller: _priceController,
                          isNumeric: true,
                          hintText: 'Nhập giá thuê (VNĐ)',
                        ),
                        _buildEditableField(
                          label: 'Diện tích tổng',
                          field: 'areaTotal',
                          controller: _areaTotalController,
                          isNumeric: true,
                          hintText: 'Nhập diện tích tổng (m²)',
                        ),
                        _buildEditableField(
                          label: 'Diện tích phòng khách',
                          field: 'areaLivingRoom',
                          controller: _areaLivingRoomController,
                          isNumeric: true,
                          hintText: 'Nhập diện tích phòng khách (m²)',
                        ),
                        _buildEditableField(
                          label: 'Diện tích phòng ngủ',
                          field: 'areaBedrooms',
                          controller: _areaBedroomsController,
                          isNumeric: true,
                          hintText: 'Nhập diện tích phòng ngủ (m²)',
                        ),
                        _buildEditableField(
                          label: 'Diện tích phòng tắm',
                          field: 'areaBathrooms',
                          controller: _areaBathroomsController,
                          isNumeric: true,
                          hintText: 'Nhập diện tích phòng tắm (m²)',
                        ),
                        _buildEditableField(
                          label: 'Loại bất động sản',
                          field: 'propertyType',
                          controller: _propertyTypeController,
                          hintText:
                              'Nhập loại bất động sản (e.g., Chung cư, Nhà riêng)',
                        ),
                        _buildStatusDropdown(),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSection(
                      title: 'Vị trí',
                      icon: Icons.location_on_outlined,
                      iconColor: Colors.blueAccent,
                      children: [
                        _buildEditableField(
                          label: 'Vị trí ngắn gọn',
                          field: 'locationShort',
                          controller: _locationShortController,
                          hintText: 'Nhập vị trí ngắn gọn',
                        ),
                        _buildEditableField(
                          label: 'Địa chỉ đầy đủ',
                          field: 'locationFullAddress',
                          controller: _locationFullAddressController,
                          hintText: 'Nhập địa chỉ đầy đủ',
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSection(
                      title: 'Tiện ích và nội thất',
                      icon: Icons.emoji_emotions_outlined,
                      iconColor: Colors.blueAccent,
                      children: [
                        _buildListField(
                          label: 'Nội thất',
                          field: 'furniture',
                          controller: _furnitureController,
                          items: _furnitureList,
                        ),
                        _buildListField(
                          label: 'Tiện ích',
                          field: 'amenities',
                          controller: _amenitiesController,
                          items: _amenitiesList,
                        ),
                        _buildListField(
                          label: 'Khu vực xung quanh',
                          field: 'surroundings',
                          controller: _surroundingsController,
                          items: _surroundingsList,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSection(
                      title: 'Điều khoản thuê',
                      icon: Icons.description_outlined,
                      iconColor: Colors.blueAccent,
                      children: [
                        _buildEditableField(
                          label: 'Thời hạn thuê tối thiểu',
                          field: 'rentalTermsMinimumLease',
                          controller: _minimumLeaseController,
                          hintText:
                              'Nhập thời hạn thuê tối thiểu (e.g., 6 tháng)',
                        ),
                        _buildEditableField(
                          label: 'Tiền cọc',
                          field: 'rentalTermsDeposit',
                          controller: _depositController,
                          isNumeric: true,
                          hintText: 'Nhập tiền cọc (VNĐ)',
                        ),
                        _buildEditableField(
                          label: 'Phương thức thanh toán',
                          field: 'rentalTermsPaymentMethod',
                          controller: _paymentMethodController,
                          hintText: 'Nhập phương thức thanh toán',
                        ),
                        _buildEditableField(
                          label: 'Điều khoản gia hạn',
                          field: 'rentalTermsRenewalTerms',
                          controller: _renewalTermsController,
                          hintText: 'Nhập điều khoản gia hạn',
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSection(
                      title: 'Thông tin liên hệ',
                      icon: Icons.person_outlined,
                      iconColor: Colors.blueAccent,
                      children: [
                        _buildEditableField(
                          label: 'Tên liên hệ',
                          field: 'contactInfoName',
                          controller: _contactNameController,
                          hintText: 'Nhập tên liên hệ',
                        ),
                        _buildEditableField(
                          label: 'Số điện thoại liên hệ',
                          field: 'contactInfoPhone',
                          controller: _contactPhoneController,
                          hintText: 'Nhập số điện thoại',
                        ),
                        _buildEditableField(
                          label: 'Giờ liên hệ',
                          field: 'contactInfoAvailableHours',
                          controller: _availableHoursController,
                          hintText: 'Nhập giờ liên hệ (e.g., 8:00 - 20:00)',
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSection(
                      title: 'Hình ảnh',
                      icon: Icons.image_outlined,
                      iconColor: Colors.blueAccent,
                      children: [
                        _buildImageSection(),
                      ],
                    ),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: BottomAppBar(
        color: Colors.white,
        elevation: 8,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 7.0),
          child: Container(
            width: double.infinity,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blueAccent,
                  Colors.blueAccent.withOpacity(0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.blueAccent.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: authViewModel.isLoading ? null : _submitChanges,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: authViewModel.isLoading
                  ? const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    )
                  : const Text(
                      'Lưu thay đổi',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
