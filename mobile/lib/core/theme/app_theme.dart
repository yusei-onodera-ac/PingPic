import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

/// PingPic's Material 3 theme. Built from ColorScheme.fromSeed (so every
/// Material widget gets a coherent, contrast-checked role assignment for
/// free) with a handful of targeted overrides for the roles this app
/// actually leans on by name (primary = coral, tertiary = success green
/// for "posted" states) — not a hand-specified 61-role token set.
abstract class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.coral,
      brightness: brightness,
      tertiary: AppColors.success,
      surface: isDark ? AppColors.ink : AppColors.cream,
    ).copyWith(
      primary: AppColors.coral,
      onPrimary: Colors.white,
    );

    final mutedColor = isDark ? AppColors.mutedDark : AppColors.mutedLight;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      splashFactory: InkSparkle.splashFactory,

      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTextStyles.headline.copyWith(color: colorScheme.onSurface),
      ),

      textTheme: TextTheme(
        headlineMedium: AppTextStyles.headline.copyWith(color: colorScheme.onSurface),
        titleMedium: AppTextStyles.title.copyWith(color: colorScheme.onSurface),
        bodyMedium: AppTextStyles.body.copyWith(color: colorScheme.onSurface),
        bodySmall: AppTextStyles.caption.copyWith(color: mutedColor),
        labelLarge: AppTextStyles.label,
      ),

      cardTheme: CardThemeData(
        color: isDark ? AppColors.inkSurface : Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.4)),
        ),
        margin: EdgeInsets.zero,
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          textStyle: AppTextStyles.label,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          textStyle: AppTextStyles.label,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(textStyle: AppTextStyles.bodyStrong),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.inkSurface : AppColors.creamSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        labelStyle: AppTextStyles.body.copyWith(color: mutedColor),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: isDark ? AppColors.inkSurface : AppColors.creamSurface,
        labelStyle: AppTextStyles.caption.copyWith(color: colorScheme.onSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(100),
          side: BorderSide.none,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),

      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withOpacity(0.4),
        space: 32,
      ),
    );
  }
}
