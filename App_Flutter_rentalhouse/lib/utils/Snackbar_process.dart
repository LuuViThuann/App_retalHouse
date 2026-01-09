import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/constants/app_color.dart';

class AppSnackBar {
  //  SUCCESS
  static SnackBar success({
    required String message,
    IconData icon = Icons.check_circle,
    int seconds = 2,
  }) {
    return SnackBar(
      content: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: AppColors.greenSnackbar,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
      duration: Duration(seconds: seconds),
    );
  }

  //  INFO
  static SnackBar info({
    required String message,
    IconData icon = Icons.info,
    int seconds = 2,
  }) {
    return SnackBar(
      content: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: AppColors.primaryBlue,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
      duration: Duration(seconds: seconds),
    );
  }

  //  ERROR
  static SnackBar error({
    required String message,
    IconData icon = Icons.error_outline,
    int seconds = 4,
  }) {
    return SnackBar(
      content: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.red[700],
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
      duration: Duration(seconds: seconds),
    );
  }

  //  WARNING
  static SnackBar warning({
    required String message,
    IconData icon = Icons.warning_amber_rounded,
    int seconds = 3,
  }) {
    return SnackBar(
      content: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.orange[700],
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
      duration: Duration(seconds: seconds),
    );
  }

  //  NETWORK ERROR - Thông báo lỗi mạng cụ thể
  static SnackBar networkError() {
    return error(
      message: 'Không có kết nối internet. Vui lòng kiểm tra mạng.',
      icon: Icons.wifi_off,
      seconds: 5,
    );
  }

  //  SERVER ERROR - Lỗi server
  static SnackBar serverError() {
    return error(
      message: 'Lỗi kết nối server. Vui lòng thử lại sau.',
      icon: Icons.cloud_off,
      seconds: 4,
    );
  }

  //  TIMEOUT ERROR - Timeout
  static SnackBar timeoutError() {
    return error(
      message: 'Kết nối quá chậm. Vui lòng thử lại.',
      icon: Icons.hourglass_empty,
      seconds: 4,
    );
  }

  // AUTH ERROR - Lỗi xác thực cụ thể
  static SnackBar authError({required String message}) {
    return error(
      message: message,
      icon: Icons.lock_outline,
      seconds: 4,
    );
  }

  //  LOGIN SUCCESS - Đăng nhập thành công với tên user
  static SnackBar loginSuccess({String? username}) {
    return success(
      message: username != null && username.isNotEmpty
          ? 'Chào mừng $username trở lại!'
          : 'Đăng nhập thành công!',
      icon: Icons.check_circle_outline,
      seconds: 2,
    );
  }

  //  Hiển thị SnackBar
  static void show(BuildContext context, SnackBar snackBar) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);
  }

  //  Hiển thị nhanh các loại thông báo
  static void showSuccess(BuildContext context, String message) {
    show(context, success(message: message));
  }

  static void showError(BuildContext context, String message) {
    show(context, error(message: message));
  }

  static void showInfo(BuildContext context, String message) {
    show(context, info(message: message));
  }

  static void showWarning(BuildContext context, String message) {
    show(context, warning(message: message));
  }
}