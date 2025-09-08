import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/config/api_routes.dart';
import 'package:flutter_rentalhouse/views/rental_detail_view.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:location/location.dart' as loc;
import 'package:intl/intl.dart';
import 'package:flutter_rentalhouse/models/rental.dart';
import 'package:provider/provider.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_rental.dart';
import 'package:url_launcher/url_launcher.dart';

class RentalMapView extends StatefulWidget {
  final Rental rental;

  const RentalMapView({super.key, required this.rental});

  @override
  State<RentalMapView> createState() => _RentalMapViewState();
}

class _RentalMapViewState extends State<RentalMapView> {
  GoogleMapController? _controller;
  LatLng? _rentalLatLng;
  LatLng? _currentLatLng;
  Set<Marker> _markers = {};
  String? _errorMessage;
  bool _isMapLoading = true;
  Rental? _selectedRental;
  bool _showCustomInfo = false;

  @override
  void initState() {
    super.initState();
    _getLocationFromAddress();
    _getCurrentLocation();
    _fetchNearbyRentals();
  }

  @override
  void didUpdateWidget(RentalMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rental.id != widget.rental.id) {
      _getLocationFromAddress();
      _fetchNearbyRentals();
    }
  }

  Future<void> _getLocationFromAddress() async {
    try {
      if (widget.rental.location['latitude'] != 0.0 &&
          widget.rental.location['longitude'] != 0.0) {
        setState(() {
          _rentalLatLng = LatLng(
            widget.rental.location['latitude'] as double,
            widget.rental.location['longitude'] as double,
          );
          _isMapLoading = false;
        });
        _updateMarkers();
        if (_controller != null) {
          _controller
              ?.animateCamera(CameraUpdate.newLatLngZoom(_rentalLatLng!, 16));
        }
      } else {
        final locations =
            await locationFromAddress(widget.rental.location['fullAddress']);
        if (locations.isNotEmpty) {
          final location = locations.first;
          final latLng = LatLng(location.latitude, location.longitude);
          setState(() {
            _rentalLatLng = latLng;
            _isMapLoading = false;
          });
          _updateMarkers();
          if (_controller != null) {
            _controller?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 16));
          }
        } else {
          setState(() {
            _errorMessage = 'Không tìm thấy tọa độ cho địa chỉ này.';
            _isMapLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Lỗi khi lấy tọa độ: $e';
        _isMapLoading = false;
      });
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
        });
        _updateMarkers();
        if (_controller != null && _rentalLatLng == null) {
          _controller?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 16));
        }
      } else {
        setState(() => _errorMessage = 'Không lấy được tọa độ hiện tại.');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Lỗi khi lấy vị trí hiện tại: $e';
      });
    }
  }

  Future<void> _fetchNearbyRentals() async {
    try {
      final rentalViewModel =
          Provider.of<RentalViewModel>(context, listen: false);
      await rentalViewModel.fetchNearbyRentals(widget.rental.id, radius: 5.0);
      _updateMarkers();
    } catch (e) {
      setState(() {
        _errorMessage = 'Lỗi khi tải nhà trọ gần đây: $e';
      });
    }
  }

  void _showRentalInfo(Rental rental) {
    setState(() {
      _selectedRental = rental;
      _showCustomInfo = true;
    });
  }

  void _hideRentalInfo() {
    setState(() {
      _selectedRental = null;
      _showCustomInfo = false;
    });
  }

  Future<void> _openInGoogleMaps(LatLng location, String title) async {
    final String googleMapsUrl =
        'https://www.google.com/maps/search/?api=1&query=${location.latitude},${location.longitude}&query_place_id=$title';

    try {
      if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
        await launchUrl(Uri.parse(googleMapsUrl),
            mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      // Fallback URL scheme
      final String fallbackUrl =
          'geo:${location.latitude},${location.longitude}?q=${location.latitude},${location.longitude}($title)';
      try {
        if (await canLaunchUrl(Uri.parse(fallbackUrl))) {
          await launchUrl(Uri.parse(fallbackUrl),
              mode: LaunchMode.externalApplication);
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể mở Google Maps')),
        );
      }
    }
  }

  void _updateMarkers() {
    final Set<Marker> markers = {};

    // Add primary rental marker (red)
    if (_rentalLatLng != null) {
      markers.add(
        Marker(
          markerId: MarkerId(widget.rental.id),
          position: _rentalLatLng!,
          infoWindow: InfoWindow(
            title: widget.rental.title,
            snippet:
                '${formatCurrency(widget.rental.price)} • ${widget.rental.location['fullAddress']}',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          onTap: () => _showRentalInfo(widget.rental),
        ),
      );
    }

    // Add current location marker (blue)
    if (_currentLatLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('current-location'),
          position: _currentLatLng!,
          infoWindow: const InfoWindow(title: 'Vị trí hiện tại'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }

    // Add nearby rentals markers (green)
    final rentalViewModel =
        Provider.of<RentalViewModel>(context, listen: false);
    for (var rental in rentalViewModel.nearbyRentals) {
      if (rental.location['latitude'] != null &&
          rental.location['longitude'] != null &&
          rental.id != widget.rental.id) {
        markers.add(
          Marker(
            markerId: MarkerId(rental.id),
            position: LatLng(
              rental.location['latitude'] as double,
              rental.location['longitude'] as double,
            ),
            infoWindow: InfoWindow(
              title: rental.title,
              snippet:
                  '${formatCurrency(rental.price)} • ${rental.location['fullAddress']}',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueGreen),
            onTap: () => _showRentalInfo(rental),
          ),
        );
      }
    }

    setState(() {
      _markers = markers;
    });
  }

  String formatCurrency(double amount) {
    final formatter =
        NumberFormat.currency(locale: 'vi_VN', symbol: 'VNĐ', decimalDigits: 0);
    return formatter.format(amount);
  }

  Widget _buildCustomInfoWindow() {
    if (!_showCustomInfo || _selectedRental == null)
      return const SizedBox.shrink();

    final rental = _selectedRental!;
    final imageUrl = rental.images.isNotEmpty
        ? '${ApiRoutes.baseUrl.replaceAll('/api', '')}${rental.images[0]}'
        : '';

    return Positioned(
      top: 100,
      left: 16,
      right: 16,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Close button
            Align(
              alignment: Alignment.topRight,
              child: GestureDetector(
                onTap: _hideRentalInfo,
                child: Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 20),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.home, color: Colors.grey),
                          ),
                          errorWidget: (context, url, error) => Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.error, color: Colors.grey),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rental.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              formatCurrency(rental.price),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              rental.location['fullAddress'],
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    RentalDetailScreen(rental: rental),
                              ),
                            );
                          },
                          icon: const Icon(Icons.info_outline, size: 18),
                          label: const Text('Chi tiết'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[600],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            final position = LatLng(
                              rental.location['latitude'] as double,
                              rental.location['longitude'] as double,
                            );
                            _openInGoogleMaps(position, rental.title);
                          },
                          icon: const Icon(Icons.directions, size: 18),
                          label: const Text('Chỉ đường'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.blue[600],
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            side: BorderSide(color: Colors.blue[600]!),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rentalViewModel = Provider.of<RentalViewModel>(context);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.black),
        ),
        title: Text(
          widget.rental.title,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              if (_rentalLatLng != null) {
                _openInGoogleMaps(_rentalLatLng!, widget.rental.title);
              }
            },
            icon: const Icon(Icons.directions, color: Colors.black),
            tooltip: 'Mở trong Google Maps',
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              if (_errorMessage != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16.0),
                  color: Colors.red[50],
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          color: Colors.red[600], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style:
                              TextStyle(color: Colors.red[700], fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: _isMapLoading
                    ? const Center(child: CircularProgressIndicator())
                    : GoogleMap(
                        mapType: MapType.normal,
                        initialCameraPosition: CameraPosition(
                          target: _rentalLatLng ??
                              _currentLatLng ??
                              const LatLng(10.0, 105.0),
                          zoom: 16.0,
                        ),
                        onMapCreated: (GoogleMapController controller) {
                          _controller = controller;
                          if (_rentalLatLng != null) {
                            controller.animateCamera(
                                CameraUpdate.newLatLngZoom(_rentalLatLng!, 16));
                          } else if (_currentLatLng != null) {
                            controller.animateCamera(CameraUpdate.newLatLngZoom(
                                _currentLatLng!, 16));
                          }
                        },
                        onTap: (_) => _hideRentalInfo(),
                        markers: _markers,
                        myLocationEnabled: true,
                        myLocationButtonEnabled: true,
                        zoomControlsEnabled: true,
                        scrollGesturesEnabled: true,
                        rotateGesturesEnabled: true,
                        tiltGesturesEnabled: true,
                      ),
              ),
              // Bottom info panel
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      spreadRadius: 1,
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.green[600],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                formatCurrency(widget.rental.price),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade700,
                                ),
                              ),
                              Text(
                                widget.rental.location['fullAddress'],
                                style: const TextStyle(
                                    fontSize: 14, color: Colors.black87),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (rentalViewModel.isLoading)
                Container(
                  padding: const EdgeInsets.all(16.0),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Text('Đang tải nhà trọ gần đây...'),
                    ],
                  ),
                )
              else if (rentalViewModel.nearbyRentals.isNotEmpty)
                Container(
                  height: 160,
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          children: [
                            Icon(Icons.location_on,
                                color: Colors.green, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Gợi ý nhà trọ gần đây',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: rentalViewModel.nearbyRentals.length,
                          itemBuilder: (context, index) {
                            final rental = rentalViewModel.nearbyRentals[index];
                            if (rental.id == widget.rental.id)
                              return const SizedBox.shrink();
                            final imageUrl = rental.images.isNotEmpty
                                ? '${ApiRoutes.baseUrl.replaceAll('/api', '')}${rental.images[0]}'
                                : '';
                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        RentalDetailScreen(rental: rental),
                                  ),
                                );
                              },
                              child: Container(
                                width: 200,
                                margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey[300]!),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.withOpacity(0.1),
                                      spreadRadius: 1,
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                  color: Colors.white,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: const BorderRadius.vertical(
                                          top: Radius.circular(12)),
                                      child: CachedNetworkImage(
                                        imageUrl: imageUrl,
                                        height: 85,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) =>
                                            Container(
                                          height: 85,
                                          color: Colors.grey[200],
                                          child: const Center(
                                            child: CircularProgressIndicator(),
                                          ),
                                        ),
                                        errorWidget: (context, url, error) =>
                                            Container(
                                          height: 85,
                                          color: Colors.grey[200],
                                          child: const Icon(Icons.error),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            rental.title,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            formatCurrency(rental.price),
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.green.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          // Custom info window overlay
          _buildCustomInfoWindow(),
        ],
      ),
    );
  }
}
