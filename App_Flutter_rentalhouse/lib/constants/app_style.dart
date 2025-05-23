import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/constants/app_color.dart';


class AppStyles {
  // Colors (moved to app_colors.dart)
  static final Color whiteColor = AppColors.white;
  static final Color primaryColor = AppColors.primary;
  static final Color primaryDarkColor = AppColors.primaryDark;
  static final Color shadowColor = AppColors.black26;
  static final Color grey400 = AppColors.grey400;
  static final Color backgroundLight = AppColors.grey100;
  static final Color errorColor = AppColors.redAccent;
  static final Color successColor = AppColors.green;
  static final Color avatarBackground = AppColors.blue100;
  static final Color avatarIconColor = AppColors.blue800;
  static final Color unreadGradientStart = AppColors.blue50;
  static final Color unreadGradientEnd = AppColors.blue100;

  // Text Styles
  static const appBarTitle = TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 22,
    color: Colors.white,
  );

  static var emptyStateText = TextStyle(
    fontSize: 18,
    color: AppColors.grey700,
    fontWeight: FontWeight.w500,
  );

  static var loadingText = TextStyle(
    fontSize: 16,
    color: AppColors.grey600,
    fontWeight: FontWeight.w500,
  );

  static var errorText = TextStyle(
    fontSize: 16,
    color: AppColors.redAccent,
    fontWeight: FontWeight.w500,
  );

  static const retryButtonText = TextStyle(
    color: Colors.white,
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  static const snackbarText = TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.w500,
  );

  static var titleText = TextStyle(
    fontWeight: FontWeight.w600,
    fontSize: 16,
    color: AppColors.black87,
  );

  static var unreadTitleText = TextStyle(
    fontWeight: FontWeight.w700,
    fontSize: 16,
    color: AppColors.blue900,
  );

  static var subtitleText = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.grey600,
  );

  static var unreadSubtitleText = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.blue700,
  );

  static var timestampText = TextStyle(
    fontSize: 12,
    color: AppColors.grey500,
    fontWeight: FontWeight.w500,
  );

  static var unreadTimestampText = TextStyle(
    fontSize: 12,
    color: AppColors.blue700,
    fontWeight: FontWeight.w600,
  );

  static const unreadBadgeText = TextStyle(
    color: Colors.white,
    fontSize: 14,
    fontWeight: FontWeight.bold,
  );

  // Button Styles
  static final retryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: AppColors.primary,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
  );
}