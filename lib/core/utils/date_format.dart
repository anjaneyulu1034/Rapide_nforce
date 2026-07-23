/// Formats a date value as `MM-DD-YYYY`, matching the web app's
/// `formatDateMMDDYYYY` (`src/utils/index.ts`). A `YYYY-MM-DD`-prefixed
/// string is read as a literal calendar date — no `DateTime.parse` +
/// timezone conversion — so a UTC-midnight timestamp never shifts a day
/// backward for users behind UTC. Anything else falls back to
/// `DateTime.tryParse`.
String? formatDateMMDDYYYY(String? value, {String? fallback}) {
  if (value == null || value.trim().isEmpty) return fallback;
  final trimmed = value.trim();

  final ymd = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(trimmed);
  if (ymd != null) {
    return '${ymd.group(2)}-${ymd.group(3)}-${ymd.group(1)}';
  }

  final parsed = DateTime.tryParse(trimmed);
  if (parsed == null) return fallback ?? trimmed;
  final mm = parsed.month.toString().padLeft(2, '0');
  final dd = parsed.day.toString().padLeft(2, '0');
  return '$mm-$dd-${parsed.year}';
}

/// Formats a moment-in-time (e.g. a telematics sync timestamp) as
/// `MM-DD-YYYY HH:mm`, matching web's `formatLastSyncDisplay`. Unlike
/// [formatDateMMDDYYYY], this intentionally converts to the device's local
/// time — a sync event is a real instant, not a calendar date that must
/// stay fixed regardless of viewer timezone.
String? formatDateTimeMMDDYYYY(String? value, {String? fallback}) {
  if (value == null || value.trim().isEmpty) return fallback;
  final parsed = DateTime.tryParse(value.trim())?.toLocal();
  if (parsed == null) return fallback ?? value.trim();
  final mm = parsed.month.toString().padLeft(2, '0');
  final dd = parsed.day.toString().padLeft(2, '0');
  final hh = parsed.hour.toString().padLeft(2, '0');
  final min = parsed.minute.toString().padLeft(2, '0');
  return '$mm-$dd-${parsed.year} $hh:$min';
}
