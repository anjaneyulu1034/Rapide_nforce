/// km/miles display-unit conversion for work order odometer fields.
/// Values are always stored/submitted in km; only the on-screen display
/// and user input are converted, mirroring the web app's `odometer.ts`.
library;

const double _kmPerMile = 1.609344;
const double _milesPerKm = 0.621371;

enum OdometerDisplayUnit {
  km('km', 'km'),
  miles('miles', 'Miles');

  const OdometerDisplayUnit(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static OdometerDisplayUnit fromApiValue(String? raw) {
    final normalized = raw?.trim().toLowerCase();
    return normalized == 'miles' || normalized == 'mi'
        ? OdometerDisplayUnit.miles
        : OdometerDisplayUnit.km;
  }
}

/// Convert a stored km string to the digits shown for [unit].
String kmStringToDisplayValue(String km, OdometerDisplayUnit unit) {
  final trimmed = km.trim();
  if (trimmed.isEmpty) return '';
  final n = double.tryParse(trimmed);
  if (n == null || n < 0) return trimmed;
  if (unit == OdometerDisplayUnit.km) return n.round().toString();
  return (n * _milesPerKm).round().toString();
}

/// Convert user input (in [unit]) back to a km string for storage/API.
String displayValueToKmString(String value, OdometerDisplayUnit unit) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';
  final n = double.tryParse(trimmed);
  if (n == null || n < 0) return trimmed;
  if (unit == OdometerDisplayUnit.km) return n.round().toString();
  return (n * _kmPerMile).round().toString();
}
