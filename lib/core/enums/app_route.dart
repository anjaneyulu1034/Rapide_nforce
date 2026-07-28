enum AppRoute {
  dashboard,
  carriers,
  powerUnit,
  myTrailers,
  maintenance,
  dvir,
  faultCodes,
  inventory,
  logs,
  documents,
  reports,
  requests,
  approvals,
  profile,
  drivers,
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
      case AppRoute.dvir:
        return 'DVIR Inspection Reports';
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
      case AppRoute.drivers:
        return 'Drivers';
    }
  }
}

const List<AppRoute> kDrawerRoutes = [
  AppRoute.dashboard,
  AppRoute.carriers,
  AppRoute.powerUnit,
  AppRoute.myTrailers,
  AppRoute.maintenance,
  AppRoute.dvir,
  AppRoute.inventory,
  AppRoute.logs,
  AppRoute.documents,
  AppRoute.reports,
  AppRoute.requests,
  AppRoute.approvals,
  AppRoute.profile,
  AppRoute.drivers,
];

/// Main bottom navigation tabs (4 icons).
const List<AppRoute> kBottomNavRoutes = [
  AppRoute.dashboard,
  AppRoute.maintenance,
  AppRoute.requests,
  AppRoute.profile,
];

extension AppRouteNavX on AppRoute {
  String get bottomNavLabel {
    switch (this) {
      case AppRoute.dashboard:
        return 'Home';
      case AppRoute.maintenance:
        return 'Maintenance';
      case AppRoute.requests:
        return 'Requests';
      case AppRoute.profile:
        return 'Profile';
      default:
        return title;
    }
  }
}

const List<({String label, AppRoute route})> kMaintenanceSubRoutes = [
  (label: 'Work Orders', route: AppRoute.maintenance),
  (label: 'DVIR', route: AppRoute.dvir),
  (label: 'Fault Codes', route: AppRoute.faultCodes),
  (label: 'Inventory', route: AppRoute.inventory),
  (label: 'Logs', route: AppRoute.logs),
];
