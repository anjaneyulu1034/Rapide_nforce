class DvirDefectModel {
  const DvirDefectModel({
    required this.id,
    this.syncedDvirReportId,
    required this.defectName,
    required this.defectCode,
    this.defectDescription,
    required this.defectStatus,
    this.severity,
    this.vehicleNumber,
    this.vin,
    required this.companyName,
    required this.integrationSourceName,
    required this.createdAt,
    this.resolvedAt,
    this.resolvedBy,
    this.raw,
  });

  final String id;
  final String? syncedDvirReportId;
  final String defectName;
  final String defectCode;
  final String? defectDescription;
  final String defectStatus;
  final String? severity;
  final String? vehicleNumber;
  final String? vin;
  final String companyName;
  final String integrationSourceName;
  final String createdAt;
  final String? resolvedAt;
  final String? resolvedBy;
  final Map<String, dynamic>? raw;

  factory DvirDefectModel.fromJson(Map<String, dynamic> json) {
    return DvirDefectModel(
      id: json['id']?.toString() ?? '',
      syncedDvirReportId: json['syncedDvirReportId']?.toString(),
      defectName: json['defectName']?.toString() ?? 'Unknown Defect',
      defectCode: json['defectCode']?.toString() ?? '—',
      defectDescription: json['defectDescription']?.toString(),
      defectStatus: json['defectStatus']?.toString() ?? 'Open',
      severity: json['severity']?.toString(),
      vehicleNumber: json['vehicleNumber']?.toString(),
      vin: json['vin']?.toString(),
      companyName: json['companyName']?.toString() ?? '—',
      integrationSourceName: json['integrationSourceName']?.toString() ?? 'Samsara',
      createdAt: json['createdAt']?.toString() ?? '',
      resolvedAt: json['resolvedAt']?.toString(),
      resolvedBy: json['resolvedBy']?.toString(),
      raw: json,
    );
  }
}
