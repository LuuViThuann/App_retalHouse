import 'package:flutter/material.dart';

void showSnackBar(BuildContext context, String message,
    {bool isError = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      // Nội dung tùy chỉnh với Row để chứa icon và text
      content: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isError
                ? [Colors.redAccent, Colors.red]
                : [Colors.deepPurple, Colors.deepPurpleAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Roboto',
                ),
              ),
            ),
          ],
        ),
      ),
      // Loại bỏ contentTextStyle vì không cần thiết
      backgroundColor:
          Colors.transparent, // Để gradient trong Container hoạt động
      elevation: 0, // Loại bỏ shadow mặc định của SnackBar
      behavior: SnackBarBehavior.floating, // Hiển thị dạng nổi
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      duration: const Duration(seconds: 3),
      // Hành động đóng
      action: SnackBarAction(
        label: 'Đóng',
        textColor: Colors.white,
        onPressed: () {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        },
      ),
      // Animation mặc định của SnackBar, không cần animationCurve
      showCloseIcon: false, // Không hiển thị close icon mặc định
      clipBehavior: Clip.antiAlias, // Đảm bảo không bị cắt khi có borderRadius
    ),
  );
}
