/// API endpoint paths and shared request constants.
class ApiConstants {
  ApiConstants._();

  /// Dev API (pairs with web UI: https://cm-ui-dev.iicl.app)
  static const String baseUrl = 'https://cm-api-dev.iicl.app/api/v1';

  /// Production API
  // static const String baseUrl = 'https://api.rapidenforce.com/v1';

  static const String allCarriersId = 'ALL_CARRIERS';
  // Auth
  static const String login = '/auth/login';
  static const String me = '/auth/me';
  static const String logout = '/auth/logout';
  static const String changePassword = '/auth/change-password';

  // Users & uploads
  static const String users = '/users';
  static const String uploads = '/uploads';

  // Fleet
  static const String trucks = '/trucks';
  static const String trailers = '/trailers';
  static const String carriers = '/carriers';
  static const String consentDocuments = '/consent-documents';
  static const String plans = '/plans';
  static const String billingCycles = '/billing-cycles';
  static const String countries = '/countries';
  static const String states = '/states';
  static const String cities = '/cities';
  static const String fuelTypes = '/Fuel%20Types/getAllFuelTypes';
  static const String maintenancePolicies = '/maintenance-policies';
  static const String permitTypes = '/permit-types';
  static const String complianceDocumentTypes = '/compliance-document-types';
  static const String documentCategories = '/document-categories';
  static const String drivers = '/drivers';

  // Documents
  static const String documents = '/documents';
  static const String documentsExpiring = '/documents/expiring';
  static const String documentsNoExpiry = '/documents/no-expiry';

  // OCR (Browse/Scan auto-fill on Add/Edit forms)
  static const String ocrResults = '/ocr/ocr-results';

  // Notifications
  static const String notifications = '/notifications';

  // Fault codes
  static const String syncedFaultCodes = '/synced-fault-codes';

  // Dashboard
  static const String dashboardAdmin = '/dashboard/admin';

  // Maintenance
  static const String workOrders = '/maintenance/work-orders';
  static const String maintenanceSummary = '/maintenance/summary';
  static const String myRequests = '/maintenance/my-requests';
  static const String maintenanceApprovals = '/maintenance/approvals';
  static const String maintenanceLogs = '/maintenance/logs';
  static const String techniciansSummary = '/maintenance/technicians-summary';
  static const String partTypes = '/maintenance/part-types';
  static const String partTypesSummary = '/maintenance/part-types-summary';
  static const String parts = '/maintenance/parts';
  static const String samsaraOdometer = '/maintenance/samsara-odometer';
  static const String pmInspectionItems = '/maintenance/pm-inspection-items';
  static const String maintenanceIssues = '/maintenance/maintenance-issues';
  static const String maintenanceIssueUploads =
      '/maintenance/maintenance-issues/uploads';
  static const String workOrderLabourEntries =
      '/maintenance/work-order-labour-entries';
  static const String workOrderLabourTimerLogs =
      '/maintenance/work-order-labour-timer-logs';
  static const String entityTypes = '/entity-types';
  static const String entities = '/entities';
  static const String companies = '/companies';

  // Menus (sidebar — same as web GET /menus/me)
  static const String menus = '/menus';
  static const String menusMe = '/menus/me';
  static const String menusAccess = '/menus/access';

  // Menu CRUD permissions (same as web GET /manage-permissions/by-user/:id)
  static const String managePermissionsByUser = '/manage-permissions/by-user';

  // Reports
  static const String reportsOcrAuditLogs = '/reports/ocr-audit-logs';
  static const String reportsTruckSafety = '/reports/trucks/safety-pdf-table';

  // Legacy
  static const String dashboard = '/dashboard/summary';
  static const String opportunities = '/opportunities';
}
