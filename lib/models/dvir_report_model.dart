int? _parseInt(dynamic value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

class DvirReportModel {
  const DvirReportModel({
    required this.id,
    required this.reportedAt,
    required this.driverName,
    required this.driverExternalId,
    required this.vehicleNumber,
    this.vin,
    required this.companyName,
    this.companyId,
    this.companyTimeZone,
    required this.defectCount,
    required this.inspectionType,
    required this.reportStatus,
    this.safetyStatus,
    required this.integrationSourceName,
    this.integrationSourceId,
    this.integrationSourceCode,
    this.syncMethod,
    this.externalReportId,
    this.entityTypeId,
    this.entityId,
    this.syncStatus,
    this.processedAt,
    this.lastSyncedAt,
    this.createdAt,
    this.updatedAt,
    this.raw,
  });

  final String id;
  final String reportedAt;
  final String driverName;
  final String driverExternalId;
  final String vehicleNumber;
  final String? vin;
  final String companyName;
  final int? companyId;
  final String? companyTimeZone;
  final int defectCount;
  final String inspectionType;
  final String reportStatus;
  /// Raw `safetyStatus` from the API, distinct from `reportStatus` (the two
  /// are usually equal but the web app surfaces them as separate fields).
  final String? safetyStatus;
  final String integrationSourceName;
  final int? integrationSourceId;
  final String? integrationSourceCode;
  final String? syncMethod;
  final String? externalReportId;
  final int? entityTypeId;
  final int? entityId;
  final String? syncStatus;
  final String? processedAt;
  final String? lastSyncedAt;
  final String? createdAt;
  final String? updatedAt;
  final Map<String, dynamic>? raw;

  factory DvirReportModel.fromJson(Map<String, dynamic> json) {
    return DvirReportModel(
      id: json['id']?.toString() ?? '',
      reportedAt: json['reportedAt']?.toString() ?? '',
      driverName: json['driverName']?.toString() ?? 'Unknown',
      driverExternalId: json['driverExternalId']?.toString() ?? '—',
      vehicleNumber: json['vehicleNumber']?.toString() ?? '—',
      vin: json['vin']?.toString(),
      companyName: json['companyName']?.toString() ?? '—',
      companyId: _parseInt(json['companyId']),
      companyTimeZone: json['companyTimeZone']?.toString(),
      defectCount: json['defectCount'] as int? ?? json['defect_count'] as int? ?? 0,
      inspectionType: json['inspectionType']?.toString() ?? 'Unspecified',
      reportStatus: json['reportStatus']?.toString() ?? json['safetyStatus']?.toString() ?? 'Safe',
      safetyStatus: json['safetyStatus']?.toString(),
      integrationSourceName: json['integrationSourceName']?.toString() ?? 'Samsara',
      integrationSourceId: _parseInt(json['integrationSourceId']),
      integrationSourceCode: json['integrationSourceCode']?.toString(),
      syncMethod: json['syncMethod']?.toString(),
      externalReportId: json['externalReportId']?.toString(),
      entityTypeId: _parseInt(json['entityTypeId']),
      entityId: _parseInt(json['entityId']),
      syncStatus: json['syncStatus']?.toString(),
      processedAt: json['processedAt']?.toString(),
      lastSyncedAt: json['lastSyncedAt']?.toString(),
      createdAt: json['createdAt']?.toString(),
      updatedAt: json['updatedAt']?.toString(),
      raw: json,
    );
  }
}
