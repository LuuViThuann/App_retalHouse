// lib/utils/thousands_formatter.dart
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class OptimizedThousandsFormatter extends TextInputFormatter {
  final NumberFormat _formatter = NumberFormat('#,###', 'vi_VN');

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    // Nhanh chóng bỏ qua nếu không thay đổi số
    final newTextOnlyDigits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    final oldTextOnlyDigits = oldValue.text.replaceAll(RegExp(r'[^\d]'), '');

    if (newTextOnlyDigits == oldTextOnlyDigits) {
      return newValue;
    }

    if (newTextOnlyDigits.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Parse an toàn
    final number = int.tryParse(newTextOnlyDigits);
    if (number == null) return oldValue;

    final formatted = _formatter.format(number);

    // Tính toán vị trí con trỏ mới (quan trọng để không nhảy lung tung)
    final oldLength = oldValue.text.length;
    final newLength = formatted.length;
    int newOffset = newValue.selection.end + (newLength - oldLength);

    newOffset = newOffset.clamp(0, formatted.length);

    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: newOffset),
      composing: TextRange.empty,
    );
  }
}