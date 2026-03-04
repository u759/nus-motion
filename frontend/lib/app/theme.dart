import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // ── Brand palette ─────────────────────────────────────────────────
  static const Color primary = Color(0xFF25A8F4);
  static const Color backgroundDark = Color(0xFF101B22);
  static const Color neutralDark = Color(0xFF182A34);
  static const Color borderDark = Color(0xFF223B49);

  // ── Text palette ──────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFF1F5F9); // slate-100
  static const Color textSecondary = Color(0xFF94A3B8); // slate-400
  static const Color textMuted = Color(0xFF64748B); // slate-500

  // ── Dark theme ────────────────────────────────────────────────────
  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.dark(
      primary: primary,
      surface: neutralDark,
      onPrimary: Colors.white,
      onSurface: textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: backgroundDark,
      fontFamily: null, // system sans-serif
      // ── AppBar ──────────────────────────────────────────────────
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),

      // ── Cards ───────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: neutralDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
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

      // ── Text theme ─────────────────────────────────────────────
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: textPrimary),
        displayMedium: TextStyle(color: textPrimary),
        displaySmall: TextStyle(color: textPrimary),
        headlineLarge: TextStyle(color: textPrimary),
        headlineMedium: TextStyle(color: textPrimary),
        headlineSmall: TextStyle(color: textPrimary),
        titleLarge: TextStyle(color: textPrimary),
        titleMedium: TextStyle(color: textPrimary),
        titleSmall: TextStyle(color: textPrimary),
        bodyLarge: TextStyle(color: textPrimary),
        bodyMedium: TextStyle(color: textSecondary),
        bodySmall: TextStyle(color: textMuted),
        labelLarge: TextStyle(color: textPrimary),
        labelMedium: TextStyle(color: textSecondary),
        labelSmall: TextStyle(color: textMuted),
      ),

      // ── Divider ────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(color: borderDark, thickness: 1),
    );
  }
}
