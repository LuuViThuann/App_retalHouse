import 'dart:io';

import 'package:custom_map_markers/custom_map_markers.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:location/location.dart' as loc;

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
        Image.asset('assets/img/map_pin.png', width: 35, fit: BoxFit.contain),
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

        await _controller
            ?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 16));
        await _updateAddressFromLatLng(latLng);

        _showConfirmDialog(
            "Bạn có muốn chọn địa chỉ hiện tại?", _currentAddress);
      } else {
        setState(() => _errorMessage = 'Không lấy được tọa độ hiện tại.');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Lỗi khi lấy vị trí hiện tại: $e');
    }
  }

  void _onMapTapped(LatLng position) async {
    await _updateAddressFromLatLng(position);
    _showConfirmDialog("Bạn có muốn chọn địa chỉ mới?", _currentAddress);
  }

  void _showConfirmDialog(String title, String address) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(address),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Hủy"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Đóng dialog
              Navigator.pop(context, _currentAddress); // Trả về địa chỉ
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
          icon: Image.asset('assets/img/btn_back.png', width: 24, height: 24),
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
            child: CustomGoogleMapMarkerBuilder(
              customMarkers: _customMarkers,
              builder: (BuildContext context, Set<Marker>? markers) {
                if (markers == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                return GoogleMap(
                  mapType: MapType.normal,
                  initialCameraPosition: CameraPosition(
                    target: _currentLatLng ?? const LatLng(10.0, 105.0),
                    zoom: 16.0,
                  ),
                  onMapCreated: (controller) {
                    _controller = controller;
                    setState(() => _errorMessage = null);
                  },
                  onTap: _onMapTapped,
                  markers: markers,
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
