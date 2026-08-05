import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
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
class OcrUploadDocItem {
  const OcrUploadDocItem({
    required this.filePath,
    required this.fileName,
    required this.documentType,
  });

  final String filePath;
  final String fileName;
  final String documentType;
}

/// Uploads picked documents via generic `POST /documents` + triggers `POST /ocr/extract_info`
/// and polls status via `POST /ocr/status` — exact port of web's `documentsService.uploadMultipleDocuments`
/// and `ocrService.extractInfo`/`getOCRResults` in `Documentupload.tsx`.
class OcrService {
  OcrService._();
  static final OcrService instance = OcrService._();

  final ApiClient _api = ApiClient.instance;

  /// Calls `POST /ocr/status` to poll OCR extraction status for [batchId].
  Future<ApiResult<TruckOcrPrefill?>> pollStatus(
    String batchId, {
    String? jobId,
  }) async {
    try {
      final payload = {
        'batchId': batchId,
        'sessionId': 'session_001',
        'job_id': jobId ?? '',
      };
      final body = await _api.parseJson(
        () => _api.post(ApiConstants.ocrStatus, body: payload),
        onSuccess: (b) => b,
      );
      final map = ApiParse.asMap(body) ?? {};
      final batchStatus = (map['status']?.toString() ??
              _asMap(map['data'])?['status']?.toString() ??
              '')
          .toLowerCase()
          .trim();

      debugPrint(
        '[OCR Service] pollStatus response: batchStatus=$batchStatus, body=$map',
      );

      if (batchStatus == 'failed' || batchStatus == 'error') {
        debugPrint('[OCR Service] Batch status failed/error.');
        return ApiResult.fail('No data could be extracted from the document.');
      }

      final rows = _collectResultRows(map);
      debugPrint('[OCR Service] Collected ${rows.length} result row(s).');
      if (rows.isEmpty) {
        return ApiResult.ok(null); // still processing
      }

      bool anyInProgress = batchStatus == 'processing' ||
          batchStatus == 'pending' ||
          batchStatus == 'queued' ||
          batchStatus == 'in_progress';

      for (final row in rows) {
        final state = (row['job_state'] ?? row['status'] ?? '')
            .toString()
            .toLowerCase()
            .trim();
        if (state == 'in_progress' ||
            state == 'processing' ||
            state == 'pending' ||
            state == 'queued' ||
            state == 'retrying') {
          anyInProgress = true;
          break;
        }
      }

      TruckOcrPrefill? foundPrefill;
      for (final row in rows) {
        if (!_isSuccessfulResultRow(row)) continue;

        final documentType =
            (row['documentType'] ?? row['document_type'])?.toString() ?? '';
        final entity = _resultRowEntity(row);
        if (entity == null) continue;

        final prefill = _buildTruckPrefill(entity, documentType);
        if (!prefill.isEmpty) {
          foundPrefill = prefill;
          break;
        }
      }

      if (foundPrefill != null) {
        debugPrint(
          '[OCR Service] Found prefill fields: ${foundPrefill.values}',
        );
        return ApiResult.ok(foundPrefill);
      }

      if (anyInProgress) {
        debugPrint('[OCR Service] Jobs still in progress...');
        return ApiResult.ok(null); // Still in progress
      }

      debugPrint(
        '[OCR Service] All jobs completed but no prefill fields extracted.',
      );
      // All jobs in batch completed with no prefill fields extracted
      return ApiResult.ok(const TruckOcrPrefill({}));
    } on ApiClientException catch (e) {
      debugPrint('[OCR Service] pollStatus client exception: ${e.message}');
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (e) {
      debugPrint('[OCR Service] pollStatus exception: $e');
      return ApiResult.fail('Failed to check OCR status.');
    }
  }

  /// Uploads documents via `POST /documents`, calls `POST /ocr/extract_info`,
  /// and polls `POST /ocr/status` for extracted prefill fields.
  Future<TruckOcrPrefill?> uploadAndExtractOcr({
    required List<OcrUploadDocItem> documents,
    int entityTypeId = 1,
    String entityType = 'Truck',
    String entityName = 'TR-101',
    String? companyId,
  }) async {
    if (documents.isEmpty) return null;

    try {
      debugPrint(
        '[OCR Service] Starting upload for ${documents.length} document(s)...',
      );
      final request = http.MultipartRequest('POST', Uri.parse('dummy'));

      final nowIso = DateTime.now().toUtc().toIso8601String();
      final tenYearsIso =
          DateTime.now().add(const Duration(days: 3650)).toUtc().toIso8601String();

      final metadataList = <Map<String, dynamic>>[];

      for (var i = 0; i < documents.length; i++) {
        final doc = documents[i];
        metadataList.add({
          'documentType': doc.documentType,
          'documentTypeId': null,
          'issueDate': nowIso,
          'expiryDate': tenYearsIso,
          'noExpiryDate': false,
          'isOcrUpload': true,
          'entityTypeId': entityTypeId,
          'entityType': entityType,
          'entityName': entityName,
          'entityId': 1,
        });

        request.files.add(
          await http.MultipartFile.fromPath(
            'files',
            doc.filePath,
            filename: doc.fileName,
            contentType: _contentTypeFor(doc.fileName),
          ),
        );
      }

      request.fields['documents'] = jsonEncode(metadataList);

      debugPrint(
        '[OCR Service] Posting /documents with metadata: ${request.fields['documents']}',
      );
      final uploadBody = await _api.parseJson(
        () => _api.postMultipart(
          ApiConstants.documents,
          request,
          companyId: companyId,
        ),
        onSuccess: (b) => b,
      );

      final bodyMap = ApiParse.asMap(uploadBody) ?? {};
      final dataMap = ApiParse.asMap(ApiParse.unwrapData(uploadBody)) ?? {};
      var batchId = (dataMap['batchId'] ??
              dataMap['batch_id'] ??
              bodyMap['batchId'] ??
              bodyMap['batch_id'])
          ?.toString();

      debugPrint(
        '[OCR Service] /documents upload completed. Returned batchId: $batchId',
      );
      if (batchId == null || batchId.isEmpty) return null;

      final returnedData = bodyMap['data'] ?? dataMap['data'];
      final returnedList = returnedData is List
          ? returnedData
          : (returnedData != null ? [returnedData] : []);

      String resolveDocUrl(dynamic item) {
        final map = _asMap(item);
        if (map == null) return '';
        if (map['fileUrl'] != null) return map['fileUrl'].toString();
        if (map['file_url'] != null) return map['file_url'].toString();
        final docs = map['uploadedDocuments'];
        if (docs is Map && docs['fileUrl'] != null) return docs['fileUrl'].toString();
        if (docs is List && docs.isNotEmpty && docs[0] is Map && docs[0]['fileUrl'] != null) {
          return docs[0]['fileUrl'].toString();
        }
        if (map['filePath'] != null) return map['filePath'].toString();
        return '';
      }

      const typeMapping = {
        'External Repair Invoice': 'external_repair_invoice',
        'PM Service Record': 'pm_service_record',
        'RC': 'truck_registration',
        'Registration': 'truck_registration',
        'TRUCK CVIP': 'truck_cvip',
        'Part Invoice': 'part_invoice',
      };

      final extractDocsList = <Map<String, dynamic>>[];
      for (var idx = 0; idx < documents.length; idx++) {
        final d = documents[idx];
        final matchedDoc = idx < returnedList.length ? returnedList[idx] : (returnedList.isNotEmpty ? returnedList[0] : null);
        final resolvedUrl = resolveDocUrl(matchedDoc);
        final matchedMap = _asMap(matchedDoc);
        final docId = matchedMap?['id']?.toString() ??
            _asMap(matchedMap?['uploadedDocuments'])?['id']?.toString() ??
            'doc_${idx + 1}';

        final rawType = d.documentType;
        final resolvedType = typeMapping[rawType] ?? rawType;

        extractDocsList.add({
          'documentId': docId,
          'fileName': d.fileName,
          'fileType': d.fileName.toLowerCase().endsWith('.pdf') ? 'pdf' : 'image',
          'fileUrl': resolvedUrl,
          'document_type': resolvedType,
          'information_schema': {},
        });
      }

      final extractPayload = {
        'batchId': batchId,
        'sessionId': 'session_001',
        'callbackUrl': '',
        'submittedAt': nowIso,
        'documents': extractDocsList,
      };

      debugPrint(
        '[OCR Service] Calling /ocr/extract_info payload: ${jsonEncode(extractPayload)}',
      );

      String? jobId;
      try {
        final extractRes = await _api.parseJson(
          () => _api.post(ApiConstants.ocrExtractInfo, body: extractPayload),
          onSuccess: (b) => b,
        );
        debugPrint('[OCR Service] /ocr/extract_info response: $extractRes');
        final extractMap = ApiParse.asMap(extractRes) ?? {};
        final resData = _asMap(extractMap['data']) ?? extractMap;

        final jobIdsList = resData['job_ids'];
        if (jobIdsList is List && jobIdsList.isNotEmpty && jobIdsList[0] is Map) {
          jobId = jobIdsList[0]['job_id']?.toString();
        } else {
          jobId = (resData['jobId'] ?? resData['primaryJobId'])?.toString();
        }

        final extractedBatchId = (resData['batch_id'] ?? resData['batchId'])?.toString();
        if (extractedBatchId != null && extractedBatchId.isNotEmpty) {
          batchId = extractedBatchId;
        }
      } catch (e) {
        debugPrint('[OCR Service] Warning: /ocr/extract_info failed: $e');
      }

      debugPrint(
        '[OCR Service] Starting polling /ocr/status for batchId=$batchId (jobId=$jobId)...',
      );
      // Poll status endpoint
      for (var attempt = 0; attempt < 60; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 2500));
        debugPrint(
          '[OCR Service] Polling attempt ${attempt + 1}/60 for batchId=$batchId...',
        );
        final poll = await pollStatus(batchId!, jobId: jobId);
        if (!poll.isSuccess) {
          debugPrint('[OCR Service] Polling failed: ${poll.message}');
          return null;
        }
        if (poll.data != null) {
          debugPrint(
            '[OCR Service] OCR processing completed! Extracted fields (${poll.data!.values.length}): ${poll.data!.values}',
          );
          return poll.data;
        }
      }

      debugPrint('[OCR Service] Polling timed out after 60 attempts (150s).');
      return null;
    } catch (e, stack) {
      debugPrint('[OCR Service] Exception during uploadAndExtractOcr: $e\n$stack');
      return null;
    }
  }

  Future<TruckOcrPrefill?> scanAndExtract({
    required String filePath,
    required String fileName,
    String documentType = 'OCR Scan',
    String? companyId,
  }) async {
    return uploadAndExtractOcr(
      documents: [
        OcrUploadDocItem(
          filePath: filePath,
          fileName: fileName,
          documentType: documentType,
        ),
      ],
      companyId: companyId,
    );
  }

  MediaType _contentTypeFor(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;
    switch (ext) {
      case 'pdf':
        return MediaType('application', 'pdf');
      case 'jpg':
      case 'jpeg':
        return MediaType('image', 'jpeg');
      case 'png':
        return MediaType('image', 'png');
      default:
        return MediaType('application', 'pdf');
    }
  }

  List<Map<String, dynamic>> _collectResultRows(Map<String, dynamic> raw) {
    final rows = <Map<String, dynamic>>[];
    void addList(dynamic list) {
      if (list is List) {
        for (final item in list) {
          final map = _asMap(item);
          if (map != null) rows.add(map);
        }
      }
    }

    addList(raw['results']);
    addList(raw['job_data']);

    final topLevelData = _asMap(raw['data']);
    if (topLevelData != null) {
      addList(topLevelData['results']);
      if (rows.isEmpty) addList(topLevelData['job_data']);

      final nestedData = _asMap(topLevelData['data']);
      if (nestedData != null) {
        addList(nestedData['results']);
        if (rows.isEmpty) addList(nestedData['job_data']);
      }
    }
    if (rows.isEmpty && topLevelData != null) {
      if (topLevelData.containsKey('vin') ||
          topLevelData.containsKey('truck') ||
          topLevelData.containsKey('trailer') ||
          topLevelData.containsKey('basic_information')) {
        rows.add(topLevelData);
      }
    }
    return rows;
  }

  bool _isSuccessfulResultRow(Map<String, dynamic> row) {
    final status = (row['status']?.toString() ?? '').trim().toLowerCase();
    if (status == 'failed' || status == 'error' || status == 'retried') {
      return false;
    }
    const okStatuses = {
      'success',
      'succeeded',
      'completed',
      'complete',
      'done',
      'partially_processed',
      'partially processed',
      'partiallyprocessed',
    };
    if (okStatuses.contains(status)) return true;

    final jobState = (row['job_state']?.toString() ?? '').trim().toLowerCase();
    if (jobState == 'completed' || jobState == 'success') {
      final entity = _resultRowEntity(row);
      return entity != null;
    }
    if (status.isEmpty) {
      final entity = _resultRowEntity(row);
      return entity != null;
    }
    return false;
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

  Map<String, dynamic>? _resultRowEntity(Map<String, dynamic> row) {
    final resultObj = _asMap(row['result']);
    final root = resultObj ?? row;
    return _asMap(root['truck']) ??
        _asMap(root['trailer']) ??
        _parseJsonCandidate(root['extracted_info']) ??
        _parseJsonCandidate(root['extractedInfo']) ??
        _parseJsonCandidate(root['extracted_data']) ??
        _parseJsonCandidate(root['extractedData']) ??
        root;
  }

  List<Map<String, dynamic>> _flattenEntitySections(
    Map<String, dynamic> root, {
    int maxDepth = 6,
  }) {
    final sections = <Map<String, dynamic>>[];
    final seen = <Map<String, dynamic>>{};

    void walk(Map<String, dynamic> node, int depth) {
      if (depth > maxDepth || seen.contains(node)) return;
      seen.add(node);
      sections.add(node);

      for (final value in node.values) {
        final child = _asMap(value);
        if (child != null) walk(child, depth + 1);
      }
    }

    walk(root, 0);
    return sections;
  }

  List<Map<String, dynamic>> _collectEntitySources(
    Map<String, dynamic> entity,
    String documentType,
  ) {
    final normalizedType = documentType.trim().toLowerCase();
    final directSection =
        normalizedType.isNotEmpty ? _asMap(entity[normalizedType]) : null;
    final flattened = _flattenEntitySections(entity);
    if (directSection != null) {
      return [
        directSection,
        ...flattened.where((s) => s != directSection),
      ];
    }
    return flattened;
  }

  String? _pickFirst(
    List<Map<String, dynamic>> sources,
    List<String> keys,
  ) {
    for (final source in sources) {
      for (final key in keys) {
        final v = source[key];
        if (v != null && v.toString().trim().isNotEmpty) {
          return v.toString().trim();
        }
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
    final sources = _collectEntitySources(entity, documentType);
    final values = <String, String>{};
    void put(String key, String? value) {
      if (value != null && value.isNotEmpty) values[key] = value;
    }

    final odometer = _numeric(
      _pickFirst(sources, [
        'odometer',
        'odometer_reading',
        'current_odometer',
        'mileage',
        'km_reading',
        'hubodometer',
        'hours',
      ]),
    );

    put('vin', _pickFirst(sources, ['vin', 'vin_number', 'vehicle_identification_number', 'chassis_no', 'serial_number']));
    put('make', _pickFirst(sources, ['make', 'vehicle_make', 'truck_make', 'trailer_make']));
    put('model', _pickFirst(sources, ['model', 'vehicle_model', 'truck_model', 'trailer_model']));
    put('year', _pickFirst(sources, ['year', 'model_year', 'year_of_manufacture']));
    put('color', _pickFirst(sources, ['color', 'vehicle_color']));
    put('fuelType', _pickFirst(sources, ['fuel_type', 'fuelType', 'type_of_fuel']));
    final gvwrVal = _numeric(_pickFirst(sources, ['gvwr', 'gvw', 'gross_vehicle_weight', 'licensed_mass', 'gross_weight', 'spec_gvwr', 'specGvwr']));
    put('gvwr', gvwrVal);
    put('specGvwr', gvwrVal);

    final vehicleTypeVal = _pickFirst(sources, ['vehicle_type', 'vehicleType', 'vehicle', 'body_type', 'spec_type', 'specType', 'trailer_type']);
    put('vehicleType', vehicleTypeVal);
    put('specType', vehicleTypeVal);

    put('unitNumber', _pickFirst(sources, ['unit_number', 'unitNumber', 'truck_unit', 'truckUnit', 'trailer_unit', 'trailerUnit', 'unit_no', 'unitNo', 'vehicle_number', 'fleet_number']));
    put('plateNumber', _pickFirst(sources, ['plate_number', 'plateNumber', 'license_plate', 'licenseplate', 'plate', 'registration_plate', 'plate_no']));
    put('plateProvince', _pickFirst(sources, ['plate_province', 'plateProvince', 'state', 'province', 'issuing_jurisdiction', 'jurisdiction']));
    put('registrationNumber', _pickFirst(sources, ['registration_number', 'registrationNumber', 'rin', 'permit_number', 'registration_no']));
    put('registrationExpiry', _pickFirst(sources, ['registration_expiry', 'registrationExpiry', 'expiry_date', 'expiration_date']));
    put('odometer', odometer);
    put('currentOdometer', odometer);
    put('ownerName', _pickFirst(sources, ['owner_name', 'ownerName', 'registered_owner', 'name_of_owner']));
    put('ownerAddress', _pickFirst(sources, ['owner_address', 'ownerAddress', 'address', 'street_address']));
    put('ownerPhone', _pickFirst(sources, ['owner_phone', 'ownerPhone', 'telephone', 'phone_number']));
    put('ownerProvince', _pickFirst(sources, ['owner_province', 'ownerProvince', 'owner_state']));
    put('ownerEmail', _pickFirst(sources, ['owner_email', 'ownerEmail', 'email']));
    put('imsNumber', _pickFirst(sources, ['ims_number', 'imsNumber', 'ims_no', 'imsNo']));
    put('transmission', _pickFirst(sources, ['transmission', 'transmission_type', 'gearbox']));
    put('engineMake', _pickFirst(sources, ['engine_make', 'engineMake']));
    put('engineModel', _pickFirst(sources, ['engine_model', 'engineModel']));
    put('purchaseDate', _pickFirst(sources, ['purchase_date', 'purchaseDate', 'date_of_purchase']));
    put('certificateNumber', _pickFirst(sources, ['certificate_number', 'certificateNumber', 'annualSafetyCurrent', 'annual_safety_current', 'cert_no', 'cvip_number', 'cvip_no']));
    put('inspectionDate', _pickFirst(sources, ['inspection_date', 'inspectionDate', 'last_inspection', 'inspection_start_date', 'date_of_inspection']));
    put('expiryDate', _pickFirst(sources, ['expiry_date', 'expiryDate', 'annual_safety_last', 'annual_inspection_expiry', 'safety_standards_expiry', 'cvip_expiry', 'expiration_date']));
    put('inspectorName', _pickFirst(sources, ['inspector_name', 'inspectorName', 'technician_name', 'inspector', 'technician']));
    put('inspectorLicense', _pickFirst(sources, ['inspector_license', 'inspectorLicense', 'technician_id', 'mechanic_license', 'license_no']));
    put('inspectionFacility', _pickFirst(sources, ['inspection_facility', 'inspectionFacility', 'inspector_facility', 'station_name', 'facility_name']));
    put('facilityNumber', _pickFirst(sources, ['facility_number', 'facilityNumber', 'centre_number', 'station_number', 'station_id', 'facility_no']));
    put('permitNumber', _pickFirst(sources, ['permit_number', 'permitNumber', 'permit_no', 'identification_number', 'reference_number']));
    put('permitType', _pickFirst(sources, ['permit_type', 'permitType']));
    put('issueDate', _pickFirst(sources, ['issue_date', 'issueDate', 'date_of_issue']));
    put('nextInspectionDue', _pickFirst(sources, ['next_inspection_due', 'nextInspectionDue', 'annual_inspection_due', 'annual_inspection_expiry']));
    put('criticalDefects', _pickFirst(sources, ['critical_defects', 'criticalDefects']));
    put('majorDefects', _pickFirst(sources, ['major_defects', 'majorDefects']));
    put('advisoryItems', _pickFirst(sources, ['advisory_items', 'advisoryItems']));
    put('inspectionSummary', _pickFirst(sources, ['inspection_summary', 'inspectionSummary', 'summary', 'remarks', 'comments']));

    return TruckOcrPrefill(
      values,
      documentType: documentType.isEmpty ? null : documentType,
    );
  }

  /// Normalizes an OCR-extracted date string to `yyyy-MM-dd`. Ported from
  /// the web's `normalizeOcrDate` in `ocrPrefillMapper.ts`.
  static String normalizeDate(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';

    if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(value)) return value.substring(0, 10);
    if (RegExp(r'^\d{4}/\d{2}/\d{2}').hasMatch(value)) {
      return value.substring(0, 10).replaceAll('/', '-');
    }

    final monthDayYearMatch = RegExp(
      r'^([a-zA-Z]+)\s+(\d{1,2}),?\s+(\d{4})$',
    ).firstMatch(value);
    if (monthDayYearMatch != null) {
      final parsed = DateTime.tryParse(
        '${monthDayYearMatch.group(1)} ${monthDayYearMatch.group(2)}, ${monthDayYearMatch.group(3)}',
      );
      if (parsed != null) {
        final y = parsed.year.toString().padLeft(4, '0');
        final m = parsed.month.toString().padLeft(2, '0');
        final d = parsed.day.toString().padLeft(2, '0');
        return '$y-$m-$d';
      }
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
        // d-m-y or m-d-y
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
