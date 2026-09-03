/// One event from `GET /maintenance/entity-audit-trail` — a Dart port of
/// web's `AuditTrailEntry` (`components/common/AuditTrail.tsx`). Shared
/// across every entity type the endpoint supports (`work_order`,
/// `dvir_defect`, `fault_code`); only the fields the UI actually renders are
/// kept (`previousValue`/`newValue`/`metadata` are ignored, matching how the
/// web component never reads them either — `details` already carries the
/// human-readable summary).
class AuditTrailEntry {
  const AuditTrailEntry({
    required this.id,
    required this.eventType,
    required this.createdAt,
    required this.details,
    this.actorUsername,
    this.actorRole,
  });

  final String id;
  final String eventType;
  final String createdAt;
  final String details;
  final String? actorUsername;
  final String? actorRole;

  /// Web treats a missing/blank username as a system-generated entry
  /// (`!entry.actorUsername`) — mirrored here for the same icon/label switch.
  bool get isSystem => (actorUsername ?? '').trim().isEmpty;

  factory AuditTrailEntry.fromJson(Map<String, dynamic> json) {
    return AuditTrailEntry(
      id: json['id']?.toString() ?? '',
      eventType: json['eventType']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
      details: json['details']?.toString() ?? '',
      actorUsername: json['actorUsername']?.toString(),
      actorRole: json['actorRole']?.toString(),
    );
  }
}
