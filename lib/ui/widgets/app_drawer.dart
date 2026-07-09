import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/core/constants/app_gradients.dart';
import 'package:rapide_nforce/core/enums/app_route.dart';
import 'package:rapide_nforce/core/utils/menu_route_mapper.dart';
import 'package:rapide_nforce/models/nav_menu_item.dart';
import 'package:rapide_nforce/models/user_model.dart';
import 'package:rapide_nforce/services/auth_service.dart';
import 'package:rapide_nforce/ui/widgets/brand_logo.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({
    super.key,
    required this.currentRoute,
    required this.onRouteSelected,
    this.menuItems = const [],
    this.menusLoading = false,
  });

  final AppRoute currentRoute;
  final ValueChanged<AppRoute> onRouteSelected;
  final List<NavMenuItem> menuItems;
  final bool menusLoading;

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  String? _expandedId;

  @override
  void didUpdateWidget(covariant AppDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncExpandedForRoute();
  }

  @override
  void initState() {
    super.initState();
    _syncExpandedForRoute();
  }

  void _syncExpandedForRoute() {
    final items = _menuSource();
    for (final item in items) {
      if (!item.hasChildren) continue;
      if (_isGroupActive(item)) {
        _expandedId = item.id;
        return;
      }
    }
  }

  List<NavMenuItem> _menuSource() {
    final items = widget.menuItems.isNotEmpty
        ? widget.menuItems
        : _staticMenus();
    // Carrier Compliance hidden for now — not needed yet. Remove this
    // filter to bring it back in the drawer.
    return items
        .where((item) => MenuRouteMapper.routeFromPath(item.path) != AppRoute.carriers)
        .toList();
  }

  bool _isGroupActive(NavMenuItem item) {
    if (_routeMatches(item.path, widget.currentRoute)) return true;
    for (final child in item.children) {
      final route = MenuRouteMapper.routeFromPath(child.path);
      if (route == widget.currentRoute) return true;
    }
    if (MenuRouteMapper.isMaintenanceLabel(item.label)) {
      return widget.currentRoute == AppRoute.maintenance ||
          widget.currentRoute == AppRoute.inventory ||
          widget.currentRoute == AppRoute.logs ||
          widget.currentRoute == AppRoute.faultCodes ||
          widget.currentRoute == AppRoute.dvir;
    }
    return false;
  }

  bool _routeMatches(String path, AppRoute route) {
    return MenuRouteMapper.routeFromPath(path) == route;
  }

  void _select(BuildContext context, AppRoute route) {
    Navigator.pop(context);
    widget.onRouteSelected(route);
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser ??
        const UserModel(
          id: 0,
          employeeId: '',
          name: 'Tech Mtwo',
          role: 'Technician',
        );
    final items = _menuSource();

    return Drawer(
      backgroundColor: AppColors.drawerBg,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: const BrandLogo(height: 72, maxWidth: 180),
              ),
            ),
            Expanded(
              child: widget.menusLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        for (final item in items)
                          if (item.hasChildren)
                            _DrawerGroup(
                              item: item,
                              expanded: _expandedId == item.id,
                              currentRoute: widget.currentRoute,
                              onToggle: () => setState(() {
                                _expandedId =
                                    _expandedId == item.id ? null : item.id;
                              }),
                              onSelect: (route) => _select(context, route),
                            )
                          else if (MenuRouteMapper.routeFromPath(item.path) !=
                              null)
                            _DrawerTile(
                              label: item.label,
                              menuIcon: item.label,
                              route: MenuRouteMapper.routeFromPath(item.path)!,
                              selected: _routeMatches(
                                item.path,
                                widget.currentRoute,
                              ),
                              onTap: () => _select(
                                context,
                                MenuRouteMapper.routeFromPath(item.path)!,
                              ),
                            ),
                      ],
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: AppGradients.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.goldLight,
                      child: const Icon(
                        Icons.person_outline,
                        color: AppColors.gold,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            user.role,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<NavMenuItem> _staticMenus() {
    return const [
      NavMenuItem(id: 'dashboard', label: 'Dashboard', path: '/dashboard'),
      NavMenuItem(id: 'carriers', label: 'Carrier', path: '/carriers'),
      NavMenuItem(id: 'drivers', label: 'Drivers', path: '/drivers'),
      NavMenuItem(id: 'powerunit', label: 'Power Unit', path: '/powerunit'),
      NavMenuItem(id: 'trailers', label: 'My Trailers', path: '/trailers'),
      NavMenuItem(
        id: 'maintenance',
        label: 'Service Maintenance',
        path: '/maintenance',
        children: [
          NavMenuItem(
            id: 'inventory',
            label: 'Inventory',
            path: '/inventory',
          ),
          NavMenuItem(
            id: 'maintenance-hub',
            label: 'Work Orders',
            path: '/maintenance',
          ),
          NavMenuItem(
            id: 'dvir',
            label: 'DVIR',
            path: '/dvir-reports',
          ),
          NavMenuItem(
            id: 'fault-codes',
            label: 'Fault Codes',
            path: '/fault-codes',
          ),
        ],
      ),
      NavMenuItem(id: 'documents', label: 'Documents', path: '/documents'),
      NavMenuItem(id: 'reports', label: 'Reports', path: '/reports'),
      NavMenuItem(id: 'requests', label: 'Requests', path: '/requests'),
      NavMenuItem(id: 'approvals', label: 'Approvals', path: '/lead-approvals'),
      NavMenuItem(id: 'profile', label: 'Profile', path: '/settings'),
    ];
  }
}

class _DrawerGroup extends StatelessWidget {
  const _DrawerGroup({
    required this.item,
    required this.expanded,
    required this.currentRoute,
    required this.onToggle,
    required this.onSelect,
  });

  final NavMenuItem item;
  final bool expanded;
  final AppRoute currentRoute;
  final VoidCallback onToggle;
  final ValueChanged<AppRoute> onSelect;

  bool get _active {
    if (MenuRouteMapper.routeFromPath(item.path) == currentRoute) return true;
    for (final child in item.children) {
      if (MenuRouteMapper.routeFromPath(child.path) == currentRoute) {
        return true;
      }
    }
    if (MenuRouteMapper.isMaintenanceLabel(item.label)) {
      return currentRoute == AppRoute.maintenance ||
          currentRoute == AppRoute.inventory ||
          currentRoute == AppRoute.logs ||
          currentRoute == AppRoute.faultCodes;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final tint = _active ? AppColors.gold : AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        children: [
          Material(
            color: _active ? AppColors.drawerActive : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onToggle,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    AppMenuIcon(
                      fallback: Icons.build_outlined,
                      menuIcon: item.label,
                      label: item.label,
                      color: tint,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              _active ? FontWeight.w600 : FontWeight.w500,
                          color: _active ? AppColors.gold : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Icon(
                      expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 20,
                      color: tint,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.only(left: 20, top: 2),
              child: Column(
                children: [
                  for (final child in item.children)
                    if (MenuRouteMapper.routeFromPath(child.path) != null)
                      _DrawerTile(
                        label: child.label,
                        menuIcon: child.label,
                        route: MenuRouteMapper.routeFromPath(child.path)!,
                        selected: MenuRouteMapper.routeFromPath(child.path) ==
                            currentRoute,
                        dense: true,
                        onTap: () =>
                            onSelect(MenuRouteMapper.routeFromPath(child.path)!),
                      ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.label,
    required this.route,
    required this.selected,
    required this.onTap,
    this.menuIcon,
    this.dense = false,
  });

  final String label;
  final AppRoute route;
  final bool selected;
  final VoidCallback onTap;
  final String? menuIcon;
  final bool dense;

  IconData get _fallbackIcon {
    switch (route) {
      case AppRoute.dashboard:
        return Icons.home_outlined;
      case AppRoute.carriers:
        return Icons.business_outlined;
      case AppRoute.powerUnit:
        return Icons.local_shipping_outlined;
      case AppRoute.myTrailers:
        return Icons.inventory_2_outlined;
      case AppRoute.maintenance:
        return Icons.build_outlined;
      case AppRoute.inventory:
        return Icons.inventory_2_outlined;
      case AppRoute.logs:
        return Icons.receipt_long_outlined;
      case AppRoute.faultCodes:
        return Icons.info_outline;
      case AppRoute.documents:
        return Icons.description_outlined;
      case AppRoute.reports:
        return Icons.bar_chart_outlined;
      case AppRoute.requests:
        return Icons.handyman_outlined;
      case AppRoute.approvals:
        return Icons.check_circle_outline;
      case AppRoute.profile:
        return Icons.settings_outlined;
      case AppRoute.drivers:
        return Icons.people_outline;
      case AppRoute.dvir:
        return Icons.description_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tint = selected ? AppColors.gold : AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? AppColors.drawerActive : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: dense ? 8 : 10,
            ),
            child: Row(
              children: [
                if (dense) const SizedBox(width: 16),
                AppMenuIcon(
                  fallback: _fallbackIcon,
                  menuIcon: menuIcon,
                  label: label,
                  size: dense ? 16 : 20,
                  color: tint,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: dense ? 13 : 14,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected ? AppColors.gold : AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
