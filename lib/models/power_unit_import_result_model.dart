/// Result of importing a single row from the power unit bulk-upload
/// spreadsheet. Mirrors the backend's `BulkImportRowResult`
/// (`POST /trucks/bulk-import`).
class PowerUnitImportRowResult {
  const PowerUnitImportRowResult({
    required this.rowNumber,
    this.unitNumber,
    this.vin,
    required this.success,
    required this.message,
    this.truckId,
  });

  final int rowNumber;
  final String? unitNumber;
  final String? vin;
  final bool success;
  final String message;
  final int? truckId;

  factory PowerUnitImportRowResult.fromJson(Map<String, dynamic> json) {
    int? toInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      return int.tryParse(v.toString());
    }

    return PowerUnitImportRowResult(
      rowNumber: toInt(json['rowNumber']) ?? 0,
      unitNumber: json['unitNumber'] as String?,
      vin: json['vin'] as String?,
      success: json['success'] == true,
      message: json['message']?.toString() ?? '',
      truckId: toInt(json['truckId']),
    );
  }
}

/// Summary returned by `POST /trucks/bulk-import` — distinct shape from the
/// generic `/imports/excel` result used for trailers (uses `created`/`total`/
/// `failed` + a per-row `results` list rather than `errors`).
class PowerUnitImportResult {
  const PowerUnitImportResult({
    required this.total,
    required this.created,
    required this.failed,
    required this.results,
  });

  final int total;
  final int created;
  final int failed;
  final List<PowerUnitImportRowResult> results;

  factory PowerUnitImportResult.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic v) {
      if (v is int) return v;
      return int.tryParse(v?.toString() ?? '') ?? 0;
    }

    final rawResults = json['results'];
    return PowerUnitImportResult(
      total: toInt(json['total']),
      created: toInt(json['created']),
      failed: toInt(json['failed']),
      results: rawResults is List
          ? rawResults
              .whereType<Map>()
              .map(
                (e) => PowerUnitImportRowResult.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .toList()
          : const [],
    );
  }
}
