import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:rapide_nforce/core/constants/app_assets.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/core/constants/app_strings.dart';

/// App brand mark — uses bundled `rapide-nforce-full.png`.
class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.height = 52,
    this.maxWidth,
    this.light = false,
  });

  final double height;
  final double? maxWidth;
  final bool light;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      AppAssets.logoFull,
      height: height,
      width: maxWidth,
      fit: BoxFit.contain,
      semanticLabel: AppStrings.appTitle,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, _, _) => _FallbackLogo(height: height, light: light),
    );
  }
}

class _FallbackLogo extends StatelessWidget {
  const _FallbackLogo({required this.height, required this.light});

  final double height;
  final bool light;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SvgPicture.asset(
          AppAssets.logo,
          height: height * 0.9,
          fit: BoxFit.contain,
        ),
        SizedBox(width: height * 0.15),
        _TextLogo(height: height, light: light),
      ],
    );
  }
}

class _TextLogo extends StatelessWidget {
  const _TextLogo({required this.height, required this.light});

  final double height;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final titleColor = light ? AppColors.white : AppColors.textPrimary;
    final subColor =
        light ? AppColors.white.withValues(alpha: 0.85) : AppColors.textSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          AppStrings.appBrand,
          style: TextStyle(
            fontSize: height * 0.28,
            fontWeight: FontWeight.w900,
            color: titleColor,
            letterSpacing: 1.2,
            height: 1.1,
          ),
        ),
        Text(
          AppStrings.appBrandSub,
          style: TextStyle(
            fontSize: height * 0.22,
            fontWeight: FontWeight.w600,
            color: subColor,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}

/// Sidebar / drawer icon — prefers web SVG assets, falls back to Material.
class AppMenuIcon extends StatelessWidget {
  const AppMenuIcon({
    super.key,
    required this.fallback,
    this.menuIcon,
    this.label,
    this.size = 20,
    this.color,
  });

  final IconData fallback;
  final String? menuIcon;
  final String? label;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final asset = AppAssets.iconForMenu(menuIcon: menuIcon, label: label);
    final tint = color ?? AppColors.textSecondary;

    if (asset != null) {
      return SvgPicture.asset(
        asset,
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
      );
    }

    return Icon(fallback, size: size, color: tint);
  }
}
