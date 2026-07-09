import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/theme/app_palette.dart';
import 'package:rapide_nforce/services/theme_service.dart';

/// App colors — brand accents are fixed; surfaces and text follow [ThemeService].
class AppColors {
  AppColors._();

  static AppPalette get _p => ThemeService.instance.palette;

  // Brand accents (shared across themes)
  static const Color _primaryLightTheme = Color(0xFF272A2D);
  static const Color _primaryDarkTheme = Color(0xFFE22D2D);
  static Color get primary =>
      ThemeService.instance.isLight ? _primaryLightTheme : _primaryDarkTheme;
  static const Color primaryDark = Color(0xFF93000A);
  static Color get primaryLight => primary.withValues(alpha: 0.2);
  static Color get primaryTint => primary.withValues(alpha: 0.1);
  static const Color gold = Color(0xFFE22D2D);
  static Color get goldLight => gold.withValues(alpha: 0.2);

  static Color get accent => primary;
  static Color get accentLight => accent.withValues(alpha: 0.2);

  static const Color secondary = Color(0xFF3A4968);
  static Color get secondaryLight => secondary.withValues(alpha: 0.2);

  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFE22D2D);
  static const Color required = Color(0xFFFF4D6D);
  static const Color logoRed = Color(0xFFE11D48);

  // Text
  static Color get textPrimary => _p.textPrimary;
  static Color get textSecondary => _p.textSecondary;
  static Color get textTertiary => _p.textTertiary;
  static Color get textMuted => _p.textMuted;
  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);

  // Surfaces
  static Color get border => _p.border;
  static Color get borderLight => _p.borderLight;
  static Color get surface => _p.surface;
  static Color get surfaceTertiary => _p.surfaceTertiary;
  static Color get card => _p.card;
  static Color get cardElevated => _p.cardElevated;
  static Color get drawerBg => _p.drawerBg;
  static Color get drawerActive => _p.drawerActive;
  static Color get cardShadow => _p.cardShadow;
  static Color get inputFill => _p.inputFill;
  static Color get bottomNavBg => _p.bottomNavBg;

  // Page gradient stops
  static Color get gradientTop => _p.gradientTop;
  static Color get gradientMid => _p.gradientMid;
  static Color get gradientBottom => _p.gradientBottom;

  // Stat cards
  static Color get statBlueBgStart => _p.statBlueBgStart;
  static Color get statBlueBgEnd => _p.statBlueBgEnd;
  static Color get statBlueBorder => _p.statBlueBorder;
  static Color get statBlueText => _p.statBlueText;
  static Color get statBlueValue => _p.statBlueValue;

  static Color get statOrangeBgStart => _p.statOrangeBgStart;
  static Color get statOrangeBgEnd => _p.statOrangeBgEnd;
  static Color get statOrangeBorder => _p.statOrangeBorder;
  static Color get statOrangeText => _p.statOrangeText;
  static Color get statOrangeValue => _p.statOrangeValue;

  static Color get statRoseBgStart => _p.statRoseBgStart;
  static Color get statRoseBgEnd => _p.statRoseBgEnd;
  static Color get statRoseBorder => _p.statRoseBorder;
  static Color get statRoseText => _p.statRoseText;
  static Color get statRoseValue => _p.statRoseValue;

  static Color get statEmeraldBgStart => _p.statEmeraldBgStart;
  static Color get statEmeraldBgEnd => _p.statEmeraldBgEnd;
  static Color get statEmeraldBorder => _p.statEmeraldBorder;
  static Color get statEmeraldText => _p.statEmeraldText;
  static Color get statEmeraldValue => _p.statEmeraldValue;

  // Legacy aliases
  static Color get cardWorkOrders => statBlueBgEnd;
  static Color get cardInventory => statOrangeBgEnd;
  static Color get cardRequests => statRoseBgEnd;
  static Color get cardCompleted => statEmeraldBgEnd;
  static const Color statusCompleted = Color(0xFF34D399);
  static Color get statusLow => warning;
  static Color get liveFeed => accent;
}
