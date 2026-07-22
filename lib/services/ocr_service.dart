import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:rapide_nforce/core/constants/api_constants.dart';
import 'package:rapide_nforce/core/models/api_result.dart';
import 'package:rapide_nforce/core/utils/api_parse.dart';
import 'package:rapide_nforce/services/api_client.dart';

/// Flat, camelCase OCR-extracted vehicle fields — a Dart port of the web
/// app's `TruckOcrPrefill`/`TrailerOcrPrefill` (`ocrPrefillMapper.ts`), used
/// to auto-fill the Add/Edit Power Unit and Add/Edit Trailer forms after a
/// Browse/Scan/Camera pick. The extracted key set (VIN, plate, registration,
/// ownership, CVIP/annual-safety) is shared by both vehicle types.
class TruckOcrPrefill {
  const TruckOcrPrefill(this.values, {this.documentType});

  final Map<String, String> values;
  final String? documentType;

  String? operator [](String key) => values[key];
  bool get isEmpty => values.isEmpty;
}

/// Uploads a picked document as an OCR "scan", polls the extraction job,
/// and maps the result onto Power Unit form fields — mirrors the web app's
/// upload-then-poll flow (`documentsService.uploadMultipleDocuments` with
/// `isOcrUpload: true`, then `ocrService.getOCRResults(batchId)`).
class OcrService {
  OcrService._();
  static final OcrService instance = OcrService._();

  final ApiClient _api = ApiClient.instance;

  /// Uploads [filePath] as a staging OCR document (not tied to any specific
  /// truck yet) and returns the batch id to poll. The backend's generic
  /// `POST /documents` auto-triggers OCR server-side when `isOcrUpload` is
  /// true, so no separate `/ocr/extract_info` call is needed.
  Future<ApiResult<String>> submitScan({
    required String filePath,
    required String fileName,
    String documentType = 'OCR Scan',
    String? companyId,
  }) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('dummy'))
        ..fields['documents'] = jsonEncode([
          {
            'documentType': documentType,
            'isOcrUpload': true,
            'isEntityNotApplicable': true,
          },
        ]);
      request.files.add(
        await http.MultipartFile.fromPath('files', filePath, filename: fileName),
      );

      final body = await _api.parseJson(
        () => _api.postMultipart(
          ApiConstants.documents,
          request,
          companyId: companyId,
        ),
        onSuccess: (b) => b,
      );
      final data = ApiParse.asMap(ApiParse.unwrapData(body)) ?? {};
      final batchId = data['batchId']?.toString();
      if (batchId == null || batchId.isEmpty) {
        return ApiResult.fail('Upload did not return a batch ID.');
      }
      return ApiResult.ok(batchId);
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to upload document for scanning.');
    }
  }

  /// Polls `GET /ocr/ocr-results/:batchId` once. Returns `ApiResult.ok(null)`
  /// while still processing, `ApiResult.ok(prefill)` once data is extracted,
  /// or `ApiResult.fail(...)` on a terminal failure.
  Future<ApiResult<TruckOcrPrefill?>> pollResult(String batchId) async {
    try {
      final body = await _api.parseJson(
        () => _api.get('${ApiConstants.ocrResults}/$batchId'),
        onSuccess: (b) => b,
      );
      final map = ApiParse.asMap(body) ?? {};
      final status = (map['status']?.toString() ?? '').toLowerCase();
      final results = (map['results'] as List?) ?? const [];

      if (status == 'failed' || status == 'error') {
        return ApiResult.fail('No data could be extracted from the document.');
      }
      if (results.isEmpty) {
        return ApiResult.ok(null); // still processing
      }

      for (final raw in results) {
        if (raw is! Map) continue;
        final row = Map<String, dynamic>.from(raw);
        final rowStatus = (row['status']?.toString() ?? 'success').toLowerCase();
        const terminalOk = {
          'success',
          'succeeded',
          'completed',
          'complete',
          'done',
        };
        if (!terminalOk.contains(rowStatus)) continue;

        final documentType = (row['documentType'] ?? row['document_type'])
            ?.toString();
        final entity = _resultRowEntity(row);
        if (entity == null) continue;

        final prefill = _buildTruckPrefill(entity, documentType ?? '');
        if (!prefill.isEmpty) return ApiResult.ok(prefill);
      }
      // Every row was pending/failed-individually with none extracted yet.
      return ApiResult.ok(null);
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to check OCR status.');
    }
  }

  /// Uploads then polls (every 2s, up to 15 attempts / ~30s) for a result,
  /// returning the extracted fields or `null` on failure/timeout.
  Future<TruckOcrPrefill?> scanAndExtract({
    required String filePath,
    required String fileName,
    String documentType = 'OCR Scan',
    String? companyId,
  }) async {
    final submit = await submitScan(
      filePath: filePath,
      fileName: fileName,
      documentType: documentType,
      companyId: companyId,
    );
    if (!submit.isSuccess || submit.data == null) return null;
    final batchId = submit.data!;

    for (var attempt = 0; attempt < 15; attempt++) {
      await Future<void>.delayed(const Duration(seconds: 2));
      final poll = await pollResult(batchId);
      if (!poll.isSuccess) return null;
      if (poll.data != null) return poll.data;
    }
    return null; // timed out
  }

  Map<String, dynamic>? _asMap(dynamic v) =>
      v is Map ? Map<String, dynamic>.from(v) : null;

  Map<String, dynamic>? _parseJsonCandidate(dynamic candidate) {
    if (candidate == null) return null;
    if (candidate is String) {
      try {
        return _asMap(jsonDecode(candidate));
      } catch (_) {
        return null;
      }
    }
    return _asMap(candidate);
  }

  /// Finds the extracted-data object within a result row — the backend may
  /// nest it under `truck`/`trailer`, encode it as an `extracted_info` JSON
  /// string, or return it already flattened at the row's top level.
  Map<String, dynamic>? _resultRowEntity(Map<String, dynamic> row) {
    return _asMap(row['truck']) ??
        _asMap(row['trailer']) ??
        _parseJsonCandidate(row['extracted_info']) ??
        row;
  }

  String? _pickFirst(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final v = source[key];
      if (v != null && v.toString().trim().isNotEmpty) {
        return v.toString().trim();
      }
    }
    return null;
  }

  String? _numeric(String? text) {
    if (text == null) return null;
    final match = RegExp(r'[\d,]+(?:\.\d+)?').firstMatch(text);
    return match?.group(0)?.replaceAll(',', '');
  }

  TruckOcrPrefill _buildTruckPrefill(
    Map<String, dynamic> entity,
    String documentType,
  ) {
    final values = <String, String>{};
    void put(String key, String? value) {
      if (value != null && value.isNotEmpty) values[key] = value;
    }

    put(
      'unitNumber',
      _pickFirst(entity, [
        'unit_number',
        'unitNumber',
        'trailer_unit',
        'trailerUnit',
        'truck_unit',
        'truckUnit',
      ]),
    );
    put('vin', _pickFirst(entity, ['vin', 'vin_number']));
    put('make', _pickFirst(entity, ['make']));
    put('model', _pickFirst(entity, ['model']));
    put('year', _pickFirst(entity, ['year']));
    put('color', _pickFirst(entity, ['color']));
    put('fuelType', _pickFirst(entity, ['fuel_type', 'fuelType']));
    put(
      'gvwr',
      _numeric(
        _pickFirst(entity, [
          'gvwr',
          'gvw',
          'gross_vehicle_weight',
          'licensed_mass',
        ]),
      ),
    );
    put(
      'plateNumber',
      _pickFirst(entity, [
        'plate_number',
        'plateNumber',
        'license_plate',
        'licenseplate',
        'plate',
      ]),
    );
    put(
      'plateProvince',
      _pickFirst(entity, ['plate_province', 'plateProvince', 'state', 'province']),
    );
    put(
      'registrationNumber',
      _pickFirst(entity, ['registration_number', 'registrationNumber', 'rin']),
    );
    put(
      'registrationExpiry',
      _pickFirst(entity, ['registration_expiry', 'registrationExpiry']),
    );
    put(
      'vehicleType',
      _pickFirst(entity, ['vehicle_type', 'vehicleType', 'vehicle']),
    );
    put(
      'odometer',
      _numeric(
        _pickFirst(entity, ['odometer', 'odometer_reading', 'current_odometer']),
      ),
    );
    put('ownerName', _pickFirst(entity, ['owner_name', 'ownerName']));
    put('ownerAddress', _pickFirst(entity, ['owner_address', 'ownerAddress']));
    put('ownerPhone', _pickFirst(entity, ['owner_phone', 'ownerPhone']));
    put('ownerEmail', _pickFirst(entity, ['owner_email', 'ownerEmail', 'email']));
    put(
      'imsNumber',
      _pickFirst(entity, ['ims_number', 'imsNumber', 'ims_no', 'imsNo']),
    );
    put('transmission', _pickFirst(entity, ['transmission', 'transmission_type']));
    put('engineMake', _pickFirst(entity, ['engine_make', 'engineMake']));
    put('engineModel', _pickFirst(entity, ['engine_model', 'engineModel']));
    put(
      'purchaseDate',
      _pickFirst(entity, ['purchase_date', 'purchaseDate', 'date_of_purchase']),
    );
    put(
      'certificateNumber',
      _pickFirst(entity, [
        'certificate_number',
        'certificateNumber',
        'annualSafetyCurrent',
        'annual_safety_current',
      ]),
    );
    put(
      'inspectionDate',
      _pickFirst(entity, [
        'inspection_date',
        'inspectionDate',
        'last_inspection',
        'inspection_start_date',
      ]),
    );
    put(
      'expiryDate',
      _pickFirst(entity, [
        'expiry_date',
        'expiryDate',
        'annual_safety_last',
        'annual_inspection_expiry',
        'safety_standards_expiry',
      ]),
    );
    put(
      'inspectorName',
      _pickFirst(entity, ['inspector_name', 'inspectorName', 'technician_name']),
    );
    put(
      'inspectorLicense',
      _pickFirst(entity, ['inspector_license', 'inspectorLicense', 'technician_id']),
    );
    put(
      'inspectionFacility',
      _pickFirst(entity, [
        'inspection_facility',
        'inspectionFacility',
        'inspector_facility',
      ]),
    );
    put(
      'facilityNumber',
      _pickFirst(entity, ['facility_number', 'facilityNumber', 'centre_number']),
    );

    return TruckOcrPrefill(
      values,
      documentType: documentType.isEmpty ? null : documentType,
    );
  }

  /// Normalizes an OCR-extracted date string to `yyyy-MM-dd`. Ported from
  /// the web's `normalizeOcrDate` (common ISO/slash/dash shapes + a generic
  /// `DateTime` fallback); returns the original text if nothing matches.
  static String normalizeDate(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';

    if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(value)) return value.substring(0, 10);
    if (RegExp(r'^\d{4}/\d{2}/\d{2}').hasMatch(value)) {
      return value.substring(0, 10).replaceAll('/', '-');
    }

    final parsed = DateTime.tryParse(value);
    if (parsed != null) {
      final y = parsed.year.toString().padLeft(4, '0');
      final m = parsed.month.toString().padLeft(2, '0');
      final d = parsed.day.toString().padLeft(2, '0');
      return '$y-$m-$d';
    }

    final parts = value.split(RegExp(r'[/\-\s]'));
    if (parts.length == 3) {
      if (parts[2].length == 4) {
        // d-m-y
        return '${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}';
      }
      if (parts[0].length == 4) {
        // y-m-d
        return '${parts[0]}-${parts[1].padLeft(2, '0')}-${parts[2].padLeft(2, '0')}';
      }
    }
    return value;
  }
}
