import 'dart:async';
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

  const AddressSearchWidget({
    Key? key,
    required this.onAddressSelected,
    this.mapController,
    this.onClose,
    this.onSearchStart,
    this.onSearchEnd,
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

    // 🔥 Trigger callback khi user bắt đầu input
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

        final String url =
            'https://nominatim.openstreetmap.org/search'
            '?q=${Uri.encodeComponent(query)}'
            '&format=json'
            '&addressdetails=1'
            '&countrycodes=vn'
            '&limit=8'
            '&accept-language=vi';

        final response = await http.get(
          Uri.parse(url),
          headers: {
            'User-Agent': 'RentalHouseApp/1.0',
          },
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw TimeoutException('Quá thời gian chờ'),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as List<dynamic>;
          final results = data
              .map((json) => AddressSearchResult.fromNominatim(json as Map<String, dynamic>))
              .toList();

          debugPrint('✅ [ADDRESS-SEARCH] Found ${results.length} results');

          if (mounted) {
            setState(() {
              _searchResults = results;
              _showResults = results.isNotEmpty;
              _isSearching = false;
            });
          }
        } else {
          debugPrint('❌ [ADDRESS-SEARCH] Error: ${response.statusCode}');
          if (mounted) {
            setState(() {
              _searchResults = [];
              _showResults = false;
              _isSearching = false;
            });
          }
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