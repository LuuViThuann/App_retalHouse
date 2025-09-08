import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:shimmer/shimmer.dart';

class LocationForm extends StatefulWidget {
  final TextEditingController shortController;
  final TextEditingController fullAddressController;
  final ValueNotifier<double?> latitudeNotifier;
  final ValueNotifier<double?> longitudeNotifier;

  const LocationForm({
    super.key,
    required this.shortController,
    required this.fullAddressController,
    required this.latitudeNotifier,
    required this.longitudeNotifier,
  });

  @override
  _LocationFormState createState() => _LocationFormState();
}

class _LocationFormState extends State<LocationForm> {
  bool _isLoading = false;

  Future<void> _pickAddressFromMap() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ChangeAddressView()),
      );

      if (result != null && mounted) {
        if (result is Map<String, dynamic>) {
          setState(() {
            widget.fullAddressController.text = result['address'] ?? '';
            widget.latitudeNotifier.value = result['latitude'];
            widget.longitudeNotifier.value = result['longitude'];
            _isLoading = false;
          });
        } else if (result is String) {
          setState(() {
            widget.fullAddressController.text = result;
            widget.latitudeNotifier.value = null;
            widget.longitudeNotifier.value = null;
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi chọn địa chỉ từ bản đồ: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickAddressManually() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final selectedAddress = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => NewAddressPage()),
      );

      if (selectedAddress != null && selectedAddress is String && mounted) {
        setState(() {
          widget.fullAddressController.text = selectedAddress;
          widget.latitudeNotifier.value = null;
          widget.longitudeNotifier.value = null;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
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
    void Function(String)? onChanged,
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
        onChanged: onChanged,
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
          validator: (value) =>
              value == null || value.isEmpty ? 'Vui lòng nhập vị trí' : null,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: _isLoading
              ? _buildLoadingShimmer()
              : Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        context: context,
                        controller: widget.fullAddressController,
                        labelText: 'Địa chỉ đầy đủ',
                        hintText:
                            'VD: 123 Nguyễn Thị Thập, Tân Phú, Quận 7, TP.HCM',
                        prefixIcon: Icons.maps_home_work_outlined,
                        isRequired: true,
                        validator: (value) => value == null || value.isEmpty
                            ? 'Vui lòng nhập địa chỉ đầy đủ'
                            : null,
                        onChanged: (value) {
                          widget.latitudeNotifier.value = null;
                          widget.longitudeNotifier.value = null;
                        },
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

class ChangeAddressView extends StatefulWidget {
  @override
  _ChangeAddressViewState createState() => _ChangeAddressViewState();
}

class _ChangeAddressViewState extends State<ChangeAddressView> {
  GoogleMapController? _mapController;
  LatLng _selectedLocation =
      const LatLng(10.762622, 106.660172); // Default: Ho Chi Minh City
  String _selectedAddress = '';
  bool _isLoading = false;

  Future<void> _geocodeLatLng(LatLng latLng) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json?latlng=${latLng.latitude},${latLng.longitude}&region=vn&key=${const String.fromEnvironment('GOOGLE_MAPS_API_KEY')}',
        ),
      );

      final data = json.decode(response.body);
      if (data['status'] == 'OK' && data['results'].isNotEmpty) {
        setState(() {
          _selectedAddress = data['results'][0]['formatted_address'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _selectedAddress = 'Không tìm thấy địa chỉ';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi lấy địa chỉ: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chọn vị trí trên bản đồ'),
        actions: [
          TextButton(
            onPressed: _isLoading
                ? null
                : () {
                    Navigator.pop(context, {
                      'address': _selectedAddress,
                      'latitude': _selectedLocation.latitude,
                      'longitude': _selectedLocation.longitude,
                    });
                  },
            child:
                const Text('Xác nhận', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _selectedLocation,
              zoom: 15,
            ),
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
            },
            onTap: (LatLng latLng) {
              setState(() {
                _selectedLocation = latLng;
              });
              _geocodeLatLng(latLng);
            },
            markers: {
              Marker(
                markerId: const MarkerId('selected-location'),
                position: _selectedLocation,
              ),
            },
          ),
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : Text(
                        _selectedAddress.isEmpty
                            ? 'Chọn một điểm trên bản đồ'
                            : _selectedAddress,
                        style: const TextStyle(fontSize: 16),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NewAddressPage extends StatelessWidget {
  final TextEditingController _addressController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nhập địa chỉ'),
        actions: [
          TextButton(
            onPressed: () {
              if (_addressController.text.isNotEmpty) {
                Navigator.pop(context, _addressController.text);
              }
            },
            child:
                const Text('Xác nhận', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: TextField(
          controller: _addressController,
          decoration: InputDecoration(
            labelText: 'Địa chỉ đầy đủ',
            hintText: 'VD: 123 Nguyễn Thị Thập, Tân Phú, Quận 7, TP.HCM',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
      ),
    );
  }
}
