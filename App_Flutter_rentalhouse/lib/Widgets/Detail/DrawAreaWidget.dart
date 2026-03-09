// ============================================================
// FILE: Widgets/Detail/DrawAreaWidget.dart
// Tính năng: Vẽ vùng tìm kiếm tự do trên bản đồ
// ============================================================

import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// ============================================================
// ENUM & MODEL
// ============================================================

enum DrawMode { none, freehand, polygon }

class DrawAreaResult {
  final List<LatLng> polygon;
  final LatLng center;
  final double approximateRadiusKm;
  final int rentalCount;

  DrawAreaResult({
    required this.polygon,
    required this.center,
    required this.approximateRadiusKm,
    this.rentalCount = 0,
  });
}

// ============================================================
// HELPER: Point in Polygon (Ray Casting Algorithm)
// ============================================================
class DrawAreaHelper {
  /// Kiểm tra một LatLng có nằm trong polygon không
  static bool isPointInPolygon(LatLng point, List<LatLng> polygon) {
    if (polygon.length < 3) return false;

    bool inside = false;
    int j = polygon.length - 1;

    for (int i = 0; i < polygon.length; i++) {
      final double xi = polygon[i].longitude;
      final double yi = polygon[i].latitude;
      final double xj = polygon[j].longitude;
      final double yj = polygon[j].latitude;

      final bool intersect =
          ((yi > point.latitude) != (yj > point.latitude)) &&
              (point.longitude < (xj - xi) * (point.latitude - yi) / (yj - yi) + xi);

      if (intersect) inside = !inside;
      j = i;
    }

    return inside;
  }

  /// Tính tâm của polygon
  static LatLng calculateCenter(List<LatLng> polygon) {
    if (polygon.isEmpty) return const LatLng(0, 0);
    double lat = 0, lng = 0;
    for (final p in polygon) {
      lat += p.latitude;
      lng += p.longitude;
    }
    return LatLng(lat / polygon.length, lng / polygon.length);
  }

  /// Tính bán kính xấp xỉ (km) của vùng vẽ
  static double calculateApproximateRadius(List<LatLng> polygon) {
    if (polygon.isEmpty) return 0;
    final center = calculateCenter(polygon);
    double maxDist = 0;
    for (final p in polygon) {
      final dist = _haversineDistance(center, p);
      if (dist > maxDist) maxDist = dist;
    }
    return maxDist;
  }

  static double _haversineDistance(LatLng a, LatLng b) {
    const R = 6371.0;
    final dLat = _deg2rad(b.latitude - a.latitude);
    final dLon = _deg2rad(b.longitude - a.longitude);
    final x = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(a.latitude)) *
            math.cos(_deg2rad(b.latitude)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(x), math.sqrt(1 - x));
    return R * c;
  }

  static double _deg2rad(double deg) => deg * (math.pi / 180);

  /// Đơn giản hóa polygon (giảm số điểm) theo thuật toán Ramer–Douglas–Peucker
  static List<LatLng> simplifyPolygon(List<LatLng> points,
      {double epsilon = 0.00005}) {
    if (points.length <= 2) return points;
    return _rdpReduce(points, epsilon);
  }

  static List<LatLng> _rdpReduce(List<LatLng> points, double epsilon) {
    if (points.length <= 2) return points;

    double maxDist = 0;
    int maxIndex = 0;
    final first = points.first;
    final last = points.last;

    for (int i = 1; i < points.length - 1; i++) {
      final dist = _perpendicularDist(points[i], first, last);
      if (dist > maxDist) {
        maxDist = dist;
        maxIndex = i;
      }
    }

    if (maxDist > epsilon) {
      final left = _rdpReduce(points.sublist(0, maxIndex + 1), epsilon);
      final right = _rdpReduce(points.sublist(maxIndex), epsilon);
      return [...left.sublist(0, left.length - 1), ...right];
    }

    return [first, last];
  }

  static double _perpendicularDist(LatLng p, LatLng a, LatLng b) {
    final double dx = b.longitude - a.longitude;
    final double dy = b.latitude - a.latitude;
    final double num =
    (dy * p.longitude - dx * p.latitude + b.longitude * a.latitude - b.latitude * a.longitude)
        .abs();
    final double den = math.sqrt(dy * dy + dx * dx);
    return den == 0 ? 0 : num / den;
  }

  /// Chuyển đổi điểm màn hình → LatLng (cần visible region)
  static LatLng screenToLatLng(
      Offset screenPoint,
      LatLngBounds visibleRegion,
      Size screenSize,
      ) {
    final double lat = visibleRegion.northeast.latitude -
        (screenPoint.dy / screenSize.height) *
            (visibleRegion.northeast.latitude - visibleRegion.southwest.latitude);
    final double lng = visibleRegion.southwest.longitude +
        (screenPoint.dx / screenSize.width) *
            (visibleRegion.northeast.longitude - visibleRegion.southwest.longitude);
    return LatLng(lat, lng);
  }
}

// ============================================================
// PAINTER: Vẽ đường và vùng lên Canvas
// ============================================================
class DrawAreaPainter extends CustomPainter {
  final List<Offset> points;
  final DrawMode mode;
  final List<Offset>? polygonPoints; // Cho polygon mode
  final bool isCompleted;
  final Color strokeColor;
  final Color fillColor;

  DrawAreaPainter({
    required this.points,
    required this.mode,
    this.polygonPoints,
    this.isCompleted = false,
    this.strokeColor = const Color(0xFF2E7D32),
    this.fillColor = const Color(0x3326A69A),
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty && (polygonPoints == null || polygonPoints!.isEmpty)) {
      return;
    }

    final strokePaint = Paint()
      ..color = strokeColor
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    final dashPaint = Paint()
      ..color = strokeColor.withOpacity(0.5)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    if (mode == DrawMode.freehand) {
      _drawFreehand(canvas, size, strokePaint, fillPaint);
    } else if (mode == DrawMode.polygon) {
      _drawPolygon(canvas, size, strokePaint, fillPaint, dashPaint);
    }
  }

  void _drawFreehand(
      Canvas canvas, Size size, Paint strokePaint, Paint fillPaint) {
    if (points.length < 2) return;

    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);

    for (int i = 1; i < points.length - 1; i++) {
      final mid = Offset(
        (points[i].dx + points[i + 1].dx) / 2,
        (points[i].dy + points[i + 1].dy) / 2,
      );
      path.quadraticBezierTo(points[i].dx, points[i].dy, mid.dx, mid.dy);
    }
    path.lineTo(points.last.dx, points.last.dy);

    if (isCompleted) {
      path.close();
      // Vẽ fill trước
      canvas.drawPath(path, fillPaint);
      // Vẽ viền với hiệu ứng glow
      final glowPaint = Paint()
        ..color = strokeColor.withOpacity(0.3)
        ..strokeWidth = 8.0
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawPath(path, glowPaint);
    }

    canvas.drawPath(path, strokePaint);

    // Vẽ điểm đầu
    canvas.drawCircle(
      points.first,
      5,
      Paint()..color = strokeColor,
    );
  }

  void _drawPolygon(Canvas canvas, Size size, Paint strokePaint, Paint fillPaint,
      Paint dashPaint) {
    final displayPoints = polygonPoints ?? points;
    if (displayPoints.isEmpty) return;

    if (displayPoints.length >= 2) {
      final path = Path();
      path.moveTo(displayPoints.first.dx, displayPoints.first.dy);
      for (int i = 1; i < displayPoints.length; i++) {
        path.lineTo(displayPoints[i].dx, displayPoints[i].dy);
      }

      if (isCompleted) {
        path.close();
        canvas.drawPath(path, fillPaint);
        // Glow
        final glowPaint = Paint()
          ..color = strokeColor.withOpacity(0.3)
          ..strokeWidth = 8.0
          ..style = PaintingStyle.stroke
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        canvas.drawPath(path, glowPaint);
        canvas.drawPath(path, strokePaint);
      } else {
        canvas.drawPath(path, strokePaint);
        // Đường đứt từ điểm cuối về điểm đầu (preview)
        _drawDashedLine(
          canvas,
          displayPoints.last,
          displayPoints.first,
          dashPaint,
        );
      }
    }

    // Vẽ điểm vertex
    for (int i = 0; i < displayPoints.length; i++) {
      final isFirst = i == 0;
      final dotPaint = Paint()
        ..color = isFirst ? strokeColor : strokeColor.withOpacity(0.8);
      final outerPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;

      canvas.drawCircle(displayPoints[i], isFirst ? 10 : 7, outerPaint);
      canvas.drawCircle(displayPoints[i], isFirst ? 8 : 5, dotPaint);

      if (isFirst && !isCompleted) {
        // Vòng tròn nháy ở điểm đầu để hint "bấm để hoàn thành"
        final hintPaint = Paint()
          ..color = strokeColor.withOpacity(0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
        canvas.drawCircle(displayPoints[i], 15, hintPaint);
      }
    }
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const dashLength = 8.0;
    const dashGap = 5.0;
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final distance = math.sqrt(dx * dx + dy * dy);
    final steps = distance / (dashLength + dashGap);
    final stepX = dx / steps;
    final stepY = dy / steps;

    Offset current = p1;
    bool drawing = true;

    double traveled = 0;
    while (traveled < distance) {
      final next = Offset(
        current.dx + stepX * (dashLength / (dashLength + dashGap)),
        current.dy + stepY * (dashLength / (dashLength + dashGap)),
      );
      if (drawing) canvas.drawLine(current, next, paint);
      current = Offset(
        current.dx + stepX,
        current.dy + stepY,
      );
      traveled += dashLength + dashGap;
      drawing = !drawing;
    }
  }

  @override
  bool shouldRepaint(DrawAreaPainter oldDelegate) => true;
}

// ============================================================
// WIDGET CHÍNH: DrawAreaOverlay
// Overlay hiển thị lên trên GoogleMap
// ============================================================
class DrawAreaOverlay extends StatefulWidget {
  final GoogleMapController? mapController;
  final DrawMode drawMode;
  final Function(DrawAreaResult) onAreaCompleted;
  final VoidCallback onCancel;

  const DrawAreaOverlay({
    super.key,
    required this.mapController,
    required this.drawMode,
    required this.onAreaCompleted,
    required this.onCancel,
  });

  @override
  State<DrawAreaOverlay> createState() => _DrawAreaOverlayState();
}

class _DrawAreaOverlayState extends State<DrawAreaOverlay>
    with SingleTickerProviderStateMixin {
  List<Offset> _screenPoints = [];
  List<LatLng> _latLngPoints = [];
  List<Offset> _polygonScreenPoints = [];
  List<LatLng> _polygonLatLngPoints = [];
  bool _isDrawing = false;
  bool _isCompleted = false;
  LatLngBounds? _visibleRegion;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  String _hintText = '';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation =
        Tween<double>(begin: 0.6, end: 1.0).animate(_pulseController);

    _updateHint();
    _fetchVisibleRegion();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _updateHint() {
    if (widget.drawMode == DrawMode.freehand) {
      _hintText = _isCompleted
          ? 'Vùng đã hoàn thành!'
          : (_isDrawing ? 'Kéo để vẽ vùng...' : 'Chạm và kéo để vẽ vùng');
    } else {
      _hintText = _isCompleted
          ? 'Đa giác đã hoàn thành!'
          : (_polygonScreenPoints.isEmpty
          ? 'Nhấn để thêm điểm'
          : _polygonScreenPoints.length < 3
          ? 'Thêm ít nhất 3 điểm (${_polygonScreenPoints.length}/3)'
          : 'Nhấn điểm đầu tiên để đóng vùng');
    }
    setState(() {});
  }

  Future<void> _fetchVisibleRegion() async {
    if (widget.mapController == null) return;
    try {
      _visibleRegion = await widget.mapController!.getVisibleRegion();
    } catch (_) {}
  }

  LatLng? _screenToLatLng(Offset screenPoint) {
    if (_visibleRegion == null) return null;
    final size = MediaQuery.of(context).size;
    // Trừ appBar height (~56), status bar
    final adjustedY = screenPoint.dy;
    return DrawAreaHelper.screenToLatLng(
      Offset(screenPoint.dx, adjustedY),
      _visibleRegion!,
      size,
    );
  }

  // ── FREEHAND HANDLERS ──────────────────────────────────
  void _onFreehandStart(DragStartDetails details) async {
    await _fetchVisibleRegion();
    setState(() {
      _screenPoints = [details.localPosition];
      _latLngPoints = [];
      _isDrawing = true;
      _isCompleted = false;
    });
    _updateHint();
  }

  void _onFreehandUpdate(DragUpdateDetails details) {
    if (!_isDrawing) return;
    setState(() {
      _screenPoints.add(details.localPosition);
    });
  }

  void _onFreehandEnd(DragEndDetails details) async {
    if (_screenPoints.length < 10) {
      setState(() {
        _screenPoints = [];
        _isDrawing = false;
      });
      _updateHint();
      return;
    }

    // Chuyển đổi sang LatLng
    await _fetchVisibleRegion();
    final size = MediaQuery.of(context).size;

    List<LatLng> rawLatLngs = [];
    for (final sp in _screenPoints) {
      if (_visibleRegion != null) {
        rawLatLngs.add(DrawAreaHelper.screenToLatLng(sp, _visibleRegion!, size));
      }
    }

    // Đơn giản hóa polygon
    final simplified = DrawAreaHelper.simplifyPolygon(rawLatLngs);

    setState(() {
      _latLngPoints = simplified;
      _isDrawing = false;
      _isCompleted = true;
    });
    _updateHint();

    // Callback
    final center = DrawAreaHelper.calculateCenter(_latLngPoints);
    final radius = DrawAreaHelper.calculateApproximateRadius(_latLngPoints);
    widget.onAreaCompleted(DrawAreaResult(
      polygon: _latLngPoints,
      center: center,
      approximateRadiusKm: radius,
    ));
  }

  // ── POLYGON HANDLERS ───────────────────────────────────
  void _onPolygonTap(TapUpDetails details) async {
    if (_isCompleted) return;
    await _fetchVisibleRegion();
    final size = MediaQuery.of(context).size;

    final tapPoint = details.localPosition;

    // Kiểm tra tap vào điểm đầu để đóng polygon
    if (_polygonScreenPoints.length >= 3) {
      final first = _polygonScreenPoints.first;
      final dist = (tapPoint - first).distance;
      if (dist < 25) {
        // Đóng polygon
        setState(() {
          _isCompleted = true;
        });
        _updateHint();

        final center = DrawAreaHelper.calculateCenter(_polygonLatLngPoints);
        final radius =
        DrawAreaHelper.calculateApproximateRadius(_polygonLatLngPoints);
        widget.onAreaCompleted(DrawAreaResult(
          polygon: _polygonLatLngPoints,
          center: center,
          approximateRadiusKm: radius,
        ));
        return;
      }
    }

    // Thêm điểm mới
    LatLng? latLng;
    if (_visibleRegion != null) {
      latLng = DrawAreaHelper.screenToLatLng(tapPoint, _visibleRegion!, size);
    }

    setState(() {
      _polygonScreenPoints.add(tapPoint);
      if (latLng != null) _polygonLatLngPoints.add(latLng);
    });
    _updateHint();
  }

  void _undoLastPoint() {
    if (_polygonScreenPoints.isNotEmpty) {
      setState(() {
        _polygonScreenPoints.removeLast();
        if (_polygonLatLngPoints.isNotEmpty) _polygonLatLngPoints.removeLast();
      });
      _updateHint();
    }
  }

  void _reset() {
    setState(() {
      _screenPoints = [];
      _latLngPoints = [];
      _polygonScreenPoints = [];
      _polygonLatLngPoints = [];
      _isDrawing = false;
      _isCompleted = false;
    });
    _updateHint();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ── Semi-transparent overlay ──
        Container(
          color: Colors.black.withOpacity(0.08),
        ),

        // ── Drawing canvas ──
        if (widget.drawMode == DrawMode.freehand)
          GestureDetector(
            onPanStart: _onFreehandStart,
            onPanUpdate: _onFreehandUpdate,
            onPanEnd: _onFreehandEnd,
            child: CustomPaint(
              painter: DrawAreaPainter(
                points: _screenPoints,
                mode: DrawMode.freehand,
                isCompleted: _isCompleted,
              ),
              child: Container(color: Colors.transparent),
            ),
          )
        else if (widget.drawMode == DrawMode.polygon)
          GestureDetector(
            onTapUp: _onPolygonTap,
            child: CustomPaint(
              painter: DrawAreaPainter(
                points: _polygonScreenPoints,
                mode: DrawMode.polygon,
                polygonPoints: _polygonScreenPoints,
                isCompleted: _isCompleted,
              ),
              child: Container(color: Colors.transparent),
            ),
          ),

        // ── TOP: Header bar ──
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _buildHeaderBar(),
        ),

        // ── CENTER: Hint text ──
        if (!_isCompleted)
          Positioned(
            top: 70,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (_, __) => Opacity(
                  opacity: _pulseAnimation.value,
                  child: Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.65),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _hintText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

        // ── BOTTOM: Controls ──
        Positioned(
          bottom: 240,
          left: 0,
          right: 0,
          child: _buildBottomControls(),
        ),
      ],
    );
  }

  Widget _buildHeaderBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.75),
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.draw, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Vẽ vùng tìm kiếm',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  widget.drawMode == DrawMode.freehand
                      ? 'Chế độ vẽ tự do'
                      : 'Chế độ đa giác',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const Spacer(),
            // Nút hủy
            GestureDetector(
              onTap: widget.onCancel,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white30),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.close, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Hủy',
                      style: TextStyle(color: Colors.white, fontSize: 13),
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

  Widget _buildBottomControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Nút Undo (chỉ polygon mode)
          if (widget.drawMode == DrawMode.polygon &&
              _polygonScreenPoints.isNotEmpty &&
              !_isCompleted)
            _buildCircleButton(
              icon: Icons.undo,
              label: 'Hoàn tác',
              onTap: _undoLastPoint,
              color: Colors.orange[700]!,
            ),

          const SizedBox(width: 12),

          // Nút Reset
          if (_screenPoints.isNotEmpty ||
              _polygonScreenPoints.isNotEmpty ||
              _isCompleted)
            _buildCircleButton(
              icon: Icons.refresh,
              label: 'Vẽ lại',
              onTap: _reset,
              color: Colors.red[600]!,
            ),

          // Nút hoàn thành polygon thủ công
          if (widget.drawMode == DrawMode.polygon &&
              _polygonScreenPoints.length >= 3 &&
              !_isCompleted) ...[
            const SizedBox(width: 12),
            _buildCircleButton(
              icon: Icons.check,
              label: 'Xong',
              onTap: () async {
                setState(() => _isCompleted = true);
                _updateHint();
                final center =
                DrawAreaHelper.calculateCenter(_polygonLatLngPoints);
                final radius = DrawAreaHelper.calculateApproximateRadius(
                    _polygonLatLngPoints);
                widget.onAreaCompleted(DrawAreaResult(
                  polygon: _polygonLatLngPoints,
                  center: center,
                  approximateRadiusKm: radius,
                ));
              },
              color: const Color(0xFF2E7D32),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// WIDGET: DrawModeSelector
// Hiển thị dialog chọn chế độ vẽ
// ============================================================
class DrawModeSelector extends StatelessWidget {
  final VoidCallback onFreehand;
  final VoidCallback onPolygon;
  final VoidCallback onCancel;

  const DrawModeSelector({
    super.key,
    required this.onFreehand,
    required this.onPolygon,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              const Icon(Icons.draw_outlined, color: Color(0xFF2E7D32), size: 24),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vẽ vùng tìm kiếm',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Chọn cách vẽ vùng trên bản đồ',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onCancel,
                icon: const Icon(Icons.close),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Option 1: Freehand
          _buildModeOption(
            icon: Icons.gesture,
            title: 'Vẽ tự do',
            description: 'Kéo ngón tay để vẽ vùng bất kỳ',
            color: const Color(0xFF2E7D32),
            onTap: onFreehand,
          ),

          const SizedBox(height: 16),

          // Option 2: Polygon
          _buildModeOption(
            icon: Icons.pentagon_outlined,
            title: 'Vẽ đa giác',
            description: 'Nhấn từng điểm để tạo vùng chính xác hơn',
            color: const Color(0xFF1565C0),
            onTap: onPolygon,
          ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildModeOption({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.25), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color, size: 20),
          ],
        ),
      ),
    );
  }
}