import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Light theme color palette — blue-tinted neutrals, no pure grays
class AppColors {
  static const Color primary = Color(0xFF135BEC);
  static const Color primaryLight = Color(0xFF3B7BF6);

  // Surfaces (subtle cool blue tint)
  static const Color background = Color(0xFFF7F8FB);
  static const Color surface = Color(0xFFFAFBFD);
  static const Color surfaceMuted = Color(0xFFEEF1F7);

  // Borders (blue-tinted)
  static const Color border = Color(0xFFDDE2ED);
  static const Color borderLight = Color(0xFFEEF1F7);

  // Text (deep navy, never pure black)
  static const Color textPrimary = Color(0xFF0C1222);
  static const Color textSecondary = Color(0xFF556481);
  static const Color textMuted = Color(0xFF8794AE);

  // Semantic
  static const Color success = Color(0xFF059669);
  static const Color warning = Color(0xFFD97706);
  static const Color error = Color(0xFFDC2626);
  static const Color orange = Color(0xFFEA580C);

  // Semantic backgrounds
  static const Color errorBg = Color(0xFFFDE3E3);
  static const Color warningBg = Color(0xFFFDD8AB);
  static const Color infoBg = Color(0xFFDAE8FD);
  static const Color successBg = Color(0xFFD0F9E4);
  static const Color mutedBg = Color(0xFFDDE2ED);
}

/// Dark theme color palette — rich near-black with blue undertone
class AppDarkColors {
  static const Color primary = Color(0xFF6B97F2);
  static const Color primaryLight = Color(0xFF8BADF5);

  // Surfaces (charcoal with blue warmth)
  static const Color background = Color(0xFF0A0E1A);
  static const Color surface = Color(0xFF141825);
  static const Color surfaceMuted = Color(0xFF1E2536);

  // Borders (subtle, blue-tinted)
  static const Color border = Color(0xFF2D3548);
  static const Color borderLight = Color(0xFF1E2536);

  // Text (blue-tinted whites)
  static const Color textPrimary = Color(0xFFEDF0F7);
  static const Color textSecondary = Color(0xFF8B97B0);
  static const Color textMuted = Color(0xFF5A6680);

  // Semantic (tuned for dark backgrounds)
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFFBBF24);
  static const Color error = Color(0xFFEF4444);
  static const Color orange = Color(0xFFF97316);

  // Semantic backgrounds (deeper, richer)
  static const Color errorBg = Color(0xFF3B1218);
  static const Color warningBg = Color(0xFF3B2508);
  static const Color infoBg = Color(0xFF0F2340);
  static const Color successBg = Color(0xFF0A3028);
  static const Color mutedBg = Color(0xFF1E2536);
}

class AppTheme {
  static ThemeData get light {
    final baseText = GoogleFonts.dmSansTextTheme();
    final displayText = GoogleFonts.spaceGroteskTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorSchemeSeed: AppColors.primary,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: baseText.copyWith(
        displayLarge: displayText.displayLarge,
        displayMedium: displayText.displayMedium,
        displaySmall: displayText.displaySmall,
        headlineLarge: displayText.headlineLarge,
        headlineMedium: displayText.headlineMedium,
        headlineSmall: displayText.headlineSmall,
        titleLarge: displayText.titleLarge,
        titleMedium: displayText.titleMedium,
        titleSmall: displayText.titleSmall,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0.5,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0.5,
        shadowColor: AppColors.textPrimary.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }

  static ThemeData get dark {
    final baseText = GoogleFonts.dmSansTextTheme(ThemeData.dark().textTheme);
    final displayText = GoogleFonts.spaceGroteskTextTheme(
      ThemeData.dark().textTheme,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorSchemeSeed: AppDarkColors.primary,
      scaffoldBackgroundColor: AppDarkColors.background,
      textTheme: baseText.copyWith(
        displayLarge: displayText.displayLarge,
        displayMedium: displayText.displayMedium,
        displaySmall: displayText.displaySmall,
        headlineLarge: displayText.headlineLarge,
        headlineMedium: displayText.headlineMedium,
        headlineSmall: displayText.headlineSmall,
        titleLarge: displayText.titleLarge,
        titleMedium: displayText.titleMedium,
        titleSmall: displayText.titleSmall,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppDarkColors.surface,
        foregroundColor: AppDarkColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0.5,
      ),
      cardTheme: CardThemeData(
        color: AppDarkColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppDarkColors.border, width: 0.5),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppDarkColors.surface,
        selectedItemColor: AppDarkColors.primary,
        unselectedItemColor: AppDarkColors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppDarkColors.surfaceMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppDarkColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }
}

/// Theme-aware color accessor.
///
/// Usage: `context.nusColors.surface` — returns the correct color for current theme.
extension NusColors on BuildContext {
  NusColorsData get nusColors {
    final isDark = Theme.of(this).brightness == Brightness.dark;
    return isDark ? NusColorsData.dark : NusColorsData.light;
  }
}

class NusColorsData {
  final Color primary;
  final Color primaryLight;
  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color border;
  final Color borderLight;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color success;
  final Color warning;
  final Color error;
  final Color orange;
  final Color errorBg;
  final Color warningBg;
  final Color infoBg;
  final Color successBg;
  final Color mutedBg;

  const NusColorsData({
    required this.primary,
    required this.primaryLight,
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.border,
    required this.borderLight,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.success,
    required this.warning,
    required this.error,
    required this.orange,
    required this.errorBg,
    required this.warningBg,
    required this.infoBg,
    required this.successBg,
    required this.mutedBg,
  });

  static const light = NusColorsData(
    primary: AppColors.primary,
    primaryLight: AppColors.primaryLight,
    background: AppColors.background,
    surface: AppColors.surface,
    surfaceMuted: AppColors.surfaceMuted,
    border: AppColors.border,
    borderLight: AppColors.borderLight,
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    textMuted: AppColors.textMuted,
    success: AppColors.success,
    warning: AppColors.warning,
    error: AppColors.error,
    orange: AppColors.orange,
    errorBg: AppColors.errorBg,
    warningBg: AppColors.warningBg,
    infoBg: AppColors.infoBg,
    successBg: AppColors.successBg,
    mutedBg: AppColors.mutedBg,
  );

  static const dark = NusColorsData(
    primary: AppDarkColors.primary,
    primaryLight: AppDarkColors.primaryLight,
    background: AppDarkColors.background,
    surface: AppDarkColors.surface,
    surfaceMuted: AppDarkColors.surfaceMuted,
    border: AppDarkColors.border,
    borderLight: AppDarkColors.borderLight,
    textPrimary: AppDarkColors.textPrimary,
    textSecondary: AppDarkColors.textSecondary,
    textMuted: AppDarkColors.textMuted,
    success: AppDarkColors.success,
    warning: AppDarkColors.warning,
    error: AppDarkColors.error,
    orange: AppDarkColors.orange,
    errorBg: AppDarkColors.errorBg,
    warningBg: AppDarkColors.warningBg,
    infoBg: AppDarkColors.infoBg,
    successBg: AppDarkColors.successBg,
    mutedBg: AppDarkColors.mutedBg,
  );
}
