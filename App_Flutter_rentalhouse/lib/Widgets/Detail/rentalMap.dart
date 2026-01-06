import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/Widgets/Detail/FilterDialogWidget.dart';
import 'package:flutter_rentalhouse/Widgets/Detail/HorizontalRentalList.dart';
import 'package:flutter_rentalhouse/Widgets/Detail/NearbyRentals.dart';
import 'package:flutter_rentalhouse/Widgets/Detail/analytics_screen.dart';
import 'package:flutter_rentalhouse/Widgets/Detail/customMarker.dart';
import 'package:flutter_rentalhouse/config/api_routes.dart';
import 'package:flutter_rentalhouse/utils/Snackbar_process.dart';
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
    _initializeMap();
  }

  @override
  void didUpdateWidget(RentalMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rental.id != widget.rental.id) {
      _initializeMap();
    }
  }

  Future<void> _initializeMap() async {
    await _getLocationFromAddress();
    await _getCurrentLocation();
    await _fetchNearbyRentals();
  }

  Future<void> _getLocationFromAddress() async {
    try {
      if (_validateRental(widget.rental) &&
          widget.rental.location['latitude'] != 0.0 &&
          widget.rental.location['longitude'] != 0.0) {
        setState(() {
          _rentalLatLng = LatLng(
            widget.rental.location['latitude'] as double,
            widget.rental.location['longitude'] as double,
          );
          _isMapLoading = false;
        });
        _updateMarkers();
        _animateToPosition(_rentalLatLng!, 16.0);
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
          _animateToPosition(latLng, 16.0);
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
        if (_rentalLatLng == null) {
          _animateToPosition(latLng, 16.0);
        }
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
      await rentalViewModel.fetchNearbyRentals(widget.rental.id);
      _updateMarkers();
    } catch (e) {
      setState(() {
        _errorMessage = 'Lỗi khi tải bất động sản gần đây: $e';
      });
    }
  }

  void _updateMarkers() async {
    final Set<Marker> markers = {};

    // Main rental marker (RED)
    if (_rentalLatLng != null && _validateRental(widget.rental)) {
      final customIcon = await CustomMarkerHelper.createCustomMarker(
        price: widget.rental.price,
        propertyType: 'Rental',
        isMainRental: true,
        hasValidCoords: widget.rental.location['latitude'] != 0.0 &&
            widget.rental.location['longitude'] != 0.0,
      );
      markers.add(
        Marker(
          markerId: MarkerId('main-${widget.rental.id}'),
          position: _rentalLatLng!,
          infoWindow: InfoWindow(
            title: 'Nhà này: ${widget.rental.title}',
            snippet: _formatPriceCompact(widget.rental.price),
          ),
          icon: customIcon,
          onTap: () => _showRentalInfo(widget.rental),
        ),
      );
    }

    // Current location marker (BLUE)
    if (_currentLatLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('current-location'),
          position: _currentLatLng!,
          infoWindow: const InfoWindow(
            title: 'Vị trí của bạn',
            snippet: 'Vị trí hiện tại',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }

    // Nearby rental markers
    final rentalViewModel =
    Provider.of<RentalViewModel>(context, listen: false);

    for (int i = 0; i < rentalViewModel.nearbyRentals.length; i++) {
      final rental = rentalViewModel.nearbyRentals[i];

      if (rental.id == widget.rental.id) continue;
      if (!_validateRental(rental)) continue;

      final lat = _safeParseDouble(
          rental.location['latitude'], 'rental.location.latitude') ??
          0.0;
      final lng = _safeParseDouble(
          rental.location['longitude'], 'rental.location.longitude') ??
          0.0;

      if (lat == 0.0 && lng == 0.0) continue;

      final position = LatLng(lat, lng);
      final customIcon = await CustomMarkerHelper.createCustomMarker(
        price: rental.price,
        propertyType: 'Rental',
        isMainRental: false,
        hasValidCoords: lat != 0.0 && lng != 0.0,
      );
      markers.add(
        Marker(
          markerId: MarkerId('nearby-${rental.id}'),
          position: position,
          infoWindow: InfoWindow(
            title: 'Gần đây: ${rental.title}',
            snippet:
            '${_formatPriceCompact(rental.price)} - ${rental.location['short'] ?? ''}',
          ),
          icon: customIcon,
          onTap: () => _showRentalInfo(rental),
        ),
      );
    }

    if (mounted) {
      setState(() {
        _markers = markers;
      });
    }
  }

  String _buildImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) {
      return 'https://via.placeholder.com/400x300?text=No+Image';
    }

    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return imagePath;
    }

    if (imagePath.startsWith('/')) {
      return '${ApiRoutes.baseUrl.replaceAll('/api', '')}$imagePath';
    }

    return '${ApiRoutes.baseUrl.replaceAll('/api', '')}/$imagePath';
  }

  bool _validateRental(Rental rental) {
    try {
      if (rental.id.isEmpty || rental.title.isEmpty) return false;
      final price = _safeParseDouble(rental.price, 'rental.price');
      final lat = _safeParseDouble(
          rental.location['latitude'], 'rental.location.latitude');
      final lng = _safeParseDouble(
          rental.location['longitude'], 'rental.location.longitude');
      if (price == null || lat == null || lng == null) return false;
      return true;
    } catch (e) {
      return false;
    }
  }

  double? _safeParseDouble(dynamic value, String fieldName) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      final trimmed = value.trim().replaceAll(',', '.');
      if (trimmed.isEmpty) return null;
      return double.tryParse(trimmed);
    }
    return null;
  }

  String _formatPriceCompact(double price) {
    try {
      if (price >= 1000000000) {
        return '${(price / 1000000000).toStringAsFixed(1)} tỷ VNĐ';
      } else if (price >= 1000000) {
        return '${(price / 1000000).toStringAsFixed(0)} triệu VNĐ';
      } else if (price >= 1000) {
        return '${(price / 1000).toStringAsFixed(0)} nghìn VNĐ';
      } else {
        return '${price.toStringAsFixed(0)} VNĐ';
      }
    } catch (e) {
      return '0 VNĐ';
    }
  }

  void _animateToPosition(LatLng position, double zoom) {
    if (_controller != null) {
      _controller!.animateCamera(CameraUpdate.newLatLngZoom(position, zoom));
    }
  }

  void _showRentalInfo(Rental rental) {
    if (!_validateRental(rental)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Dữ liệu bài viết không hợp lệ'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

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

  String formatCurrency(dynamic amount) {
    try {
      final double price = amount is num ? amount.toDouble() : 0.0;
      final formatter = NumberFormat.currency(
        locale: 'vi_VN',
        symbol: 'VNĐ',
        decimalDigits: 0,
      );
      return formatter.format(price);
    } catch (e) {
      return '0 VNĐ';
    }
  }

  Widget _buildCustomInfoWindow() {
    if (!_showCustomInfo || _selectedRental == null) {
      return const SizedBox.shrink();
    }

    final rental = _selectedRental!;
    final imageUrl = _buildImageUrl(
      rental.images.isNotEmpty ? rental.images[0] : null,
    );

    final bool isCurrentRental = rental.id == widget.rental.id;
    final bool hasValidCoords = _safeParseDouble(
        rental.location['latitude'], 'rental.location.latitude') !=
        null &&
        _safeParseDouble(
            rental.location['longitude'], 'rental.location.longitude') !=
            null &&
        (rental.location['latitude'] != 0.0 ||
            rental.location['longitude'] != 0.0);

    return Positioned(
      top: 100,
      left: 16,
      right: 16,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCurrentRental ? Colors.red[300]! : Colors.green[300]!,
            width: 2,
          ),
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
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isCurrentRental ? Colors.red[50] : Colors.green[50],
                borderRadius:
                const BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Row(
                children: [
                  Icon(
                    isCurrentRental ? Icons.home : Icons.location_on,
                    color:
                    isCurrentRental ? Colors.red[600] : Colors.green[600],
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isCurrentRental ? 'Bất động sản này' : 'Bất động sản gần đây',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isCurrentRental
                            ? Colors.red[700]
                            : Colors.green[700],
                      ),
                    ),
                  ),
                  if (!hasValidCoords)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Cần cập nhật vị trí',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.orange[800],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  GestureDetector(
                    onTap: _hideRentalInfo,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, size: 16),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                              rental.location['fullAddress'] ??
                                  'Chưa có địa chỉ',
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
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (_validateRental(rental)) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      RentalDetailScreen(rental: rental),
                                ),
                              );
                            }
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
                          onPressed: hasValidCoords
                              ? () {
                            final position = LatLng(
                              _safeParseDouble(rental.location['latitude'],
                                  'rental.location.latitude') ??
                                  0.0,
                              _safeParseDouble(
                                  rental.location['longitude'],
                                  'rental.location.longitude') ??
                                  0.0,
                            );
                            _openInGoogleMaps(position, rental.title);
                          }
                              : null,
                          icon: Icon(
                            hasValidCoords
                                ? Icons.directions
                                : Icons.location_disabled,
                            size: 18,
                          ),
                          label: Text(
                              hasValidCoords ? 'Chỉ đường' : 'Không có vị trí'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor:
                            hasValidCoords ? Colors.blue[600] : Colors.grey,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            side: BorderSide(
                              color: hasValidCoords
                                  ? Colors.blue[600]!
                                  : Colors.grey[400]!,
                            ),
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

  void _showFilterDialog() {
    final rentalViewModel =
    Provider.of<RentalViewModel>(context, listen: false);

    showFilterDialog(
      context: context,
      initialRadius: rentalViewModel.currentRadius,
      initialMinPrice: rentalViewModel.currentMinPrice,
      initialMaxPrice: rentalViewModel.currentMaxPrice,
      onApply: (radius, minPrice, maxPrice) async {
        await rentalViewModel.fetchNearbyRentals(
          widget.rental.id,
          radius: radius,
          minPrice: minPrice,
          maxPrice: maxPrice,
        );

        _updateMarkers();

        if (mounted) {
          AppSnackBar.show(
            context,
            AppSnackBar.success(
              message: 'Tìm thấy ${rentalViewModel.nearbyRentals.length} kết quả',
              seconds: 3,
            ),
          );
        }
      },
      onReset: () {
        rentalViewModel.resetNearbyFilters();
        _fetchNearbyRentals();
      },
    );
  }

  Widget _buildTopLeftControls() {
    final rentalViewModel = Provider.of<RentalViewModel>(context);

    return Positioned(
      top: 16,
      left: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ============ THỐNG KÊ BUTTON ============
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AnalyticsScreen(),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.analytics, color: Colors.purple[700], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Thống kê',
                        style: TextStyle(
                          color: Colors.purple[700],
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Filter button
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _showFilterDialog,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tune_rounded, color: Colors.blue[700], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Lọc',
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Refresh button
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: rentalViewModel.isLoading
                    ? null
                    : () async {
                  await _fetchNearbyRentals();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.white),
                            const SizedBox(width: 12),
                            Text('Đã cập nhật: ${rentalViewModel.nearbyRentals.length} bài'),
                          ],
                        ),
                        backgroundColor: Colors.green[700],
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        margin: const EdgeInsets.all(16),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: rentalViewModel.isLoading
                      ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.blue[700]!,
                      ),
                    ),
                  )
                      : Icon(Icons.refresh_rounded, color: Colors.blue[700], size: 20),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Info badge showing count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green[600],
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              '${rentalViewModel.nearbyRentals.length} bài',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
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
    if (rentalViewModel.warningMessage != null)
    Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16.0),
    color: Colors.yellow[50],
    child: Row(
    children: [
    Icon(Icons.warning_amber,
    color: Colors.yellow[700], size: 20),
    const SizedBox(width: 8),
    Expanded(
    child: Text(
    rentalViewModel.warningMessage!,
    style: TextStyle(
    color: Colors.yellow[800], fontSize: 14),
    ),// Phần build method tiếp theo (từ dòng bị cắt ở document 4)

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
                controller.animateCamera(
                    CameraUpdate.newLatLngZoom(_currentLatLng!, 16));
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
      ],
      ),

            // Top left controls overlay
            _buildTopLeftControls(),

            // Custom info window overlay
            _buildCustomInfoWindow(),

            // Horizontal rental list at bottom
            HorizontalRentalListWidget(
              rentals: rentalViewModel.nearbyRentals,
              mainRental: widget.rental,
              validateRental: _validateRental,
              onRentalTap: (rental) {
                final lat = _safeParseDouble(
                    rental.location['latitude'], 'rental.location.latitude') ??
                    0.0;
                final lng = _safeParseDouble(
                    rental.location['longitude'], 'rental.location.longitude') ??
                    0.0;

                if (lat != 0.0 && lng != 0.0) {
                  _animateToPosition(LatLng(lat, lng), 16.0);
                  _showRentalInfo(rental);
                }
              },
            ),
          ],
      ),
    );
  }
}