import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/theme/app_palette.dart';
import 'package:rapide_nforce/services/theme_service.dart';

/// Shared gradients — adapt to the active theme palette.
class AppGradients {
  AppGradients._();

  static AppPalette get _p => ThemeService.instance.palette;

  static LinearGradient get pageBackground => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [_p.gradientTop, _p.gradientMid, _p.gradientBottom],
    stops: const [0.0, 0.35, 1.0],
  );

  static LinearGradient get primaryButton => ThemeService.instance.isLight
      ? const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF272A2D), Color(0xFF1D2022)],
        )
      : const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFFFF8C00), Color(0xFFFF4500)],
        );

  static LinearGradient get card => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [_p.cardElevated, _p.card],
  );

  static LinearGradient get cardHeader => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [_p.cardHeaderStart, _p.cardHeaderEnd],
  );

  static LinearGradient get selectedTab => ThemeService.instance.isLight
      ? const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF272A2D), Color(0xFF1D2022)],
        )
      : const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF8C00), Color(0xFFE11D48)],
        );

  static const LinearGradient goldAccent = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF5C542), Color(0xFFD4AF37)],
  );
}
