import 'package:rapide_nforce/core/constants/api_constants.dart';
import 'package:rapide_nforce/core/enums/app_route.dart';
import 'package:rapide_nforce/core/models/api_result.dart';
import 'package:rapide_nforce/core/utils/api_parse.dart';
import 'package:rapide_nforce/core/utils/menu_route_mapper.dart';
import 'package:rapide_nforce/models/nav_menu_item.dart';
import 'package:rapide_nforce/services/api_client.dart';
import 'package:rapide_nforce/services/auth_service.dart';

class MenuService {
  MenuService._();

  static final MenuService instance = MenuService._();

  final ApiClient _api = ApiClient.instance;

  Future<ApiResult<List<NavMenuItem>>> fetchMenusForCurrentUser() async {
    try {
      var menus = await _fetchMenusFromEndpoint(ApiConstants.menusMe);
      if (menus.isEmpty) {
        menus = await _fetchMenusFromEndpoint(ApiConstants.menusAccess);
      }
      if (menus.isEmpty) {
        return ApiResult.ok(_fallbackMenus());
      }

      final withSubMenus = await _attachSubMenus(menus);
      final filtered = _filterMaintenanceDuplicates(withSubMenus);
      final navItems = filtered
          .where((m) => m['isActive'] != false)
          .map(_mapMenu)
          .where((m) => m.path.isNotEmpty)
          .toList()
        ..sort(
          (a, b) => _orderFor(a).compareTo(_orderFor(b)),
        );

      if (navItems.isEmpty) {
        return ApiResult.ok(_fallbackMenus());
      }
      return ApiResult.ok(navItems);
    } catch (_) {
      return ApiResult.ok(_fallbackMenus());
    }
  }

  Future<List<Map<String, dynamic>>> _fetchMenusFromEndpoint(String path) async {
    final body = await _api.parseJson(
      () => _api.get(path),
      onSuccess: (b) => b,
    );
    return _extractMenuList(body);
  }

  List<Map<String, dynamic>> _extractMenuList(dynamic body) {
    if (body is List) {
      return body.whereType<Map>().map(Map<String, dynamic>.from).toList();
    }
    if (body is! Map<String, dynamic>) return [];

    final data = body['data'];
    if (data is List) {
      return data.whereType<Map>().map(Map<String, dynamic>.from).toList();
    }
    if (data is Map<String, dynamic>) {
      final nested = data['data'] ?? data['items'] ?? data['menus'];
      if (nested is List) {
        return nested.whereType<Map>().map(Map<String, dynamic>.from).toList();
      }
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> _attachSubMenus(
    List<Map<String, dynamic>> menus,
  ) async {
    final result = <Map<String, dynamic>>[];
    for (final menu in menus) {
      final existing = menu['subMenus'];
      if (existing is List && existing.isNotEmpty) {
        result.add(menu);
        continue;
      }

      final menuId = menu['id'];
      if (menuId is! num) {
        result.add(menu);
        continue;
      }

      try {
        final subBody = await _api.parseJson(
          () => _api.get('${ApiConstants.menus}/$menuId/sub-menus'),
          onSuccess: (b) => b,
        );
        final subMenus = ApiParse.listItems(subBody);
        result.add({...menu, 'subMenus': subMenus});
      } catch (_) {
        result.add(menu);
      }
    }
    return result;
  }

  List<Map<String, dynamic>> _filterMaintenanceDuplicates(
    List<Map<String, dynamic>> menus,
  ) {
    final role = AuthService.instance.currentUser?.role ?? '';
    final isAdmin = _isAdminRole(role);
    final hasMaintenance = menus.any(
      (m) => MenuRouteMapper.isMaintenanceLabel(_menuLabel(m)),
    );
    if (!hasMaintenance || isAdmin) return menus;

    return menus.where((m) {
      final label = _menuLabel(m).toLowerCase();
      return label != 'inventory' &&
          label != 'work orders' &&
          label != 'work-orders';
    }).toList();
  }

  bool _isAdminRole(String role) {
    final normalized = role.toUpperCase().replaceAll(' ', '_');
    return normalized.contains('SUPER_ADMIN') || normalized == 'ADMIN';
  }

  NavMenuItem _mapMenu(Map<String, dynamic> menu) {
    final rawSubs = menu['subMenus'];
    final children = <NavMenuItem>[];
    if (rawSubs is List) {
      for (var i = 0; i < rawSubs.length; i++) {
        final sub = rawSubs[i];
        if (sub is! Map) continue;
        final subMap = Map<String, dynamic>.from(sub);
        if (subMap['isActive'] == false) continue;
        final path = _subMenuPath(subMap);
        if (path.isEmpty) continue;
        children.add(
          NavMenuItem(
            id: 'sub-${subMap['id'] ?? i}',
            label: _subMenuLabel(subMap),
            path: path,
          ),
        );
      }
    }

    return NavMenuItem(
      id: '${menu['id'] ?? _menuLabel(menu)}',
      label: _menuLabel(menu),
      path: _menuPath(menu),
      children: children,
    );
  }

  String _menuLabel(Map<String, dynamic> menu) {
    return (menu['menuName'] ??
            menu['label'] ??
            menu['name'] ??
            'Menu')
        .toString();
  }

  String _menuPath(Map<String, dynamic> menu) {
    final raw = menu['menuUrl'] ?? menu['path'] ?? menu['route'] ?? '';
    return _normalizePath(raw.toString());
  }

  String _subMenuLabel(Map<String, dynamic> sub) {
    return (sub['subMenuTitle'] ?? sub['name'] ?? sub['label'] ?? 'Submenu')
        .toString();
  }

  String _subMenuPath(Map<String, dynamic> sub) {
    final raw = sub['subMenuUrl'] ?? sub['path'] ?? sub['route'] ?? '';
    return _normalizePath(raw.toString());
  }

  String _normalizePath(String raw) {
    if (raw.isEmpty || raw == '#') return '';
    return raw.startsWith('/') ? raw : '/$raw';
  }

  int _orderFor(NavMenuItem item) {
    final route = MenuRouteMapper.routeFromPath(item.path);
    final order = <AppRoute, int>{
      AppRoute.dashboard: 0,
      AppRoute.carriers: 5,
      AppRoute.powerUnit: 10,
      AppRoute.myTrailers: 20,
      AppRoute.maintenance: 30,
      AppRoute.faultCodes: 35,
      AppRoute.inventory: 40,
      AppRoute.logs: 50,
      AppRoute.documents: 60,
      AppRoute.reports: 70,
      AppRoute.requests: 80,
      AppRoute.approvals: 90,
      AppRoute.profile: 100,
    };
    return order[route] ?? 500;
  }

  List<NavMenuItem> _fallbackMenus() {
    return const [
      NavMenuItem(id: 'dashboard', label: 'Dashboard', path: '/dashboard'),
      NavMenuItem(id: 'carriers', label: 'Carrier', path: '/carriers'),
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
