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

    // Kích thước marker lớn hơn để dễ nhìn và rõ ràng hơn
    const double width = 230;
    const double height = 98;
    const double padding = 14;
    const double iconSize = 28;

    // Màu sắc gradient theo loại
    List<Color> gradientColors;
    Color borderColor;
    Color iconColor;

    if (!hasValidCoords) {
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

    // Vẽ shadow mềm mại hơn
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

    // Vẽ background với gradient
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

    // Vẽ border sáng bóng
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawRRect(rrect, borderPaint);

    // Vẽ highlight effect (ánh sáng phía trên)
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

    // Vẽ icon nhà bên trái
    final iconPath = Path();
    const iconLeft = padding;
    const iconTop = (height - iconSize) / 2;

    // Hình ngôi nhà đơn giản
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

    // Vẽ cửa nhà
    canvas.drawRect(
      Rect.fromLTWH(
        iconLeft + iconSize / 3,
        iconTop + iconSize / 2,
        iconSize / 3,
        iconSize / 2,
      ),
      Paint()..color = borderColor,
    );

    // Format và vẽ giá tiền
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

    // Căn giữa text bên phải icon
    final textOffset = Offset(
      iconLeft + iconSize + 8,
      (height - textPainter.height) / 2,
    );

    textPainter.paint(canvas, textOffset);

    // Vẽ tam giác pointer với gradient - lớn hơn
    final pointerPath = Path();
    const pointerWidth = 20.0;
    const pointerHeight = 14.0;

    pointerPath.moveTo(width / 2 - pointerWidth / 2, height);
    pointerPath.lineTo(width / 2, height + pointerHeight);
    pointerPath.lineTo(width / 2 + pointerWidth / 2, height);
    pointerPath.close();

    // Gradient cho pointer
    final pointerPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(width / 2, height),
        Offset(width / 2, height + pointerHeight),
        [gradientColors[0], gradientColors[1].withOpacity(0.8)],
      );

    canvas.drawPath(pointerPath, pointerPaint);

    // Border cho pointer
    canvas.drawPath(
      pointerPath,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // Vẽ badge nhỏ nếu là nhà chính hoặc không có tọa độ - lớn hơn
    if (isMainRental || !hasValidCoords) {
      const badgeSize = 24.0;
      final badgeCenter = Offset(width - badgeSize / 2 - 5, badgeSize / 2 + 5);

      // Badge background
      canvas.drawCircle(
        badgeCenter,
        badgeSize / 2,
        Paint()..color = Colors.white,
      );

      canvas.drawCircle(
        badgeCenter,
        badgeSize / 2 - 2,
        Paint()..color = isMainRental ? Colors.yellow.shade600 : Colors.orange.shade600,
      );

      // Badge icon - font lớn hơn
      final badgeIconPainter = TextPainter(
        text: TextSpan(
          text: isMainRental ? '★' : '!',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
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

  static String _formatPriceCompact(double price) {
    // Giữ lại hàm cũ để backward compatible
    return _formatPriceModern(price);
  }
}