import 'package:flutter/material.dart';

/// Theme-dependent colors for dark and light modes.
class AppPalette {
  const AppPalette({
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textMuted,
    required this.border,
    required this.borderLight,
    required this.surface,
    required this.surfaceTertiary,
    required this.card,
    required this.cardElevated,
    required this.drawerBg,
    required this.drawerActive,
    required this.cardShadow,
    required this.inputFill,
    required this.gradientTop,
    required this.gradientMid,
    required this.gradientBottom,
    required this.bottomNavBg,
    required this.statBlueBgStart,
    required this.statBlueBgEnd,
    required this.statBlueBorder,
    required this.statBlueText,
    required this.statBlueValue,
    required this.statOrangeBgStart,
    required this.statOrangeBgEnd,
    required this.statOrangeBorder,
    required this.statOrangeText,
    required this.statOrangeValue,
    required this.statRoseBgStart,
    required this.statRoseBgEnd,
    required this.statRoseBorder,
    required this.statRoseText,
    required this.statRoseValue,
    required this.statEmeraldBgStart,
    required this.statEmeraldBgEnd,
    required this.statEmeraldBorder,
    required this.statEmeraldText,
    required this.statEmeraldValue,
    required this.cardHeaderStart,
    required this.cardHeaderEnd,
  });

  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textMuted;
  final Color border;
  final Color borderLight;
  final Color surface;
  final Color surfaceTertiary;
  final Color card;
  final Color cardElevated;
  final Color drawerBg;
  final Color drawerActive;
  final Color cardShadow;
  final Color inputFill;
  final Color gradientTop;
  final Color gradientMid;
  final Color gradientBottom;
  final Color bottomNavBg;
  final Color statBlueBgStart;
  final Color statBlueBgEnd;
  final Color statBlueBorder;
  final Color statBlueText;
  final Color statBlueValue;
  final Color statOrangeBgStart;
  final Color statOrangeBgEnd;
  final Color statOrangeBorder;
  final Color statOrangeText;
  final Color statOrangeValue;
  final Color statRoseBgStart;
  final Color statRoseBgEnd;
  final Color statRoseBorder;
  final Color statRoseText;
  final Color statRoseValue;
  final Color statEmeraldBgStart;
  final Color statEmeraldBgEnd;
  final Color statEmeraldBorder;
  final Color statEmeraldText;
  final Color statEmeraldValue;
  final Color cardHeaderStart;
  final Color cardHeaderEnd;

  static const AppPalette dark = AppPalette(
    textPrimary: Color(0xFFE0E3E6), // on-surface
    textSecondary: Color(0xFFE5BDB9), // on-surface-variant
    textTertiary: Color(0xFFB7C7EB), // secondary
    textMuted: Color(0xFF5C403D), // outline-variant
    border: Color(0xFF2D3D5A), // border-muted
    borderLight: Color(0xFF2D3D5A),
    surface: Color(0xFF081121), // surface-deep (Level 0 base)
    surfaceTertiary: Color(0xFF1D2022), // surface-container
    card: Color(0xFF0B1B33), // Level 1 Card Container
    cardElevated: Color(0xFF1B2B48), // Level 2 Elevated surfaces
    drawerBg: Color(0xFF101416), // surface
    drawerActive: Color(0x22E22D2D), // Primary Red hover glow
    cardShadow: Color(0x33000000),
    inputFill: Color(0xFF081121), // surface-deep
    gradientTop: Color(0xFF081121),
    gradientMid: Color(0xFF081121),
    gradientBottom: Color(0xFF081121),
    bottomNavBg: Color(0xFF101416), // surface
    statBlueBgStart: Color(0x182563EB),
    statBlueBgEnd: Color(0xFF0B1B33),
    statBlueBorder: Color(0xFF2563EB),
    statBlueText: Color(0xFFB7C7EB),
    statBlueValue: Color(0xFFFFFFFF),
    statOrangeBgStart: Color(0x18F59E0B),
    statOrangeBgEnd: Color(0xFF0B1B33),
    statOrangeBorder: Color(0xFFF59E0B),
    statOrangeText: Color(0xFFF59E0B),
    statOrangeValue: Color(0xFFFFFFFF),
    statRoseBgStart: Color(0x18E22D2D),
    statRoseBgEnd: Color(0xFF0B1B33),
    statRoseBorder: Color(0xFFE22D2D),
    statRoseText: Color(0xFFE22D2D),
    statRoseValue: Color(0xFFFFFFFF),
    statEmeraldBgStart: Color(0x1810B981),
    statEmeraldBgEnd: Color(0xFF0B1B33),
    statEmeraldBorder: Color(0xFF10B981),
    statEmeraldText: Color(0xFF10B981),
    statEmeraldValue: Color(0xFFFFFFFF),
    cardHeaderStart: Color(0xFF0B1B33),
    cardHeaderEnd: Color(0xFF0B1B33),
  );

  static const AppPalette light = AppPalette(
    textPrimary: Color(0xFF111827), // dark text matching image
    textSecondary: Color(0xFF6B7280),
    textTertiary: Color(0xFF9CA3AF),
    textMuted: Color(0xFFD1D5DB),
    border: Color(0xFFE5E7EB), // subtle grey border
    borderLight: Color(0xFFF3F4F6),
    surface: Color(0xFFF8FAFC), // light grey/blue screen background matching image
    surfaceTertiary: Color(0xFFF1F5F9),
    card: Color(0xFFFFFFFF), // white cards matching image
    cardElevated: Color(0xFFFFFFFF),
    drawerBg: Color(0xFFFFFFFF), // sidebar/drawer background
    drawerActive: Color(0x15E22D2D),
    cardShadow: Color(0x05000000),
    inputFill: Color(0xFFFFFFFF),
    gradientTop: Color(0xFFF8FAFC),
    gradientMid: Color(0xFFF8FAFC),
    gradientBottom: Color(0xFFF8FAFC),
    bottomNavBg: Color(0xFFFFFFFF), // white bottom nav
    statBlueBgStart: Color(0xFFEFF6FF),
    statBlueBgEnd: Color(0xFFDBEAFE),
    statBlueBorder: Color(0xFFBFDBFE),
    statBlueText: Color(0xFF1D4ED8),
    statBlueValue: Color(0xFF1E3A8A),
    statOrangeBgStart: Color(0xFFFFF7ED),
    statOrangeBgEnd: Color(0xFFFFEDD5),
    statOrangeBorder: Color(0xFFFED7AA),
    statOrangeText: Color(0xFFC2410C),
    statOrangeValue: Color(0xFF7C2D12),
    statRoseBgStart: Color(0xFFFFF1F2),
    statRoseBgEnd: Color(0xFFFFE4E6),
    statRoseBorder: Color(0xFFFECDD3),
    statRoseText: Color(0xFFBE123C),
    statRoseValue: Color(0xFF881337),
    statEmeraldBgStart: Color(0xFFECFDF5),
    statEmeraldBgEnd: Color(0xFFD1FAE5),
    statEmeraldBorder: Color(0xFFA7F3D0),
    statEmeraldText: Color(0xFF047857),
    statEmeraldValue: Color(0xFF064E3B),
    cardHeaderStart: Color(0xFFFFFFFF),
    cardHeaderEnd: Color(0xFFFFFFFF),
  );
}
