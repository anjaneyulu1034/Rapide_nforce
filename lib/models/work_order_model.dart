import 'package:flutter/material.dart';
import 'package:rapide_nforce/models/work_order_pm_model.dart';

export 'package:rapide_nforce/models/work_order_pm_model.dart';

/// Tolerant JSON coercions — backend numeric/decimal fields are sometimes
/// serialized as strings (e.g. Prisma `Decimal` columns), so a strict `as`
/// cast would throw and fail the whole work order load over one field.
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

/// Parses a raw JSON list defensively: if any single item fails to parse,
/// that item is skipped rather than the whole list (and its parent object)
/// failing to load.
List<T> _tryParseList<T>(
  dynamic raw,
  T Function(Map<String, dynamic>) parse,
) {
  if (raw is! List) return const [];
  final result = <T>[];
  for (final item in raw) {
    if (item is! Map) continue;
    try {
      result.add(parse(item.cast<String, dynamic>()));
    } catch (_) {
      // Skip malformed entries instead of failing the entire parse.
    }
  }
  return result;
}

/// Work order status codes — aligned with web `WorkOrderStatus` enum.
enum WorkOrderStatus {
  notStarted(1, 'Not Started'),
  inProgress(2, 'In Progress'),
  onHold(3, 'On Hold'),
  completed(4, 'Completed');

  const WorkOrderStatus(this.code, this.label);

  final int code;
  final String label;

  static WorkOrderStatus fromCode(int? code) {
    return WorkOrderStatus.values.firstWhere(
      (s) => s.code == code,
      orElse: () => WorkOrderStatus.notStarted,
    );
  }

  bool get canEdit => this != WorkOrderStatus.completed;

  Color get backgroundColor {
    switch (this) {
      case WorkOrderStatus.notStarted:
        return const Color(0xFFF3F4F6);
      case WorkOrderStatus.inProgress:
        return const Color(0xFFDBEAFE);
      case WorkOrderStatus.onHold:
        return const Color(0xFFFFF7ED);
      case WorkOrderStatus.completed:
        return const Color(0xFFDCFCE7);
    }
  }

  Color get textColor {
    switch (this) {
      case WorkOrderStatus.notStarted:
        return const Color(0xFF374151);
      case WorkOrderStatus.inProgress:
        return const Color(0xFF1447E6);
      case WorkOrderStatus.onHold:
        return const Color(0xFFEA580C);
      case WorkOrderStatus.completed:
        return const Color(0xFF008236);
    }
  }
}

enum WorkOrderPriority {
  high(1, 'High'),
  medium(2, 'Medium'),
  low(3, 'Low');

  const WorkOrderPriority(this.code, this.label);

  final int code;
  final String label;

  static WorkOrderPriority fromCode(int? code) {
    return WorkOrderPriority.values.firstWhere(
      (p) => p.code == code,
      orElse: () => WorkOrderPriority.medium,
    );
  }

  Color get backgroundColor {
    switch (this) {
      case WorkOrderPriority.high:
        return const Color(0xFFFEE2E2);
      case WorkOrderPriority.medium:
        return const Color(0xFFDBEAFE);
      case WorkOrderPriority.low:
        return const Color(0xFFF3F4F6);
    }
  }

  Color get textColor {
    switch (this) {
      case WorkOrderPriority.high:
        return const Color(0xFF991B1B);
      case WorkOrderPriority.medium:
        return const Color(0xFF1E40AF);
      case WorkOrderPriority.low:
        return const Color(0xFF374151);
    }
  }
}

class WorkOrderDetails {
  const WorkOrderDetails({
    this.priority,
    this.odometer,
    this.startOdometer,
    this.endOdometer,
    this.estimatedCost,
    this.assignee,
    this.hours,
    this.location,
    this.startDate,
    this.dueDate,
    this.endDate,
    this.technicianName,
  });

  final int? priority;
  final String? odometer;
  final String? startOdometer;
  final String? endOdometer;
  final double? estimatedCost;
  final int? assignee;
  final String? hours;
  final String? location;
  final String? startDate;
  final String? dueDate;
  final String? endDate;
  final String? technicianName;

  WorkOrderPriority? get priorityEnum =>
      priority != null ? WorkOrderPriority.fromCode(priority) : null;

  factory WorkOrderDetails.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const WorkOrderDetails();
    final tech = json['technician'];
    return WorkOrderDetails(
      priority: _asInt(json['priority']),
      odometer: json['odometer']?.toString(),
      startOdometer: json['startOdometer']?.toString() ??
          json['start_odometer']?.toString(),
      endOdometer:
          json['endOdometer']?.toString() ?? json['end_odometer']?.toString(),
      estimatedCost: _toDouble(json['estimatedCost'] ?? json['estimated_cost']),
      assignee: _asInt(json['assignee']),
      hours: json['hours']?.toString(),
      location: json['location']?.toString(),
      startDate: json['startDate']?.toString() ?? json['start_date']?.toString(),
      dueDate: json['dueDate']?.toString() ?? json['due_date']?.toString(),
      endDate: json['endDate']?.toString() ?? json['end_date']?.toString(),
      technicianName: tech is Map
          ? tech['name']?.toString()
          : json['technicianName']?.toString(),
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}

class WorkOrderPartLine {
  const WorkOrderPartLine({
    this.id,
    this.description,
    this.partTypeId,
    this.partId,
    this.quantityUsed,
    this.partCode,
    this.partName,
    this.cost,
    this.repairPerformedBy = RepairPerformedBy.internal,
    this.repairStatus = RepairStatus.notStarted,
    this.assignedTechnicianId,
    this.vendorName,
    this.vendorContact,
    this.vendorInvoiceNumber,
    this.repairStartedAt,
    this.repairCompletedAt,
    this.repairNotes,
    this.defectHours,
  });

  final int? id;
  final String? description;
  final int? partTypeId;
  final int? partId;
  final num? quantityUsed;
  final String? partCode;
  final String? partName;
  final num? cost;
  final RepairPerformedBy repairPerformedBy;
  final RepairStatus repairStatus;
  final int? assignedTechnicianId;
  final String? vendorName;
  final String? vendorContact;
  final String? vendorInvoiceNumber;
  final String? repairStartedAt;
  final String? repairCompletedAt;
  final String? repairNotes;
  final num? defectHours;

  factory WorkOrderPartLine.fromJson(Map<String, dynamic> json) {
    final part = json['part'];
    return WorkOrderPartLine(
      id: _toInt(json['id']),
      description: json['description']?.toString() ??
          json['usageDescription']?.toString(),
      partTypeId: _toInt(json['partTypeId'] ?? json['part_type_id']),
      partId: _toInt(json['partId'] ?? json['usedPart'] ?? part?['id']),
      quantityUsed: _toNum(json['quantityUsed'] ?? json['quantity']),
      partCode: part is Map ? part['code']?.toString() : null,
      partName: part is Map ? part['name']?.toString() : null,
      cost: part is Map ? _toNum(part['cost']) : null,
      repairPerformedBy: RepairPerformedBy.fromCode(
          json['repairPerformedBy']?.toString()),
      repairStatus:
          RepairStatus.fromCode(json['repairStatus']?.toString()),
      assignedTechnicianId: _toInt(json['assignedTechnicianId']),
      vendorName: json['vendorName']?.toString(),
      vendorContact: json['vendorContact']?.toString(),
      vendorInvoiceNumber: json['vendorInvoiceNumber']?.toString(),
      repairStartedAt: json['repairStartedAt']?.toString(),
      repairCompletedAt: json['repairCompletedAt']?.toString(),
      repairNotes: json['repairNotes']?.toString(),
      defectHours: _toNum(json['defectHours']),
    );
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static num? _toNum(dynamic value) {
    if (value == null) return null;
    if (value is num) return value;
    return num.tryParse(value.toString());
  }
}

class WorkOrderModel {
  const WorkOrderModel({
    required this.id,
    required this.workOrderNumber,
    required this.unitNumber,
    required this.issueDescription,
    required this.status,
    this.workOrderType,
    this.companyName,
    this.companyId,
    this.createdOn,
    this.isPreventativeMaintenance = false,
    this.approvalStatus,
    this.entityTypeId,
    this.entityTypeName,
    this.workOrderDetails,
    this.workOrderParts = const [],
    this.notes = const [],
    this.updatedAt,
    this.totalLabourHours,
    this.totalLabourCost,
    this.resolutionNotes,
    this.pmInspectionResults = const [],
    this.pmTireMeasurements = const [],
    this.pmDefects = const [],
    this.attachments = const [],
  });

  final int id;
  final String workOrderNumber;
  final String unitNumber;
  final String issueDescription;
  final WorkOrderStatus status;
  final String? workOrderType;
  final String? companyName;
  final int? companyId;
  final String? createdOn;
  final bool isPreventativeMaintenance;
  final String? approvalStatus;
  final int? entityTypeId;
  final String? entityTypeName;
  final WorkOrderDetails? workOrderDetails;
  final List<WorkOrderPartLine> workOrderParts;
  final List<WorkOrderNote> notes;
  final DateTime? updatedAt;
  final num? totalLabourHours;
  final num? totalLabourCost;
  final String? resolutionNotes;
  final List<PmInspectionResultModel> pmInspectionResults;
  final List<PmTireMeasurementModel> pmTireMeasurements;
  final List<PmDefectModel> pmDefects;
  final List<WorkOrderAttachment> attachments;

  /// Backward-compatible aliases used by dashboard.
  String get unitName => unitNumber;
  String get description => issueDescription;
  String get statusLabel => status.label;

  WorkOrderPriority? get priority => workOrderDetails?.priorityEnum;

  factory WorkOrderModel.fromSummaryJson(Map<String, dynamic> json) {
    final detailsRaw = json['workOrderDetails'] ?? json['work_order_details'];
    final entityType = json['entity_type'];
    return WorkOrderModel(
      id: json['id'] as int? ?? 0,
      workOrderNumber: json['workOrderNumber'] as String? ??
          json['work_order_number'] as String? ??
          '',
      unitNumber:
          json['unitNumber'] as String? ?? json['unit_number'] as String? ?? '',
      issueDescription: json['issueDescription'] as String? ??
          json['issue_description'] as String? ??
          '',
      status: WorkOrderStatus.fromCode(json['status'] as int?),
      workOrderType: json['workOrderType'] as String?,
      companyName: json['companyName'] as String? ??
          (json['company'] is Map
              ? (json['company'] as Map)['companyName'] as String?
              : null),
      companyId: json['companyId'] as int? ??
          (json['company'] is Map ? (json['company'] as Map)['id'] as int? : null),
      createdOn:
          json['createdOn'] as String? ?? json['created_on'] as String?,
      isPreventativeMaintenance:
          json['isPreventativeMaintenance'] as bool? ?? false,
      approvalStatus: json['approval_status']?.toString(),
      entityTypeId: json['entity_type_id'] as int?,
      entityTypeName: entityType is Map ? entityType['name'] as String? : null,
      workOrderDetails: detailsRaw is Map<String, dynamic>
          ? WorkOrderDetails.fromJson(detailsRaw)
          : null,
      workOrderParts: const [],
      updatedAt: DateTime.tryParse(
        json['createdOn'] as String? ??
            json['modifiedOn'] as String? ??
            '',
      ),
    );
  }

  factory WorkOrderModel.fromDetailJson(Map<String, dynamic> json) {
    final workOrder = json['workOrder'] as Map<String, dynamic>? ?? json;
    final details = json['details'] ??
        json['workOrderDetails'] ??
        workOrder['workOrderDetails'];
    final partsRaw = json['parts'] ??
        json['workOrderParts'] ??
        workOrder['workOrderParts'] ??
        [];
    final notesRaw = json['workOrderNotes'] ?? workOrder['workOrderNotes'];
    final pmResultsRaw =
        json['pmInspectionResults'] ?? workOrder['pmInspectionResults'];
    final pmTiresRaw =
        json['pmTireMeasurements'] ?? workOrder['pmTireMeasurements'];
    final pmDefectsRaw = json['pmDefects'] ?? workOrder['pmDefects'];
    final attachmentsRaw = details is Map ? details['attachments'] : null;

    return WorkOrderModel(
      id: _asInt(workOrder['id']) ?? _asInt(json['id']) ?? 0,
      workOrderNumber: workOrder['workOrderNumber']?.toString() ?? '',
      unitNumber: workOrder['unitNumber']?.toString() ?? '',
      issueDescription: workOrder['issueDescription']?.toString() ?? '',
      status: WorkOrderStatus.fromCode(_asInt(workOrder['status'])),
      workOrderType: workOrder['workOrderType']?.toString(),
      companyName: workOrder['companyName']?.toString(),
      companyId: _asInt(workOrder['companyId']),
      createdOn: workOrder['createdOn']?.toString(),
      isPreventativeMaintenance:
          workOrder['isPreventativeMaintenance'] as bool? ?? false,
      approvalStatus: workOrder['approval_status']?.toString(),
      entityTypeId: _asInt(workOrder['entity_type_id']),
      entityTypeName: workOrder['entity_type'] is Map
          ? (workOrder['entity_type'] as Map)['name']?.toString()
          : null,
      workOrderDetails: details is Map<String, dynamic>
          ? WorkOrderDetails.fromJson(details)
          : null,
      workOrderParts: _tryParseList(
        partsRaw,
        (e) => WorkOrderPartLine.fromJson(e),
      ),
      notes: _tryParseList(notesRaw, (e) => WorkOrderNote.fromJson(e)),
      totalLabourHours: _asNum(workOrder['totalLabourHours']),
      totalLabourCost: _asNum(workOrder['totalLabourCost']),
      resolutionNotes: workOrder['resolutionNotes']?.toString(),
      pmInspectionResults: _tryParseList(
        pmResultsRaw,
        (e) => PmInspectionResultModel.fromJson(e),
      ),
      pmTireMeasurements: _tryParseList(
        pmTiresRaw,
        (e) => PmTireMeasurementModel.fromJson(e),
      ),
      pmDefects: _tryParseList(pmDefectsRaw, (e) => PmDefectModel.fromJson(e)),
      attachments: WorkOrderAttachment.listFromDynamic(attachmentsRaw),
    );
  }

  /// Legacy dashboard JSON shape.
  factory WorkOrderModel.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('workOrderNumber') || json.containsKey('unitNumber')) {
      return WorkOrderModel.fromSummaryJson(json);
    }
    return WorkOrderModel(
      id: json['id'] as int? ?? 0,
      workOrderNumber: json['work_order_number'] as String? ?? '#${json['id']}',
      unitNumber:
          json['unit_name'] as String? ?? json['unitName'] as String? ?? '',
      issueDescription:
          json['description'] as String? ?? json['issueDescription'] as String? ?? '',
      status: _legacyStatus(json['status']),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  static WorkOrderStatus _legacyStatus(dynamic value) {
    if (value is int) return WorkOrderStatus.fromCode(value);
    switch ((value as String?)?.toLowerCase()) {
      case 'open':
      case 'not_started':
        return WorkOrderStatus.notStarted;
      case 'in_progress':
        return WorkOrderStatus.inProgress;
      case 'pending':
      case 'on_hold':
        return WorkOrderStatus.onHold;
      default:
        return WorkOrderStatus.completed;
    }
  }
}

class WorkOrderNote {
  const WorkOrderNote({
    required this.id,
    required this.description,
    required this.timestamp,
  });

  final int id;
  final String description;
  final String timestamp;

  factory WorkOrderNote.fromJson(Map<String, dynamic> json) {
    return WorkOrderNote(
      id: json['id'] as int? ?? 0,
      description: json['description'] as String? ?? '',
      timestamp: json['timestamp'] as String? ?? '',
    );
  }
}

class TechnicianSummary {
  const TechnicianSummary({
    required this.userId,
    required this.id,
    required this.name,
  });

  final int userId;
  final int id;
  final String name;

  factory TechnicianSummary.fromJson(Map<String, dynamic> json) {
    return TechnicianSummary(
      userId: json['userId'] as int? ?? json['user_id'] as int? ?? 0,
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
    );
  }
}

class EntityTypeModel {
  const EntityTypeModel({required this.id, required this.name});

  final int id;
  final String name;

  factory EntityTypeModel.fromJson(Map<String, dynamic> json) {
    return EntityTypeModel(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
    );
  }
}

class EntityModel {
  const EntityModel({
    required this.id,
    required this.name,
    this.vinNumber,
    this.odometer,
  });

  final int id;
  final String name;
  final String? vinNumber;
  final String? odometer;

  factory EntityModel.fromJson(Map<String, dynamic> json) {
    return EntityModel(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      vinNumber: json['vinNumber'] as String? ?? json['vin_number'] as String?,
      odometer: json['odometer']?.toString() ??
          json['current_odometer']?.toString(),
    );
  }
}

class PartTypeSummary {
  const PartTypeSummary({required this.id, required this.name});

  final int id;
  final String name;

  factory PartTypeSummary.fromJson(Map<String, dynamic> json) {
    return PartTypeSummary(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
    );
  }
}

class PartSummary {
  const PartSummary({
    required this.id,
    required this.code,
    required this.typeId,
    this.quantity,
  });

  final int id;
  final String code;
  final int typeId;
  final num? quantity;

  factory PartSummary.fromJson(Map<String, dynamic> json) {
    return PartSummary(
      id: json['id'] as int? ?? 0,
      code: json['code'] as String? ?? '',
      typeId: json['typeId'] as int? ?? json['type_id'] as int? ?? 0,
      quantity: json['quantity'] as num?,
    );
  }
}

class WorkOrderFormPayload {
  const WorkOrderFormPayload({
    required this.unitNumber,
    required this.issueDescription,
    required this.status,
    required this.isPreventativeMaintenance,
    required this.entityTypeId,
    required this.priority,
    required this.assignee,
    required this.estimatedCost,
    required this.startDate,
    required this.dueDate,
    this.vin,
    this.location,
    this.startOdometer,
    this.endOdometer,
    this.endDate,
    this.hours,
    this.notes,
    this.companyId,
    this.approvalStatus = 1,
    this.parts = const [],
    this.totalLabourHours,
    this.totalLabourCost,
    this.resolutionNotes,
    this.pmInspectionResults = const [],
    this.pmTireMeasurements = const [],
    this.pmDefects = const [],
  });

  final String unitNumber;
  final String issueDescription;
  final int status;
  final bool isPreventativeMaintenance;
  final int entityTypeId;
  final int priority;
  final int assignee;
  final double estimatedCost;
  final DateTime? startDate;
  final DateTime? dueDate;
  final String? vin;
  final String? location;
  final String? startOdometer;
  final String? endOdometer;
  final DateTime? endDate;
  final String? hours;
  final String? notes;
  final int? companyId;
  final int approvalStatus;
  final List<WorkOrderPartPayload> parts;
  final num? totalLabourHours;
  final num? totalLabourCost;
  final String? resolutionNotes;
  final List<PmInspectionResultModel> pmInspectionResults;
  final List<PmTireMeasurementModel> pmTireMeasurements;
  final List<PmDefectModel> pmDefects;

  Map<String, dynamic> toJson() => {
        'workOrderNumber': '',
        'unitNumber': unitNumber,
        'issueDescription': issueDescription,
        'status': status,
        'approval_status': approvalStatus,
        'isPreventativeMaintenance': isPreventativeMaintenance,
        'entity_type_id': entityTypeId,
        if (vin != null && vin!.isNotEmpty) 'vin': vin,
        if (notes != null) 'notes': notes,
        if (companyId != null) 'companyId': companyId,
        if (totalLabourHours != null) 'totalLabourHours': totalLabourHours,
        if (totalLabourCost != null) 'totalLabourCost': totalLabourCost,
        if (resolutionNotes != null) 'resolutionNotes': resolutionNotes,
        'details': {
          'priority': priority,
          'odometer': startOdometer ?? '',
          if (startOdometer != null) 'startOdometer': startOdometer,
          if (endOdometer != null) 'endOdometer': endOdometer,
          'location': location ?? '',
          'assignee': assignee,
          'estimatedCost': estimatedCost,
          'dueDate': dueDate?.toUtc().toIso8601String(),
          'startDate': startDate?.toUtc().toIso8601String(),
          if (endDate != null) 'endDate': endDate!.toUtc().toIso8601String(),
          'hours': hours ?? '',
          'notes': notes ?? '',
          'attachments': '',
        },
        'parts': parts.map((p) => p.toJson()).toList(),
        if (pmInspectionResults.isNotEmpty)
          'pmInspectionResults':
              pmInspectionResults.map((r) => r.toJson()).toList(),
        if (pmTireMeasurements.isNotEmpty)
          'pmTireMeasurements':
              pmTireMeasurements.map((t) => t.toJson()).toList(),
        if (pmDefects.isNotEmpty)
          'pmDefects': pmDefects.map((d) => d.toJson()).toList(),
      };
}

class WorkOrderPartPayload {
  const WorkOrderPartPayload({
    required this.usedPart,
    required this.usageDescription,
    this.quantity,
    this.partTypeId,
    this.partTypeName,
    this.id,
    this.repairPerformedBy,
    this.repairStatus,
    this.assignedTechnicianId,
    this.vendorName,
    this.vendorContact,
    this.vendorInvoiceNumber,
    this.repairNotes,
    this.defectHours,
    this.repairStartedAt,
    this.repairCompletedAt,
  });

  final int? id;
  final int? usedPart;
  final String usageDescription;
  final num? quantity;
  final int? partTypeId;
  final String? partTypeName;
  final RepairPerformedBy? repairPerformedBy;
  final RepairStatus? repairStatus;
  final int? assignedTechnicianId;
  final String? vendorName;
  final String? vendorContact;
  final String? vendorInvoiceNumber;
  final String? repairNotes;
  final num? defectHours;
  final DateTime? repairStartedAt;
  final DateTime? repairCompletedAt;

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'usedPart': usedPart,
        'usageDescription': usageDescription,
        if (quantity != null) 'quantity': quantity,
        if (partTypeId != null) 'partTypeId': partTypeId,
        if (partTypeName != null) 'partTypeName': partTypeName,
        if (repairPerformedBy != null)
          'repairPerformedBy': repairPerformedBy!.code,
        if (repairStatus != null) 'repairStatus': repairStatus!.code,
        if (assignedTechnicianId != null)
          'assignedTechnicianId': assignedTechnicianId,
        if (vendorName != null) 'vendorName': vendorName,
        if (vendorContact != null) 'vendorContact': vendorContact,
        if (vendorInvoiceNumber != null)
          'vendorInvoiceNumber': vendorInvoiceNumber,
        if (repairNotes != null) 'repairNotes': repairNotes,
        if (defectHours != null) 'defectHours': defectHours,
        if (repairStartedAt != null)
          'repairStartedAt': repairStartedAt!.toUtc().toIso8601String(),
        if (repairCompletedAt != null)
          'repairCompletedAt': repairCompletedAt!.toUtc().toIso8601String(),
      };
}
