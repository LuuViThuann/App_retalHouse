import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/config/loading.dart';
import 'package:lottie/lottie.dart';

class AppLoadingDialog extends StatelessWidget {
  final String message;

  const AppLoadingDialog({
    super.key,
    this.message = 'Đang xử lý...',
  });

  // Show nhanh
  static void show(BuildContext context, {String? message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.6), // nền mờ đen nhẹ – đẹp nhất
      builder: (_) => AppLoadingDialog(message: message ?? 'Đang xử lý...'),
    );
  }

  // Hide nhanh
  static void hide(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.zero, // full màn hình
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Lottie.asset(
              AssetsConfig.loadingLottie,
              width: 110,
              height: 110,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
