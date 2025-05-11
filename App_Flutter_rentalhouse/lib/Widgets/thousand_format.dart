// lib/utils/thousands_formatter.dart
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class ThousandsFormatter extends TextInputFormatter {
  final NumberFormat _formatter;
  final bool allowZero;

  ThousandsFormatter({String? locale, this.allowZero = false})
      : _formatter = NumberFormat.decimalPattern(locale ?? 'vi_VN');

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    String newText = newValue.text.replaceAll(RegExp(r'[^\d]'), '');

    if (newText.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Ngăn người dùng nhập '0' là ký tự đầu tiên nếu không cho phép số 0
    // và giá trị hiện tại không phải là '' (để cho phép xóa về rỗng)
    if (!allowZero && newText == '0' && oldValue.text.isNotEmpty) {
      // Nếu người dùng cố nhập '0' vào đầu một số đã có (ví dụ '0123')
      // hoặc nhập '0' khi trường không rỗng và không cho phép số 0.
      // Trong trường hợp này, ta có thể trả về giá trị cũ để không cho phép thay đổi,
      // hoặc trả về TextEditingValue.empty nếu muốn xóa hẳn.
      // Ở đây, ta sẽ không cho phép bắt đầu bằng '0' nếu allowZero là false.
      if (oldValue.text.isEmpty || newValue.text.length == 1) {
        return TextEditingValue.empty;
      }
      return oldValue;
    }
    if (!allowZero && newText.startsWith('0') && newText.length > 1) {
      newText = newText.substring(1); // Loại bỏ số 0 ở đầu nếu có nhiều hơn 1 chữ số
      if (newText.isEmpty) { // Nếu sau khi bỏ số 0 mà rỗng thì trả về rỗng
        return TextEditingValue.empty;
      }
    }


    double value = double.tryParse(newText) ?? 0.0;
    String formattedText = _formatter.format(value);

    return newValue.copyWith(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }
}