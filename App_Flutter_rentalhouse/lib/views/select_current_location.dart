import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart' as loc;

class SelectCurrentLocationView extends StatefulWidget {
  const SelectCurrentLocationView({super.key});

  @override
  State<SelectCurrentLocationView> createState() =>
      _SelectCurrentLocationViewState();
}

class _SelectCurrentLocationViewState extends State<SelectCurrentLocationView> {
  GoogleMapController? _controller;
  LatLng? _currentLatLng;
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
        final latLng =
            LatLng(currentLocation.latitude!, currentLocation.longitude!);
        setState(() {
          _currentLatLng = latLng;
          _isMapLoading = false;
        });
        await _updateAddressFromLatLng(latLng);
        if (_controller != null) {
          await _controller!
              .animateCamera(CameraUpdate.newLatLngZoom(latLng, 16));
        }
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

  void _onConfirm() {
    if (_currentAddress.isNotEmpty) {
      Navigator.pop(context, _currentAddress);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Vui lòng chờ lấy địa chỉ hoặc thử lại!'),
            backgroundColor: Colors.red),
      );
    }
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
          "Lấy địa chỉ hiện tại",
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
                : GoogleMap(
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
                    markers: _currentLatLng != null
                        ? {
                            Marker(
                              markerId: const MarkerId('current-location'),
                              position: _currentLatLng!,
                              infoWindow: InfoWindow(title: _currentAddress),
                            ),
                          }
                        : {},
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    zoomControlsEnabled: true,
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text(
                  _currentAddress.isEmpty
                      ? 'Vui lòng chờ lấy địa chỉ...'
                      : _currentAddress,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _onConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('Xác nhận địa chỉ',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
