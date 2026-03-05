import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  AppTheme._();

  // ── Brand palette ─────────────────────────────────────────────────
  static const Color primary = Color(0xFF25A8F4);
  static const Color primaryLight = Color(0xFF5FBFF9);
  static const Color backgroundDark = Color(0xFF101B22);
  static const Color neutralDark = Color(0xFF182A34);
  static const Color borderDark = Color(0xFF223B49);
  static const Color surfaceVariant = Color(0xFF1E293B);

  // ── Semantic colours ──────────────────────────────────────────────
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFFFBF00);
  static const Color error = Color(0xFFEF4444);

  // ── Text palette ──────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  // ── Spacing scale ─────────────────────────────────────────────────
  static const double spacing4 = 4;
  static const double spacing8 = 8;
  static const double spacing12 = 12;
  static const double spacing16 = 16;
  static const double spacing20 = 20;
  static const double spacing24 = 24;
  static const double spacing32 = 32;

  // ── Radius ────────────────────────────────────────────────────────
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 24;
  static const double radiusFull = 9999;

  // ── Animation ─────────────────────────────────────────────────────
  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationMedium = Duration(milliseconds: 250);
  static const Duration durationSlow = Duration(milliseconds: 350);
  static const Curve curve = Curves.easeInOutCubic;

  // ── Dark theme ────────────────────────────────────────────────────
  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.dark(
      primary: primary,
      primaryContainer: primary.withValues(alpha: 0.15),
      secondary: primaryLight,
      surface: neutralDark,
      surfaceContainerHighest: surfaceVariant,
      onPrimary: Colors.white,
      onSurface: textPrimary,
      onSurfaceVariant: textSecondary,
      outline: borderDark,
      outlineVariant: borderDark.withValues(alpha: 0.5),
      error: error,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: backgroundDark,

      // ── AppBar ──────────────────────────────────────────────────
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),

      // ── Cards ───────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: neutralDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: borderDark, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      // ── Bottom navigation ───────────────────────────────────────
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: neutralDark,
        selectedItemColor: primary,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // ── Input ──────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: neutralDark,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: BorderSide(color: primary.withValues(alpha: 0.5)),
        ),
        hintStyle: const TextStyle(color: textMuted, fontSize: 14),
      ),

      // ── Buttons ────────────────────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),

      // ── Bottom sheet ───────────────────────────────────────────
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: backgroundDark,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXl)),
        ),
      ),

      // ── Snackbar ───────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceVariant,
        contentTextStyle: const TextStyle(color: textPrimary, fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // ── Text theme ─────────────────────────────────────────────
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        headlineSmall: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
        titleLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
        titleSmall: TextStyle(color: textPrimary, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(color: textPrimary),
        bodyMedium: TextStyle(color: textSecondary),
        bodySmall: TextStyle(color: textMuted, fontSize: 12),
        labelLarge: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
        labelMedium: TextStyle(
          color: textSecondary,
          fontWeight: FontWeight.w500,
        ),
        labelSmall: TextStyle(
          color: textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.0,
        ),
      ),

      // ── Divider ────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: borderDark,
        thickness: 1,
        space: 0,
      ),

      // ── Splash / ripple ────────────────────────────────────────
      splashColor: primary.withValues(alpha: 0.08),
      highlightColor: primary.withValues(alpha: 0.04),
    );
  }
}
