class Validators {
  static String? requiredField(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng nhập $fieldName';
    }
    return null;
  }

  static String? priceValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng nhập giá thuê';
    }
    final numericValue = value.replaceAll(RegExp(r'[^\d]'), '');
    if (double.tryParse(numericValue) == null ||
        double.parse(numericValue) <= 0) {
      return 'Giá thuê không hợp lệ';
    }
    return null;
  }

  static String? areaValidator(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng nhập $fieldName';
    }
    if (double.tryParse(value) == null || double.parse(value) <= 0) {
      return '$fieldName không hợp lệ';
    }
    return null;
  }

  static String? optionalAreaValidator(String? value) {
    if (value != null && value.isNotEmpty) {
      if (double.tryParse(value) == null || double.parse(value) < 0) {
        return 'Diện tích không hợp lệ';
      }
    }
    return null;
  }

  static String? phoneValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng nhập số điện thoại';
    }
    if (!RegExp(r'^(0|\+84)[0-9]{9,10}$').hasMatch(value)) {
      return 'Số điện thoại không hợp lệ';
    }
    return null;
  }

  static String? depositValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng nhập tiền cọc';
    }
    final numericValue = value.replaceAll(RegExp(r'[^\d]'), '');
    if (double.tryParse(numericValue) == null ||
        double.parse(numericValue) < 0) {
      return 'Tiền cọc không hợp lệ';
    }
    return null;
  }
}
