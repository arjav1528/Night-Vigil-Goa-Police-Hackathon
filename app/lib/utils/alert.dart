import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:night_vigil/theme.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

enum AlertType { success, error, warning, info }

class CustomSnackBar {
  static void show(
    BuildContext context, {
    required String message,
    required AlertType alertType,
    Duration duration = const Duration(seconds: 3),
  }) {
    final snackBar = SnackBar(
      duration: duration,
      backgroundColor: _alertConfig[alertType]!['background'],
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(color: _alertConfig[alertType]!['borderColor']!),
      ),
      margin: EdgeInsets.all(16.w),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      content: Row(
        children: [
          // Icon
          Icon(
            _alertConfig[alertType]!['icon'],
            color: _alertConfig[alertType]!['textColor'],
            size: 24.sp,
          ),
          SizedBox(width: 12.w),
          // Message
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 14.sp,
                color: _alertConfig[alertType]!['textColor'],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);
  }

  // Configuration map for different alert types
  static final Map<AlertType, Map<String, dynamic>> _alertConfig = {
    AlertType.success: {
      'background': const Color(0xFFE8F5E9), // Light Green
      'textColor': const Color(0xFF1B5E20), // Dark Green
      'borderColor': const Color(0xFF4CAF50),
      'icon': PhosphorIcons.checkCircle(),
    },
    AlertType.error: {
      'background': const Color(0xFFFFEBEE), // Light Red
      'textColor': const Color(0xFFB71C1C), // Dark Red
      'borderColor': const Color(0xFFD32F2F),
      'icon': PhosphorIcons.xCircle(),
    },
    AlertType.warning: {
      'background': const Color(0xFFFFF8E1), // Light Amber
      'textColor': const Color(0xFFFF6F00), // Dark Amber
      'borderColor': const Color(0xFFFFA000),
      'icon': PhosphorIcons.warning(),
    },
    AlertType.info: {
      'background': const Color(0xFFE3F2FD), // Light Blue
      'textColor': AppColors.primary, // Using your theme's primary color
      'borderColor': const Color(0xFF1976D2),
      'icon': PhosphorIcons.info(),
    },
  };
}