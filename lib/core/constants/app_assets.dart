/// Bundled image and icon paths (copied from rapidenforce-ui `src/assets`).
class AppAssets {
  AppAssets._();

  static const String logo = 'assets/images/logo/app_logo.svg';
  static const String logoFull = 'assets/images/logo/rapide-nforce-full.png';
  static const String logoPrimary = logoFull;

  static const String iconDashboard = 'assets/icons/dashboard.svg';
  static const String iconMyTrucks = 'assets/icons/myTrucks.svg';
  static const String iconMyTrailers = 'assets/icons/myTrailers.svg';
  static const String iconMaintenance = 'assets/icons/maintenance.svg';
  static const String iconDocuments = 'assets/icons/documents.svg';
  static const String iconReports = 'assets/icons/reports.svg';
  static const String iconRequests = 'assets/icons/requests.svg';

  /// Map API `menuIcon` / menu label to a bundled SVG (web sidebar parity).
  static String? iconForMenu({String? menuIcon, String? label}) {
    final key = (menuIcon ?? label ?? '').trim().toLowerCase();
    if (key.isEmpty) return null;

    if (key.contains('dashboard')) return iconDashboard;
    if (key.contains('mytruck') ||
        key.contains('powerunit') ||
        key.contains('power unit') ||
        key.contains('truck')) {
      return iconMyTrucks;
    }
    if (key.contains('trailer')) return iconMyTrailers;
    if (key.contains('maintenance') ||
        key.contains('work order') ||
        key.contains('work-order') ||
        key.contains('inventory') ||
        key.contains('log')) {
      return iconMaintenance;
    }
    if (key.contains('document')) return iconDocuments;
    if (key.contains('report')) return iconReports;
    if (key.contains('request')) return iconRequests;
    return null;
  }
}
