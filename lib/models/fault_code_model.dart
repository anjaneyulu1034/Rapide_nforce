class FaultCodeModel {
  const FaultCodeModel({
    required this.id,
    required this.vehicleNumber,
    required this.faultCode,
    required this.faultDescription,
    required this.faultStatus,
    this.companyName,
    this.vin,
    this.faultName,
    this.severity,
    this.integrationSourceName,
    this.lastDetectedAt,
    this.firstDetectedAt,
    this.reportedAt,
    this.createdAt,
  });

  final String id;
  final String vehicleNumber;
  final String faultCode;
  final String faultDescription;
  final String faultStatus;
  final String? companyName;
  final String? vin;
  final String? faultName;
  final String? severity;
  final String? integrationSourceName;
  final String? lastDetectedAt;
  final String? firstDetectedAt;
  final String? reportedAt;
  final String? createdAt;

  String get detectedAt =>
      lastDetectedAt ?? firstDetectedAt ?? reportedAt ?? createdAt ?? '';

  factory FaultCodeModel.fromJson(Map<String, dynamic> json) {
    final spn = json['spn']?.toString().trim();
    final fmi = json['fmi']?.toString().trim();
    final rawCode = json['faultCode'] as String? ?? '';
    final code = rawCode.trim().isNotEmpty
        ? rawCode.trim()
        : (spn != null &&
                spn.isNotEmpty &&
                fmi != null &&
                fmi.isNotEmpty)
            ? 'SPN $spn · FMI $fmi'
            : (spn != null && spn.isNotEmpty)
                ? 'SPN $spn'
                : '—';

    return FaultCodeModel(
      id: '${json['id']}',
      vehicleNumber: json['vehicleNumber'] as String? ?? '—',
      faultCode: code,
      faultDescription: json['faultDescription'] as String? ?? '',
      faultStatus: json['faultStatus'] as String? ?? 'Unknown',
      companyName: json['companyName'] as String?,
      vin: json['vin'] as String?,
      faultName: json['faultName'] as String?,
      severity: json['severity'] as String?,
      integrationSourceName: json['integrationSourceName'] as String?,
      lastDetectedAt: json['lastDetectedAt'] as String?,
      firstDetectedAt: json['firstDetectedAt'] as String?,
      reportedAt: json['reportedAt'] as String?,
      createdAt: json['createdAt'] as String?,
    );
  }
}
