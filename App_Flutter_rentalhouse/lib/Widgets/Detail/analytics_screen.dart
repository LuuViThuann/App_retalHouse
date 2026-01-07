import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';

import '../../config/loading.dart';
import '../../viewmodels/vm_analytics.dart';
import '../Analytics/hot_areas_list.dart';
import '../Analytics/location_filter.dart';
import '../Analytics/location_stats_chart.dart';
import '../Analytics/overview_charts.dart';
import '../Analytics/property_types_chart.dart';


class AnalyticsScreen extends StatefulWidget {
  final String? initialRadiusKm;

  const AnalyticsScreen({Key? key, this.initialRadiusKm}) : super(key: key);

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  // Location filter state
  String? selectedProvince;
  String? selectedDistrict;
  String? selectedWard;

  // ✅ Loading state for filtered data
  bool isFilterLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AnalyticsViewModel>().fetchAllAnalytics();
    });
  }

  void _onLocationChanged({String? province, String? district, String? ward}) {
    setState(() {
      selectedProvince = province;
      selectedDistrict = district;
      selectedWard = ward;
    });
    // NOTE: Don't fetch here anymore, wait for user to click Apply button
  }

  // ✅ Apply filter and fetch filtered data
  Future<void> _applyLocationFilter() async {
    setState(() => isFilterLoading = true);

    try {
      // Build filter params
      final filters = <String, String?>{
        'province': selectedProvince,
        'district': selectedDistrict,
        'ward': selectedWard,
      };

      // Fetch filtered analytics
      await context.read<AnalyticsViewModel>().fetchFilteredAnalytics(filters);

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text('Đã áp dụng lọc địa chỉ đã chọn...'),
              ],
            ),
            backgroundColor: Colors.green[600],
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi lọc dữ liệu: $e'),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isFilterLoading = false);
      }
    }
  }

  void _clearLocationFilter() {
    setState(() {
      selectedProvince = null;
      selectedDistrict = null;
      selectedWard = null;
    });
    context.read<AnalyticsViewModel>().fetchAllAnalytics();

    // Show clear message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.clear_all, color: Colors.white),
            SizedBox(width: 8),
            Text('Đã xóa bộ lọc - Hiển thị tất cả khu vực'),
          ],
        ),
        backgroundColor: Colors.orange[600],
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  // ✅ Get filter text for display
  String _getFilterText() {
    final parts = <String>[];
    if (selectedProvince != null) parts.add(selectedProvince!);
    if (selectedDistrict != null) parts.add(selectedDistrict!);
    if (selectedWard != null) parts.add(selectedWard!);
    return parts.join(' → ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: Consumer<AnalyticsViewModel>(
        builder: (context, vm, _) {
          // ✅ Show loading when filtering
          final isLoading = vm.isLoading || isFilterLoading;

          if (isLoading) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Lottie.asset(
                    AssetsConfig.loadingLottie,
                    width: 80,
                    height: 80,
                    fit: BoxFit.fill,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isFilterLoading ? 'Đang lọc dữ liệu...' : 'Đang tải thống kê...',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }

          if (vm.errorMessage != null) {
            return _buildErrorWidget(vm.errorMessage!);
          }

          final hasFilter = selectedProvince != null ||
              selectedDistrict != null ||
              selectedWard != null;

          return RefreshIndicator(
            onRefresh: () async {
              if (hasFilter) {
                await _applyLocationFilter();
              } else {
                await vm.fetchAllAnalytics();
              }
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Location Filter
                  LocationFilter(
                    selectedProvince: selectedProvince,
                    selectedDistrict: selectedDistrict,
                    selectedWard: selectedWard,
                    onLocationChanged: _onLocationChanged,
                    onClear: _clearLocationFilter,
                    onApply: _applyLocationFilter,
                  ),
                  const SizedBox(height: 20),

                  // ✅ Filter status banner
                  if (hasFilter) _buildFilterStatus(),

                  // ✅ Location Stats Chart with filter props
                  LocationStatsChart(
                    viewModel: vm,
                    filteredProvince: selectedProvince,
                    filteredDistrict: selectedDistrict,
                    filteredWard: selectedWard,
                  ),
                  const SizedBox(height: 24),

                  // Price Distribution Chart
                  PriceDistributionChart(viewModel: vm),
                  const SizedBox(height: 24),
                  // Overview Charts
                  OverviewCharts(viewModel: vm),
                  const SizedBox(height: 24),

                  // Property Types Chart
                  PropertyTypesChart(viewModel: vm),
                  const SizedBox(height: 24),

                  // Hot Areas List
                  HotAreasList(viewModel: vm),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ✅ Filter status widget
  Widget _buildFilterStatus() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[600]!, Colors.blue[700]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.filter_alt,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Đang hiển thị kết quả lọc',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _getFilterText(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _clearLocationFilter,
            icon: const Icon(Icons.close, color: Colors.white, size: 20),
            tooltip: 'Xóa bộ lọc',
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.blue[700],
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Icon(Icons.analytics_outlined, color: Colors.white, size: 24),
          const SizedBox(width: 8),
          const Text(
            'Thống kê & Phân tích',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 19,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: () {
            if (selectedProvince != null || selectedDistrict != null || selectedWard != null) {
              _applyLocationFilter();
            } else {
              context.read<AnalyticsViewModel>().fetchAllAnalytics();
            }
          },
          tooltip: 'Làm mới',
        ),
      ],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
    );
  }

  Widget _buildErrorWidget(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.red[300], size: 64),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey[700]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              if (selectedProvince != null || selectedDistrict != null || selectedWard != null) {
                _applyLocationFilter();
              } else {
                context.read<AnalyticsViewModel>().fetchAllAnalytics();
              }
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Thử lại'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}