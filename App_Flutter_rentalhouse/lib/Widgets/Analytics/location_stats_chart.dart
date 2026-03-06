import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../viewmodels/vm_analytics.dart';

class LocationStatsChart extends StatefulWidget {
  final AnalyticsViewModel viewModel;
  final String? filteredProvince;
  final String? filteredDistrict;
  final String? filteredWard;

  const LocationStatsChart({
    Key? key,
    required this.viewModel,
    this.filteredProvince,
    this.filteredDistrict,
    this.filteredWard,
  }) : super(key: key);

  @override
  State<LocationStatsChart> createState() => _LocationStatsChartState();
}

class _LocationStatsChartState extends State<LocationStatsChart>
    with SingleTickerProviderStateMixin {
  static const _tabKeys  = ['cities', 'districts', 'wards'];
  static const _typeMap  = {'cities': 'province', 'districts': 'district', 'wards': 'ward'};
  static const _levelMap = {'none': 'cities', 'province': 'districts', 'district': 'wards', 'ward': 'wards'};

  // Số mục hiển thị mặc định khi mở
  static const int _defaultVisible = 5;
  // Mỗi lần nhấn "Xem thêm" mở thêm bao nhiêu
  static const int _loadMoreStep   = 5;

  String selectedTab  = 'cities';
  int?   touchedIndex;
  late TabController _tabController;

  // Tracking số item đang hiển thị theo từng tab
  final Map<String, int> _visibleCount = {
    'cities':    _defaultVisible,
    'districts': _defaultVisible,
    'wards':     _defaultVisible,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          selectedTab  = _tabKeys[_tabController.index];
          touchedIndex = null;
        });
      }
    });
  }

  @override
  void didUpdateWidget(LocationStatsChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    final stats       = widget.viewModel.locationStats;
    final filterLevel = stats['filterLevel']?.toString() ?? 'none';
    final targetTab   = _levelMap[filterLevel] ?? 'cities';
    final targetIndex = _tabKeys.indexOf(targetTab);

    if (targetTab != selectedTab && targetIndex >= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _tabController.animateTo(targetIndex);
          setState(() {
            selectedTab  = targetTab;
            touchedIndex = null;
            // Reset visible count khi filter thay đổi
            _visibleCount[targetTab] = _defaultVisible;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ─── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.location_on_rounded, color: Colors.red[700], size: 22),
            ),
            const SizedBox(width: 10),
            const Text(
              'Thống kê theo khu vực',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 14),

        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              if (_hasFilter) _buildFilterBanner(),
              _buildTabBar(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: _buildContent(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool get _hasFilter =>
      widget.filteredProvince != null ||
          widget.filteredDistrict != null ||
          widget.filteredWard     != null;

  // ─── Filter banner ───────────────────────────────────────────────────────────
  Widget _buildFilterBanner() {
    final parts = <String>[
      if (widget.filteredProvince != null) widget.filteredProvince!,
      if (widget.filteredDistrict != null) widget.filteredDistrict!,
      if (widget.filteredWard     != null) widget.filteredWard!,
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange[400]!, Colors.deepOrange[400]!],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          const Icon(Icons.filter_alt_rounded, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              parts.join(' › '),
              style: const TextStyle(
                  color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('Đang lọc',
                style: TextStyle(color: Colors.white, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  // ─── Tab bar ─────────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    final tabs = [
      {'key': 'cities',    'label': 'Tỉnh/TP',    'icon': Icons.location_city_rounded},
      {'key': 'districts', 'label': 'Quận/Huyện', 'icon': Icons.map_rounded},
      {'key': 'wards',     'label': 'Phường/Xã',  'icon': Icons.home_work_rounded},
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(14),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: _tabColor(selectedTab),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: _tabColor(selectedTab).withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey[600],
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle:
        const TextStyle(fontWeight: FontWeight.normal, fontSize: 12),
        dividerColor: Colors.transparent,
        tabs: tabs.map((t) {
          return Tab(
            height: 36,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(t['icon'] as IconData, size: 13),
                const SizedBox(width: 4),
                Text(t['label'] as String,
                    style: const TextStyle(fontSize: 11)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _tabColor(String tab) {
    switch (tab) {
      case 'cities':    return Colors.blue[600]!;
      case 'districts': return Colors.orange[600]!;
      case 'wards':     return Colors.green[600]!;
      default:          return Colors.blue[600]!;
    }
  }

  // ─── Content ─────────────────────────────────────────────────────────────────
  Widget _buildContent() {
    final locationStats = widget.viewModel.locationStats;

    if (locationStats.isEmpty) {
      return _buildEmptyState('Chưa có dữ liệu thống kê khu vực');
    }

    final data = _parseDataForTab(locationStats);

    if (data.isEmpty) {
      return _buildEmptyState(_emptyMessage());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSummaryRow(data),
        const SizedBox(height: 16),
        _buildTopItemCard(data.first),
        const SizedBox(height: 16),
        if (selectedTab == 'cities' && data.length > 5)
          _buildProvinceScrollChart(data)
        else
          _buildBarChart(data),
        const SizedBox(height: 16),
        // Ranking list với "Xem thêm"
        _buildRankingListWithLoadMore(data),
      ],
    );
  }

  // ─── Parse data ──────────────────────────────────────────────────────────────
  List<_LocationData> _parseDataForTab(Map<String, dynamic> locationStats) {
    List<_LocationData> result = [];

    final locationsRaw = locationStats['locations'];
    final filterLevel  = locationStats['filterLevel']?.toString() ?? 'none';

    if (locationsRaw is List && locationsRaw.isNotEmpty) {
      final wantType = _typeMap[selectedTab] ?? 'province';

      result = locationsRaw
          .where((loc) => (loc['type']?.toString() ?? '') == wantType)
          .map((loc) => _LocationData(
        name:     _shortenName(loc['name']?.toString() ?? ''),
        fullName: loc['name']?.toString() ?? '',
        count:    _toInt(loc['count']),
        avgPrice: _toDouble(loc['avgPrice']),
      ))
          .where((d) => d.count > 0 && d.fullName.isNotEmpty)
          .toList();

      if (result.isEmpty) {
        final autoType = _autoTypeForFilterLevel(filterLevel);
        result = locationsRaw
            .where((loc) => (loc['type']?.toString() ?? '') == autoType)
            .map((loc) => _LocationData(
          name:     _shortenName(loc['name']?.toString() ?? ''),
          fullName: loc['name']?.toString() ?? '',
          count:    _toInt(loc['count']),
          avgPrice: _toDouble(loc['avgPrice']),
        ))
            .where((d) => d.count > 0 && d.fullName.isNotEmpty)
            .toList();
      }
    }

    if (result.isEmpty) {
      final items = locationStats[selectedTab] as List?;
      if (items != null && items.isNotEmpty) {
        result = items
            .map((item) {
          final name = (item['name'] ?? item['_id'] ?? '').toString().trim();
          return _LocationData(
            name:     _shortenName(name),
            fullName: name,
            count:    _toInt(item['count']),
            avgPrice: _toDouble(item['avgPrice']),
          );
        })
            .where((d) =>
        d.count > 0 &&
            d.fullName.isNotEmpty &&
            !['việt nam', 'vietnam', 'viet nam']
                .contains(d.fullName.toLowerCase()))
            .toList();
      }
    }

    result.sort((a, b) => b.count.compareTo(a.count));
    final limit = selectedTab == 'cities' ? 63 : 20;
    return result.take(limit).toList();
  }

  String _autoTypeForFilterLevel(String filterLevel) {
    switch (filterLevel) {
      case 'province': return 'district';
      case 'district': return 'ward';
      case 'ward':     return 'ward';
      default:         return 'province';
    }
  }

  String _shortenName(String name) {
    return name
        .replaceAll('Thành phố ', 'TP. ')
        .replaceAll('Tỉnh ', '')
        .replaceAll('Quận ', 'Q.')
        .replaceAll('Huyện ', 'H.')
        .replaceAll('Phường ', 'P.')
        .replaceAll('Xã ', 'X.');
  }

  // ─── Summary row ─────────────────────────────────────────────────────────────
  Widget _buildSummaryRow(List<_LocationData> data) {
    final total    = data.fold<int>(0, (s, d) => s + d.count);
    final topCount = data.isNotEmpty ? data.first.count : 0;
    final topPct   = total > 0 ? (topCount / total * 100).toStringAsFixed(0) : '0';
    return Row(
      children: [
        _summaryChip(Icons.analytics_rounded, total.toString(),      'Tổng BĐS',    Colors.blue),
        const SizedBox(width: 8),
        _summaryChip(Icons.location_on_rounded, data.length.toString(), _levelLabel(), _tabColor(selectedTab)),
        const SizedBox(width: 8),
        _summaryChip(Icons.star_rounded,        '$topPct%',           'Top 1',       Colors.amber[700]!),
      ],
    );
  }

  Widget _summaryChip(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold, color: color)),
            Text(label,
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  // ─── Top card ────────────────────────────────────────────────────────────────
  Widget _buildTopItemCard(_LocationData top) {
    final color = _tabColor(selectedTab);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber[600],
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.emoji_events_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dẫn đầu: ${top.fullName}',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14, color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  '${top.count} BĐS'
                      '${top.avgPrice > 0 ? ' · TB: ${_fmtPrice(top.avgPrice)}' : ''}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.amber[600],
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('#1',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ),
        ],
      ),
    );
  }

  // ─── Province horizontal scroll chart ────────────────────────────────────────
  Widget _buildProvinceScrollChart(List<_LocationData> data) {
    final color = _tabColor(selectedTab);
    final double rawMax = data.map((d) => d.count.toDouble())
        .fold(0.0, (prev, v) => v > prev ? v : prev);
    final double maxY    = rawMax > 0 ? rawMax * 1.3 : 10.0;
    final double interval = (maxY / 4).clamp(1.0, double.infinity);

    const double barWidth  = 48.0;
    final double chartWidth = data.length * barWidth + 32;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Biểu đồ ${data.length} ${_levelLabel().toLowerCase()} (cuộn ngang)',
          style: TextStyle(
              fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey[700]),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 240,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: chartWidth.clamp(300, double.infinity),
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchCallback: (event, response) {
                      setState(() {
                        if (response?.spot != null &&
                            event is! FlTapUpEvent &&
                            event is! FlPanEndEvent) {
                          touchedIndex =
                              response!.spot!.touchedBarGroupIndex;
                        } else {
                          touchedIndex = null;
                        }
                      });
                    },
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => color,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        if (groupIndex >= data.length) return null;
                        final item = data[groupIndex];
                        return BarTooltipItem(
                          '${item.fullName}\n${rod.toY.toInt()} BĐS'
                              '${item.avgPrice > 0 ? '\n${_fmtPrice(item.avgPrice)}' : ''}',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= data.length) return const SizedBox();
                          final name  = data[i].name;
                          final lines = name.split(' ');
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: lines.take(2).map((line) => Text(
                                line.length > 8
                                    ? '${line.substring(0, 8)}..'
                                    : line,
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: i == touchedIndex
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: i == touchedIndex
                                      ? color
                                      : Colors.grey[700],
                                ),
                                textAlign: TextAlign.center,
                              )).toList(),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        interval: interval,
                        getTitlesWidget: (value, meta) => Text(
                          _fmtCount(value.toInt()),
                          style:
                          TextStyle(fontSize: 9, color: Colors.grey[500]),
                        ),
                      ),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: interval,
                    getDrawingHorizontalLine: (_) =>
                        FlLine(color: Colors.grey[200]!, strokeWidth: 1),
                  ),
                  barGroups: data.asMap().entries.map((e) {
                    final isTouched = e.key == touchedIndex;
                    final rank      = e.key;
                    Color barColor;
                    if (rank == 0)      barColor = Colors.amber[600]!;
                    else if (rank == 1) barColor = Colors.blueGrey[500]!;
                    else if (rank == 2) barColor = Colors.brown[500]!;
                    else                barColor = color;

                    return BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(
                          toY: e.value.count.toDouble(),
                          width: isTouched ? 20 : 16,
                          borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(6)),
                          gradient: LinearGradient(
                            colors: isTouched
                                ? [barColor, barColor.withOpacity(0.6)]
                                : [barColor.withOpacity(0.9),
                              barColor.withOpacity(0.5)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _legendDot(Colors.amber[600]!,    'Top 1'),
            const SizedBox(width: 12),
            _legendDot(Colors.blueGrey[500]!, 'Top 2'),
            const SizedBox(width: 12),
            _legendDot(Colors.brown[500]!,    'Top 3'),
            const SizedBox(width: 12),
            _legendDot(color,                 'Còn lại'),
          ],
        ),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 10,
            height: 10,
            decoration:
            BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(fontSize: 10, color: Colors.grey[600])),
      ],
    );
  }

  // ─── Bar chart (dùng cho district / ward) ────────────────────────────────────
  Widget _buildBarChart(List<_LocationData> data) {
    final displayData = data.take(7).toList();
    if (displayData.isEmpty) return const SizedBox.shrink();

    final color    = _tabColor(selectedTab);
    final double rawMax = displayData
        .map((d) => d.count.toDouble())
        .fold(0.0, (prev, v) => v > prev ? v : prev);
    final double maxY    = (rawMax > 0 ? rawMax * 1.3 : 10.0);
    final double interval = (maxY / 4).clamp(1.0, double.infinity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Biểu đồ top ${displayData.length} ${_levelLabel().toLowerCase()}',
          style: TextStyle(
              fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey[700]),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 220,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxY,
              barTouchData: BarTouchData(
                enabled: true,
                touchCallback: (event, response) {
                  setState(() {
                    if (response?.spot != null &&
                        event is! FlTapUpEvent &&
                        event is! FlPanEndEvent) {
                      touchedIndex = response!.spot!.touchedBarGroupIndex;
                    } else {
                      touchedIndex = null;
                    }
                  });
                },
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => color,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    if (groupIndex >= displayData.length) return null;
                    final item = displayData[groupIndex];
                    return BarTooltipItem(
                      '${item.fullName}\n${rod.toY.toInt()} BĐS',
                      const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 44,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= displayData.length) return const SizedBox();
                      final name = displayData[i].name;
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          name.length > 10 ? '${name.substring(0, 10)}..' : name,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: i == touchedIndex
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: i == touchedIndex ? color : Colors.grey[700],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    interval: interval,
                    getTitlesWidget: (value, meta) => Text(
                      _fmtCount(value.toInt()),
                      style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                    ),
                  ),
                ),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: interval,
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: Colors.grey[200]!, strokeWidth: 1),
              ),
              barGroups: displayData.asMap().entries.map((e) {
                final isTouched = e.key == touchedIndex;
                return BarChartGroupData(
                  x: e.key,
                  barRods: [
                    BarChartRodData(
                      toY: e.value.count.toDouble(),
                      width: isTouched ? 22 : 18,
                      borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(6)),
                      gradient: LinearGradient(
                        colors: isTouched
                            ? [color, color.withOpacity(0.6)]
                            : [color.withOpacity(0.85), color.withOpacity(0.45)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Ranking list với Load More ───────────────────────────────────────────────
  Widget _buildRankingListWithLoadMore(List<_LocationData> data) {
    final color      = _tabColor(selectedTab);
    final visible    = _visibleCount[selectedTab] ?? _defaultVisible;
    // Số item đang hiển thị thực tế (không vượt quá total)
    final showCount  = visible.clamp(0, data.length);
    final hasMore    = showCount < data.length;
    final remaining  = data.length - showCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.format_list_numbered_rounded,
                    color: color, size: 18),
                const SizedBox(width: 6),
                Text(
                  'Bảng xếp hạng',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Colors.grey[800]),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Top ${data.length} ${_levelLabel().toLowerCase()}',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // ── Animated list ────────────────────────────────────
        AnimatedSize(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
          child: Column(
            children: [
              ...data.take(showCount).toList().asMap().entries.map((e) =>
                  _buildRankRow(e.key + 1, e.value, data.first.count)),
            ],
          ),
        ),

        // ── Load more / Collapse buttons ─────────────────────
        const SizedBox(height: 8),
        if (hasMore) ...[
          _buildLoadMoreButton(
            label: 'Xem thêm ${ remaining > _loadMoreStep ? _loadMoreStep : remaining} khu vực',
            sublabel: 'Còn $remaining chưa hiển thị',
            color: color,
            onTap: () {
              setState(() {
                _visibleCount[selectedTab] =
                    (visible + _loadMoreStep).clamp(0, data.length);
              });
            },
          ),
        ],
        // Nút thu gọn (chỉ show khi đã mở rộng hơn mặc định)
        if (showCount > _defaultVisible) ...[
          const SizedBox(height: 6),
          _buildCollapseButton(
            color: color,
            onTap: () {
              setState(() {
                _visibleCount[selectedTab] = _defaultVisible;
              });
            },
          ),
        ],
      ],
    );
  }

  Widget _buildLoadMoreButton({
    required String label,
    required String sublabel,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.08), color.withOpacity(0.04)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.keyboard_arrow_down_rounded, color: color, size: 22),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: color),
                ),
                Text(
                  sublabel,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollapseButton({
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.keyboard_arrow_up_rounded,
                color: Colors.grey[600], size: 20),
            const SizedBox(width: 6),
            Text(
              'Thu gọn',
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Rank row ─────────────────────────────────────────────────────────────────
  Widget _buildRankRow(int rank, _LocationData item, int maxCount) {
    final color  = _tabColor(selectedTab);
    final double pct = maxCount > 0 ? item.count / maxCount : 0.0;

    Color rankColor;
    if (rank == 1)      rankColor = Colors.amber[600]!;
    else if (rank == 2) rankColor = Colors.blueGrey[400]!;
    else if (rank == 3) rankColor = Colors.brown[400]!;
    else                rankColor = Colors.grey[400]!;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: rank <= 3 ? rankColor.withOpacity(0.06) : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: rank <= 3 ? rankColor.withOpacity(0.2) : Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 32,
                child: rank <= 3
                    ? Icon(Icons.emoji_events_rounded, color: rankColor, size: 22)
                    : Center(
                    child: Text('$rank',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[500]))),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.fullName,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    if (item.avgPrice > 0)
                      Text('Giá TB: ${_fmtPrice(item.avgPrice)}',
                          style:
                          TextStyle(fontSize: 11, color: Colors.grey[600])),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${item.count}',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: rank <= 3 ? rankColor : Colors.grey[700])),
                  Text('BĐS',
                      style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                rank == 1 ? color : color.withOpacity(0.4 + pct * 0.5),
              ),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Empty state ─────────────────────────────────────────────────────────────
  Widget _buildEmptyState(String message) {
    return SizedBox(
      height: 160,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off_rounded, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(message,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey[500])),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────────
  String _levelLabel() {
    switch (selectedTab) {
      case 'cities':    return 'Tỉnh/TP';
      case 'districts': return 'Quận/Huyện';
      case 'wards':     return 'Phường/Xã';
      default:          return 'Khu vực';
    }
  }

  String _emptyMessage() {
    final level = _levelLabel().toLowerCase();
    if (widget.filteredWard     != null) return 'Không có dữ liệu $level\ntrong "${widget.filteredWard}"';
    if (widget.filteredDistrict != null) return 'Không có dữ liệu $level\ntrong "${widget.filteredDistrict}"';
    if (widget.filteredProvince != null) return 'Không có dữ liệu $level\ntrong "${widget.filteredProvince}"';
    return 'Không có dữ liệu $level';
  }

  String _fmtPrice(double price) {
    if (price >= 1000000000) return '${(price / 1000000000).toStringAsFixed(1)} tỷ';
    if (price >= 1000000)     return '${(price / 1000000).toStringAsFixed(0)} tr';
    if (price >= 1000)         return '${(price / 1000).toStringAsFixed(0)}K';
    return price.toStringAsFixed(0);
  }

  String _fmtCount(int count) {
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '$count';
  }

  int    _toInt(dynamic v)    { if (v is int) return v; if (v is double) return v.toInt(); if (v is String) return int.tryParse(v) ?? 0; return 0; }
  double _toDouble(dynamic v) { if (v is double) return v; if (v is int) return v.toDouble(); if (v is String) return double.tryParse(v) ?? 0.0; return 0.0; }
}

class _LocationData {
  final String name;
  final String fullName;
  final int    count;
  final double avgPrice;

  _LocationData({
    required this.name,
    required this.fullName,
    required this.count,
    required this.avgPrice,
  });
}