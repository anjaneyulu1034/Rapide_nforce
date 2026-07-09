class DvirReportModel {
  const DvirReportModel({
    required this.id,
    required this.reportedAt,
    required this.driverName,
    required this.driverExternalId,
    required this.vehicleNumber,
    this.vin,
    required this.companyName,
    required this.defectCount,
    required this.inspectionType,
    required this.reportStatus,
    required this.integrationSourceName,
    this.raw,
  });

  final String id;
  final String reportedAt;
  final String driverName;
  final String driverExternalId;
  final String vehicleNumber;
  final String? vin;
  final String companyName;
  final int defectCount;
  final String inspectionType;
  final String reportStatus;
  final String integrationSourceName;
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
      defectCount: json['defectCount'] as int? ?? json['defect_count'] as int? ?? 0,
      inspectionType: json['inspectionType']?.toString() ?? 'Unspecified',
      reportStatus: json['reportStatus']?.toString() ?? json['safetyStatus']?.toString() ?? 'Safe',
      integrationSourceName: json['integrationSourceName']?.toString() ?? 'Samsara',
      raw: json,
    );
  }
}
