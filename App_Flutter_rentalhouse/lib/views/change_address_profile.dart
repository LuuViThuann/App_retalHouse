import 'dart:async';
import 'package:custom_map_markers/custom_map_markers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/Widgets/Profile/enter_new_address.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart' as loc;
import 'package:provider/provider.dart';
import '../viewmodels/vm_auth.dart';

class ChangeAddressView extends StatefulWidget {
  const ChangeAddressView({super.key});

  @override
  State<ChangeAddressView> createState() => _ChangeAddressViewState();
}

class _ChangeAddressViewState extends State<ChangeAddressView> {
  GoogleMapController? _controller;
  LatLng? _currentLatLng;
  List<MarkerData> _customMarkers = [];
  String _currentAddress = '';
  String? _errorMessage;
  bool _isMapLoading = true;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Widget _customMarkerWidget(String title) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset('assets/img/location.png', width: 35, fit: BoxFit.contain),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Future<void> _updateAddressFromLatLng(LatLng position) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final parts = [
          place.name,
          place.street,
          place.subLocality,
          place.locality,
          place.administrativeArea,
          place.country,
        ];

        final fullAddress = parts
            .where((part) => part != null && part!.trim().isNotEmpty)
            .map((part) => part!.trim())
            .join(', ');

        setState(() {
          _currentLatLng = position;
          _currentAddress = fullAddress;
          _errorMessage = null;
          _customMarkers = [
            MarkerData(
              marker: Marker(
                markerId: const MarkerId('selected-location'),
                position: position,
                infoWindow: InfoWindow(title: fullAddress),
              ),
              child: _customMarkerWidget("Vị trí đã chọn"),
            ),
          ];
        });

        _controller?.animateCamera(CameraUpdate.newLatLngZoom(position, 16));
      } else {
        setState(() => _errorMessage = 'Không tìm thấy địa chỉ từ tọa độ.');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Lỗi khi lấy địa chỉ: $e');
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final location = loc.Location();

      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) {
          setState(() => _errorMessage = 'Dịch vụ vị trí chưa được bật.');
          return;
        }
      }

      var permissionGranted = await location.hasPermission();
      if (permissionGranted == loc.PermissionStatus.denied) {
        permissionGranted = await location.requestPermission();
        if (permissionGranted != loc.PermissionStatus.granted) {
          setState(() => _errorMessage = 'Quyền truy cập vị trí bị từ chối.');
          return;
        }
      }

      final currentLocation = await location.getLocation();

      if (currentLocation.latitude != null &&
          currentLocation.longitude != null) {
        final latLng = LatLng(
          currentLocation.latitude!,
          currentLocation.longitude!,
        );

        setState(() {
          _currentLatLng = latLng;
          _isMapLoading = false;
        });

        await _updateAddressFromLatLng(latLng);

        if (_controller != null) {
          await _controller!
              .animateCamera(CameraUpdate.newLatLngZoom(latLng, 16));
        }

        _showConfirmDialog(
            "Bạn có muốn chọn địa chỉ hiện tại?", _currentAddress);
      } else {
        setState(() => _errorMessage = 'Không lấy được tọa độ hiện tại.');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Lỗi khi lấy vị trí hiện tại: $e';
        _isMapLoading = false;
      });
    }
  }

  void _onMapTapped(LatLng position) async {
    await _updateAddressFromLatLng(position);
    _showConfirmDialog("Bạn có muốn chọn địa chỉ mới?", _currentAddress);
  }

  void _showConfirmDialog(String title, String address) {
    // Store the AuthViewModel reference before showing the dialog
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(title),
        content: Text(address),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Hủy"),
          ),
          TextButton(
            onPressed: () async {
              // Close the dialog first
              Navigator.pop(dialogContext);
              try {
                // Perform the update using the stored AuthViewModel
                await authViewModel.updateUserProfile(
                  phoneNumber: authViewModel.currentUser?.phoneNumber ?? '',
                  address: address,
                  username: authViewModel.currentUser?.username ?? '',
                );
                // Check if the widget is still mounted before updating state
                if (!mounted) return;
                if (authViewModel.errorMessage == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Địa chỉ đã được cập nhật thành công!'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ),
                  );
                  // Return address to MyProfileView
                  Navigator.pop(context, address);
                } else {
                  setState(() {
                    _errorMessage = authViewModel.errorMessage ??
                        'Lỗi khi cập nhật địa chỉ';
                  });
                }
              } catch (e) {
                if (mounted) {
                  setState(() {
                    _errorMessage = 'Lỗi khi cập nhật địa chỉ: $e';
                  });
                }
              }
            },
            child: const Text("Xác nhận"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.black),
        ),
        title: const Text(
          "Chọn địa chỉ",
          style: TextStyle(
            color: Colors.black,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 14),
              ),
            ),
          Expanded(
            child: _isMapLoading
                ? const Center(child: CircularProgressIndicator())
                : CustomGoogleMapMarkerBuilder(
                    customMarkers: _customMarkers,
                    builder: (BuildContext context, Set<Marker>? markers) {
                      return GoogleMap(
                        mapType: MapType.normal,
                        initialCameraPosition: CameraPosition(
                          target: _currentLatLng ?? const LatLng(10.0, 105.0),
                          zoom: 16.0,
                        ),
                        onMapCreated: (GoogleMapController controller) {
                          _controller = controller;
                          setState(() {
                            _errorMessage = null;
                            _isMapLoading = false;
                          });
                          if (_currentLatLng != null) {
                            controller.animateCamera(
                              CameraUpdate.newLatLngZoom(_currentLatLng!, 16),
                            );
                          }
                        },
                        onTap: _onMapTapped,
                        markers: markers ?? {},
                        myLocationEnabled: true,
                        myLocationButtonEnabled: true,
                        zoomControlsEnabled: true,
                        scrollGesturesEnabled: true,
                        rotateGesturesEnabled: true,
                        tiltGesturesEnabled: true,
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              _currentAddress.isEmpty
                  ? 'Vui lòng chọn địa chỉ'
                  : _currentAddress,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
              textAlign: TextAlign.center,
            ),
          ),

        ],
      ),
    );
  }
}
