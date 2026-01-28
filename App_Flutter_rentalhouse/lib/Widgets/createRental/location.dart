import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/Widgets/Profile/enter_new_address.dart';
import 'package:flutter_rentalhouse/Widgets/createRental/CoordinateConverter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;


// ====================== LOCATION FORM CẢI TIẾN V2 ======================
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
  String? _geocodedAddressDisplay;
  String? _lastGeocodedInput;

  // 🔥 NEW: Lưu thông tin địa chỉ chi tiết
  Map<String, String>? _addressComponents;
  String? _geocodingStatus; // 'success', 'partial', 'failed'

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
    _debounce = Timer(const Duration(milliseconds: 1500), () {
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

  /// 🔥 CHUẨN HÓA ĐỊA CHỈ VIỆT NAM - CẢI TIẾN
  String _normalizeVietnameseAddress(String addr) {
    String normalized = addr.trim().replaceAll(RegExp(r'\s+'), ' ');

    // Danh sách viết tắt phổ biến ở Việt Nam
    final abbreviations = {
      r'\bP\.?\s': 'Phường ',
      r'\bQ\.?\s': 'Quận ',
      r'\bTP\.?\s': 'Thành phố ',
      r'\bH\.?\s': 'Huyện ',
      r'\bTX\.?\s': 'Thị xã ',
      r'\bSO\.?\s': 'Số ',
      r'\bĐ\.?\s': 'Đường ',
      r'\bTr\.?\s': 'Trạm ',
      r'\bKP\.?\s': 'Khu phố ',
    };

    abbreviations.forEach((pattern, replacement) {
      normalized = normalized.replaceAll(RegExp(pattern, caseSensitive: false), replacement);
    });

    // Xóa các ký tự đặc biệt không cần thiết
    normalized = normalized.replaceAll(RegExp(r'[<>\[\]{}|]'), '');

    // Đảm bảo kết thúc bằng "Việt Nam" nếu là địa chỉ Việt Nam
    if (!normalized.toLowerCase().contains('việt nam') &&
        !normalized.toLowerCase().contains('vietnam')) {
      normalized += ', Việt Nam';
    }

    return normalized;
  }

  /// 🔥 KIỂM TRA ĐỊA CHỈ HỢP LỆ - CẢI TIẾN
  bool _isValidVietnamAddress(String addr) {
    // Phải chứa ít nhất: Đường + Phường/Huyện + Quận/Tỉnh
    final parts = addr.toLowerCase().split(',').map((e) => e.trim()).toList();

    if (parts.length < 3) {
      return false; // Quá thiếu thông tin
    }

    // Kiểm tra xem có các từ khóa địa chỉ Việt Nam không
    final vietnamKeywords = [
      'phường', 'huyện', 'quận', 'tỉnh', 'thành phố', 'thị xã',
      'đường', 'khu phố', 'xã', 'hẻm'
    ];

    final fullAddr = addr.toLowerCase();
    final hasVietnamKeywords =
    vietnamKeywords.any((keyword) => fullAddr.contains(keyword));

    if (!hasVietnamKeywords) {
      return false; // Không có keywords địa chỉ Việt Nam
    }

    return true;
  }

  /// 🔥 EXTRACT ĐỊA CHỈ CHI TIẾT - CẢI TIẾN
  Map<String, String> _extractAddressComponents(String fullAddress, Map<String, dynamic> nominatimData) {
    try {
      final displayName = nominatimData['display_name'] as String? ?? '';
      final addressObj = nominatimData['address'] as Map<String, dynamic>? ?? {};

      return {
        'street': addressObj['road'] ?? addressObj['street'] ?? '',
        'ward': addressObj['suburb'] ?? addressObj['hamlet'] ?? '',
        'district': addressObj['city_district'] ?? addressObj['county'] ?? '',
        'city': addressObj['city'] ?? addressObj['town'] ?? '',
        'province': addressObj['state'] ?? '',
        'country': addressObj['country'] ?? 'Vietnam',
        'displayName': displayName,
        'osmType': nominatimData['osm_type'] ?? '',
        'osmId': nominatimData['osm_id']?.toString() ?? '',
      };
    } catch (e) {
      debugPrint('Error extracting address components: $e');
      return {};
    }
  }

  /// 🔥 GEOCODING CẢI TIẾN - Thử nhiều phương pháp
  Future<void> _geocodeAddress(String rawAddress) async {
    if (!_isValidVietnamAddress(rawAddress)) {
      _showError('❌ Địa chỉ không hợp lệ. Phải gồm: Đường + Phường/Huyện + Quận/Tỉnh');
      _clearPreview();
      return;
    }

    setState(() {
      _isLoading = true;
      _geocodedAddressDisplay = null;
      _geocodingStatus = 'pending';
    });

    try {
      final normalized = _normalizeVietnameseAddress(rawAddress);
      _lastGeocodedInput = rawAddress;

      // 🔥 Phương pháp 1: Nominatim với địa chỉ đầy đủ
      debugPrint('🔍 [GEO-1] Trying full address: $normalized');
      var result = await _tryGeocode(normalized);

      if (result == null) {
        // 🔥 Phương pháp 2: Nominatim với địa chỉ rút gọn
        final simplified = _createSimplifiedAddress(normalized);
        debugPrint('🔍 [GEO-2] Trying simplified: $simplified');
        result = await _tryGeocode(simplified);
      }

      if (result == null) {
        // 🔥 Phương pháp 3: Nominatim với chỉ Quận/Tỉnh
        final minimal = _createMinimalAddress(normalized);
        debugPrint('🔍 [GEO-3] Trying minimal: $minimal');
        result = await _tryGeocode(minimal);
      }

      if (result != null) {
        await _processGeocodeResult(result);
      } else {
        _showError('❌ Không tìm thấy địa chỉ này. Vui lòng kiểm tra lại.');
        _clearPreview();
      }
    } catch (e) {
      _showError('❌ Lỗi kết nối: $e');
      _clearPreview();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 🔥 Tạo địa chỉ rút gọn: Đường + Quận + Tỉnh
  String _createSimplifiedAddress(String normalized) {
    final parts = normalized
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (parts.length >= 3) {
      return '${parts[0]}, ${parts[parts.length - 2]}, ${parts[parts.length - 1]}';
    }
    return normalized;
  }

  /// 🔥 Tạo địa chỉ tối thiểu: Quận + Tỉnh
  String _createMinimalAddress(String normalized) {
    final parts = normalized
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (parts.length >= 2) {
      return '${parts[parts.length - 2]}, ${parts[parts.length - 1]}';
    }
    return normalized;
  }

  /// 🔥 Thử geocode với Nominatim OSM
  Future<Map<String, dynamic>?> _tryGeocode(String address) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
            '?format=json'
            '&q=${Uri.encodeComponent(address)}'
            '&limit=5'
            '&countrycodes=vn'
            '&addressdetails=1'
            '&accept-language=vi',
      );

      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'RentalHouseApp/1.0 (+https://rentalhouse.app)',
          'Accept-Language': 'vi-VN,vi;q=0.9',
        },
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        if (data.isNotEmpty) {
          // 🔥 Lựa chọn kết quả tốt nhất: ưu tiên là đường hoặc phường
          for (var item in data) {
            final osmType = item['osm_type'] as String? ?? '';
            final osmClass = item['class'] as String? ?? '';
            final type = item['type'] as String? ?? '';

            // Ưu tiên: place/quarter, place/village, highway, building
            if ((osmClass == 'place' &&
                (type == 'quarter' || type == 'village' || type == 'neighborhood')) ||
                osmClass == 'highway' ||
                osmClass == 'building') {
              return item as Map<String, dynamic>;
            }
          }

          // Nếu không tìm được ưu tiên, lấy kết quả đầu tiên
          return data.first as Map<String, dynamic>;
        }
      }
    } catch (e) {
      debugPrint('Geocode attempt failed: $e');
    }
    return null;
  }

  /// 🔥 Xử lý kết quả geocoding
  Future<void> _processGeocodeResult(Map<String, dynamic> result) async {
    try {
      final lat = double.parse(result['lat']);
      final lon = double.parse(result['lon']);
      final displayName = result['display_name'] as String? ?? '';

      // 🔥 KIỂM TRA: Có nằm trong Việt Nam không?
      if (!CoordinateConverter.isInVietnam(lat, lon)) {
        _showError('⚠️ Vị trí này không nằm ở Việt Nam. Vui lòng kiểm tra lại.');
        _clearPreview();
        return;
      }

      // 🔥 Extract chi tiết
      final addressComponents = _extractAddressComponents(displayName, result);

      setState(() {
        _previewPosition = LatLng(lat, lon);
        _geocodedAddressDisplay = displayName;
        _addressComponents = addressComponents;
        _geocodingStatus = 'success';
        _previewMarkers = {
          Marker(
            markerId: const MarkerId('preview'),
            position: _previewPosition!,
            infoWindow: InfoWindow(
              title: 'Vị trí xác định',
              snippet: _formatAddressSnippet(displayName),
            ),
          ),
        };
      });

      widget.latitudeNotifier.value = lat;
      widget.longitudeNotifier.value = lon;

      _previewMapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _previewPosition!, zoom: 17),
        ),
      );

      debugPrint('✅ Geocoded successfully');
      debugPrint('   Address: $displayName');
      debugPrint('   Lat: $lat, Lon: $lon');
      debugPrint('   Components: $addressComponents');
    } catch (e) {
      _showError('❌ Lỗi xử lý tọa độ: $e');
      _clearPreview();
    }
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
      _addressComponents = null;
      _geocodingStatus = null;
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

  Future<void> _pickAddressManually() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NewAddressPage()),
    );

    if (result != null && result is String && result.trim().isNotEmpty && mounted) {
      final selectedAddress = result.trim();
      widget.fullAddressController.text = selectedAddress;
      await Future.delayed(const Duration(milliseconds: 300));
      _geocodeAddress(selectedAddress);
    }
  }

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
        _geocodingStatus = 'manual';
        _previewMarkers = {
          Marker(
            markerId: const MarkerId('preview'),
            position: latLng,
            infoWindow: InfoWindow(title: '📍 Vị trí đã chọn'),
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
                '✅ Định dạng CHÍNH XÁC:',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
              ),
              SizedBox(height: 8),
              Text('• Lê Hồng Phong, Phường Thắng Lợi, Quận Ninh Kiều, Cần Thơ'),
              Text('• Trần Hưng Đạo, Phường An Phú, Quận Ninh Kiều, TP Cần Thơ'),
              Text('• Đường Hùng Vương, Xã Tân Hưng, Huyện Hồng Dân, Bạc Liêu'),
              SizedBox(height: 16),
              Text(
                '❌ Format KHÔNG HỢP LỆ (tránh):',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
              ),
              SizedBox(height: 8),
              Text('• Gần chợ Ninh Kiều (quá mơ hồ)'),
              Text('• Đường 3/2 (thiếu phường/quận)'),
              Text('• Cần Thơ (quá rộng)'),
              SizedBox(height: 16),
              Text(
                '💡 Mẹo quan trọng:',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
              ),
              SizedBox(height: 8),
              Text('1️⃣ Nhất định phải có: Đường + Phường/Xã + Quận/Huyện + Tỉnh'),
              Text('2️⃣ Dùng nút "Chọn địa chỉ nhanh" để tránh lỗi'),
              Text('3️⃣ Hoặc dùng "Chọn trên bản đồ" để xác định chính xác'),
              Text('4️⃣ Nếu lỗi, thử xóa số nhà rồi thử lại'),
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

        // Địa chỉ đầy đủ
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
                      hintText: '123 Nguyễn Văn Cừ, Phường An Khánh, Quận Ninh Kiều, Cần Thơ',
                      prefixIcon: Icons.home_outlined,
                      isRequired: true,
                      maxLines: 3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    children: [
                      // Nút chọn địa chỉ
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.location_searching, color: Colors.blue, size: 28),
                          tooltip: 'Chọn địa chỉ nhanh',
                          onPressed: _pickAddressManually,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Nút hướng dẫn
                      IconButton(
                        icon: const Icon(Icons.help_outline, color: Colors.orange, size: 28),
                        tooltip: 'Hướng dẫn',
                        onPressed: _showAddressGuide,
                      ),
                    ],
                  ),
                ],
              ),

              Padding(
                padding: const EdgeInsets.only(top: 4, left: 12),
                child: Text(
                  'Mẫu địa chỉ như sau : Đường + Phường/Xã + Quận/Huyện + Tỉnh',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),

              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(),
                ),

              // 🔥 Preview Map & Address Details
              if (_previewPosition != null && !_isLoading) ...[
                const SizedBox(height: 12),

                // Status badge
                _buildStatusBadge(),

                // Chi tiết tọa độ
                _buildCoordinateInfo(),

                // Chi tiết địa chỉ từ Nominatim
                if (_addressComponents != null && _addressComponents!.isNotEmpty)
                  _buildAddressComponentsCard(),

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
                      onMapCreated: (controller) => _previewMapController = controller,
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

  Widget _buildStatusBadge() {
    final status = _geocodingStatus;
    final colors = {
      'success': (Colors.green, Icons.check_circle),
      'manual': (Colors.blue, Icons.edit_location),
      'partial': (Colors.orange, Icons.warning),
      'failed': (Colors.red, Icons.error),
    };

    final (bgColor, icon) = colors[status] ?? (Colors.grey, Icons.info);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.1),
        border: Border.all(color: bgColor.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: bgColor, size: 18),
          const SizedBox(width: 8),
          Text(
            status == 'success' ? 'Vị trí đã xác định' :
            status == 'manual' ? '📍 Vị trí chọn thủ công' :
            status == 'partial' ? '⚠️ Vị trí gần đúng' :
            '❌ Lỗi xác định vị trí',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: bgColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoordinateInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(top: 8),
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
              Icon(Icons.location_on, color: Colors.green[700], size: 18),
              const SizedBox(width: 8),
              const Text(
                'Tọa độ WGS84',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 12, color: Colors.black87),
              children: [
                const TextSpan(
                  text: 'Latitude: ',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(text: '${_previewPosition!.latitude.toStringAsFixed(6)}'),
                const TextSpan(text: '\n'),
                const TextSpan(
                  text: 'Longitude: ',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(text: '${_previewPosition!.longitude.toStringAsFixed(6)}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressComponentsCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        border: Border.all(color: Colors.blue[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue[700], size: 18),
              const SizedBox(width: 8),
              const Text(
                'Chi tiết địa chỉ',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildComponentRow('Đường:', _addressComponents!['street']),
          _buildComponentRow('Phường/Xã:', _addressComponents!['ward']),
          _buildComponentRow('Quận/Huyện:', _addressComponents!['district']),
          _buildComponentRow('Tỉnh/TP:', _addressComponents!['city']),
        ],
      ),
    );
  }

  Widget _buildComponentRow(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
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
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: Colors.grey[600]) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
          borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
          borderSide: BorderSide(color: Colors.grey[400]!, width: 1.0),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
        headers: {
          'User-Agent': 'RentalHouseApp/1.0 (+https://rentalhouse.app)',
          'Accept-Language': 'vi-VN,vi;q=0.9',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
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
            label: const Text('Xác nhận', style: TextStyle(color: Colors.white)),
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
                        Icon(Icons.location_on, color: Theme.of(context).primaryColor),
                        const SizedBox(width: 8),
                        const Text('Địa chỉ đã chọn',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_isLoading)
                      const LinearProgressIndicator()
                    else
                      Text(
                        _selectedAddress.isEmpty ? 'Nhấn vào bản đồ để chọn' : _selectedAddress,
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