import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/Widgets/Profile/enter_new_address.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

// ====================== LOCATION FORM CẢI TIẾN ======================
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
  State<LocationForm> createState() => _LocationFormState();
}

class _LocationFormState extends State<LocationForm> {
  bool _isLoading = false;
  GoogleMapController? _previewMapController;
  LatLng? _previewPosition;
  Set<Marker> _previewMarkers = {};
  Timer? _debounce;
  String? _geocodedAddressDisplay; // Địa chỉ đã geocode thành công
  String? _lastGeocodedInput; // Lưu input cuối cùng đã geocode

  @override
  void initState() {
    super.initState();
    widget.fullAddressController.addListener(_onAddressChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.fullAddressController.removeListener(_onAddressChanged);
    _previewMapController?.dispose();
    super.dispose();
  }

  void _onAddressChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 1500), () { // Tăng lên 1.5s
      final address = widget.fullAddressController.text.trim();
      if (address.isNotEmpty &&
          address.length > 15 &&
          address != _lastGeocodedInput) {
        _geocodeAddress(address);
      } else if (address.isEmpty) {
        _clearPreview();
      }
    });
  }

  /// Chuẩn hóa địa chỉ Việt Nam theo đúng format backend
  String _normalizeVietnameseAddress(String addr) {
    String normalized = addr.trim().replaceAll(RegExp(r'\s+'), ' ');

    // Chuẩn hóa các viết tắt
    normalized = normalized.replaceAll(
        RegExp(r'\bP\.?\s*', caseSensitive: false), 'Phường ');
    normalized = normalized.replaceAll(
        RegExp(r'\bQ\.?\s*', caseSensitive: false), 'Quận ');
    normalized = normalized.replaceAll(
        RegExp(r'\bTP\.?\s*', caseSensitive: false), 'Thành phố ');
    normalized = normalized.replaceAll(
        RegExp(r'\bH\.?\s*', caseSensitive: false), 'Huyện ');
    normalized = normalized.replaceAll(
        RegExp(r'\bTX\.?\s*', caseSensitive: false), 'Thị xã ');

    // Thêm "Việt Nam" nếu chưa có
    if (!normalized.toLowerCase().contains('việt nam') &&
        !normalized.toLowerCase().contains('vietnam')) {
      normalized += ', Việt Nam';
    }

    return normalized;
  }

  /// Geocoding với Nominatim OSM (giống backend) - ĐỘ CHÍNH XÁC CAO
  Future<void> _geocodeAddress(String rawAddress) async {
    setState(() {
      _isLoading = true;
      _geocodedAddressDisplay = null;
    });

    try {
      final normalized = _normalizeVietnameseAddress(rawAddress);
      _lastGeocodedInput = rawAddress;

      // Tạo nhiều phiên bản địa chỉ để thử (giống backend)
      final addressVariants = _createAddressVariants(normalized);

      // Thử geocode với từng phiên bản
      for (final addressToTry in addressVariants) {
        final result = await _tryGeocode(addressToTry);
        if (result != null) {
          final lat = result['lat'];
          final lon = result['lon'];
          final displayName = result['display_name'];

          setState(() {
            _previewPosition = LatLng(lat, lon);
            _geocodedAddressDisplay = displayName;
            _previewMarkers = {
              Marker(
                markerId: const MarkerId('preview'),
                position: _previewPosition!,
                infoWindow: InfoWindow(
                  title: 'Vị trí chính xác',
                  snippet: _formatAddressSnippet(displayName),
                ),
              ),
            };
          });

          widget.latitudeNotifier.value = lat;
          widget.longitudeNotifier.value = lon;

          // Animate camera với zoom phù hợp
          _previewMapController?.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: _previewPosition!, zoom: 17),
            ),
          );

          setState(() => _isLoading = false);
          return; // Thành công, dừng vòng lặp
        }
      }

      _clearPreview();
    } catch (e) {
      _showError('Lỗi kết nối: $e');
      _clearPreview();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Tạo các phiên bản địa chỉ để thử (giống backend logic)
  List<String> _createAddressVariants(String normalized) {
    final parts = normalized
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    List<String> variants = [normalized]; // Full address

    if (parts.length >= 4) {
      // Simplified: Đường + Quận + Thành phố + Việt Nam
      final road = parts[0];
      final district = parts.length > 2 ? parts[2] : parts[1];
      final city = parts[parts.length - 2];
      variants.add('$road, $district, $city, Việt Nam');
    }

    if (parts.length >= 3) {
      // Minimal: Quận + Thành phố + Việt Nam
      final district = parts[parts.length - 3];
      final city = parts[parts.length - 2];
      variants.add('$district, $city, Việt Nam');
    }

    return variants;
  }

  /// Thử geocode với một địa chỉ cụ thể
  Future<Map<String, dynamic>?> _tryGeocode(String address) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?format=json'
        '&q=${Uri.encodeComponent(address)}'
        '&limit=1'
        '&countrycodes=vn'
        '&addressdetails=1'
        '&accept-language=vi',
      );

      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'RentalHouseApp/1.0 (+https://rentalhouse.app)'
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        if (data.isNotEmpty) {
          return {
            'lat': double.parse(data[0]['lat']),
            'lon': double.parse(data[0]['lon']),
            'display_name': data[0]['display_name'],
          };
        }
      }
    } catch (e) {
      print('Geocode attempt failed: $e');
    }
    return null;
  }

  String _formatAddressSnippet(String fullAddress) {
    final parts = fullAddress.split(',');
    return parts.take(4).join(', ');
  }

  void _clearPreview() {
    setState(() {
      _previewPosition = null;
      _previewMarkers.clear();
      _geocodedAddressDisplay = null;
      _lastGeocodedInput = null;
    });
    widget.latitudeNotifier.value = null;
    widget.longitudeNotifier.value = null;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Chọn địa chỉ từ form thủ công
  Future<void> _pickAddressManually() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NewAddressPage()),
    );

    if (result != null &&
        result is String &&
        result.trim().isNotEmpty &&
        mounted) {
      final selectedAddress = result.trim();
      widget.fullAddressController.text = selectedAddress;

      // Trigger geocoding ngay lập tức
      await Future.delayed(const Duration(milliseconds: 300));
      _geocodeAddress(selectedAddress);
    }
  }

  /// Chọn vị trí trực tiếp trên bản đồ
  Future<void> _pickLocationOnMap() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdvancedMapPicker(
          initialPosition: _previewPosition,
          initialAddress: widget.fullAddressController.text,
        ),
      ),
    );

    if (result != null && result is Map<String, dynamic> && mounted) {
      widget.fullAddressController.text = result['address'] ?? '';
      widget.latitudeNotifier.value = result['latitude'];
      widget.longitudeNotifier.value = result['longitude'];

      final latLng = LatLng(result['latitude'], result['longitude']);
      setState(() {
        _previewPosition = latLng;
        _geocodedAddressDisplay = result['address'];
        _previewMarkers = {
          Marker(
            markerId: const MarkerId('preview'),
            position: latLng,
            infoWindow: InfoWindow(title: 'Vị trí đã chọn'),
          ),
        };
      });
      _previewMapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: latLng, zoom: 17),
        ),
      );
    }
  }

  void _showAddressGuide() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Theme.of(context).primaryColor),
            const SizedBox(width: 12),
            const Text('Hướng dẫn nhập địa chỉ'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '✅ Địa chỉ CHÍNH XÁC (khuyên dùng):',
                style:
                    TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
              ),
              SizedBox(height: 8),
              Text(
                  '• 86/41 Lê Hồng Phong, Phường Thắng Lợi, Quận Ninh Kiều, Cần Thơ'),
              Text(
                  '• 123 Trần Hưng Đạo, Phường An Phú, Quận Ninh Kiều, TP Cần Thơ'),
              SizedBox(height: 16),
              Text(
                '⚠️ Địa chỉ KHÔNG CHÍNH XÁC (tránh):',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.orange),
              ),
              SizedBox(height: 8),
              Text('• Gần chợ Ninh Kiều (quá mơ hồ)'),
              Text('• Đường 3/2 (thiếu phường/quận)'),
              SizedBox(height: 16),
              Text(
                '💡 Mẹo:',
                style:
                    TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
              ),
              SizedBox(height: 8),
              Text(
                  '• Dùng nút "Chọn địa chỉ nhanh" để chọn đúng theo cấp hành chính'),
              Text(
                  '• Hoặc dùng nút "Chọn trên bản đồ" để chọn trực tiếp vị trí'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'Vị trí'),

        // Vị trí ngắn gọn
        _buildTextField(
          context: context,
          controller: widget.shortController,
          labelText: 'Vị trí ngắn gọn',
          hintText: 'VD: Đường 3/2, Quận Ninh Kiều',
          prefixIcon: Icons.location_on_outlined,
          isRequired: true,
        ),

        // Địa chỉ đầy đủ với các nút action
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildTextField(
                      context: context,
                      controller: widget.fullAddressController,
                      labelText: 'Địa chỉ đầy đủ',
                      hintText:
                          '123 Nguyễn Văn Cừ, An Khánh, Ninh Kiều, Cần Thơ',
                      prefixIcon: Icons.home_outlined,
                      isRequired: true,
                      maxLines: 3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    children: [
                      // Nút chọn địa chỉ từ form
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.location_searching,
                              color: Colors.blue, size: 28),
                          tooltip: 'Chọn địa chỉ nhanh',
                          onPressed: _pickAddressManually,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Nút hướng dẫn
                      IconButton(
                        icon: const Icon(Icons.help_outline,
                            color: Colors.orange, size: 28),
                        tooltip: 'Hướng dẫn',
                        onPressed: _showAddressGuide,
                      ),
                    ],
                  ),
                ],
              ),

              // Gợi ý nhập
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 12),
                child: Text(
                  'Nhập: Số nhà + Đường + Phường + Quận + Tỉnh',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),

              // Loading indicator
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(),
                ),

              // Preview Map với thông tin chi tiết
              if (_previewPosition != null && !_isLoading) ...[
                const SizedBox(height: 12),
                // Thông tin tọa độ
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    border: Border.all(color: Colors.green[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check_circle,
                              color: Colors.green[700], size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Đã xác định vị trí chính xác',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tọa độ: ${_previewPosition!.latitude.toStringAsFixed(6)}, ${_previewPosition!.longitude.toStringAsFixed(6)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                      if (_geocodedAddressDisplay != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Địa chỉ: $_geocodedAddressDisplay',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[700]),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Bản đồ preview
                SizedBox(
                  height: 250,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: _previewPosition!,
                        zoom: 17,
                      ),
                      onMapCreated: (controller) =>
                          _previewMapController = controller,
                      markers: _previewMarkers,
                      zoomControlsEnabled: true,
                      myLocationButtonEnabled: false,
                      mapToolbarEnabled: false,
                      compassEnabled: true,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.grey[800],
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
    required bool isRequired,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: isRequired ? '$labelText *' : labelText,
        hintText: hintText,
        prefixIcon: prefixIcon != null
            ? Icon(
                prefixIcon,
                color: Colors.grey[600],
              )
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
      textCapitalization: TextCapitalization.sentences,
    );
  }
}

// ====================== MAP PICKER NÂNG CAO ======================
class AdvancedMapPicker extends StatefulWidget {
  final LatLng? initialPosition;
  final String? initialAddress;

  const AdvancedMapPicker({
    super.key,
    this.initialPosition,
    this.initialAddress,
  });

  @override
  State<AdvancedMapPicker> createState() => _AdvancedMapPickerState();
}

class _AdvancedMapPickerState extends State<AdvancedMapPicker> {
  GoogleMapController? _mapController;
  LatLng _selectedLocation = const LatLng(10.045631, 105.746865); // Cần Thơ
  String _selectedAddress = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialPosition != null) {
      _selectedLocation = widget.initialPosition!;
      _selectedAddress = widget.initialAddress ?? '';
    }
  }

  Future<void> _reverseGeocode(LatLng latLng) async {
    setState(() => _isLoading = true);
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?format=json'
        '&lat=${latLng.latitude}'
        '&lon=${latLng.longitude}'
        '&zoom=18'
        '&addressdetails=1'
        '&accept-language=vi',
      );

      final response = await http.get(
        uri,
        headers: {'User-Agent': 'RentalHouseApp/1.0'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['display_name'] != null) {
          setState(() {
            _selectedAddress = data['display_name'];
            _isLoading = false;
          });
          return;
        }
      }

      setState(() {
        _selectedAddress =
            'Lat: ${latLng.latitude.toStringAsFixed(6)}, Lon: ${latLng.longitude.toStringAsFixed(6)}';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _selectedAddress = 'Không thể lấy địa chỉ';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chọn vị trí trên bản đồ'),
        actions: [
          TextButton.icon(
            onPressed: _isLoading
                ? null
                : () {
                    Navigator.pop(context, {
                      'address': _selectedAddress,
                      'latitude': _selectedLocation.latitude,
                      'longitude': _selectedLocation.longitude,
                    });
                  },
            icon: const Icon(Icons.check, color: Colors.white),
            label:
                const Text('Xác nhận', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _selectedLocation,
              zoom: 16,
            ),
            onMapCreated: (controller) => _mapController = controller,
            onTap: (latLng) {
              setState(() => _selectedLocation = latLng);
              _reverseGeocode(latLng);
            },
            markers: {
              Marker(
                markerId: const MarkerId('selected'),
                position: _selectedLocation,
                draggable: true,
                onDragEnd: (latLng) {
                  setState(() => _selectedLocation = latLng);
                  _reverseGeocode(latLng);
                },
              ),
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: true,
          ),

          // Thông tin địa chỉ
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.location_on,
                            color: Theme.of(context).primaryColor),
                        const SizedBox(width: 8),
                        const Text(
                          'Địa chỉ đã chọn',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_isLoading)
                      const LinearProgressIndicator()
                    else
                      Text(
                        _selectedAddress.isEmpty
                            ? 'Nhấn vào bản đồ để chọn'
                            : _selectedAddress,
                        style: const TextStyle(fontSize: 14),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      'Tọa độ: ${_selectedLocation.latitude.toStringAsFixed(6)}, ${_selectedLocation.longitude.toStringAsFixed(6)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
