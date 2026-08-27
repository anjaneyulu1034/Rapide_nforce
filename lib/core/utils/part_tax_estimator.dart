import 'package:rapide_nforce/models/part_models.dart';

/// Result of a client-side tax preview computation — mirrors web's
/// `EstimatedTaxResult` (`tax.constants.ts`).
class PartTaxEstimateResult {
  const PartTaxEstimateResult({
    required this.taxRate,
    required this.taxType,
    required this.taxAmount,
  });

  final double taxRate;
  final String taxType;
  final double taxAmount;
}

/// Dart port of web's `estimateTax()` (`src/constants/tax.constants.ts`) —
/// a pure, offline preview shown as the "Estimated Tax Summary" on Add
/// Part. The authoritative tax figures are computed server-side on submit
/// (`POST /maintenance/parts`) and may differ from this preview.
class PartTaxEstimator {
  PartTaxEstimator._();

  /// NOTE: when destination and origin countries are both set and differ,
  /// this returns zero tax ("EXPORT") even though the backend always taxes
  /// at the destination regardless of origin. That mismatch is intentional
  /// and matches web's implementation exactly — do not "fix" it here, or
  /// the mobile preview will disagree with the web app's preview for the
  /// same inputs.
  static PartTaxEstimateResult estimate({
    required double subtotal,
    required String destinationCountry,
    required String destinationState,
    required String originCountry,
    required bool taxExempt,
    required double additionalLocalRate,
    required List<PartTaxRateModel> taxRates,
  }) {
    if (taxExempt) {
      return const PartTaxEstimateResult(taxRate: 0, taxType: 'EXEMPT', taxAmount: 0);
    }
    if (subtotal <= 0) {
      return const PartTaxEstimateResult(taxRate: 0, taxType: 'NONE', taxAmount: 0);
    }
    if (destinationCountry.isNotEmpty &&
        originCountry.isNotEmpty &&
        destinationCountry != originCountry) {
      return const PartTaxEstimateResult(taxRate: 0, taxType: 'EXPORT', taxAmount: 0);
    }

    PartTaxRateModel? matched;
    for (final tr in taxRates) {
      if (tr.country == destinationCountry &&
          (tr.regionCode == destinationState || tr.aliases.contains(destinationState))) {
        matched = tr;
        break;
      }
    }

    double rate;
    String type;
    if (matched != null) {
      rate = matched.totalRate;
      type = matched.taxType;
      if (destinationCountry == 'US') rate += additionalLocalRate;
    } else if (destinationCountry == 'CA') {
      switch (destinationState) {
        case 'ON':
          rate = 0.13;
          type = 'HST';
          break;
        case 'QC':
          rate = 0.14975;
          type = 'GST + QST';
          break;
        case 'BC':
        case 'MB':
          rate = 0.12;
          type = 'GST + PST';
          break;
        case 'SK':
          rate = 0.11;
          type = 'GST + PST';
          break;
        case 'NS':
        case 'NB':
        case 'NL':
        case 'PE':
          rate = 0.15;
          type = 'HST';
          break;
        case 'AB':
        case 'NT':
        case 'NU':
        case 'YT':
          rate = 0.05;
          type = 'GST';
          break;
        default:
          rate = 0.05;
          type = 'GST';
      }
    } else if (destinationCountry == 'US') {
      final stateRate = _usStateRates[destinationState] ?? 0.06;
      rate = stateRate + additionalLocalRate;
      type = 'Sales Tax';
    } else {
      rate = 0;
      type = 'TAX';
    }

    return PartTaxEstimateResult(taxRate: rate, taxType: type, taxAmount: subtotal * rate);
  }

  static const Map<String, double> _usStateRates = {
    'AL': 0.04, 'AK': 0.0, 'AZ': 0.056, 'AR': 0.065, 'CA': 0.0725,
    'CO': 0.029, 'CT': 0.0635, 'DE': 0.0, 'FL': 0.06, 'GA': 0.04,
    'HI': 0.04, 'ID': 0.06, 'IL': 0.0625, 'IN': 0.07, 'IA': 0.06,
    'KS': 0.065, 'KY': 0.06, 'LA': 0.0445, 'ME': 0.055, 'MD': 0.06,
    'MA': 0.0625, 'MI': 0.06, 'MN': 0.06875, 'MS': 0.07, 'MO': 0.04225,
    'MT': 0.0, 'NE': 0.055, 'NV': 0.0685, 'NH': 0.0, 'NJ': 0.06625,
    'NM': 0.05125, 'NY': 0.04, 'NC': 0.0475, 'ND': 0.05, 'OH': 0.0575,
    'OK': 0.045, 'OR': 0.0, 'PA': 0.06, 'RI': 0.07, 'SC': 0.06,
    'SD': 0.045, 'TN': 0.07, 'TX': 0.0625, 'UT': 0.0485, 'VT': 0.06,
    'VA': 0.043, 'WA': 0.065, 'WV': 0.06, 'WI': 0.05, 'WY': 0.04,
  };
}
