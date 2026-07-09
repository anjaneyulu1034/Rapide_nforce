import 'package:flutter/material.dart';

/// Tolerant JSON coercions — backend numeric/decimal fields are sometimes
/// serialized as strings (e.g. Prisma `Decimal` columns), so a strict `as`
/// cast would throw and fail the whole parse over one field.
int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

num? _asNum(dynamic value) {
  if (value == null) return null;
  if (value is num) return value;
  return num.tryParse(value.toString());
}

bool _asBool(dynamic value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is String) return value.toLowerCase() == 'true';
  if (value is num) return value != 0;
  return fallback;
}

/// Repair line status — aligned with backend `repair_status` values.
enum RepairStatus {
  notStarted('NOT_STARTED', 'Not Started'),
  inProgress('IN_PROGRESS', 'In Progress'),
  pendingParts('PENDING_PARTS', 'Pending Parts'),
  completed('COMPLETED', 'Completed'),
  deferred('DEFERRED', 'Deferred'),
  cancelled('CANCELLED', 'Cancelled'),
  onHold('ON_HOLD', 'On Hold');

  const RepairStatus(this.code, this.label);

  final String code;
  final String label;

  static RepairStatus fromCode(String? code) {
    return RepairStatus.values.firstWhere(
      (s) => s.code == code,
      orElse: () => RepairStatus.notStarted,
    );
  }

  Color get backgroundColor {
    switch (this) {
      case RepairStatus.notStarted:
        return const Color(0xFFF3F4F6);
      case RepairStatus.inProgress:
        return const Color(0xFFDBEAFE);
      case RepairStatus.pendingParts:
        return const Color(0xFFFFF7ED);
      case RepairStatus.completed:
        return const Color(0xFFDCFCE7);
      case RepairStatus.deferred:
        return const Color(0xFFFEE2E2);
      case RepairStatus.cancelled:
        return const Color(0xFFF3F4F6);
      case RepairStatus.onHold:
        return const Color(0xFFFFF7ED);
    }
  }

  Color get textColor {
    switch (this) {
      case RepairStatus.notStarted:
        return const Color(0xFF374151);
      case RepairStatus.inProgress:
        return const Color(0xFF1447E6);
      case RepairStatus.pendingParts:
        return const Color(0xFFEA580C);
      case RepairStatus.completed:
        return const Color(0xFF008236);
      case RepairStatus.deferred:
        return const Color(0xFF991B1B);
      case RepairStatus.cancelled:
        return const Color(0xFF6B7280);
      case RepairStatus.onHold:
        return const Color(0xFFEA580C);
    }
  }
}

enum RepairPerformedBy {
  internal('INTERNAL', 'Internal'),
  external('EXTERNAL', 'External');

  const RepairPerformedBy(this.code, this.label);

  final String code;
  final String label;

  static RepairPerformedBy fromCode(String? code) {
    return RepairPerformedBy.values.firstWhere(
      (s) => s.code == code,
      orElse: () => RepairPerformedBy.internal,
    );
  }
}

/// PM inspection result code per checklist item.
enum PmResultCode {
  ok('OK', 'OK'),
  adjusted('A', 'Adjusted'),
  greased('G', 'Greased & Lubed'),
  repaired('R', 'Repaired'),
  serviced('S', 'Serviced'),
  defective('X', 'Defective'),
  notApplicable('NA', 'Not Equipped');

  const PmResultCode(this.code, this.label);

  final String code;
  final String label;

  static PmResultCode fromCode(String? code) {
    return PmResultCode.values.firstWhere(
      (s) => s.code == code,
      orElse: () => PmResultCode.ok,
    );
  }
}

class WorkOrderAttachment {
  const WorkOrderAttachment({required this.key, this.url, this.fileName});

  final String key;
  final String? url;
  final String? fileName;

  String get displayName => fileName ?? key.split('/').last;

  factory WorkOrderAttachment.fromJson(Map<String, dynamic> json) {
    return WorkOrderAttachment(
      key: json['key']?.toString() ?? '',
      url: json['url']?.toString(),
      fileName: json['fileName']?.toString() ?? json['name']?.toString(),
    );
  }

  static List<WorkOrderAttachment> listFromDynamic(dynamic raw) {
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => WorkOrderAttachment.fromJson(e.cast<String, dynamic>()))
          .toList();
    }
    return const [];
  }
}

class PmInspectionItem {
  const PmInspectionItem({
    required this.id,
    required this.categoryId,
    required this.itemName,
    this.sortOrder = 0,
    this.entityTypeId,
  });

  final int id;
  final int categoryId;
  final String itemName;
  final int sortOrder;
  final int? entityTypeId;

  factory PmInspectionItem.fromJson(Map<String, dynamic> json) {
    return PmInspectionItem(
      id: _asInt(json['id']) ?? 0,
      categoryId: _asInt(json['category_id']) ?? 0,
      itemName: json['item_name']?.toString() ?? '',
      sortOrder: _asInt(json['sort_order']) ?? 0,
      entityTypeId: _asInt(json['entity_type_id']),
    );
  }
}

class PmInspectionCategory {
  const PmInspectionCategory({
    required this.id,
    required this.code,
    required this.name,
    this.entityTypeId,
    this.items = const [],
  });

  final int id;
  final String code;
  final String name;
  final int? entityTypeId;
  final List<PmInspectionItem> items;

  factory PmInspectionCategory.fromJson(Map<String, dynamic> json) {
    final itemsRaw = json['items'] as List<dynamic>? ?? [];
    return PmInspectionCategory(
      id: _asInt(json['id']) ?? 0,
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      entityTypeId: _asInt(json['entity_type_id']),
      items: itemsRaw
          .whereType<Map>()
          .map((e) =>
              PmInspectionItem.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }
}

/// A filled-in result for one [PmInspectionItem] on a work order.
class PmInspectionResultModel {
  PmInspectionResultModel({
    required this.itemId,
    this.itemName,
    this.isChecked = false,
    this.code = PmResultCode.ok,
    this.repairNotes,
    this.repairDate,
  });

  final int itemId;
  final String? itemName;
  bool isChecked;
  PmResultCode code;
  String? repairNotes;
  String? repairDate;

  factory PmInspectionResultModel.fromJson(Map<String, dynamic> json) {
    final item = json['item'];
    return PmInspectionResultModel(
      itemId: _asInt(json['item_id']) ?? 0,
      itemName: item is Map ? item['item_name']?.toString() : null,
      isChecked: _asBool(json['is_checked']),
      code: PmResultCode.fromCode(json['code']?.toString()),
      repairNotes: json['repair_notes']?.toString(),
      repairDate: json['repair_date']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'item_id': itemId,
        'code': code.code,
        'is_checked': isChecked,
        if (repairNotes != null) 'repair_notes': repairNotes,
        if (repairDate != null) 'repair_date': repairDate,
      };
}

class PmTireMeasurementModel {
  PmTireMeasurementModel({
    required this.position,
    this.axleNo,
    this.tireAirPsi,
    this.treadDepth32nds,
    this.pushrodMeasurementIn,
    this.brakeLiningPercent,
    this.brakeMeasurementIn,
    this.brakePercentage,
  });

  final String position;
  final int? axleNo;
  num? tireAirPsi;
  num? treadDepth32nds;
  num? pushrodMeasurementIn;
  num? brakeLiningPercent;
  num? brakeMeasurementIn;
  num? brakePercentage;

  factory PmTireMeasurementModel.fromJson(Map<String, dynamic> json) {
    return PmTireMeasurementModel(
      position: json['position']?.toString() ?? '',
      axleNo: _asInt(json['axle_no']),
      tireAirPsi: _asNum(json['tire_air_psi']),
      treadDepth32nds: _asNum(json['tread_depth_32nds']),
      pushrodMeasurementIn: _asNum(json['pushrod_measurement_in']),
      brakeLiningPercent: _asNum(json['brake_lining_percent']),
      brakeMeasurementIn: _asNum(json['brake_measurement_in']),
      brakePercentage: _asNum(json['brake_percentage']),
    );
  }

  Map<String, dynamic> toJson() => {
        'position': position,
        if (axleNo != null) 'axle_no': axleNo,
        if (tireAirPsi != null) 'tire_air_psi': tireAirPsi,
        if (treadDepth32nds != null) 'tread_depth_32nds': treadDepth32nds,
        if (pushrodMeasurementIn != null)
          'pushrod_measurement_in': pushrodMeasurementIn,
        if (brakeLiningPercent != null)
          'brake_lining_percent': brakeLiningPercent,
        if (brakeMeasurementIn != null)
          'brake_measurement_in': brakeMeasurementIn,
        if (brakePercentage != null) 'brake_percentage': brakePercentage,
      };
}

class PmDefectModel {
  PmDefectModel({
    required this.rowNo,
    this.defectDescription,
    this.quantity,
    this.actionTaken,
  });

  final int rowNo;
  String? defectDescription;
  num? quantity;
  String? actionTaken;

  factory PmDefectModel.fromJson(Map<String, dynamic> json) {
    return PmDefectModel(
      rowNo: _asInt(json['row_no']) ?? 0,
      defectDescription: json['defect_description']?.toString(),
      quantity: _asNum(json['quantity']),
      actionTaken: json['action_taken']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'row_no': rowNo,
        if (defectDescription != null) 'defect_description': defectDescription,
        if (quantity != null) 'quantity': quantity,
        if (actionTaken != null) 'action_taken': actionTaken,
      };
}

class WorkOrderLabourEntry {
  const WorkOrderLabourEntry({
    required this.id,
    required this.workOrderId,
    this.workOrderPartId,
    this.userId,
    this.userName,
    this.workDate,
    this.regularHours,
    this.overtimeHours,
    this.labourCost,
    this.labourBillableAmount,
    this.approvalStatus,
    this.timerStartedAt,
    this.timerStoppedAt,
    this.totalTimerMinutes,
  });

  final int id;
  final int workOrderId;
  final int? workOrderPartId;
  final int? userId;
  final String? userName;
  final String? workDate;
  final num? regularHours;
  final num? overtimeHours;
  final num? labourCost;
  final num? labourBillableAmount;
  final String? approvalStatus;
  final String? timerStartedAt;
  final String? timerStoppedAt;
  final int? totalTimerMinutes;

  bool get timerRunning => timerStartedAt != null && timerStoppedAt == null;

  factory WorkOrderLabourEntry.fromJson(Map<String, dynamic> json) {
    return WorkOrderLabourEntry(
      id: _asInt(json['id']) ?? 0,
      workOrderId: _asInt(json['workOrderId']) ?? 0,
      workOrderPartId: _asInt(json['workOrderPartId']),
      userId: _asInt(json['userId']),
      userName: json['userName']?.toString(),
      workDate: json['workDate']?.toString(),
      regularHours: _asNum(json['regularHours']),
      overtimeHours: _asNum(json['overtimeHours']),
      labourCost: _asNum(json['labourCost']),
      labourBillableAmount: _asNum(json['labourBillableAmount']),
      approvalStatus: json['approvalStatus']?.toString(),
      timerStartedAt: json['timerStartedAt']?.toString(),
      timerStoppedAt: json['timerStoppedAt']?.toString(),
      totalTimerMinutes: _asInt(json['totalTimerMinutes']),
    );
  }
}

/// A DVIR defect / fault code / manual issue that can be linked to a work order.
class MaintenanceIssueSummary {
  const MaintenanceIssueSummary({
    required this.id,
    required this.issueSource,
    this.issueName,
    this.issueDescription,
    this.severity,
    this.firstReportedAt,
    this.lastReportedAt,
    this.defect,
    this.category,
    this.status,
    this.externalReference,
    this.reportedDate,
    this.reportedBy,
  });

  final int id;
  final String issueSource;
  final String? issueName;
  final String? issueDescription;
  final String? severity;
  final String? firstReportedAt;
  final String? lastReportedAt;
  final String? defect;
  final String? category;
  final String? status;
  final String? externalReference;
  final String? reportedDate;
  final String? reportedBy;

  factory MaintenanceIssueSummary.fromJson(Map<String, dynamic> json) {
    return MaintenanceIssueSummary(
      id: _asInt(json['id']) ?? 0,
      issueSource: json['issueSource']?.toString() ?? 'MANUAL',
      issueName: json['issueName']?.toString(),
      issueDescription: json['issueDescription']?.toString(),
      severity: json['severity']?.toString(),
      firstReportedAt: json['firstReportedAt']?.toString(),
      lastReportedAt: json['lastReportedAt']?.toString(),
      defect: json['defect']?.toString(),
      category: json['category']?.toString(),
      status: json['status']?.toString(),
      externalReference: json['externalReference']?.toString() ??
          json['external_reference']?.toString(),
      reportedDate: json['reportedDate']?.toString(),
      reportedBy: json['reportedBy']?.toString(),
    );
  }
}

class MaintenanceIssueUpload {
  const MaintenanceIssueUpload({
    required this.id,
    required this.fileName,
    this.fileType,
    this.signedUrl,
  });

  final int id;
  final String fileName;
  final String? fileType;
  final String? signedUrl;

  bool get isImage {
    final type = (fileType ?? '').toLowerCase();
    if (type.startsWith('image/')) return true;
    final name = fileName.toLowerCase();
    return name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.png') ||
        name.endsWith('.gif') ||
        name.endsWith('.webp') ||
        name.endsWith('.bmp') ||
        name.endsWith('.svg');
  }

  factory MaintenanceIssueUpload.fromJson(Map<String, dynamic> json) {
    return MaintenanceIssueUpload(
      id: _asInt(json['id']) ?? 0,
      fileName: json['fileName']?.toString() ?? 'file',
      fileType: json['fileType']?.toString(),
      signedUrl: json['signedUrl']?.toString(),
    );
  }
}
