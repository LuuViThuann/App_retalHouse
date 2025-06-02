import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/Widgets/createRental/validation_rental.dart';
import 'package:flutter_rentalhouse/views/change_address_profile.dart';
import 'package:flutter_rentalhouse/Widgets/Profile/enter_new_address.dart';
import 'package:shimmer/shimmer.dart';

class LocationForm extends StatefulWidget {
  final TextEditingController shortController;
  final TextEditingController fullAddressController;

  const LocationForm({
    super.key,
    required this.shortController,
    required this.fullAddressController,
  });

  @override
  _LocationFormState createState() => _LocationFormState();
}

class _LocationFormState extends State<LocationForm> {
  bool _isLoading = false; // Trạng thái loading khi chọn địa chỉ

  Future<void> _pickAddressFromMap() async {
    setState(() {
      _isLoading = true; // Bật loading
    });

    try {
      final selectedAddress = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ChangeAddressView()),
      );

      if (selectedAddress != null && selectedAddress is String && mounted) {
        setState(() {
          widget.fullAddressController.text = selectedAddress;
          _isLoading = false; // Tắt loading
        });
      } else {
        setState(() {
          _isLoading = false; // Tắt loading nếu không có địa chỉ
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi chọn địa chỉ: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickAddressManually() async {
    setState(() {
      _isLoading = true; // Bật loading
    });

    try {
      final selectedAddress = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => NewAddressPage()),
      );

      if (selectedAddress != null && selectedAddress is String && mounted) {
        setState(() {
          widget.fullAddressController.text = selectedAddress;
          _isLoading = false; // Tắt loading
        });
      } else {
        setState(() {
          _isLoading = false; // Tắt loading nếu không có địa chỉ
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi nhập địa chỉ: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showAddressPickerMenu() {
    showMenu(
      color: Colors.white,
      context: context,
      position: const RelativeRect.fromLTRB(100, 400, 100, 100),
      items: [
        const PopupMenuItem(
          value: 'map',
          child: Row(
            children: [
              Icon(Icons.map, color: Colors.blueAccent),
              SizedBox(width: 8),
              Text('Chọn từ bản đồ'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'manual',
          child: Row(
            children: [
              Icon(Icons.edit, color: Colors.blueAccent),
              SizedBox(width: 8),
              Text('Nhập địa chỉ'),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'map') {
        _pickAddressFromMap();
      } else if (value == 'manual') {
        _pickAddressManually();
      }
    });
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
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
    required BuildContext context,
    required TextEditingController controller,
    required String labelText,
    String? hintText,
    IconData? prefixIcon,
    int minLines = 1,
    int maxLines = 1,
    String? Function(String?)? validator,
    bool isRequired = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: isRequired ? '$labelText *' : labelText,
          hintText: hintText,
          prefixIcon: prefixIcon != null
              ? Icon(prefixIcon,
              color: Theme.of(context).primaryColor.withOpacity(0.8))
              : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide:
            BorderSide(color: Theme.of(context).primaryColor, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: BorderSide(color: Colors.grey[400]!, width: 1.0),
          ),
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        minLines: minLines,
        maxLines: maxLines,
        validator: validator,
        textCapitalization: TextCapitalization.sentences,
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      period: const Duration(milliseconds: 1000),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10.0),
          border: Border.all(color: Colors.grey[400]!, width: 1.0),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'Vị trí'),
        _buildTextField(
          context: context,
          controller: widget.shortController,
          labelText: 'Vị trí ngắn gọn',
          hintText: 'VD: Đường Nguyễn Văn Cừ, Quận Ninh Kiều',
          prefixIcon: Icons.location_on_outlined,
          isRequired: true,
          validator: (value) => Validators.requiredField(value, 'vị trí'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: _isLoading
              ? _buildLoadingShimmer()
              : Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: widget.fullAddressController,
                  decoration: InputDecoration(
                    labelText: 'Địa chỉ đầy đủ *',
                    hintText: 'Chọn địa chỉ...',
                    prefixIcon: Icon(
                      Icons.maps_home_work_outlined,
                      color: Theme.of(context).primaryColor.withOpacity(0.8),
                    ),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.0),
                      borderSide: BorderSide(
                          color: Theme.of(context).primaryColor, width: 1.5),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.0),
                      borderSide:
                      BorderSide(color: Colors.grey[400]!, width: 1.0),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                  readOnly: true,
                  onTap: _showAddressPickerMenu,
                  validator: (value) =>
                      Validators.requiredField(value, 'địa chỉ đầy đủ'),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                color: Colors.white,
                icon: const Icon(
                  Icons.place,
                  color: Colors.blueAccent,
                ),
                onSelected: (value) {
                  if (value == 'map') {
                    _pickAddressFromMap();
                  } else if (value == 'manual') {
                    _pickAddressManually();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'map',
                    child: Row(
                      children: [
                        Icon(Icons.map, color: Colors.blueAccent),
                        SizedBox(width: 8),
                        Text('Chọn từ bản đồ'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'manual',
                    child: Row(
                      children: [
                        Icon(Icons.edit, color: Colors.blueAccent),
                        SizedBox(width: 8),
                        Text('Nhập địa chỉ'),
                      ],
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
}