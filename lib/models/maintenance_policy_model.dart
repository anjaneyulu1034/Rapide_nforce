int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

/// A maintenance policy's PM/inspection scheduling rules — mirrors web's
/// `MaintenancePolicyConfiguration` (see `maintenancePolicies.ts`). Used to
/// auto-fill Next PM Due / PM Interval / Annual Inspection Due once a policy
/// is selected on the power unit form, the same way the web app does.
class MaintenancePolicyModel {
  const MaintenancePolicyModel({
    required this.id,
    required this.name,
    this.pmIntervalDays,
    this.pmIntervalKm,
    this.inspectionFrequency,
  });

  final int id;
  final String name;
  final int? pmIntervalDays;
  final int? pmIntervalKm;
  final String? inspectionFrequency;

  factory MaintenancePolicyModel.fromJson(Map<String, dynamic> json) {
    final rawConfig = json['configuration'];
    final config = rawConfig is Map
        ? Map<String, dynamic>.from(rawConfig)
        : const <String, dynamic>{};
    return MaintenancePolicyModel(
      id: json['id'] as int? ?? 0,
      name: (json['name'] as String? ?? '').trim(),
      pmIntervalDays: _asInt(config['pmIntervalDays']),
      pmIntervalKm: _asInt(config['pmIntervalKm']),
      inspectionFrequency: (config['inspectionFrequency'] as String?)?.trim(),
    );
  }
}
