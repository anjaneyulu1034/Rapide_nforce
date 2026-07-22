/// A single deferred-repair line item pending Lead Approval —
/// `GET /maintenance/repairs/deferred`. Mirrors web's `LeadApprovalsPage`
/// row shape: a `WorkOrderPart` with its parent `workOrder`/`part` joined
/// in, plus a server-computed `approvalState` parsed from `reasonNotes`.
class DeferredRepairModel {
  const DeferredRepairModel({
    required this.id,
    this.workOrderNumber,
    this.unitNumber,
    this.odometer,
    this.issueDescription,
    this.invoiceNumber,
    this.usageDescription,
    required this.repairStatus,
    required this.approvalStatus,
  });

  final int id;
  final String? workOrderNumber;
  final String? unitNumber;
  final String? odometer;
  final String? issueDescription;
  final String? invoiceNumber;
  final String? usageDescription;
  final String repairStatus;
  final String approvalStatus;

  String get workOrderLabel =>
      workOrderNumber != null && workOrderNumber!.isNotEmpty
          ? 'WO-$workOrderNumber'
          : 'None';

  bool get isPending =>
      approvalStatus != 'APPROVED' && approvalStatus != 'REJECTED';

  factory DeferredRepairModel.fromJson(Map<String, dynamic> json) {
    final workOrder = json['workOrder'] is Map
        ? Map<String, dynamic>.from(json['workOrder'] as Map)
        : const <String, dynamic>{};
    final part = json['part'] is Map
        ? Map<String, dynamic>.from(json['part'] as Map)
        : const <String, dynamic>{};
    final approvalState = json['approvalState'] is Map
        ? Map<String, dynamic>.from(json['approvalState'] as Map)
        : const <String, dynamic>{};
    final details = workOrder['workOrderDetails'] is Map
        ? Map<String, dynamic>.from(workOrder['workOrderDetails'] as Map)
        : const <String, dynamic>{};

    return DeferredRepairModel(
      id: json['id'] as int? ?? 0,
      workOrderNumber: json['workOrderNumber']?.toString(),
      unitNumber: workOrder['unitNumber'] as String?,
      odometer: details['odometer']?.toString(),
      issueDescription: workOrder['issueDescription'] as String?,
      invoiceNumber: part['invoice_number'] as String?,
      usageDescription: json['usageDescription'] as String?,
      repairStatus: json['repairStatus'] as String? ?? 'DEFERRED',
      approvalStatus:
          approvalState['approvalStatus'] as String? ?? 'PENDING',
    );
  }
}
