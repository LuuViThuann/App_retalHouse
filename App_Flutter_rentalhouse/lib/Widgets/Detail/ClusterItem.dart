// marker_cluster_helper.dart
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_rentalhouse/models/rental.dart';

class ClusterItem {
  final String id;
  final LatLng position;
  final Rental rental;

  ClusterItem({
    required this.id,
    required this.position,
    required this.rental,
  });
}

class Cluster {
  final String id;
  final LatLng center;
  final List<ClusterItem> items;
  int get size => items.length;

  Cluster({
    required this.id,
    required this.center,
    required this.items,
  });
}

class MarkerClusterHelper {
  // Cấu hình clustering
  static const int _minClusterSize = 2;
  static const double _clusterRadius = 120.0; // pixels

  // Tính khoảng cách giữa 2 điểm trên bản đồ (Haversine)
  static double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000; // meters

    final lat1 = point1.latitude * math.pi / 180;
    final lat2 = point2.latitude * math.pi / 180;
    final deltaLat = (point2.latitude - point1.latitude) * math.pi / 180;
    final deltaLng = (point2.longitude - point1.longitude) * math.pi / 180;

    final a = math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1) * math.cos(lat2) *
            math.sin(deltaLng / 2) * math.sin(deltaLng / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  // Tính khoảng cách pixel giữa 2 điểm dựa trên zoom level
  static double _pixelDistance(LatLng point1, LatLng point2, double zoomLevel) {
    final distance = _calculateDistance(point1, point2);
    final metersPerPixel = 156543.03392 * math.cos(point1.latitude * math.pi / 180) / math.pow(2, zoomLevel);
    return distance / metersPerPixel;
  }

  // Tạo clusters từ danh sách items
  static List<Cluster> createClusters({
    required List<ClusterItem> items,
    required double zoomLevel,
  }) {
    if (items.isEmpty) return [];

    // Nếu zoom lớn (> 15), không cluster
    if (zoomLevel > 15) {
      return items.map((item) => Cluster(
        id: 'single-${item.id}',
        center: item.position,
        items: [item],
      )).toList();
    }

    final List<Cluster> clusters = [];
    final List<ClusterItem> remainingItems = List.from(items);

    while (remainingItems.isNotEmpty) {
      final ClusterItem currentItem = remainingItems.removeAt(0);
      final List<ClusterItem> clusterItems = [currentItem];

      // Tìm các items gần đây để gom vào cluster
      remainingItems.removeWhere((item) {
        final pixelDist = _pixelDistance(
          currentItem.position,
          item.position,
          zoomLevel,
        );

        if (pixelDist <= _clusterRadius) {
          clusterItems.add(item);
          return true;
        }
        return false;
      });

      // Tính tâm cluster (trung bình tọa độ)
      double sumLat = 0;
      double sumLng = 0;
      for (var item in clusterItems) {
        sumLat += item.position.latitude;
        sumLng += item.position.longitude;
      }

      final center = LatLng(
        sumLat / clusterItems.length,
        sumLng / clusterItems.length,
      );

      clusters.add(Cluster(
        id: 'cluster-${clusters.length}',
        center: center,
        items: clusterItems,
      ));
    }

    return clusters;
  }

  // Tạo cluster marker icon
  // Tạo cluster marker icon
  static Future<BitmapDescriptor> createClusterMarker({
    required int clusterSize,
    bool hasAI = false,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // ── ĐIỀU CHỈNH KÍCH THƯỚC TO HƠN, DỄ NHÌN ───────────────────────────────
    final double baseSize = 100.0;
    final double growthFactor = 4.0;
    final double maxSize = 200.0;

    double size = baseSize + (clusterSize * growthFactor);
    size = size.clamp(baseSize, maxSize);
    // ───────────────────────────────────────────────────────────────────────────

    // Màu gradient (giữ nguyên)
    List<Color> gradientColors;
    if (hasAI) {
      gradientColors = [
        const Color(0xFF6C63FF),
        const Color(0xFF00D4FF),
      ];
    } else {
      gradientColors = [
        const Color(0xFF00B894),
        const Color(0xFF00D2A0),
      ];
    }

    // Shadow (tăng blur một chút vì size to hơn)
    final shadowPath = Path()
      ..addOval(Rect.fromCircle(
        center: Offset(size / 2 + 3, size / 2 + 3),  // dịch shadow nhẹ hơn
        radius: size / 2,
      ));

    canvas.drawPath(
      shadowPath,
      Paint()
        ..color = Colors.transparent.withOpacity(0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),  // tăng blur nhẹ
    );

    // Outer circle với gradient
    final outerRect = Rect.fromCircle(
      center: Offset(size / 2, size / 2),
      radius: size / 2,
    );

    final gradientPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(size / 2, size / 2),
        size / 2,
        gradientColors,
      );

    canvas.drawCircle(
      Offset(size / 2, size / 2),
      size / 2,
      gradientPaint,
    );

    // Border trắng (tăng độ dày viền vì size to hơn)
    canvas.drawCircle(
      Offset(size / 2, size / 2),
      size / 2,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6,  // tăng từ 4 lên 6
    );

    // Inner circle trắng
    canvas.drawCircle(
      Offset(size / 2, size / 2),
      size / 2 - 10,  // tăng khoảng cách viền trong (từ -8 lên -10)
      Paint()..color = Colors.white,
    );

    // Số lượng - tăng font size tương ứng
    final textPainter = TextPainter(
      text: TextSpan(
        text: clusterSize.toString(),
        style: TextStyle(
          color: gradientColors[0],
          fontSize: size / 2.8,          // tăng font (từ /3 lên /2.8 để to hơn)
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size - textPainter.width) / 2,
        (size - textPainter.height) / 2 - 2,  // dịch lên nhẹ cho cân đối
      ),
    );

    // AI badge (tăng size badge)
    if (hasAI) {
      final badgeSize = size / 3.5;  // tăng từ /4 lên /3.5
      final badgeCenter = Offset(size - badgeSize / 2, badgeSize / 2);

      canvas.drawCircle(
        badgeCenter,
        badgeSize / 2,
        Paint()..color = Colors.white,
      );

      canvas.drawCircle(
        badgeCenter,
        badgeSize / 2 - 3,
        Paint()..color = const Color(0xFF6C63FF),
      );

      final badgeText = TextPainter(
        text: const TextSpan(
          text: '🤖',
          style: TextStyle(fontSize: 18),  // tăng từ 12 lên 18
        ),
        textDirection: ui.TextDirection.ltr,
      );

      badgeText.layout();
      badgeText.paint(
        canvas,
        Offset(
          badgeCenter.dx - badgeText.width / 2,
          badgeCenter.dy - badgeText.height / 2,
        ),
      );
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }
}