import 'package:rapide_nforce/core/enums/app_route.dart';

/// Maps web sidebar paths (`/menus/me`) to Flutter [AppRoute] values.
class MenuRouteMapper {
  MenuRouteMapper._();

  static AppRoute? routeFromPath(String? rawPath) {
    if (rawPath == null || rawPath.isEmpty || rawPath == '#') return null;

    final path = _normalize(rawPath);
    if (path.isEmpty) return null;

    switch (path) {
      case '/dashboard':
      case '/superadmin_dashboard':
        return AppRoute.dashboard;
      case '/carriers':
      case '/carrier-management':
        return AppRoute.carriers;
      case '/powerunit':
      case '/trucks':
        return AppRoute.powerUnit;
      case '/trailers':
        return AppRoute.myTrailers;
      case '/maintenance':
      case '/work-orders':
      case '/work-orders-review':
        return AppRoute.maintenance;
      case '/fault-codes':
        return AppRoute.faultCodes;
      case '/inventory':
        return AppRoute.inventory;
      case '/logs':
        return AppRoute.logs;
      case '/documents':
        return AppRoute.documents;
      case '/reports':
      case '/reports/ocr-audit-logs':
        return AppRoute.reports;
      case '/requests':
        return AppRoute.requests;
      case '/lead-approvals':
        return AppRoute.approvals;
      case '/settings':
      case '/user-profile':
        return AppRoute.profile;
      default:
        return null;
    }
  }

  static String _normalize(String raw) {
    var path = raw.trim().toLowerCase();
    if (!path.startsWith('/')) path = '/$path';
    if (path.length > 1 && path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    return path;
  }

  static bool isMaintenanceLabel(String label) {
    final name = label.trim().toLowerCase();
    return name == 'maintenance';
  }

  static bool isStandaloneMaintenanceChild(String label) {
    final name = label.trim().toLowerCase();
    return name == 'inventory' ||
        name == 'work orders' ||
        name == 'work-orders' ||
        name == 'logs';
  }
}
