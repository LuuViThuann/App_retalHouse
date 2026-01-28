import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AddressSearchResult {
  final String displayName;
  final double latitude;
  final double longitude;
  final String? addressType;
  final Map<String, String>? addressParts;

  AddressSearchResult({
    required this.displayName,
    required this.latitude,
    required this.longitude,
    this.addressType,
    this.addressParts,
  });

  factory AddressSearchResult.fromNominatim(Map<String, dynamic> json) {
    final address = json['address'] as Map<String, dynamic>? ?? {};

    return AddressSearchResult(
      displayName: json['display_name'] ?? 'Unknown',
      latitude: double.parse(json['lat'].toString()),
      longitude: double.parse(json['lon'].toString()),
      addressType: json['type'],
      addressParts: {
        'road': address['road'] ?? '',
        'village': address['village'] ?? '',
        'city': address['city'] ?? '',
        'district': address['district'] ?? address['county'] ?? '',
        'province': address['state'] ?? address['province'] ?? '',
        'postcode': address['postcode'] ?? '',
        'country': address['country'] ?? 'Vietnam',
      },
    );
  }

  String getFormattedAddress() {
    final parts = <String>[];
    if ((addressParts?['road'] ?? '').isNotEmpty) {
      parts.add(addressParts!['road']!);
    }
    if ((addressParts?['village'] ?? '').isNotEmpty) {
      parts.add(addressParts!['village']!);
    }
    if ((addressParts?['city'] ?? '').isNotEmpty) {
      parts.add(addressParts!['city']!);
    }
    if ((addressParts?['district'] ?? '').isNotEmpty) {
      parts.add(addressParts!['district']!);
    }
    if ((addressParts?['province'] ?? '').isNotEmpty) {
      parts.add(addressParts!['province']!);
    }

    return parts.join(', ');
  }
}

class AddressSearchWidget extends StatefulWidget {
  final Function(AddressSearchResult) onAddressSelected;
  final GoogleMapController? mapController;
  final VoidCallback? onClose;
  final VoidCallback? onSearchStart;
  final VoidCallback? onSearchEnd;
  final LatLng? currentLocation;


  const AddressSearchWidget({
    Key? key,
    required this.onAddressSelected,
    this.mapController,
    this.onClose,
    this.onSearchStart,
    this.onSearchEnd,
    this.currentLocation,
  }) : super(key: key);

  @override
  State<AddressSearchWidget> createState() => _AddressSearchWidgetState();
}

class _AddressSearchWidgetState extends State<AddressSearchWidget> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<AddressSearchResult> _searchResults = [];
  bool _isSearching = false;
  bool _showResults = false;
  bool _isInputFocused = false;

  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus && _searchResults.isEmpty) {
      setState(() {
        _showResults = false;
        _isInputFocused = false;
      });
      widget.onSearchEnd?.call();
    }
  }

  void _searchAddress(String query) {
    _debounceTimer?.cancel();

    if (query.isNotEmpty && !_isInputFocused) {
      setState(() => _isInputFocused = true);
      widget.onSearchStart?.call();
    } else if (query.isEmpty && _isInputFocused) {
      setState(() => _isInputFocused = false);
      widget.onSearchEnd?.call();
    }

    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _showResults = false;
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        debugPrint('🔍 [ADDRESS-SEARCH] Searching: $query');

        List<AddressSearchResult> allResults = [];

        //  STRATEGY 1: Search POI/Amenities (ưu tiên cho tên cơ sở)
        final poiResults = await _searchPOI(query);
        if (poiResults.isNotEmpty) {
          allResults.addAll(poiResults);
          debugPrint('✅ Found ${poiResults.length} POI results');
        }

        //  STRATEGY 2: Search địa chỉ thông thường
        final addressResults = await _searchAddressNormal(query);
        if (addressResults.isNotEmpty) {
          allResults.addAll(addressResults);
          debugPrint('✅ Found ${addressResults.length} address results');
        }

        //  Loại bỏ trùng lặp dựa trên tọa độ gần nhau
        final uniqueResults = _removeDuplicates(allResults);

        //  Sắp xếp theo khoảng cách nếu có vị trí hiện tại
        if (widget.currentLocation != null && uniqueResults.isNotEmpty) {
          uniqueResults.sort((a, b) {
            final aDist = _calculateDistance(
              widget.currentLocation!.latitude,
              widget.currentLocation!.longitude,
              a.latitude,
              a.longitude,
            );
            final bDist = _calculateDistance(
              widget.currentLocation!.latitude,
              widget.currentLocation!.longitude,
              b.latitude,
              b.longitude,
            );
            return aDist.compareTo(bDist);
          });
        }

        debugPrint('✅ [ADDRESS-SEARCH] Total unique results: ${uniqueResults.length}');

        if (mounted) {
          setState(() {
            _searchResults = uniqueResults;
            _showResults = uniqueResults.isNotEmpty;
            _isSearching = false;
          });
        }

        //  Nếu không có kết quả, thử search mở rộng
        if (uniqueResults.isEmpty && query.length >= 2) {
          debugPrint('🔄 [ADDRESS-SEARCH] No results, trying broader search...');
          await _searchBroader(query);
        }

      } catch (e) {
        debugPrint('❌ [ADDRESS-SEARCH] Exception: $e');
        if (mounted) {
          setState(() {
            _searchResults = [];
            _showResults = false;
            _isSearching = false;
          });
        }
      }
    });
  }
// 🔥 HÀM MỚI: Tìm POI/Amenities (trường học, bệnh viện, quán ăn, etc)
  Future<List<AddressSearchResult>> _searchPOI(String query) async {
    try {
      // Build URL với search cho POI
      String url = 'https://nominatim.openstreetmap.org/search'
          '?q=${Uri.encodeComponent(query)}'
          '&format=json'
          '&addressdetails=1'
          '&countrycodes=vn'
          '&limit=15' // Tăng limit cho POI
          '&accept-language=vi'
          '&extratags=1'; // Lấy thêm tags để biết loại POI

      //  Thêm viewbox nếu có vị trí hiện tại
      if (widget.currentLocation != null) {
        final lat = widget.currentLocation!.latitude;
        final lon = widget.currentLocation!.longitude;

        // Viewbox 30km xung quanh vị trí hiện tại
        final latOffset = 0.27; // ~30km
        final lonOffset = 0.27;

        url += '&viewbox=${lon - lonOffset},${lat + latOffset},${lon + lonOffset},${lat - latOffset}';
        url += '&bounded=1'; //  Bắt buộc trong viewbox cho POI search
      }

      debugPrint('🔍 [POI-SEARCH] URL: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'RentalHouseApp/1.0'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;

        // Lọc chỉ lấy POI thực sự (có amenity, building, shop, tourism, etc)
        final poiData = data.where((json) {
          final type = json['type']?.toString().toLowerCase() ?? '';
          final osmClass = json['class']?.toString().toLowerCase() ?? '';

          // Các class/type quan trọng cho POI
          final isPOI = [
            'amenity', 'building', 'shop', 'tourism', 'leisure',
            'office', 'healthcare', 'education', 'sport'
          ].contains(osmClass) || [
            'hospital', 'clinic', 'school', 'university', 'college',
            'restaurant', 'cafe', 'bank', 'atm', 'pharmacy',
            'supermarket', 'mall', 'hotel', 'museum', 'park'
          ].contains(type);

          final lat = double.tryParse(json['lat']?.toString() ?? '');
          final lon = double.tryParse(json['lon']?.toString() ?? '');

          return isPOI &&
              lat != null && lon != null &&
              lat >= 8.0 && lat <= 23.5 &&
              lon >= 102.0 && lon <= 109.5;
        }).toList();

        return poiData
            .map((json) => AddressSearchResult.fromNominatim(json as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('❌ [POI-SEARCH] Error: $e');
    }
    return [];
  }

// Tìm địa chỉ thông thường
  Future<List<AddressSearchResult>> _searchAddressNormal(String query) async {
    try {
      String url = 'https://nominatim.openstreetmap.org/search'
          '?q=${Uri.encodeComponent(query)}'
          '&format=json'
          '&addressdetails=1'
          '&countrycodes=vn'
          '&limit=10'
          '&accept-language=vi';

      //  Viewbox cho địa chỉ (rộng hơn POI)
      if (widget.currentLocation != null) {
        final lat = widget.currentLocation!.latitude;
        final lon = widget.currentLocation!.longitude;

        final latOffset = 0.5; // ~55km
        final lonOffset = 0.5;

        url += '&viewbox=${lon - lonOffset},${lat + latOffset},${lon + lonOffset},${lat - latOffset}';
        url += '&bounded=0'; // Không bắt buộc, chỉ ưu tiên
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'RentalHouseApp/1.0'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;

        final validResults = data.where((json) {
          final lat = double.tryParse(json['lat']?.toString() ?? '');
          final lon = double.tryParse(json['lon']?.toString() ?? '');
          return lat != null && lon != null &&
              lat >= 8.0 && lat <= 23.5 &&
              lon >= 102.0 && lon <= 109.5;
        }).toList();

        return validResults
            .map((json) => AddressSearchResult.fromNominatim(json as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('❌ [ADDRESS-NORMAL] Error: $e');
    }
    return [];
  }

// 🔥 HÀM MỚI: Loại bỏ kết quả trùng lặp (cùng tọa độ hoặc rất gần nhau)
  List<AddressSearchResult> _removeDuplicates(List<AddressSearchResult> results) {
    if (results.isEmpty) return [];

    final unique = <AddressSearchResult>[];

    for (final result in results) {
      bool isDuplicate = false;

      for (final existing in unique) {
        final distance = _calculateDistance(
          result.latitude,
          result.longitude,
          existing.latitude,
          existing.longitude,
        );

        // Nếu cách nhau < 50m, coi như trùng
        if (distance < 0.05) {
          isDuplicate = true;
          break;
        }
      }

      if (!isDuplicate) {
        unique.add(result);
      }
    }

    debugPrint('🔍 Removed ${results.length - unique.length} duplicates');
    return unique;
  }
  //  Hàm tính khoảng cách
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371; // Bán kính Trái Đất (km)
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }
  double _toRadians(double degree) {
    return degree * math.pi / 180;
  }

  //  Hàm search mở rộng khi không tìm thấy kết quả
  Future<void> _searchBroader(String query) async {
    try {
      // Thử search với các từ khóa bổ sung
      final broadQueries = [
        '$query, Việt Nam',
        '$query, Vietnam',
      ];

      // Nếu có vị trí hiện tại, thêm tên tỉnh/thành
      if (widget.currentLocation != null) {
        // Lấy tên tỉnh/thành từ vị trí hiện tại (có thể gọi reverse geocoding)
        // Hoặc đơn giản thêm "Cần Thơ" nếu lat/lon trong khu vực Cần Thơ
        final lat = widget.currentLocation!.latitude;
        final lon = widget.currentLocation!.longitude;

        if (lat >= 9.8 && lat <= 10.5 && lon >= 105.3 && lon <= 105.9) {
          broadQueries.insert(0, '$query, Cần Thơ');
        }
      }

      for (final broadQuery in broadQueries) {
        final url = 'https://nominatim.openstreetmap.org/search'
            '?q=${Uri.encodeComponent(broadQuery)}'
            '&format=json'
            '&addressdetails=1'
            '&countrycodes=vn'
            '&limit=5'
            '&accept-language=vi';

        final response = await http.get(
          Uri.parse(url),
          headers: {'User-Agent': 'RentalHouseApp/1.0'},
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as List<dynamic>;
          if (data.isNotEmpty) {
            final results = data
                .map((json) => AddressSearchResult.fromNominatim(json as Map<String, dynamic>))
                .toList();

            debugPrint('✅ [BROADER-SEARCH] Found ${results.length} results with: $broadQuery');

            if (mounted) {
              setState(() {
                _searchResults = results;
                _showResults = true;
                _isSearching = false;
              });
            }
            return; // Dừng nếu đã tìm thấy
          }
        }
      }

      // Nếu vẫn không tìm thấy
      if (mounted) {
        setState(() {
          _searchResults = [];
          _showResults = false;
          _isSearching = false;
        });
      }
    } catch (e) {
      debugPrint('❌ [BROADER-SEARCH] Error: $e');
      if (mounted) {
        setState(() {
          _searchResults = [];
          _showResults = false;
          _isSearching = false;
        });
      }
    }
  }
  void _selectResult(AddressSearchResult result) {
    debugPrint('📍 [ADDRESS-SELECT] Selected: ${result.displayName}');

    widget.onAddressSelected(result);

    if (widget.mapController != null) {
      widget.mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(result.latitude, result.longitude),
          16.0,
        ),
      );
    }

    _searchController.clear();
    _focusNode.unfocus();
    setState(() {
      _searchResults = [];
      _showResults = false;
      _isInputFocused = false;
    });
    widget.onSearchEnd?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Search Input
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    Icons.location_on,
                    color: Colors.blue[600],
                    size: 24,
                  ),
                ),

                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _focusNode,
                    decoration: InputDecoration(
                      hintText: 'Tìm kiếm địa chỉ...',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      suffixIcon: _searchController.text.isNotEmpty || widget.onClose != null
                          ? InkWell(
                        onTap: () {
                          if (_searchController.text.isNotEmpty) {
                            _searchController.clear();
                            setState(() {
                              _searchResults = [];
                              _showResults = false;
                              _isInputFocused = false;
                            });
                            widget.onSearchEnd?.call();
                          } else if (widget.onClose != null) {
                            widget.onClose!();
                          }
                        },
                        child: Icon(
                          Icons.close,
                          color: Colors.grey[500],
                          size: 20,
                        ),
                      )
                          : null,
                    ),
                    style: const TextStyle(fontSize: 16),
                    onChanged: (value) {
                      setState(() {});
                      _searchAddress(value);
                    },
                    onSubmitted: (value) {
                      if (_searchResults.isNotEmpty) {
                        _selectResult(_searchResults.first);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),

          // Search Results Dropdown
          if (_showResults || _isSearching)
            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.4,
              ),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: _isSearching
                  ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.blue[600]!,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Đang tìm kiếm...',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              )
                  : _searchResults.isEmpty
                  ? Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.search_off,
                      color: Colors.grey[400],
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Không tìm thấy địa chỉ nào',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              )
                  : ListView.separated(
                shrinkWrap: true,
                itemCount: _searchResults.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: Colors.grey[200]),
                itemBuilder: (context, index) {
                  final result = _searchResults[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    leading: Icon(
                      Icons.location_on_outlined,
                      color: Colors.blue[400],
                      size: 20,
                    ),
                    title: Text(
                      result.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Lat: ${result.latitude.toStringAsFixed(4)}, '
                            'Lon: ${result.longitude.toStringAsFixed(4)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                    onTap: () => _selectResult(result),
                    hoverColor: Colors.blue[50],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}