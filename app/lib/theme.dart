import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

// --- COLOR PALETTE ---
// Inspired by Goa Police branding for a professional and authoritative feel.
class AppColors {
  static const Color primary = Color(0xFF0A2342); // Deep, official blue
  static const Color secondary = Color(0xFFD4AF37); // Khaki/gold accent
  static const Color background = Color(0xFFF5F5F7); // Light, clean background
  static const Color surface = Colors.white; // For cards, dialogs
  static const Color error = Color(0xFFB00020); // Standard error red
  static const Color onPrimary = Colors.white; // Text on primary color
  static const Color onSecondary = Colors.black; // Text on secondary color
  static const Color onBackground = Color(0xFF212121); // Primary text color
  static const Color onSurface = Color(0xFF212121); // Text on surface color
}

// --- APP THEME ---
ThemeData buildTheme() {
  return ThemeData(
    // --- Colors ---
    scaffoldBackgroundColor: AppColors.background,
    primaryColor: AppColors.primary,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.surface,
      error: AppColors.error,
      onPrimary: AppColors.onPrimary,
      onSecondary: AppColors.onSecondary,
      onSurface: AppColors.onSurface,
      onError: Colors.white,
    ),

    // --- Text Theme with Google Fonts & ScreenUtil ---
    textTheme: GoogleFonts.poppinsTextTheme().copyWith(
      // For large titles like on a splash screen
      displayLarge: TextStyle(fontSize: 48.sp, fontWeight: FontWeight.bold, color: AppColors.primary),
      // For screen titles
      headlineMedium: TextStyle(fontSize: 28.sp, fontWeight: FontWeight.bold, color: AppColors.primary),
      // For subtitles or section headers
      titleLarge: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600, color: AppColors.onBackground),
      // For standard body text
      bodyMedium: TextStyle(fontSize: 14.sp, color: AppColors.onBackground),
      // For button text
      labelLarge: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: AppColors.onPrimary),
    ),

    // --- Component Themes ---
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.onPrimary,
      elevation: 2,
      titleTextStyle: GoogleFonts.poppins(
        fontSize: 20.sp,
        fontWeight: FontWeight.bold,
        color: AppColors.onPrimary,
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
        padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 24.w),
        textStyle: GoogleFonts.poppins(fontSize: 16.sp, fontWeight: FontWeight.bold),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14.sp),
    ),

    cardTheme: CardThemeData(
      elevation: 1,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
    ),
  );
}