int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

class PolicySchedulePanel {
  const PolicySchedulePanel({
    required this.type,
    required this.name,
    this.scheduleTypeId,
    this.scheduleTypeCode,
    this.scheduleTypeName,
    this.days,
    this.months,
    this.km,
    this.engineHours,
    this.nextDueDate,
    this.nextDueOdometer,
  });

  final String type;
  final String name;

  /// Fields identifying the schedule *type* this panel represents (e.g. "PM
  /// Inspection", "Oil Change") — used to match against a vehicle's
  /// `maintenanceRecords[]` when deciding whether a panel is pending or
  /// already up to date (see `_buildPendingPolicyEvents` in
  /// `work_order_form_screen.dart`).
  final int? scheduleTypeId;
  final String? scheduleTypeCode;
  final String? scheduleTypeName;

  final int? days;
  final int? months;
  final int? km;
  final int? engineHours;
  final String? nextDueDate;
  final int? nextDueOdometer;

  factory PolicySchedulePanel.fromJson(Map<String, dynamic> json) {
    final cfg = json['config'] is Map
        ? Map<String, dynamic>.from(json['config'])
        : const <String, dynamic>{};
    final type = (json['type'] as String? ?? '').trim();
    final rawName = (json['name'] as String? ?? '').trim();
    final name = rawName.isNotEmpty
        ? rawName
        : (type == 'PM'
            ? 'PM Schedule'
            : type == 'OIL'
                ? 'Oil Change'
                : type);

    return PolicySchedulePanel(
      type: type,
      name: name,
      scheduleTypeId: _asInt(json['scheduleTypeId']),
      scheduleTypeCode: json['scheduleTypeCode'] as String?,
      scheduleTypeName: json['scheduleTypeName'] as String?,
      days: _asInt(cfg['days']),
      months: _asInt(cfg['months']),
      km: _asInt(cfg['kilometers'] ?? cfg['km']),
      engineHours: _asInt(cfg['engineHours']),
      nextDueDate:
          json['nextDueDate'] as String? ?? json['next_due_date'] as String?,
      nextDueOdometer:
          _asInt(json['nextDueOdometer'] ?? json['next_due_odometer']),
    );
  }
}

class PolicySchedule {
  const PolicySchedule({
    required this.id,
    required this.name,
    required this.isActive,
    required this.panels,
    this.scheduleNumber,
  });

  final int id;
  final String name;
  final bool isActive;
  final List<PolicySchedulePanel> panels;

  /// Display index computed by the backend (`totalCount - index`, highest
  /// first) — used as a fallback reference label when a schedule has no
  /// meaningful `name`.
  final int? scheduleNumber;

  factory PolicySchedule.fromJson(Map<String, dynamic> json) {
    final panelsRaw =
        json['panels'] as List? ?? json['schedulePanels'] as List? ?? [];
    return PolicySchedule(
      id: _asInt(json['id']) ?? 0,
      name: (json['name'] as String? ?? 'Schedule').trim(),
      isActive: json['isActive'] != false && json['active'] != false,
      scheduleNumber: _asInt(json['scheduleNumber']),
      panels: panelsRaw
          .whereType<Map>()
          .map((p) => PolicySchedulePanel.fromJson(Map<String, dynamic>.from(p)))
          .toList(),
    );
  }
}

/// A maintenance policy's PM/inspection scheduling rules — mirrors web's
/// `MaintenancePolicy` (see `maintenancePolicies.ts`). Used to auto-fill
/// Next PM Due / PM Interval / Annual Inspection Due once a policy is selected
/// on power units and trailers.
class MaintenancePolicyModel {
  const MaintenancePolicyModel({
    required this.id,
    required this.name,
    this.pmIntervalDays,
    this.pmIntervalKm,
    this.inspectionFrequency,
    this.schedules = const [],
    this.usedInTrucks = const [],
    this.usedInTrailers = const [],
  });

  final int id;
  final String name;
  final int? pmIntervalDays;
  final int? pmIntervalKm;
  final String? inspectionFrequency;
  final List<PolicySchedule> schedules;

  /// Unit-number strings this policy is assigned to — the fallback match
  /// used when a vehicle's own `maintenancePolicy` name doesn't resolve to
  /// any loaded policy (see `_buildPendingPolicyEvents`).
  final List<String> usedInTrucks;
  final List<String> usedInTrailers;

  /// Helper getter to find PM panel across schedules
  PolicySchedulePanel? get pmPanel {
    for (final schedule in schedules) {
      for (final panel in schedule.panels) {
        if (panel.type.toUpperCase() == 'PM') return panel;
      }
    }
    return null;
  }

  /// All panels across active schedules
  List<PolicySchedulePanel> get allPanels {
    final list = <PolicySchedulePanel>[];
    for (final schedule in schedules) {
      if (schedule.isActive) {
        list.addAll(schedule.panels);
      }
    }
    return list;
  }

  factory MaintenancePolicyModel.fromJson(Map<String, dynamic> json) {
    final rawSchedules =
        json['schedules'] as List? ?? json['policySchedules'] as List? ?? [];
    final schedules = rawSchedules
        .whereType<Map>()
        .map((s) => PolicySchedule.fromJson(Map<String, dynamic>.from(s)))
        .toList();

    PolicySchedulePanel? pmPanel;
    for (final schedule in schedules) {
      for (final panel in schedule.panels) {
        if (panel.type.toUpperCase() == 'PM') {
          pmPanel = panel;
          break;
        }
      }
    }

    final rawConfig = json['configuration'];
    final config = rawConfig is Map
        ? Map<String, dynamic>.from(rawConfig)
        : const <String, dynamic>{};

    final usedIn = json['usedInVehicles'] is Map
        ? Map<String, dynamic>.from(json['usedInVehicles'])
        : const <String, dynamic>{};

    return MaintenancePolicyModel(
      id: json['id'] as int? ?? 0,
      name: (json['name'] as String? ?? '').trim(),
      pmIntervalDays: pmPanel?.days ?? _asInt(config['pmIntervalDays']),
      pmIntervalKm: pmPanel?.km ?? _asInt(config['pmIntervalKm']),
      inspectionFrequency: (config['inspectionFrequency'] as String?)?.trim(),
      schedules: schedules,
      usedInTrucks:
          (usedIn['trucks'] as List?)?.whereType<String>().toList() ?? const [],
      usedInTrailers:
          (usedIn['trailers'] as List?)?.whereType<String>().toList() ?? const [],
    );
  }
}
