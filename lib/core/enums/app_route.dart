enum AppRoute {
  dashboard,
  carriers,
  powerUnit,
  myTrailers,
  maintenance,
  faultCodes,
  inventory,
  logs,
  documents,
  reports,
  requests,
  approvals,
  profile,
}

extension AppRouteX on AppRoute {
  String get title {
    switch (this) {
      case AppRoute.dashboard:
        return 'Dashboard';
      case AppRoute.carriers:
        return 'Carrier';
      case AppRoute.powerUnit:
        return 'Power Unit';
      case AppRoute.myTrailers:
        return 'My Trailers';
      case AppRoute.maintenance:
        return 'Work Orders';
      case AppRoute.faultCodes:
        return 'Fault Codes';
      case AppRoute.inventory:
        return 'Inventory';
      case AppRoute.logs:
        return 'Logs';
      case AppRoute.documents:
        return 'Documents';
      case AppRoute.reports:
        return 'Reports';
      case AppRoute.requests:
        return 'Requests';
      case AppRoute.approvals:
        return 'Approvals';
      case AppRoute.profile:
        return 'Profile';
    }
  }
}

const List<AppRoute> kDrawerRoutes = [
  AppRoute.dashboard,
  AppRoute.carriers,
  AppRoute.powerUnit,
  AppRoute.myTrailers,
  AppRoute.maintenance,
  AppRoute.inventory,
  AppRoute.logs,
  AppRoute.documents,
  AppRoute.reports,
  AppRoute.requests,
  AppRoute.approvals,
  AppRoute.profile,
];

/// Main bottom navigation tabs (4 icons).
const List<AppRoute> kBottomNavRoutes = [
  AppRoute.dashboard,
  AppRoute.maintenance,
  AppRoute.approvals,
  AppRoute.profile,
];

extension AppRouteNavX on AppRoute {
  String get bottomNavLabel {
    switch (this) {
      case AppRoute.dashboard:
        return 'Home';
      case AppRoute.powerUnit:
        return 'Power Unit';
      case AppRoute.maintenance:
        return 'Work Order';
      case AppRoute.approvals:
        return 'Approvals';
      case AppRoute.profile:
        return 'Profile';
      default:
        return title;
    }
  }
}

const List<({String label, AppRoute route})> kMaintenanceSubRoutes = [
  (label: 'Work Orders', route: AppRoute.maintenance),
  (label: 'Inventory', route: AppRoute.inventory),
  (label: 'Logs', route: AppRoute.logs),
];
