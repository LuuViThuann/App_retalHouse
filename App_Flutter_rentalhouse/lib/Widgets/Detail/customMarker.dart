// customMarker.dart - CẬP NHẬT để hỗ trợ AI badge

import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class CustomMarkerHelper {
  static Future<BitmapDescriptor> createCustomMarker({
    required double price,
    required String propertyType,
    required bool isMainRental,
    required bool hasValidCoords,
    bool isAIRecommended = false,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    const double width = 230;
    const double height = 98;
    const double padding = 14;
    const double iconSize = 28;

    // 🔥 Màu sắc gradient - THÊM màu cho AI
    List<Color> gradientColors;
    Color borderColor;
    Color iconColor;

    if (isAIRecommended) {
      //  AI Recommendation - Màu tím/xanh lam đặc biệt
      gradientColors = [
        const Color(0xFF6C63FF), // Tím
        const Color(0xFF00D4FF), // Xanh lam
      ];
      borderColor = const Color(0xFF6C63FF);
      iconColor = Colors.white;
    } else if (!hasValidCoords) {
      gradientColors = [
        const Color(0xFFFF6B35),
        const Color(0xFFFF9234),
      ];
      borderColor = const Color(0xFFFF6B35);
      iconColor = Colors.white;
    } else if (isMainRental) {
      gradientColors = [
        const Color(0xFFE74C3C),
        const Color(0xFFF85032),
      ];
      borderColor = const Color(0xFFE74C3C);
      iconColor = Colors.white;
    } else {
      gradientColors = [
        const Color(0xFF00B894),
        const Color(0xFF00D2A0),
      ];
      borderColor = const Color(0xFF00B894);
      iconColor = Colors.white;
    }

    // Shadow
    final shadowPath = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(3, 3, width, height),
        const Radius.circular(height / 2),
      ));

    canvas.drawPath(
      shadowPath,
      Paint()
        ..color = Colors.black.withOpacity(0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Background gradient
    final rect = Rect.fromLTWH(0, 0, width, height);
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(height / 2),
    );

    final gradientPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, 0),
        Offset(width, height),
        gradientColors,
      );

    canvas.drawRRect(rrect, gradientPaint);

    // Border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawRRect(rrect, borderPaint);

    // Highlight effect
    final highlightRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(3, 3, width - 6, height / 2 - 3),
      const Radius.circular(height / 2),
    );

    canvas.drawRRect(
      highlightRect,
      Paint()
        ..color = Colors.white.withOpacity(0.2)
        ..style = PaintingStyle.fill,
    );

    // Icon nhà
    final iconPath = Path();
    const iconLeft = padding;
    const iconTop = (height - iconSize) / 2;

    iconPath.moveTo(iconLeft + iconSize / 2, iconTop);
    iconPath.lineTo(iconLeft + iconSize, iconTop + iconSize / 3);
    iconPath.lineTo(iconLeft + iconSize, iconTop + iconSize);
    iconPath.lineTo(iconLeft, iconTop + iconSize);
    iconPath.lineTo(iconLeft, iconTop + iconSize / 3);
    iconPath.close();

    canvas.drawPath(
      iconPath,
      Paint()
        ..color = iconColor
        ..style = PaintingStyle.fill,
    );

    // Cửa nhà
    canvas.drawRect(
      Rect.fromLTWH(
        iconLeft + iconSize / 3,
        iconTop + iconSize / 2,
        iconSize / 3,
        iconSize / 2,
      ),
      Paint()..color = borderColor,
    );

    // Giá tiền
    String priceText = _formatPriceModern(price);

    final textPainter = TextPainter(
      text: TextSpan(
        text: priceText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 35,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
          shadows: [
            Shadow(
              color: Colors.black26,
              offset: Offset(0, 1),
              blurRadius: 2,
            ),
          ],
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    );

    textPainter.layout();

    final textOffset = Offset(
      iconLeft + iconSize + 8,
      (height - textPainter.height) / 2,
    );

    textPainter.paint(canvas, textOffset);

    // Pointer triangle
    final pointerPath = Path();
    const pointerWidth = 20.0;
    const pointerHeight = 14.0;

    pointerPath.moveTo(width / 2 - pointerWidth / 2, height);
    pointerPath.lineTo(width / 2, height + pointerHeight);
    pointerPath.lineTo(width / 2 + pointerWidth / 2, height);
    pointerPath.close();

    final pointerPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(width / 2, height),
        Offset(width / 2, height + pointerHeight),
        [gradientColors[0], gradientColors[1].withOpacity(0.8)],
      );

    canvas.drawPath(pointerPath, pointerPaint);

    canvas.drawPath(
      pointerPath,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // 🔥 BADGE - CẬP NHẬT để hiển thị AI icon
    if (isAIRecommended || isMainRental || !hasValidCoords) {
      const badgeSize = 28.0; // Tăng size cho dễ nhìn
      final badgeCenter = Offset(width - badgeSize / 2 - 5, badgeSize / 2 + 5);

      // Badge background
      canvas.drawCircle(
        badgeCenter,
        badgeSize / 2,
        Paint()..color = Colors.white,
      );

      Color badgeColor;
      String badgeIcon;

      if (isAIRecommended) {
        badgeColor = const Color(0xFF6C63FF); // Tím cho AI
        badgeIcon = '🤖'; // Robot emoji
      } else if (isMainRental) {
        badgeColor = Colors.yellow.shade600;
        badgeIcon = '★';
      } else {
        badgeColor = Colors.orange.shade600;
        badgeIcon = '!';
      }

      canvas.drawCircle(
        badgeCenter,
        badgeSize / 2 - 2,
        Paint()..color = badgeColor,
      );

      // Badge icon
      final badgeIconPainter = TextPainter(
        text: TextSpan(
          text: badgeIcon,
          style: TextStyle(
            color: Colors.white,
            fontSize: isAIRecommended ? 16 : 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      );

      badgeIconPainter.layout();
      badgeIconPainter.paint(
        canvas,
        Offset(
          badgeCenter.dx - badgeIconPainter.width / 2,
          badgeCenter.dy - badgeIconPainter.height / 2,
        ),
      );
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      width.toInt(),
      (height + pointerHeight + 4).toInt(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  static String _formatPriceModern(double price) {
    if (price >= 1000000000) {
      final value = price / 1000000000;
      return '${value >= 10 ? value.toStringAsFixed(0) : value.toStringAsFixed(1)} tỷ';
    } else if (price >= 1000000) {
      final value = price / 1000000;
      return '${value.toStringAsFixed(value >= 10 ? 0 : 1)} tr';
    } else if (price >= 1000) {
      return '${(price / 1000).toStringAsFixed(0)}k';
    } else {
      return '${price.toStringAsFixed(0)}đ';
    }
  }
}