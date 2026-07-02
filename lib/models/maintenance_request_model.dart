import 'package:intl/intl.dart';

/// Maintenance request row — `/maintenance/my-requests` & `/maintenance/approvals`.
class MaintenanceRequestModel {
  const MaintenanceRequestModel({
    required this.id,
    required this.workOrderNumber,
    required this.unitNumber,
    required this.issueDescription,
    required this.status,
    this.approvalStatus,
    this.technicianName,
    this.companyName,
    this.createdOn,
    this.priority,
    this.estimatedCost,
    this.isPreventativeMaintenance = false,
  });

  final int id;
  final String workOrderNumber;
  final String unitNumber;
  final String issueDescription;
  final int status;
  final String? approvalStatus;
  final String? technicianName;
  final String? companyName;
  final String? createdOn;
  final int? priority;
  final double? estimatedCost;
  final bool isPreventativeMaintenance;

  String get title =>
      workOrderNumber.isNotEmpty ? workOrderNumber : 'WO #$id';

  String get subtitle => '$unitNumber · $issueDescription';

  /// Backward-compatible field for list screens.
  String get partName => issueDescription;

  String get requestedOn {
    if (createdOn == null || createdOn!.isEmpty) return '—';
    final parsed = DateTime.tryParse(createdOn!);
    if (parsed == null) return createdOn!;
    return DateFormat('MMM d, yyyy').format(parsed.toLocal());
  }

  RequestApprovalStatus get approvalStatusEnum =>
      RequestApprovalStatusX.fromValue(approvalStatus);

  factory MaintenanceRequestModel.fromJson(Map<String, dynamic> json) {
    final details = json['workOrderDetails'];
    final detailsMap = details is Map ? Map<String, dynamic>.from(details) : null;
    final tech = detailsMap?['technician'];

    return MaintenanceRequestModel(
      id: json['id'] as int? ?? 0,
      workOrderNumber: json['workOrderNumber'] as String? ?? '',
      unitNumber: json['unitNumber'] as String? ?? '',
      issueDescription: json['issueDescription'] as String? ?? '',
      status: json['status'] as int? ?? 0,
      approvalStatus: json['approval_status']?.toString(),
      technicianName: json['technician_name'] as String? ??
          (tech is Map ? tech['name'] as String? : null),
      companyName: json['company_name'] as String?,
      createdOn: json['createdOn'] as String?,
      priority: detailsMap?['priority'] as int?,
      estimatedCost: _toDouble(detailsMap?['estimatedCost']),
      isPreventativeMaintenance:
          json['isPreventativeMaintenance'] as bool? ?? false,
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}

enum RequestApprovalStatus { pending, approved, rejected, unknown }

extension RequestApprovalStatusX on RequestApprovalStatus {
  String get label {
    switch (this) {
      case RequestApprovalStatus.pending:
        return 'Pending';
      case RequestApprovalStatus.approved:
        return 'Approved';
      case RequestApprovalStatus.rejected:
        return 'Rejected';
      case RequestApprovalStatus.unknown:
        return 'Unknown';
    }
  }

  static RequestApprovalStatus fromValue(dynamic value) {
    final s = (value ?? '').toString().toUpperCase();
    if (s == '2' || s == 'APPROVED') return RequestApprovalStatus.approved;
    if (s == '3' || s == 'REJECTED') return RequestApprovalStatus.rejected;
    if (s == '1' ||
        s == 'PENDING' ||
        s == 'ON_HOLD' ||
        s == '4' ||
        s.isEmpty) {
      return RequestApprovalStatus.pending;
    }
    return RequestApprovalStatus.unknown;
  }
}

// Legacy alias used by request_model.dart consumers.
typedef RequestModel = MaintenanceRequestModel;
typedef RequestStatus = RequestApprovalStatus;

extension RequestStatusCompat on RequestApprovalStatus {
  String get statusLabel => label;
}
