import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/core/constants/app_gradients.dart';
import 'package:rapide_nforce/core/enums/app_route.dart';

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.currentRoute,
    required this.onRouteSelected,
    this.routes = kBottomNavRoutes,
  });

  final AppRoute currentRoute;
  final ValueChanged<AppRoute> onRouteSelected;
  final List<AppRoute> routes;

  IconData _icon(AppRoute route) {
    switch (route) {
      case AppRoute.dashboard:
        return Icons.home_rounded;
      case AppRoute.powerUnit:
        return Icons.local_shipping_rounded;
      case AppRoute.maintenance:
        return Icons.build_rounded;
      case AppRoute.approvals:
        return Icons.fact_check_outlined;
      case AppRoute.requests:
        return Icons.handyman_rounded;
      case AppRoute.profile:
        return Icons.person_rounded;
      default:
        return Icons.circle_outlined;
    }
  }

  bool _isMaintenanceRoute(AppRoute route) {
    return route == AppRoute.maintenance ||
        route == AppRoute.inventory ||
        route == AppRoute.logs ||
        route == AppRoute.faultCodes;
  }

  bool _isSelected(AppRoute tab) {
    if (tab == AppRoute.maintenance) {
      return _isMaintenanceRoute(currentRoute);
    }
    return currentRoute == tab;
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.bottomNavBg.withValues(alpha: 0.85),
            border: Border(
              top: BorderSide(
                color: AppColors.gold.withValues(alpha: 0.15),
                width: 1.5,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Row(
                children: [
                  for (var i = 0; i < routes.length; i++)
                    Expanded(
                      child: _NavItem(
                        label: routes[i].bottomNavLabel,
                        icon: _icon(routes[i]),
                        selected: _isSelected(routes[i]),
                        onTap: () => onRouteSelected(routes[i]),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: selected ? 1.12 : 1.0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 44,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: selected ? AppGradients.goldAccent : null,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: AppColors.gold.withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    icon,
                    size: 22,
                    color: selected ? AppColors.black : AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? AppColors.black : AppColors.textSecondary,
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
