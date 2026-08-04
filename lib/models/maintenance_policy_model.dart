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
    this.days,
    this.months,
    this.km,
    this.nextDueDate,
    this.nextDueOdometer,
  });

  final String type;
  final String name;
  final int? days;
  final int? months;
  final int? km;
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
      days: _asInt(cfg['days']),
      months: _asInt(cfg['months']),
      km: _asInt(cfg['kilometers'] ?? cfg['km']),
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
  });

  final int id;
  final String name;
  final bool isActive;
  final List<PolicySchedulePanel> panels;

  factory PolicySchedule.fromJson(Map<String, dynamic> json) {
    final panelsRaw =
        json['panels'] as List? ?? json['schedulePanels'] as List? ?? [];
    return PolicySchedule(
      id: _asInt(json['id']) ?? 0,
      name: (json['name'] as String? ?? 'Schedule').trim(),
      isActive: json['isActive'] != false && json['active'] != false,
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
  });

  final int id;
  final String name;
  final int? pmIntervalDays;
  final int? pmIntervalKm;
  final String? inspectionFrequency;
  final List<PolicySchedule> schedules;

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

    return MaintenancePolicyModel(
      id: json['id'] as int? ?? 0,
      name: (json['name'] as String? ?? '').trim(),
      pmIntervalDays: pmPanel?.days ?? _asInt(config['pmIntervalDays']),
      pmIntervalKm: pmPanel?.km ?? _asInt(config['pmIntervalKm']),
      inspectionFrequency: (config['inspectionFrequency'] as String?)?.trim(),
      schedules: schedules,
    );
  }
}
