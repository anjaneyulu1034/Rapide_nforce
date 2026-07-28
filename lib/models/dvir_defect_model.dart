int? _parseInt(dynamic value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

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
    this.companyId,
    this.companyTimeZone,
    required this.integrationSourceName,
    this.integrationSourceId,
    this.integrationSourceCode,
    this.entityTypeId,
    this.entityId,
    this.externalDefectId,
    required this.createdAt,
    this.updatedAt,
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
  final int? companyId;
  final String? companyTimeZone;
  final String integrationSourceName;
  final int? integrationSourceId;
  final String? integrationSourceCode;
  final int? entityTypeId;
  final int? entityId;
  final String? externalDefectId;
  final String createdAt;
  final String? updatedAt;
  final String? resolvedAt;
  final String? resolvedBy;
  final Map<String, dynamic>? raw;

  bool get isOpen {
    final s = defectStatus.trim().toLowerCase();
    return s == 'open' || s == 'unresolved';
  }

  bool get isResolved {
    final s = defectStatus.trim().toLowerCase();
    return s == 'resolved' ||
        s == 'corrected' ||
        s == 'repaired' ||
        s == 'closed' ||
        s == 'no_repair_needed';
  }

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
      companyId: _parseInt(json['companyId']),
      companyTimeZone: json['companyTimeZone']?.toString(),
      integrationSourceName: json['integrationSourceName']?.toString() ?? 'Samsara',
      integrationSourceId: _parseInt(json['integrationSourceId']),
      integrationSourceCode: json['integrationSourceCode']?.toString(),
      entityTypeId: _parseInt(json['entityTypeId']),
      entityId: _parseInt(json['entityId']),
      externalDefectId: json['externalDefectId']?.toString(),
      createdAt: json['createdAt']?.toString() ?? '',
      updatedAt: json['updatedAt']?.toString(),
      resolvedAt: json['resolvedAt']?.toString(),
      resolvedBy: json['resolvedBy']?.toString(),
      raw: json,
    );
  }
}
