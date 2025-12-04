// widgets/app_snackbar.dart
import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/constants/app_color.dart';

class AppSnackBar {



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
          Text(message),
        ],
      ),
      backgroundColor: AppColors.greenSnackbar,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: Duration(seconds: seconds),
    );
  }

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
          Text(message),
        ],
      ),
      backgroundColor: AppColors.primaryBlue,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: Duration(seconds: seconds),
    );
  }

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
          Expanded(child: Text(message)),
        ],
      ),
      backgroundColor: Colors.red[700],
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: Duration(seconds: seconds),
    );
  }

  static SnackBar warning({
    required String message,
    IconData icon = Icons.warning_amber_rounded,
  }) {
    return SnackBar(
      content: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Text(message),
        ],
      ),
      backgroundColor: Colors.orange[700],
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 4),
    );
  }

  // Hiển thị SnackBar
  static void show(BuildContext context, SnackBar snackBar) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);
  }
}