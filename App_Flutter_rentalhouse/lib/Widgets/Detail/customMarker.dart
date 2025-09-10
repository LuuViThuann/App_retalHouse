import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

class CustomMarkerHelper {
  static Future<BitmapDescriptor> createCustomMarker({
    required double price,
    required String propertyType,
    required bool isMainRental,
    required bool hasValidCoords,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Kích thước marker
    const double width = 200;
    const double height = 80;

    // Màu sắc theo loại
    Color backgroundColor;
    Color textColor = Colors.white;

    if (!hasValidCoords) {
      backgroundColor = Colors.orange.shade600;
    } else if (isMainRental) {
      backgroundColor = Colors.red.shade600;
    } else {
      backgroundColor = Colors.blue.shade600;
    }

    // Vẽ background rounded rectangle
    final paint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    const radius = Radius.circular(20);
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, width, height),
      radius,
    );

    // Vẽ shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    final shadowRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(2, 2, width, height),
      radius,
    );
    canvas.drawRRect(shadowRect, shadowPaint);

    // Vẽ background chính
    canvas.drawRRect(rect, paint);
    canvas.drawRRect(rect, borderPaint);

    // Format giá
    String priceText = _formatPrice(price);

    // Vẽ text
    final textPainter = TextPainter(
      text: TextSpan(
        text: priceText,
        style: TextStyle(
          color: textColor,
          fontSize: 30,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    );

    textPainter.layout();

    // Căn giữa text
    final textOffset = Offset(
      (width - textPainter.width) / 2,
      (height - textPainter.height) / 2,
    );

    textPainter.paint(canvas, textOffset);

    // Vẽ tam giác nhỏ ở dưới (pointer)
    final trianglePath = Path();
    trianglePath.moveTo(width / 2 - 5, height);
    trianglePath.lineTo(width / 2, height + 8);
    trianglePath.lineTo(width / 2 + 5, height);
    trianglePath.close();

    canvas.drawPath(trianglePath, paint);
    canvas.drawPath(trianglePath, borderPaint);

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), (height + 10).toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  static String _formatPrice(double price) {
    if (price >= 1000000000) {
      return '${(price / 1000000000).toStringAsFixed(1)}B VNĐ';
    } else if (price >= 1000000) {
      return '${(price / 1000000).toStringAsFixed(1)}M VNĐ';
    } else if (price >= 1000) {
      return '${(price / 1000).toStringAsFixed(0)}K VNĐ';
    } else {
      return '${price.toStringAsFixed(0)} VNĐ';
    }
  }
}
