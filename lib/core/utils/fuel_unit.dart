/// Liters/gallons display-unit conversion for the Power Unit / Trailer fuel
/// capacity field. Values are always stored/submitted in liters; only the
/// on-screen display and user input are converted, mirroring the web app's
/// `AddTruckPage.tsx` `handleUnitChange`/submit-payload conversion.
library;

const double _litersPerGallon = 3.78541;

enum FuelCapacityUnit {
  liters('lit', 'Liters'),
  gallons('gallons', 'Gallons');

  const FuelCapacityUnit(this.apiValue, this.label);

  final String apiValue;
  final String label;
}

/// Convert a stored liters string to the digits shown for [unit].
String litersStringToDisplayValue(String liters, FuelCapacityUnit unit) {
  final trimmed = liters.trim();
  if (trimmed.isEmpty) return '';
  final n = double.tryParse(trimmed);
  if (n == null || n < 0) return trimmed;
  if (unit == FuelCapacityUnit.liters) {
    return n == n.roundToDouble() ? n.round().toString() : n.toString();
  }
  final gallons = n / _litersPerGallon;
  return double.parse(gallons.toStringAsFixed(2)).toString();
}

/// Convert user input (in [unit]) back to a liters string for storage/API.
String displayValueToLitersString(String value, FuelCapacityUnit unit) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';
  final n = double.tryParse(trimmed);
  if (n == null || n < 0) return trimmed;
  if (unit == FuelCapacityUnit.liters) return trimmed;
  final liters = n * _litersPerGallon;
  return double.parse(liters.toStringAsFixed(4)).toString();
}
