import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/views/NewSave.dart';
import 'package:flutter_rentalhouse/views/login_view.dart';
import 'package:flutter_rentalhouse/views/my_profile_view.dart';
import 'package:flutter_rentalhouse/Widgets/Profile/my_post.dart';
import 'package:flutter_rentalhouse/Widgets/Profile/recent_comment.dart';
import 'package:flutter_rentalhouse/Widgets/Profile/notification_view.dart';
import 'package:flutter_rentalhouse/views/forgot_password.dart';
import 'package:flutter_rentalhouse/views/notification_user.dart';
import 'package:flutter_rentalhouse/views/register_view.dart';

class AppNavigator {
  // ==================================================== THÔNG TIN CÁ NHÂN ====================================================
  // Dẫn thông tin đăng nhập ----------------------------------------------
  static void goToLogin(BuildContext context, {bool replace = false}) {
    if (replace) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  // Dẫn thông tin hồ sơ ----------------------------------------------
  static void goToProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MyProfileView()),
    );
  }

  // Dẫn thông tin thông báo  ----------------------------------------------
  static void goToNotification(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => NotificationUser()),
    );
  }

  // Dẫn thông tin thông báo  ----------------------------------------------
  static void goToNewsSave(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => Newsave()),
    );
  }

  // Dẫn thông tin các bài đăng ----------------------------------------------
  static void goToPosts(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MyPostsView()),
    );
  }

  // Dẫn thông tin bình luận gần đây ----------------------------------------------
  static void goToComments(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RecentCommentsView()),
    );
  }

  // Dẫn các thông tin của tài khoản ----------------------------------------------
  static void goToNotifications(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => NotificationsView()),
    );
  }

  // Dẫn thay đổi mật khẩu ----------------------------------------------
  static void goToChangePassword(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
    );
  }

  // ==================================================== THÔNG TIN ĐĂNG NHẬP  ====================================================
  // Dẫn đến trang đăng nhập người dùng
  static void goToLoginUser(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  // Dẫn đến trang đăng ký người dùng
  static void goToRegister(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RegisterScreen()),
    );
  }
}
