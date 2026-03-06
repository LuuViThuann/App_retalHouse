import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';

import '../../config/loading.dart';
import '../../viewmodels/vm_analytics.dart';
import '../Analytics/AmenitiesStatsChart.dart';
import '../Analytics/AreaDistributionChart.dart';
import '../Analytics/GrowthStatsChart.dart';
import '../Analytics/UserBehaviorChart.dart';
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

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with SingleTickerProviderStateMixin {

  // ── Filter state ───────────────────────────────────────────────────────
  String? selectedProvince;
  String? selectedDistrict;
  String? selectedWard;
  bool isFilterLoading = false;

  // ── Tab ───────────────────────────────────────────────────────────────
  late TabController _tabController;
  int _currentTab = 0;

  static const _tabDescriptions = [
    'Vị trí • Tiện nghi • Tăng trưởng • Hành vi',
    'Diện tích • Giá • Loại BĐS • Tổng quan',
    'Khu vực hot nhất theo thời gian',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this)
      ..addListener(() {
        if (!_tabController.indexIsChanging) {
          setState(() => _currentTab = _tabController.index);
        }
      });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AnalyticsViewModel>().fetchAllAnalytics();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Filter helpers ─────────────────────────────────────────────────────
  void _onLocationChanged({String? province, String? district, String? ward}) =>
      setState(() {
        selectedProvince = province;
        selectedDistrict = district;
        selectedWard     = ward;
      });

  Future<void> _applyLocationFilter() async {
    setState(() => isFilterLoading = true);
    try {
      await context.read<AnalyticsViewModel>().fetchFilteredAnalytics({
        'province': selectedProvince,
        'district': selectedDistrict,
        'ward':     selectedWard,
      });
      if (mounted) _showSnackBar('Đã áp dụng: ${_getFilterText()}', true);
    } catch (_) {
      if (mounted) _showSnackBar('Lỗi khi lọc dữ liệu', false);
    } finally {
      if (mounted) setState(() => isFilterLoading = false);
    }
  }

  void _clearLocationFilter() {
    setState(() => selectedProvince = selectedDistrict = selectedWard = null);
    context.read<AnalyticsViewModel>().fetchAllAnalytics();
    _showSnackBar('Đã xóa bộ lọc', true);
  }

  void _showSnackBar(String msg, bool ok) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        backgroundColor: ok ? const Color(0xFF1A1A1A) : const Color(0xFFE53935),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ));

  String _getFilterText() => [selectedProvince, selectedDistrict, selectedWard]
      .whereType<String>().join(' › ');

  bool get _hasFilter =>
      selectedProvince != null || selectedDistrict != null || selectedWard != null;

  String _shortFilterLabel() {
    if (selectedWard     != null) return selectedWard!;
    if (selectedDistrict != null) return selectedDistrict!;
    if (selectedProvince != null) return selectedProvince!;
    return '';
  }

  // ── Build ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: _buildAppBar(),
      body: Consumer<AnalyticsViewModel>(
        builder: (context, vm, _) {
          if (vm.isLoading || isFilterLoading) return _buildLoading();
          if (vm.errorMessage != null)          return _buildError(vm);

          return Column(children: [
            _buildFilterSection(vm),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTab1(vm),
                  _buildTab2(vm),
                  _buildTab3(vm),
                ],
              ),
            ),
          ]);
        },
      ),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() => AppBar(
    backgroundColor: Colors.blue[700],
    elevation: 0,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
      onPressed: () => Navigator.pop(context),
    ),
    title: Row(children: [
      const Icon(Icons.analytics_rounded, color: Colors.white, size: 22),
      const SizedBox(width: 8),
      const Text('Thống kê tổng quan',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
      if (_hasFilter) ...[
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.25),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.filter_alt_rounded, color: Colors.white, size: 12),
            const SizedBox(width: 3),
            Text(_shortFilterLabel(),
                style: const TextStyle(color: Colors.white, fontSize: 11)),
          ]),
        ),
      ],
    ]),
    actions: [
      IconButton(
        icon: const Icon(Icons.refresh_rounded, color: Colors.white),
        onPressed: () => _hasFilter
            ? _applyLocationFilter()
            : context.read<AnalyticsViewModel>().fetchAllAnalytics(),
        tooltip: 'Làm mới',
      ),
    ],
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20))),
  );

  // ── Filter section ─────────────────────────────────────────────────────
  Widget _buildFilterSection(AnalyticsViewModel vm) => Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    child: Column(children: [
      LocationFilter(
        selectedProvince:  selectedProvince,
        selectedDistrict:  selectedDistrict,
        selectedWard:      selectedWard,
        onLocationChanged: _onLocationChanged,
        onClear:           _clearLocationFilter,
        onApply:           _applyLocationFilter,
      ),
      if (_hasFilter) ...[
        const SizedBox(height: 10),
        _buildActiveFilterBanner(),
        const SizedBox(height: 10),
        _buildContextStrip(vm),
      ],
      const SizedBox(height: 12),
    ]),
  );

  // ── Tab bar ────────────────────────────────────────────────────────────
  Widget _buildTabBar() => Container(
    color: Colors.white,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Divider(height: 1, color: Color(0xFFEEEEEE)),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(3),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: Colors.blue[700],
              borderRadius: BorderRadius.circular(9),
            ),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey[500],
            labelStyle:
            const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            unselectedLabelStyle: const TextStyle(fontSize: 12),
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(height: 36, child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_city_rounded, size: 14),
                  SizedBox(width: 5),
                  Text('Khu vực'),
                ],
              )),
              Tab(height: 36, child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bar_chart_rounded, size: 14),
                  SizedBox(width: 5),
                  Text('Thị trường'),
                ],
              )),
              Tab(height: 36, child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.local_fire_department, size: 14),
                  SizedBox(width: 5),
                  Text('Nổi bật'),
                ],
              )),
            ],
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
        child: Text(
          _tabDescriptions[_currentTab],
          style: TextStyle(fontSize: 11, color: Colors.grey[400]),
          textAlign: TextAlign.center,
        ),
      ),
    ]),
  );

  // ── Tab 1 — Khu vực ───────────────────────────────────────────────────
  Widget _buildTab1(AnalyticsViewModel vm) => _tabScroll([
    LocationStatsChart(
      viewModel:       vm,
      filteredProvince: selectedProvince,
      filteredDistrict: selectedDistrict,
      filteredWard:     selectedWard,
    ),
    const SizedBox(height: 20),
    AmenitiesStatsChart(viewModel: vm),
    const SizedBox(height: 20),
    GrowthStatsChart(viewModel: vm),
    const SizedBox(height: 20),
    UserBehaviorChart(viewModel: vm),
  ], vm);

  // ── Tab 2 — Thị trường ────────────────────────────────────────────────
  Widget _buildTab2(AnalyticsViewModel vm) => _tabScroll([
    AreaDistributionChart(viewModel: vm),
    const SizedBox(height: 20),
    PriceDistributionChart(viewModel: vm),
    const SizedBox(height: 20),
    PropertyTypesChart(viewModel: vm),
    const SizedBox(height: 20),
    OverviewCharts(viewModel: vm),
  ], vm);

  // ── Tab 3 — Nổi bật ───────────────────────────────────────────────────
  Widget _buildTab3(AnalyticsViewModel vm) => _tabScroll([
    HotAreasList(viewModel: vm),
  ], vm);

  // ── Tab scroll wrapper ─────────────────────────────────────────────────
  Widget _tabScroll(List<Widget> children, AnalyticsViewModel vm) =>
      RefreshIndicator(
        color: const Color(0xFF1A1A1A),
        strokeWidth: 2,
        onRefresh: () async => _hasFilter
            ? await _applyLocationFilter()
            : await vm.fetchAllAnalytics(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      );

  // ── Filter banner ──────────────────────────────────────────────────────
  Widget _buildActiveFilterBanner() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFF1A1A1A),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(children: [
      const Icon(Icons.filter_alt_rounded, color: Colors.white54, size: 16),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Đang lọc theo khu vực',
            style: TextStyle(color: Colors.white54, fontSize: 11)),
        const SizedBox(height: 2),
        Text(_getFilterText(),
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
            maxLines: 1, overflow: TextOverflow.ellipsis),
      ])),
      GestureDetector(
        onTap: _clearLocationFilter,
        child: const Icon(Icons.close_rounded, color: Colors.white54, size: 18),
      ),
    ]),
  );

  // ── Context strip ──────────────────────────────────────────────────────
  Widget _buildContextStrip(AnalyticsViewModel vm) {
    final total    = vm.getTotalRentals();
    final avgPrice = vm.getAveragePrice();
    final hotArea  = vm.getHottestArea();
    final hotCount = vm.getHottestAreaCount();

    String priceText;
    if (avgPrice >= 1e9)      priceText = '${(avgPrice / 1e9).toStringAsFixed(1)} tỷ';
    else if (avgPrice >= 1e6) priceText = '${(avgPrice / 1e6).toStringAsFixed(0)} tr';
    else                      priceText = avgPrice.toStringAsFixed(0);

    return Row(children: [
      _chip('$total',   'Tổng BĐS', Icons.home_outlined,       Colors.blue),
      const SizedBox(width: 8),
      _chip(priceText,  'Giá TB',   Icons.attach_money_rounded, Colors.green),
      const SizedBox(width: 8),
      Expanded(flex: 2, child: _chipWide(hotArea, '$hotCount BĐS')),
    ]);
  }

  Widget _chip(String value, String label, IconData icon, Color color) =>
      Expanded(child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.18)),
        ),
        child: Column(children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(height: 3),
          Text(value,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: color)),
          Text(label,
              style: const TextStyle(fontSize: 10, color: Color(0xFF888888))),
        ]),
      ));

  Widget _chipWide(String value, String sub) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
    decoration: BoxDecoration(
      color: Colors.orange.withOpacity(0.06),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.orange.withOpacity(0.18)),
    ),
    child: Row(children: [
      const Icon(Icons.trending_up_rounded, size: 15, color: Colors.orange),
      const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A)),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(sub,
            style: const TextStyle(fontSize: 10, color: Color(0xFF888888))),
      ])),
    ]),
  );

  // ── Loading & Error ────────────────────────────────────────────────────
  Widget _buildLoading() => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Lottie.asset(AssetsConfig.loadingLottie, width: 80, height: 80),
      const SizedBox(height: 16),
      Text(
        isFilterLoading ? 'Đang áp dụng bộ lọc...' : 'Đang tải dữ liệu...',
        style: const TextStyle(
            fontSize: 14, color: Color(0xFF888888), fontWeight: FontWeight.w500),
      ),
      if (_hasFilter) ...[
        const SizedBox(height: 6),
        Text(_getFilterText(),
            style: const TextStyle(fontSize: 12, color: Color(0xFF444444))),
      ],
    ],
  ));

  Widget _buildError(AnalyticsViewModel vm) => Center(child: Padding(
    padding: const EdgeInsets.all(40),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 72, height: 72,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE8E8E8)),
        ),
        child: const Icon(Icons.wifi_off_rounded,
            color: Color(0xFFCCCCCC), size: 36),
      ),
      const SizedBox(height: 20),
      Text(vm.errorMessage ?? 'Đã xảy ra lỗi',
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 14, color: Color(0xFF666666), height: 1.5)),
      const SizedBox(height: 28),
      SizedBox(
        width: double.infinity,
        child: TextButton(
          onPressed: () {
            vm.clearError();
            _hasFilter ? _applyLocationFilter() : vm.fetchAllAnalytics();
          },
          style: TextButton.styleFrom(
            backgroundColor: const Color(0xFF1A1A1A),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Thử lại',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ),
      ),
    ]),
  ));
}