import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/services/theme_service.dart';

class AppTheme {
  AppTheme._();

  static ThemeData build() {
    final isLight = ThemeService.instance.isLight;
    final palette = ThemeService.instance.palette;

    return ThemeData(
      useMaterial3: true,
      brightness: isLight ? Brightness.light : Brightness.dark,
      scaffoldBackgroundColor: palette.surface,
      colorScheme: isLight
          ? ColorScheme.light(
              primary: AppColors.primary,
              secondary: AppColors.gold,
              surface: palette.card,
              onPrimary: AppColors.white,
              onSurface: palette.textPrimary,
              error: AppColors.danger,
            )
          : ColorScheme.dark(
              primary: AppColors.primary,
              secondary: AppColors.gold,
              surface: palette.card,
              onPrimary: AppColors.white,
              onSurface: palette.textPrimary,
              error: AppColors.danger,
            ),
      drawerTheme: DrawerThemeData(
        backgroundColor: palette.drawerBg,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: palette.textPrimary,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: palette.textPrimary,
        ),
        iconTheme: IconThemeData(color: palette.textPrimary),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 4,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: palette.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: palette.border),
        ),
      ),
      dividerTheme: DividerThemeData(color: palette.border),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: TextStyle(color: palette.textPrimary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.inputFill,
        hintStyle: TextStyle(color: palette.textSecondary),
        labelStyle: TextStyle(
          color: palette.textSecondary,
          fontWeight: FontWeight.w500,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.gold),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.primary,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Default cinematic dark theme (legacy alias).
  static ThemeData get dark => build();

  /// Light theme alias.
  static ThemeData get light => build();
}
