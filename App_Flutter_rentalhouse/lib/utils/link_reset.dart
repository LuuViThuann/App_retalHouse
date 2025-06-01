import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/views/reset_password.dart';

class DeepLinkHandler {
  final FirebaseDynamicLinks _dynamicLinks = FirebaseDynamicLinks.instance;

  Future<void> initDynamicLinks(BuildContext context) async {
    // Xử lý liên kết khi ứng dụng đang chạy
    _dynamicLinks.onLink.listen((PendingDynamicLinkData? dynamicLink) async {
      await _handleDeepLink(context, dynamicLink?.link);
    }, onError: (e) {
      print('Error processing dynamic link: $e');
    });

    // Xử lý liên kết khi ứng dụng được mở từ trạng thái đóng
    final PendingDynamicLinkData? initialLink =
        await _dynamicLinks.getInitialLink();
    if (initialLink != null) {
      await _handleDeepLink(context, initialLink.link);
    }
  }

  Future<void> _handleDeepLink(BuildContext context, Uri? deepLink) async {
    if (deepLink != null) {
      print('Deep link received: $deepLink');
      final oobCode = deepLink.queryParameters['oobCode'];
      if (oobCode != null && deepLink.path == '/reset-password') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã nhận liên kết đặt lại mật khẩu')),
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ResetPasswordScreen(oobCode: oobCode),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Liên kết không hợp lệ')),
        );
      }
    }
  }
}
