class CodeSeverity {
  const CodeSeverity({required this.label, required this.value});
  final String label; // 'MIL' or 'FMI'
  final String value;
}

class FaultCodeModel {
  const FaultCodeModel({
    required this.id,
    required this.vehicleNumber,
    required this.faultCode,
    required this.faultDescription,
    required this.faultStatus,
    this.companyId,
    this.companyName,
    this.companyTimeZone,
    this.vin,
    this.spn,
    this.fmi,
    this.faultName,
    this.severity,
    this.integrationSourceName,
    this.integrationSourceCode,
    this.externalFaultId,
    this.syncStatus,
    this.syncMethod,
    this.occurrenceCount,
    this.lastDetectedAt,
    this.firstDetectedAt,
    this.reportedAt,
    this.processedAt,
    this.lastSyncedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String vehicleNumber;
  final String faultCode;
  final String faultDescription;
  final String faultStatus;
  final int? companyId;
  final String? companyName;
  final String? companyTimeZone;
  final String? vin;
  final String? spn;
  final String? fmi;
  final String? faultName;
  final String? severity;
  final String? integrationSourceName;
  final String? integrationSourceCode;
  final String? externalFaultId;
  final String? syncStatus;
  final String? syncMethod;
  final int? occurrenceCount;
  final String? lastDetectedAt;
  final String? firstDetectedAt;
  final String? reportedAt;
  final String? processedAt;
  final String? lastSyncedAt;
  final String? createdAt;
  final String? updatedAt;

  String get detectedAt =>
      lastDetectedAt ?? firstDetectedAt ?? reportedAt ?? createdAt ?? '';

  bool get isActive {
    final status = faultStatus.trim().toLowerCase();
    return status == 'active' || status == 'open';
  }

  bool get isClosed {
    final status = faultStatus.trim().toLowerCase();
    return status == 'closed' || status == 'cleared' || status == 'resolved';
  }

  bool get isCritical {
    final sev = (severity ?? '').trim().toLowerCase();
    return sev == 'critical' || sev == 'high';
  }

  String get formattedStatus {
    if (faultStatus.trim().isEmpty) return 'Unknown';
    final n = faultStatus.trim().toLowerCase();
    if (n == 'active' || n == 'open') return 'Active';
    if (n == 'closed') return 'Closed';
    if (n == 'cleared') return 'Cleared';
    if (n == 'resolved') return 'Resolved';
    return n[0].toUpperCase() + n.substring(1);
  }

  CodeSeverity? get parsedCodeSeverity {
    final fmiTrimmed = fmi?.trim();
    if (fmiTrimmed != null && RegExp(r'^\d+$').hasMatch(fmiTrimmed)) {
      return CodeSeverity(label: 'FMI', value: fmiTrimmed);
    }

    final sevTrimmed = severity?.trim();
    if (sevTrimmed == null || sevTrimmed.isEmpty) return null;

    final milMatch = RegExp(r'^MIL\s*:?\s*(\d+)$', caseSensitive: false).firstMatch(sevTrimmed);
    if (milMatch != null) {
      return CodeSeverity(label: 'MIL', value: milMatch.group(1)!);
    }

    final fmiColonMatch = RegExp(r'^FMI\s*:\s*(\d+)$', caseSensitive: false).firstMatch(sevTrimmed);
    if (fmiColonMatch != null) {
      return CodeSeverity(label: 'FMI', value: fmiColonMatch.group(1)!);
    }

    final fmiSpaceMatch = RegExp(r'^FMI\s+(\d+)$', caseSensitive: false).firstMatch(sevTrimmed);
    if (fmiSpaceMatch != null) {
      return CodeSeverity(label: 'FMI', value: fmiSpaceMatch.group(1)!);
    }

    if (RegExp(r'^\d+$').hasMatch(sevTrimmed)) {
      return CodeSeverity(label: 'FMI', value: sevTrimmed);
    }

    return null;
  }

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

    final companyIdRaw = json['companyId'];
    int? companyIdParsed;
    if (companyIdRaw is num) {
      companyIdParsed = companyIdRaw.toInt();
    } else if (companyIdRaw is String) {
      companyIdParsed = int.tryParse(companyIdRaw);
    }

    final occRaw = json['occurrenceCount'];
    int? occParsed;
    if (occRaw is num) {
      occParsed = occRaw.toInt();
    } else if (occRaw is String) {
      occParsed = int.tryParse(occRaw);
    }

    return FaultCodeModel(
      id: '${json['id']}',
      vehicleNumber: json['vehicleNumber'] as String? ?? '—',
      faultCode: code,
      faultDescription: json['faultDescription'] as String? ?? '',
      faultStatus: json['faultStatus'] as String? ?? 'Unknown',
      companyId: companyIdParsed,
      companyName: json['companyName'] as String?,
      companyTimeZone: json['companyTimeZone'] as String?,
      vin: json['vin'] as String?,
      spn: spn,
      fmi: fmi,
      faultName: json['faultName'] as String?,
      severity: json['severity'] as String?,
      integrationSourceName: json['integrationSourceName'] as String?,
      integrationSourceCode: json['integrationSourceCode'] as String?,
      externalFaultId: (json['externalFaultId'] ?? json['externalFaultCodeId']) as String?,
      syncStatus: json['syncStatus'] as String?,
      syncMethod: json['syncMethod'] as String?,
      occurrenceCount: occParsed,
      lastDetectedAt: json['lastDetectedAt'] as String?,
      firstDetectedAt: json['firstDetectedAt'] as String?,
      reportedAt: json['reportedAt'] as String?,
      processedAt: json['processedAt'] as String?,
      lastSyncedAt: json['lastSyncedAt'] as String?,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
    );
  }
}
