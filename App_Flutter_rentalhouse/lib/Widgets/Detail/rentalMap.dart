import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/Widgets/Detail/AIExplanationDialog.dart';
import 'package:flutter_rentalhouse/Widgets/Detail/AddressSearchResult.dart';
import 'package:flutter_rentalhouse/Widgets/Detail/ClusterItem.dart';
import 'package:flutter_rentalhouse/Widgets/Detail/FilterDialogWidget.dart';
import 'package:flutter_rentalhouse/Widgets/Detail/HorizontalRentalList.dart';
import 'package:flutter_rentalhouse/Widgets/Detail/LoadingPoi.dart';
import 'package:flutter_rentalhouse/Widgets/Detail/NearbyRentals.dart';
import 'package:flutter_rentalhouse/Widgets/Detail/analytics_screen.dart';
import 'package:flutter_rentalhouse/Widgets/Detail/customMarker.dart';
import 'package:flutter_rentalhouse/Widgets/Detail/poi_category_selector.dart';
import 'package:flutter_rentalhouse/config/api_routes.dart';
import 'package:flutter_rentalhouse/utils/Snackbar_process.dart';
import 'package:flutter_rentalhouse/views/rental_detail_view.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' hide Cluster;
import 'package:geocoding/geocoding.dart';
import 'package:location/location.dart' as loc;
import 'package:intl/intl.dart';
import 'package:flutter_rentalhouse/models/rental.dart';
import 'package:lottie/lottie.dart' hide Marker;
import 'package:provider/provider.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_rental.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/loading.dart';
import '../../models/poi.dart';
import '../../services/auth_service.dart';
import '../../services/poi_service.dart';

class RentalMapView extends StatefulWidget {
  final Rental rental;

  const RentalMapView({super.key, required this.rental});

  @override
  State<RentalMapView> createState() => _RentalMapViewState();
}

class _RentalMapViewState extends State<RentalMapView>
    with TickerProviderStateMixin, WidgetsBindingObserver {

  // ============================================
  // BIẾN TRẠNG THÁI MỚI
  // ============================================
  GoogleMapController? _controller;
  LatLng? _rentalLatLng;
  LatLng? _currentLatLng;
  Set<Marker> _markers = {};
  String? _errorMessage;
  bool _isMapLoading = true;
  Rental? _selectedRental;
  bool _showCustomInfo = false;

  List<Rental> _originalNearbyRentals = []; // Lưu danh sách ban đầu
  List<Rental> _filteredNearbyRentals = []; // Danh sách sau khi lọc
  bool _isFilterApplied = false; // Kiểm tra bộ lọc đã được áp dụng

  bool _isAIRecommendation = false;
  bool _isAIMode = false;

  bool _isPOIFilterActive = false;
  double _poiFilterRadius = 3.0;
  POIFilterResult? _currentFilterResult;
  POIService? _poiService;

  //===========================================
  // BIẾN CHO CLUSTER
  double _currentZoom = 16.0;
  List<Cluster> _currentClusters = [];
  bool _useCluster = true;

  // NEW: AI Context Tracking
  List<String> _shownRentalIds = [];  // Track impressions để tránh duplicate
  int _impressionCount = 0;
  String? _currentUserId;
  bool _isLoadingAIExplanation = false;

  // 🔥 NEW: Address Search Variables
  bool _showAddressSearch = false;
  AddressSearchResult? _selectedAddress;

  // 🔥 NEW: Tracking keyboard visibility
  double _keyboardHeight = 0;


// Hoặc tốt hơn là:
  AnimationController? _controlsAnimationController;
  Animation<Offset>? _controlsSlideAnimation;
  Animation<double>? _controlsOpacityAnimation;

  AnimationController? _badgeAnimationController;
  Animation<double>? _badgeOpacityAnimation;
  Animation<Offset>? _badgeSlideAnimation;

  bool _showControls = true;

 // THÊM HÀM INITIALIZE BADGE ANIMATION
  void _initializeBadgeAnimationIfNeeded() {
    if (_badgeAnimationController != null) return; // Đã init rồi

    _badgeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _badgeOpacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(
      CurvedAnimation(parent: _badgeAnimationController!, curve: Curves.easeInOut),
    );

    _badgeSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0),
      end: const Offset(-0.3, 0),
    ).animate(
      CurvedAnimation(parent: _badgeAnimationController!, curve: Curves.easeInOut),
    );

    debugPrint('🎬 Badge animations initialized');
  }

  // 🔥 PHẦN 3: THÊM HÀM TOGGLE BADGE VISIBILITY
  Future<void> _toggleBadgeVisibility(bool show) async {
    _initializeBadgeAnimationIfNeeded(); // ✅ Đảm bảo animations đã init

    if (show) {
      await _badgeAnimationController!.reverse();
    } else {
      await _badgeAnimationController!.forward();
    }
  }

  void _initializeAnimationsIfNeeded() {
    if (_controlsAnimationController != null) return; // Đã init rồi

    _controlsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _controlsSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0),
      end: const Offset(-0.5, 0),
    ).animate(
      CurvedAnimation(parent: _controlsAnimationController!, curve: Curves.easeInOut),
    );

    _controlsOpacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(
      CurvedAnimation(parent: _controlsAnimationController!, curve: Curves.easeInOut),
    );
  }
  // ============================================
  // HÀM KHỞI TẠO VÀ CẬP NHẬT
  // ============================================
  @override
  void initState() {
    super.initState();
    _poiService = POIService();
    _isPOIFilterActive = false;
    _currentFilterResult = null;
    //Lấy user ID từ AuthService
    _getCurrentUser();


    _initializeAnimationsIfNeeded();
    _initializeBadgeAnimationIfNeeded();

    WidgetsBinding.instance.addObserver(this);
    _initializeMap();

  }
  // 🔥 HÀM: Lắng nghe keyboard
  void _listenToKeyboard() {
    // Lấy keyboard height từ MediaQuery
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentKeyboardHeight =
          MediaQuery.of(context).viewInsets.bottom;
      if (_keyboardHeight != currentKeyboardHeight) {
        setState(() {
          _keyboardHeight = currentKeyboardHeight;
        });
      }
    });
  }
  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    _listenToKeyboard();
  }

  Future<void> _toggleControlsVisibility(bool show) async {
    if (show == _showControls) return;

    _initializeAnimationsIfNeeded(); // ✅ Đảm bảo animations đã init

    setState(() {
      _showControls = show;
    });

    if (show) {
      await _controlsAnimationController!.reverse();
    } else {
      await _controlsAnimationController!.forward();
    }
  }
  //  NEW: Helper method để lấy current user
  Future<void> _getCurrentUser() async {
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser != null) {
        setState(() {
          _currentUserId = firebaseUser.uid;
        });
        debugPrint('✅ Got user ID: $_currentUserId');
      } else {
        debugPrint('⚠️ No authenticated user');
      }
    } catch (e) {
      debugPrint('⚠️ Error getting user: $e');
    }
  }
// ============================================
// HÀM: Áp dụng bộ lọc POI - CẬP NHẬT
// ============================================
// ✅ CẬP NHẬT hàm _applyPOIFilter trong RentalMapView
// File: Widgets/Detail/RentalMapView.dart

  Future<void> _applyPOIFilter(List<String> selectedCategories) async {
    try {
      if (selectedCategories.isEmpty) {
        _showSnackbar(
          message: '⚠️ Vui lòng chọn ít nhất một tiện ích',
          backgroundColor: Colors.orange,
        );
        return;
      }

      // Show loading dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Center(
            child: SafeArea(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: Lottie.asset(
                          AssetsConfig.loadingLottie,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _isAIMode
                            ? 'Trợ lý AI đang tìm bài gần với tiện ích của bạn...'
                            : 'Đang tìm bài gần tiện ích',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${selectedCategories.length} tiện ích - ${_poiFilterRadius.toStringAsFixed(1)} km',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }

      final userLat = _currentLatLng?.latitude ?? _rentalLatLng!.latitude;
      final userLon = _currentLatLng?.longitude ?? _rentalLatLng!.longitude;

      debugPrint('[POI-FILTER] Request: lat=$userLat, lon=$userLon, categories=${selectedCategories.join(", ")}, AI: $_isAIMode');

      final int poisTotal;
      final List<Rental> rentals;
      final String message;

      if (_isAIMode) {
        // 🔥 SỬ DỤNG ENDPOINT MỚI: AI + POI COMBINED
        debugPrint('🤖🏢 [POI-FILTER] Using NEW AI+POI endpoint');

        final rentalViewModel = Provider.of<RentalViewModel>(context, listen: false);

        await rentalViewModel.fetchAIPersonalizedWithPOI(
          latitude: userLat,
          longitude: userLon,
          selectedCategories: selectedCategories,
          radius: 20.0, // Default radius từ API
          poiRadius: _poiFilterRadius,
          minPrice: rentalViewModel.currentMinPrice,
          maxPrice: rentalViewModel.currentMaxPrice,
        );

        rentals = rentalViewModel.nearbyRentals;
        message = rentalViewModel.aiRecommendationMessage ?? 'Gợi ý AI + POI';
        poisTotal = rentalViewModel.lastPoisTotal;

        debugPrint('🤖🏢 [POI-FILTER] AI+POI Result: ${rentals.length} rentals, $poisTotal POIs');
      } else {
        // ✅ GỌI API POI FILTER THUẦN (không AI)
        debugPrint('📍 [POI-FILTER] Using POI-only filter');

        final POIFilterResult poiResult = await _poiService!.filterRentalsByPOI(
          latitude: userLat,
          longitude: userLon,
          selectedCategories: selectedCategories,
          radius: _poiFilterRadius + 2,
          minPrice: Provider.of<RentalViewModel>(context, listen: false).currentMinPrice,
          maxPrice: Provider.of<RentalViewModel>(context, listen: false).currentMaxPrice,
        );

        rentals = poiResult.rentals.whereType<Rental>().toList();
        poisTotal = poiResult.poisTotal;
        message = poiResult.message;

        debugPrint('📍 [POI-FILTER] POI Result: ${rentals.length} rentals, $poisTotal POIs');
      }

      // Close loading dialog
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (!mounted) return;

      // ✅ Check POIs
      if (poisTotal == 0 && !_isAIMode) {
        _showSnackbar(
          message: 'Không tìm thấy tiện ích trong ${_poiFilterRadius.toStringAsFixed(1)}km\n'
              '💡 Hãy tăng khoảng cách tìm kiếm',
          backgroundColor: Colors.orange[700],
        );
        return;
      }

      // ✅ Check rentals
      if (rentals.isEmpty) {
        _showSnackbar(
          message: _isAIMode
              ? 'Không tìm thấy bài gần tiện ích này. Hãy thử chọn tiện ích khác.'
              : 'Không tìm thấy bài gần tiện ích này',
          backgroundColor: Colors.orange[700],
        );
        return;
      }

      // ✅ Update state
      setState(() {
        _isPOIFilterActive = true;
        _isFilterApplied = false;
        _currentFilterResult = POIFilterResult(
          rentals: rentals,
          pois: [],
          total: rentals.length,
          poisTotal: poisTotal,
          selectedCategories: selectedCategories,
          radius: _poiFilterRadius,
          message: message,
          success: true,
        );
        _originalNearbyRentals = rentals;
        _filteredNearbyRentals = rentals;
      });

      debugPrint('✅ [POI-FILTER] State updated: ${rentals.length} rentals');

      await _updateMarkersWithClustering();

      if (mounted) {
        _showSnackbar(
          message: _isAIMode
              ? 'Tìm thấy ${rentals.length} được AI gợi ý gần tiện ích...'
              : 'Tìm thấy ${rentals.length} bài gần $poisTotal tiện ích...',
          backgroundColor: Colors.green[700],
        );
      }
    } catch (e) {
      debugPrint('❌ [POI-FILTER] Error: $e');
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      if (mounted) {
        _showSnackbar(
          message: '❌ Lỗi: $e',
          backgroundColor: Colors.red,
        );
      }
    }
  }


  void _clearPOIFilter() {
    final wasAIMode = _isAIMode;

    setState(() {
      _isPOIFilterActive = false;
      _isFilterApplied = false;
      _currentFilterResult = null;
      _filteredNearbyRentals = List.from(_originalNearbyRentals);
    });

    // ✅ GIỮ NGUYÊN AI MODE, CHỈ FETCH LẠI DATA
    if (wasAIMode) {
      debugPrint('🔄 Clearing POI filter, keeping AI mode ON');
      _fetchNearbyRentals(); // Sẽ tự động fetch AI recommendations
    } else {
      _updateMarkersWithClustering();
    }

    _showSnackbar(
      message: wasAIMode
          ? 'Đã xóa bộ lọc tiện ích - giữ chế độ AI'
          : 'Đã xóa bộ lọc tiện ích',
      backgroundColor: Colors.green[400],
    );
  }

  // ============================================
  // CẬP NHẬT KHI WIDGET THAY ĐỔI
  // ============================================
  @override
  void didUpdateWidget(RentalMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rental.id != widget.rental.id) {
      _initializeMap();
    }
  }

  // ============================================
  // HÀM HỖ TRỢ CHÍNH
  // ============================================
  Future<void> _initializeMap() async {
    await _getLocationFromAddress();
    await _getCurrentLocation();
    await _fetchNearbyRentals();
  }

  // ============================================
  // Lấy tọa độ từ địa chỉ
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
        _updateMarkersWithClustering(); // 🔥 ĐỔI TỪ _updateMarkers()
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
          _updateMarkersWithClustering(); // 🔥 ĐỔI TỪ _updateMarkers()
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

  // ============================================
  // Lấy vị trí hiện tại của người dùng

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
        _updateMarkersWithClustering(); // 🔥 ĐỔI TỪ _updateMarkers()
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


  // ============================================
  // Lấy danh sách bất động sản gần đây
  Future<void> _fetchNearbyRentals() async {
    try {
      final rentalViewModel =
      Provider.of<RentalViewModel>(context, listen: false);

      bool isCurrentLocationView =
      widget.rental.id.startsWith('current_location_');

      if (_isAIMode) {

        if (isCurrentLocationView && _currentLatLng != null) {
          await rentalViewModel.fetchAIRecommendations(
            latitude: _currentLatLng!.latitude,
            longitude: _currentLatLng!.longitude,
            radius: rentalViewModel.currentRadius,
            minPrice: rentalViewModel.currentMinPrice,
            maxPrice: rentalViewModel.currentMaxPrice,
          );
        } else {
          await rentalViewModel.fetchAINearbyRecommendations(
            rentalId: widget.rental.id,
            radius: rentalViewModel.currentRadius,
          );
        }
      } else {
        debugPrint('📍 Fetching regular nearby rentals');

        if (isCurrentLocationView && _currentLatLng != null) {
          await rentalViewModel.fetchNearbyRentals(
            widget.rental.id,
            latitude: _currentLatLng!.latitude,
            longitude: _currentLatLng!.longitude,
          );
        } else {
          await rentalViewModel.fetchNearbyRentals(widget.rental.id);
        }
      }

      //  Đảm bảo dữ liệu được update NGAY SAU KHI fetch
      // Thêm delay nhỏ để chắc chắn ViewModel đã update
      await Future.delayed(const Duration(milliseconds: 100));

      setState(() {
        _originalNearbyRentals = List.from(rentalViewModel.nearbyRentals);
        _filteredNearbyRentals = List.from(rentalViewModel.nearbyRentals);
        _isFilterApplied = false;

        debugPrint(' Updated local rentals: ${_originalNearbyRentals.length}');
      });

      _updateMarkersWithClustering();
    } catch (e) {
      setState(() {
        _errorMessage = 'Lỗi khi tải bất động sản gần đây: $e';
      });
    }
  }
// ============================================
// THÊM HÀM: Toggle AI Mode
// ============================================
  Future<void> _toggleAIMode() async {
    final wasAIMode = _isAIMode;
    final hadPOIFilter = _isPOIFilterActive;

    setState(() {
      _isAIMode = !_isAIMode;
    });

    debugPrint('🔄 Toggling AI mode: $_isAIMode, POI filter: $hadPOIFilter');

    // ✅ NẾU ĐANG CÓ POI FILTER, TÁI ÁP DỤNG VỚI MODE MỚI
    if (hadPOIFilter && _currentFilterResult != null) {
      debugPrint('🔄 Re-applying POI filter with new AI mode');

      final selectedCategories = _currentFilterResult!.selectedCategories;
      await _applyPOIFilter(selectedCategories);
    } else {
      // Fetch lại data theo mode mới (không có POI filter)
      await _fetchNearbyRentals();
    }

    // Show snackbar
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                _isAIMode ? Icons.psychology : Icons.location_on,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _isAIMode
                      ? (hadPOIFilter
                      ? ' Đã bật gợi ý AI + lọc tiện ích'
                      : ' Đã bật gợi ý AI')
                      : (hadPOIFilter
                      ? ' Đã tắt AI + giữ lọc tiện ích'
                      : ' Đã tắt gợi ý AI'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: _isAIMode ? Colors.blue[700] : Colors.green[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // ============================================
  // THÊM HÀM: Lọc dữ liệu theo khoảng giá
  void _applyPriceFilter(double minPrice, double maxPrice) {
    setState(() {
      _isFilterApplied = true;

      // Lọc từ danh sách ban đầu
      _filteredNearbyRentals = _originalNearbyRentals.where((rental) {
        final rentalPrice = _safeParseDouble(rental.price, 'rental.price') ?? 0.0;

        final passMinPrice = minPrice == 0 || rentalPrice >= minPrice;
        final passMaxPrice = maxPrice == 0 || rentalPrice <= maxPrice;

        return passMinPrice && passMaxPrice;
      }).toList();
    });

    // Cập nhật markers
    _updateMarkersWithClustering();

  }


  // ============================================
  // CẬP NHẬT MARKERS TRÊN BẢN ĐỒ

  Future<void> _updateMarkersWithClustering() async {
    final Set<Marker> markers = {};
    final rentalViewModel = Provider.of<RentalViewModel>(context, listen: false);

    bool isCurrentLocationView = widget.rental.id.startsWith('current_location_');

    // 1. MAIN RENTAL MARKER (không cluster)
    if (!isCurrentLocationView && _rentalLatLng != null && _validateRental(widget.rental)) {
      final customIcon = await CustomMarkerHelper.createCustomMarker(
        price: widget.rental.price,
        propertyType: 'Rental',
        isMainRental: true,
        hasValidCoords: widget.rental.location['latitude'] != 0.0 &&
            widget.rental.location['longitude'] != 0.0,
        isAIRecommended: false,
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

    // 2. CURRENT LOCATION MARKER (không cluster)
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

    // 3. NEARBY RENTALS - CÓ CLUSTERING
    final displayRentals = _isFilterApplied
        ? _filteredNearbyRentals
        : _originalNearbyRentals;

    if (displayRentals.isEmpty && rentalViewModel.nearbyRentals.isNotEmpty) {
      _originalNearbyRentals = List.from(rentalViewModel.nearbyRentals);
      _filteredNearbyRentals = List.from(rentalViewModel.nearbyRentals);
    }

    // Tạo cluster items
    final List<ClusterItem> clusterItems = [];

    for (final rental in displayRentals) {
      if (!isCurrentLocationView && rental.id == widget.rental.id) continue;
      if (!_validateRental(rental)) continue;

      final lat = _safeParseDouble(
          rental.location['latitude'],
          'rental.location.latitude'
      ) ?? 0.0;
      final lng = _safeParseDouble(
          rental.location['longitude'],
          'rental.location.longitude'
      ) ?? 0.0;

      if (lat == 0.0 && lng == 0.0) continue;

      clusterItems.add(ClusterItem(
        id: rental.id,
        position: LatLng(lat, lng),
        rental: rental,
      ));
    }

    // Tạo clusters dựa trên zoom level
    if (_useCluster && _currentZoom < 15) {
      _currentClusters = MarkerClusterHelper.createClusters(
        items: clusterItems,
        zoomLevel: _currentZoom,
      );

      debugPrint('🎯 [CLUSTERING] Created ${_currentClusters.length} clusters from ${clusterItems.length} items at zoom $_currentZoom');

      // Tạo markers cho clusters
      for (final cluster in _currentClusters) {
        if (cluster.size == 1) {
          // Single item - hiển thị như marker bình thường
          final item = cluster.items.first;
          final rental = item.rental;

          bool isAIRecommended = _isAIMode ||
              (rental.isAIRecommended == true) ||
              (rental.aiScore != null && rental.aiScore! > 0);

          final customIcon = await CustomMarkerHelper.createCustomMarker(
            price: rental.price,
            propertyType: 'Rental',
            isMainRental: false,
            hasValidCoords: true,
            isAIRecommended: isAIRecommended,
          );

          markers.add(
            Marker(
              markerId: MarkerId('nearby-${rental.id}'),
              position: item.position,
              infoWindow: InfoWindow(
                title: isAIRecommended
                    ? '🤖 AI: ${rental.title}'
                    : 'Gợi ý: ${rental.title}',
                snippet: '${_formatPriceCompact(rental.price)} - ${rental.location['short'] ?? ''}',
              ),
              icon: customIcon,
              onTap: () => _showRentalInfo(rental),
            ),
          );
        } else {
          // Multiple items - hiển thị cluster marker
          bool hasAI = cluster.items.any((item) {
            final rental = item.rental;
            return _isAIMode ||
                (rental.isAIRecommended == true) ||
                (rental.aiScore != null && rental.aiScore! > 0);
          });

          final clusterIcon = await MarkerClusterHelper.createClusterMarker(
            clusterSize: cluster.size,
            hasAI: hasAI,
          );

          markers.add(
            Marker(
              markerId: MarkerId(cluster.id),
              position: cluster.center,
              icon: clusterIcon,
              onTap: () => _onClusterTap(cluster),
            ),
          );
        }
      }
    } else {
      // Không clustering - hiển thị tất cả markers
      debugPrint('📍 [NO-CLUSTER] Displaying ${clusterItems.length} individual markers');

      for (final item in clusterItems) {
        final rental = item.rental;

        bool isAIRecommended = _isAIMode ||
            (rental.isAIRecommended == true) ||
            (rental.aiScore != null && rental.aiScore! > 0);

        final customIcon = await CustomMarkerHelper.createCustomMarker(
          price: rental.price,
          propertyType: 'Rental',
          isMainRental: false,
          hasValidCoords: true,
          isAIRecommended: isAIRecommended,
        );

        markers.add(
          Marker(
            markerId: MarkerId('nearby-${rental.id}'),
            position: item.position,
            infoWindow: InfoWindow(
              title: isAIRecommended
                  ? '🤖 AI: ${rental.title}'
                  : 'Gợi ý: ${rental.title}',
              snippet: '${_formatPriceCompact(rental.price)} - ${rental.location['short'] ?? ''}',
            ),
            icon: customIcon,
            onTap: () => _showRentalInfo(rental),
          ),
        );
      }
    }

    if (mounted) {
      setState(() {
        _markers = markers;
      });

      debugPrint('✅ [MARKERS] Updated: ${markers.length} markers displayed');
    }
  }

  void _onClusterTap(Cluster cluster) {
    if (cluster.size == 1) {
      // Chỉ có 1 item - hiển thị info
      _showRentalInfo(cluster.items.first.rental);
    } else {
      // Nhiều items - zoom vào cluster
      _zoomToCluster(cluster);
    }
  }
  void _zoomToCluster(Cluster cluster) {
    if (_controller == null) return;

    // Tính bounds của cluster
    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLng = double.infinity;
    double maxLng = -double.infinity;

    for (var item in cluster.items) {
      minLat = math.min(minLat, item.position.latitude);
      maxLat = math.max(maxLat, item.position.latitude);
      minLng = math.min(minLng, item.position.longitude);
      maxLng = math.max(maxLng, item.position.longitude);
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _controller!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 80),
    );

    debugPrint('🔍 [ZOOM] Zooming to cluster with ${cluster.size} items');
  }
  // ============================================
  // HÀM HỖ TRỢ KHÁC
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

  Timer? _cameraDebounce;

  void _onCameraMove(CameraPosition position) {
    _currentZoom = position.zoom;
    _cameraDebounce?.cancel();
    _cameraDebounce = Timer(const Duration(milliseconds: 800), () {
      _updateMarkersWithClustering();  // Gọi sau 500ms
    });
  }


  Timer? _aiRefreshDebounce;

  Future<void> _refetchAIWithContextDebounced() async {
    // 🔥 Hủy previous debounce timer
    _aiRefreshDebounce?.cancel();

    // 🔥 Chờ 500ms để chắc user hoàn thành zoom
    _aiRefreshDebounce = Timer(const Duration(milliseconds: 500), () async {
      if (!_isAIMode || _currentLatLng == null) return;

      final rentalViewModel = Provider.of<RentalViewModel>(context, listen: false);

      debugPrint('🔄 Re-fetching AI with new zoom level: $_currentZoom');

      try {
        await rentalViewModel.fetchAIRecommendationsWithContext(
          latitude: _currentLatLng!.latitude,
          longitude: _currentLatLng!.longitude,
          zoomLevel: _currentZoom.toInt(),
          timeOfDay: _getTimeOfDay(),
          impressions: _shownRentalIds,
          scrollDepth: 0.5,
          radius: rentalViewModel.currentRadius,
        );

        if (mounted) {
          setState(() {
            _originalNearbyRentals = List.from(rentalViewModel.nearbyRentals);
            _filteredNearbyRentals = List.from(rentalViewModel.nearbyRentals);
          });
          _updateMarkersWithClustering();
        }
      } catch (e) {
        debugPrint('❌ Error refetching AI: $e');
      }
    });
  }

  @override
  void dispose() {
    _cameraDebounce?.cancel();
    _aiRefreshDebounce?.cancel();  // 🔥 Hủy debounce timer khi dispose
    _controlsAnimationController?.dispose();

    _badgeAnimationController?.dispose(); // ✅ THÊM DÒNG NÀY
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

// 🔥 NEW: Helper method để xác định time of day
  String _getTimeOfDay() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'morning';
    if (hour >= 12 && hour < 17) return 'afternoon';
    if (hour >= 17 && hour < 21) return 'evening';
    return 'night';
  }

  Widget _buildClusterToggle() {
    return Container(
      decoration: BoxDecoration(
        color: _useCluster ? Colors.blue[50] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: _useCluster
            ? Border.all(color: Colors.blue[400]!, width: 2)
            : null,
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
          onTap: () async {
            setState(() {
              _useCluster = !_useCluster;
            });
            await _updateMarkersWithClustering();
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _useCluster ? Icons.scatter_plot : Icons.place,
                  color: _useCluster ? Colors.blue[700] : Colors.grey[700],
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _useCluster ? 'Gom nhóm: ON' : 'Gom nhóm: OFF',
                  style: TextStyle(
                    color: _useCluster ? Colors.blue[700] : Colors.grey[700],
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  // ============================================
  // Validate rental data
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

    // Track shown rental untuk impressions
    _trackShownRental(rental);

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

  // ============================================
  // MỞ GOOGLE MAPS
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

  // ============================================
  // ĐỊNH DẠNG TIỀN TỆ
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
        rental.location['latitude'], 'rental.location.latitude') != null &&
        _safeParseDouble(
            rental.location['longitude'], 'rental.location.longitude') != null &&
        (rental.location['latitude'] != 0.0 ||
            rental.location['longitude'] != 0.0);

    // ✅ LẤY THÔNG TIN POI từ rental object
    final nearestPOIs = rental.nearestPOIs ?? [];
    final hasNearbyPOIs = nearestPOIs.isNotEmpty;

    // ✅ CHỈ LẤY 3 POI GẦN NHẤT
    final displayPOIs = nearestPOIs.take(3).toList();
    final remainingCount = nearestPOIs.length - 3;

    // 🔥 LOGIC HIỂN THỊ NÚT "XEM THÊM"

    final showViewMoreButton = remainingCount > 0 &&
        (_isPOIFilterActive || (_isAIMode && rental.nearestPOIs?.length != null && rental.nearestPOIs!.length > 3));


    return Positioned(
      top: 14,
      left: 16,
      right: 16,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
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
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isCurrentRental ? Colors.red[50] : Colors.green[50],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Row(
                children: [
                  Icon(
                    isCurrentRental ? Icons.home : Icons.location_on,
                    color: isCurrentRental ? Colors.red[600] : Colors.green[600],
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isCurrentRental ? 'Bất động sản này' : 'Bất động sản gần đây',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isCurrentRental ? Colors.red[700] : Colors.green[700],
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

            // Scrollable content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image and basic info
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
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // ✅ HIỂN THỊ 3 POI GẦN NHẤT
                    if (hasNearbyPOIs) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue[200]!, width: 1.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[100],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.location_city,
                                    color: Colors.blue[700],
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Tiện ích gần đây',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue[900],
                                        ),
                                      ),
                                      Text(
                                        '${nearestPOIs.length} tiện ích được tìm thấy',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.blue[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[700],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${nearestPOIs.length}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            const SizedBox(height: 12),

                            // ✅ CHỈ HIỂN THỊ 3 POI
                            ...displayPOIs.asMap().entries.map((entry) {
                              final index = entry.key;
                              final poi = entry.value;
                              final isLast = index == displayPOIs.length - 1;

                              return Padding(
                                padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.blue.withOpacity(0.1),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      // Icon POI
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: Colors.blue[50],
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Center(
                                          child: Text(
                                            poi['icon'] ?? '📍',
                                            style: const TextStyle(fontSize: 18),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),

                                      // Thông tin POI
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              poi['name'] ?? 'Không rõ tên',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.black87,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              poi['category'] ?? 'Khác',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // 🔥 Khoảng cách - SỬ DỤNG FORMAT MỚI
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.orange[400]!,
                                              Colors.deepOrange[500]!
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(6),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.orange.withOpacity(0.3),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.near_me,
                                              color: Colors.white,
                                              size: 12,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              _formatDistance(poi['distance']), // 🔥 SỬ DỤNG HÀM FORMAT MỚI
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),

                            // 🔥 NÚT "XEM THÊM"
                            // Hiển thị khi:
                            // - Chế độ thường + có > 3 POI
                            // - Chế độ AI + POI filter + có > 3 POI
                            // Ẩn khi:
                            // - Chế độ AI thuần (không có POI filter)
                            if (showViewMoreButton) ...[
                              const SizedBox(height: 12),
                              Center(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.blue[200]!),
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () => _showAllPOIsDialog(rental),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.expand_more,
                                              size: 18,
                                              color: Colors.blue[700],
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Xem thêm $remainingCount tiện ích',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.blue[700],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),
                    ],

                    // Buttons
                    // Buttons
                    Row(
                      children: [
                        // 🔥 NEW: Nút "Tại sao?" để xem AI explanation
                        if (rental.isAIRecommended == true)
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _showAIExplanation(rental),
                              icon: const Icon(Icons.psychology, size: 18),
                              label: const Text('Tại sao?'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[400],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              if (_validateRental(rental)) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => RentalDetailScreen(rental: rental),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.info_outline, size: 18),
                            label: const Text('Chi tiết'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[600],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
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
                                _safeParseDouble(
                                    rental.location['latitude'],
                                    'rental.location.latitude') ?? 0.0,
                                _safeParseDouble(
                                    rental.location['longitude'],
                                    'rental.location.longitude') ?? 0.0,
                              );
                              _openInGoogleMaps(position, rental.title);
                            }
                                : null,
                            icon: Icon(
                              hasValidCoords ? Icons.directions : Icons.location_disabled,
                              size: 18,
                            ),
                            label: Text(hasValidCoords ? 'Chỉ đường' : 'Không có vị trí'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: hasValidCoords ? Colors.blue[600] : Colors.grey,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              side: BorderSide(
                                color: hasValidCoords ? Colors.blue[600]! : Colors.grey[400]!,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

// 🔥 HÀM FORMAT DISTANCE (nếu chưa có)
  String _formatDistance(dynamic distanceValue) {
    double distance;

    if (distanceValue is String) {
      distance = double.tryParse(distanceValue) ?? 0.0;
    } else if (distanceValue is num) {
      distance = distanceValue.toDouble();
    } else {
      return '0 m';
    }

    // 🔥 Nếu < 1km thì hiển thị mét, >= 1km thì hiển thị km
    if (distance < 1) {
      return '${(distance * 1000).toInt()} m';
    }
    return '${distance.toStringAsFixed(2)} km';
  }

// ✅ THÊM HÀM: Hiển thị dialog tất cả POI từ _buildCustomInfoWindow
  void _showAllPOIsDialog(Rental rental) {
    final allPOIs = rental.nearestPOIs ?? [];

    showDialog(
      context: context,
      builder: (context) => LazyLoadPOIDialog(
        allPOIs: allPOIs,
        rentalTitle: rental.title,
      ),
    );
  }
  void _showFilterDialog() {
    final rentalViewModel =
    Provider.of<RentalViewModel>(context, listen: false);

    // Hide controls khi mở filter dialog
    _toggleControlsVisibility(false);
    _toggleBadgeVisibility(false);

    showFilterDialog(
      context: context,
      initialRadius: rentalViewModel.currentRadius,
      initialMinPrice: rentalViewModel.currentMinPrice,
      initialMaxPrice: rentalViewModel.currentMaxPrice,
      onApply: (radius, minPrice, maxPrice) async {
        // 🔥 TẮT POI FILTER khi apply filter thủ công
        setState(() {
          _isAIMode = false;
          _isPOIFilterActive = false; // ✅ FIX: TẮT POI FILTER
          _currentFilterResult = null;
        });

        bool isCurrentLocationView = widget.rental.id.startsWith('current_location_');

        if (isCurrentLocationView && _currentLatLng != null) {
          await rentalViewModel.fetchNearbyRentals(
            widget.rental.id,
            radius: radius,
            minPrice: minPrice,
            maxPrice: maxPrice,
            latitude: _currentLatLng!.latitude,
            longitude: _currentLatLng!.longitude,
          );
        } else {
          await rentalViewModel.fetchNearbyRentals(
            widget.rental.id,
            radius: radius,
            minPrice: minPrice,
            maxPrice: maxPrice,
          );
        }

        setState(() {
          _originalNearbyRentals = List.from(rentalViewModel.nearbyRentals);
        });

        if (minPrice != null || maxPrice != null) {
          _applyPriceFilter(
            minPrice ?? 0,
            maxPrice ?? double.infinity,
          );
        }

        _updateMarkersWithClustering();

        if (mounted) {
          AppSnackBar.show(
            context,
            AppSnackBar.success(
              message: 'Tìm thấy ${_filteredNearbyRentals.length} kết quả',
              seconds: 3,
            ),
          );
        }
        _toggleControlsVisibility(true); // Show controls
        _toggleBadgeVisibility(false);
      },
      onReset: () {
        setState(() {
          _filteredNearbyRentals = List.from(_originalNearbyRentals);
          _isFilterApplied = false;
          _isAIMode = false;
          // ✅ Reset POI filter
          _isPOIFilterActive = false;
          _currentFilterResult = null;
        });

        rentalViewModel.resetNearbyFilters();
        rentalViewModel.clearPOISelections();

        _updateMarkersWithClustering();

        if (mounted) {
          AppSnackBar.show(
            context,
            AppSnackBar.success(
              message: 'Đã làm mới bộ lọc - hiển thị ${_originalNearbyRentals.length} bài',
              seconds: 2,
            ),
          );
        }
        _toggleControlsVisibility(true); // Show controls
        _toggleBadgeVisibility(false);
      },
    ).whenComplete(() {
      // Đảm bảo controls hiện lại khi đóng dialog
      _toggleControlsVisibility(true);
      _toggleBadgeVisibility(false);
    });
  }
  // 📍 REPLACE ENTIRE _buildTopLeftControls() METHOD

  Widget _buildTopLeftControls() {
    final rentalViewModel = Provider.of<RentalViewModel>(context);
    final displayCount = _isPOIFilterActive
        ? _filteredNearbyRentals.length
        : (_isFilterApplied
        ? _filteredNearbyRentals.length
        : _originalNearbyRentals.length);

    if (_controlsSlideAnimation == null || _controlsOpacityAnimation == null) {
      _initializeAnimationsIfNeeded();
    }
    return Positioned(
      top: 60,
      left: 16,
      child: SlideTransition(
        position: _controlsSlideAnimation!,
        child: FadeTransition(
          opacity: _controlsOpacityAnimation!,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              // ============================================
              // 1️⃣ POI FILTER BUTTON
              // ============================================
              _buildControlButton(
                label: _isPOIFilterActive
                    ? (_isAIMode ? 'AI + Tiện ích' : 'Đang lọc tiện ích')
                    : 'Tìm gần tiện ích',
                icon: Icons.location_city,
                isActive: _isPOIFilterActive,
                onTap: () {
                  setState(() => _showAddressSearch = false);
                  if (_isPOIFilterActive) {
                    _clearPOIFilter();
                  } else {
                    _showPOISelector();
                  }
                },
              ),
              const SizedBox(height: 12),

              // ============================================
              // 2️⃣ AI TOGGLE BUTTON
              // ============================================
              _buildControlButton(
                label: _isAIMode
                    ? (_isPOIFilterActive ? 'AI + POI' : 'AI đang bật')
                    : 'Lọc thông minh AI',
                icon: _isAIMode ? Icons.psychology : Icons.location_on,
                isActive: _isAIMode,
                onTap: rentalViewModel.isLoading
                    ? null
                    : () {
                  setState(() => _showAddressSearch = false);
                  _toggleAIMode();
                },
              ),
              const SizedBox(height: 12),

              // ============================================
              // 3️⃣ CLUSTER TOGGLE BUTTON
              // ============================================
              _buildClusterToggle(),
              const SizedBox(height: 12),

              // ============================================
              // 4️⃣ FILTER BUTTON
              // ============================================
              if (!_isPOIFilterActive)
                _buildControlButton(
                  label: _isFilterApplied ? 'Đang lọc' : 'Lọc',
                  icon: Icons.tune_rounded,
                  isActive: _isFilterApplied,
                  onTap: () {
                    setState(() => _showAddressSearch = false);
                    _showFilterDialog();
                  },
                ),
              if (!_isPOIFilterActive) const SizedBox(height: 12),

              // ============================================
              // 5️⃣ REFRESH BUTTON
              // ============================================
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
                      debugPrint('🔄 REFRESH button tapped');

                      setState(() {
                        _filteredNearbyRentals = List.from(_originalNearbyRentals);
                        _isFilterApplied = false;
                        _isAIMode = false;
                        _isPOIFilterActive = false;
                        _currentFilterResult = null;
                        _showAddressSearch = false;
                        _selectedAddress = null;
                        _resetImpressions();
                      });

                      rentalViewModel.resetNearbyFilters();
                      rentalViewModel.clearPOISelections();

                      await _fetchNearbyRentals();

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(Icons.check_circle,
                                    color: Colors.white),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        'Đã làm mới danh sách',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Hiển thị ${_originalNearbyRentals.length} bài gợi ý',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            backgroundColor: Colors.green[700],
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            margin: const EdgeInsets.all(16),
                            duration: const Duration(seconds: 2),
                          ),
                        );

                        _updateMarkersWithClustering();
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
                          : Icon(Icons.refresh_rounded,
                          color: Colors.blue[700], size: 20),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildControlButton({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback? onTap,
    bool isIconOnly = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isActive ? (icon == Icons.tune_rounded ? Colors.blue[50] :
        (icon == Icons.psychology ? Colors.blue[50] : Colors.green[50]))
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isActive ? Border.all(
          color: icon == Icons.tune_rounded ? Colors.blue[400]! :
          (icon == Icons.psychology ? Colors.blue[400]! : Colors.green[400]!),
          width: 2,
        ) : null,
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
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: isIconOnly
                ? Icon(icon, color: Colors.blue[700], size: 20)
                : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: isActive ? Colors.blue[700] : Colors.grey[700],
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: isActive ? Colors.blue[700] : Colors.grey[700],
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                if (isActive)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue[700],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 🔥 NEW: Helper method để hiển thị AI Explanation Dialog
  void _showAIExplanation(Rental rental) {
    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để xem giải thích')),
      );
      return;
    }

    showAIExplanationDialog(
      context: context,
      userId: _currentUserId!,
      rentalId: rental.id,
      rentalTitle: rental.title,
    );
  }

  // 🔥 NEW: Helper method để track shown rentals (impressions)
  void _trackShownRental(Rental rental) {
    if (!_shownRentalIds.contains(rental.id)) {
      _shownRentalIds.add(rental.id);
      _impressionCount++;

      // Log impressions
      debugPrint('📊 [IMPRESSIONS] Added ${rental.id}, total: $_impressionCount');
    }
  }

  // 🔥 NEW: Helper method để reset impressions khi user refresh
  void _resetImpressions() {
    _shownRentalIds.clear();
    _impressionCount = 0;
    debugPrint('🔄 [IMPRESSIONS] Reset');
  }

  void _showPOISelector() {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // Hide controls khi mở POI selector
    _toggleControlsVisibility(false);
    _toggleBadgeVisibility(false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => StatefulBuilder(
          builder: (context, setStateSheet) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SingleChildScrollView(
              controller: scrollController,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildPOISelectorHeader(bottomSheetContext),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: _buildRadiusSelector(setStateSheet),
                  ),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: POICategorySelector(
                      onApply: (selectedCategories) {
                        Navigator.pop(bottomSheetContext);
                        _applyPOIFilter(selectedCategories);
                        _toggleControlsVisibility(true); // Show controls
                        _toggleBadgeVisibility(true);
                      },
                      onClose: () {
                        Navigator.pop(bottomSheetContext);
                        _toggleControlsVisibility(true); // Show controls
                        _toggleBadgeVisibility(true);
                      },
                      scaffoldMessenger: scaffoldMessenger,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ).whenComplete(() {
      // Đảm bảo controls hiện lại khi đóng modal
      _toggleControlsVisibility(true);
      _toggleBadgeVisibility(true);
    });
  }
  // ============================================
// HÀM HELPER: POI Selector Header
// ============================================
  Widget _buildPOISelectorHeader(BuildContext bottomSheetContext) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.location_city, color: Colors.blue, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tìm gần tiện ích',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Chọn tiện ích và khoảng cách',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(bottomSheetContext),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
  // ============================================
// HÀM HELPER: Radius Selector
// ============================================
  Widget _buildRadiusSelector(StateSetter setStateSheet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Khoảng cách tìm kiếm',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_poiFilterRadius.toStringAsFixed(1)} km',
                style: TextStyle(
                  color: Colors.blue[700],
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Slider(
          value: _poiFilterRadius,
          min: 1,
          max: 10,
          divisions: 9,
          label: '${_poiFilterRadius.toStringAsFixed(1)} km',
          activeColor: Colors.blue[700],
          onChanged: (value) {
            setStateSheet(() {
              _poiFilterRadius = value;
            });
          },
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [3, 6, 9].map((km) {
            final isSelected = _poiFilterRadius == km.toDouble();
            return GestureDetector(
              onTap: () {
                setStateSheet(() {
                  _poiFilterRadius = km.toDouble();
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blue[100] : Colors.grey[100],
                  border: Border.all(
                    color: isSelected ? Colors.blue[400]! : Colors.grey[300]!,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$km km',
                  style: TextStyle(
                    color: isSelected ? Colors.blue[700] : Colors.grey[600],
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

// ============================================
// HÀM HELPER: Show Snackbar
// ============================================
  void _showSnackbar({
    required String message,
    Color? backgroundColor,
    int seconds = 3,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: backgroundColor ?? Colors.blue[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: Duration(seconds: seconds),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    final rentalViewModel = Provider.of<RentalViewModel>(context);

    final displayCount = _isPOIFilterActive
        ? _filteredNearbyRentals.length
        : (_isFilterApplied
        ? _filteredNearbyRentals.length
        : _originalNearbyRentals.length);

    _keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: false,
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
                      controller.animateCamera(
                          CameraUpdate.newLatLngZoom(_currentLatLng!, 16));
                    }
                  },
                  onTap: (_) => _hideRentalInfo(),
                  onCameraMove: _onCameraMove,
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

          // 🔥 Address Search Bar - Positioned at top
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: _showAddressSearch
                ? AddressSearchWidget(
              mapController: _controller,
              onAddressSelected: (result) {
                setState(() {
                  _selectedAddress = result;
                  _showAddressSearch = false;
                });
                debugPrint('📍 Selected address: ${result.displayName}');
                _toggleControlsVisibility(true); // Show controls
                _toggleBadgeVisibility(true);
              },
              onClose: () {
                setState(() => _showAddressSearch = false);
                _toggleControlsVisibility(true); // Show controls
                _toggleBadgeVisibility(true);
              },
              onSearchStart: () {
                _toggleControlsVisibility(false); // Hide controls
                _toggleBadgeVisibility(false);
              },
              onSearchEnd: () {
                _toggleControlsVisibility(true); // Show controls
                _toggleBadgeVisibility(true);
              },
              currentLocation: _currentLatLng,
            )
                : Container(
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
                    setState(() => _showAddressSearch = true);
                    _toggleControlsVisibility(false); // Hide controls
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          color: Colors.blue[600],
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _selectedAddress?.displayName ??
                                'Tìm kiếm địa chỉ...',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              color: _selectedAddress != null
                                  ? Colors.black87
                                  : Colors.grey[500],
                            ),
                          ),
                        ),
                        if (_selectedAddress != null)
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedAddress = null;
                                _showAddressSearch = false;
                              });
                            },
                            child: Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Top left controls overlay
          _buildTopLeftControls(),

          // Custom info window overlay
          _buildCustomInfoWindow(),

          // Horizontal rental list at bottom
          Positioned(
            bottom: _keyboardHeight,
            left: 0,
            right: 0,
            child: HorizontalRentalListWidget(
              rentals: _isFilterApplied
                  ? _filteredNearbyRentals
                  : _originalNearbyRentals,
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
              isFilterApplied: _isFilterApplied,
              totalRentals: _originalNearbyRentals.length,
            ),
          ),

          // ✅ Info badge ở dưới cùng bên trái - PHÍA TRÊN HorizontalRentalListWidget
          Positioned(
            bottom: 230 + _keyboardHeight,
            left: 16,
            child: Builder(
              builder: (context) {
                // ✅ FIX: Khởi tạo animation nếu cần
                _initializeBadgeAnimationIfNeeded();

                // ✅ Kiểm tra null trước khi sử dụng
                if (_badgeSlideAnimation == null || _badgeOpacityAnimation == null) {
                  return const SizedBox.shrink();
                }

                return SlideTransition(
                  position: _badgeSlideAnimation!,
                  child: FadeTransition(
                    opacity: _badgeOpacityAnimation!,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _isPOIFilterActive && _isAIMode
                            ? Colors.blue[700]
                            : (_isPOIFilterActive
                            ? Colors.green[600]
                            : (_isAIMode
                            ? Colors.blue[700]
                            : (_isFilterApplied
                            ? Colors.orange[600]
                            : Colors.green[600]))),
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
                        _isPOIFilterActive && _isAIMode
                            ? '$displayCount bài AI đã tìm gần tiện ích'
                            : (_isPOIFilterActive
                            ? '$displayCount bài gần tiện ích'
                            : (_isAIMode
                            ? '$displayCount gợi ý từ AI'
                            : (_isFilterApplied
                            ? '${_filteredNearbyRentals.length}/${_originalNearbyRentals.length} bài'
                            : '$displayCount bài'))),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}