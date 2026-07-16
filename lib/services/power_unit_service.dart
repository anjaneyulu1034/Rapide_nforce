import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:rapide_nforce/core/constants/api_constants.dart';
import 'package:rapide_nforce/core/models/api_result.dart';
import 'package:rapide_nforce/core/models/paginated_result.dart';
import 'package:rapide_nforce/core/utils/api_parse.dart';
import 'package:rapide_nforce/models/power_unit_model.dart';
import 'package:rapide_nforce/models/truck_document_model.dart';
import 'package:rapide_nforce/models/truck_permit_model.dart';
import 'package:rapide_nforce/services/api_client.dart';
import 'package:rapide_nforce/services/auth_service.dart';

class PowerUnitService {
  PowerUnitService._();

  static final PowerUnitService instance = PowerUnitService._();

  final ApiClient _api = ApiClient.instance;

  Future<ApiResult<PaginatedResult<PowerUnitModel>>> fetchPowerUnits({
    int page = 1,
    int limit = 10,
    int? companyId,
    String? search,
    String? sortBy,
    String? sortOrder,
  }) async {
    final cid = companyId ?? AuthService.instance.selectedCompanyIdInt;
    try {
      final body = await _api.parseJson(
        () => _api.get(
          ApiConstants.trucks,
          params: {
            'page': page,
            'limit': limit,
            'companyId': ?cid,
            if (search != null && search.isNotEmpty) 'search': search,
            'sortBy': ?sortBy,
            'sortOrder': ?sortOrder,
          },
          companyId: cid?.toString(),
        ),
        onSuccess: (b) => b,
      );

      final items = ApiParse.listItems(
        body,
      ).map(PowerUnitModel.fromJson).toList();
      final pagination = ApiParse.pagination(body);

      return ApiResult.ok(
        PaginatedResult(
          items: items,
          total: pagination['total'] as int? ?? items.length,
          page: pagination['page'] as int? ?? page,
          limit: pagination['limit'] as int? ?? limit,
          totalPages: pagination['totalPages'] as int? ?? 1,
        ),
      );
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (e, stackTrace) {
      debugPrint('PowerUnitService Error: $e');
      debugPrint(stackTrace.toString());
      return ApiResult.fail('Failed to load power units: $e');
    }
  }

  Future<ApiResult<PowerUnitModel>> fetchPowerUnitById(int id) async {
    try {
      final body = await _api.parseJson(
        () => _api.get('${ApiConstants.trucks}/$id'),
        onSuccess: (b) => b,
      );

      final data = ApiParse.asMap(ApiParse.unwrapData(body));
      if (data == null) {
        return ApiResult.fail('Invalid power unit response.');
      }

      return ApiResult.ok(PowerUnitModel.fromJson(data));
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to load power unit.');
    }
  }

  Future<ApiResult<PowerUnitModel>> createPowerUnit(
    Map<String, dynamic> payload, {
    String? companyId,
  }) async {
    try {
      final body = await _api.parseJson(
        () =>
            _api.post(ApiConstants.trucks, body: payload, companyId: companyId),
        onSuccess: (b) => b,
      );
      final data = ApiParse.asMap(ApiParse.unwrapData(body)) ?? {};
      return ApiResult.ok(PowerUnitModel.fromJson(data));
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to create power unit.');
    }
  }

  Future<ApiResult<PowerUnitModel>> updatePowerUnit(
    int id,
    Map<String, dynamic> payload,
  ) async {
    try {
      final body = await _api.parseJson(
        () => _api.put('${ApiConstants.trucks}/$id', body: payload),
        onSuccess: (b) => b,
      );
      final data = ApiParse.asMap(ApiParse.unwrapData(body)) ?? {};
      return ApiResult.ok(PowerUnitModel.fromJson(data));
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to update power unit.');
    }
  }

  /// Generates a QR code (base64 PNG data URL) that links to a signed,
  /// time-limited download of the truck's roadside compliance PDF packet.
  /// Mirrors the web's `generateTruckQrCode` (`GET /trucks/:id/documents/qrcode`).
  Future<ApiResult<TruckQrCode>> generateQrCode(int truckId) async {
    try {
      final body = await _api.parseJson(
        () => _api.get('${ApiConstants.trucks}/$truckId/documents/qrcode'),
        onSuccess: (b) => b,
      );
      final data = ApiParse.asMap(ApiParse.unwrapData(body)) ?? {};
      final qrCode = data['qrCode'] as String?;
      final downloadUrl = data['downloadUrl'] as String?;
      if (qrCode == null) {
        return ApiResult.fail('QR code was not returned by the server.');
      }
      return ApiResult.ok(
        TruckQrCode(qrCodeDataUrl: qrCode, downloadUrl: downloadUrl ?? ''),
      );
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to generate QR code.');
    }
  }

  Future<ApiResult<void>> deletePowerUnit(int id) async {
    try {
      await _api.parseJson(
        () => _api.delete('${ApiConstants.trucks}/$id'),
        onSuccess: (b) => b,
      );
      return ApiResult.ok(null);
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to delete power unit.');
    }
  }

  Future<ApiResult<bool>> checkVinExists({required String vin}) async {
    try {
      final body = await _api.parseJson(
        () => _api.get(
          ApiConstants.vehiclesVinExists,
          params: {'vin': vin},
        ),
        onSuccess: (b) => b,
      );
      final data = ApiParse.asMap(ApiParse.unwrapData(body)) ?? {};
      final exists = data['exists'] == true || body == true;
      return ApiResult.ok(exists);
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      // Fail open — matches web behavior of proceeding if the check errors.
      return ApiResult.ok(false);
    }
  }

  Future<ApiResult<List<TruckDocumentModel>>> fetchDocuments(
    int truckId,
  ) async {
    try {
      final body = await _api.parseJson(
        () => _api.get('${ApiConstants.trucks}/$truckId/documents'),
        onSuccess: (b) => b,
      );
      final items = ApiParse.listItems(
        body,
      ).map((e) => TruckDocumentModel.fromJson(e)).toList();
      return ApiResult.ok(items);
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to load documents.');
    }
  }

  Future<ApiResult<TruckDocumentModel>> uploadDocument({
    required int truckId,
    required String filePath,
    required String fileName,
    required String vinNumber,
    String? documentType,
    String? issueDate,
    String? expiryDate,
    String? documentNumber,
    String? notes,
    String? companyId,
  }) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('dummy'))
        ..fields['vin_number'] = vinNumber;

      if (documentType != null && documentType.isNotEmpty) {
        request.fields['documentType'] = documentType;
      }
      if (issueDate != null && issueDate.isNotEmpty) {
        request.fields['issue_date'] = issueDate;
      }
      if (expiryDate != null && expiryDate.isNotEmpty) {
        request.fields['expiry_date'] = expiryDate;
      }
      if (documentNumber != null && documentNumber.isNotEmpty) {
        request.fields['document_number'] = documentNumber;
      }
      if (notes != null && notes.isNotEmpty) {
        request.fields['notes'] = notes;
      }

      request.files.add(
        await http.MultipartFile.fromPath('file', filePath, filename: fileName),
      );

      final body = await _api.parseJson(
        () => _api.postMultipart(
          '${ApiConstants.trucks}/$truckId/documents',
          request,
          companyId: companyId,
        ),
        onSuccess: (b) => b,
      );
      final data = ApiParse.asMap(ApiParse.unwrapData(body)) ?? {};
      return ApiResult.ok(TruckDocumentModel.fromJson(data));
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to upload document.');
    }
  }

  Future<ApiResult<void>> deleteDocument({
    required int truckId,
    required int documentId,
  }) async {
    try {
      await _api.parseJson(
        () => _api.delete(
          '${ApiConstants.trucks}/$truckId/documents/$documentId',
        ),
        onSuccess: (b) => b,
      );
      return ApiResult.ok(null);
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to delete document.');
    }
  }

  Future<ApiResult<List<TruckPermitModel>>> fetchPermits(int truckId) async {
    try {
      final body = await _api.parseJson(
        () => _api.get('${ApiConstants.trucks}/$truckId/permits'),
        onSuccess: (b) => b,
      );
      final items = ApiParse.listItems(
        body,
      ).map((e) => TruckPermitModel.fromJson(e)).toList();
      return ApiResult.ok(items);
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to load permits.');
    }
  }

  Future<ApiResult<TruckDocumentModel>> uploadDocumentFull({
    required int truckId,
    required String filePath,
    required String fileName,
    required String vinNumber,
    String? documentType,
    String? documentCategory,
    String? location,
    String? issueDate,
    String? expiryDate,
    String? documentNumber,
    String? notes,
    String? companyId,
  }) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('dummy'))
        ..fields['vin_number'] = vinNumber;

      if (documentType != null && documentType.isNotEmpty) {
        request.fields['documentType'] = documentType;
      }
      if (documentCategory != null && documentCategory.isNotEmpty) {
        request.fields['documentCategory'] = documentCategory;
      }
      if (location != null && location.isNotEmpty) {
        request.fields['location'] = location;
      }
      if (issueDate != null && issueDate.isNotEmpty) {
        request.fields['issue_date'] = issueDate;
      }
      if (expiryDate != null && expiryDate.isNotEmpty) {
        request.fields['expiry_date'] = expiryDate;
      }
      if (documentNumber != null && documentNumber.isNotEmpty) {
        request.fields['document_number'] = documentNumber;
      }
      if (notes != null && notes.isNotEmpty) {
        request.fields['notes'] = notes;
      }

      request.files.add(
        await http.MultipartFile.fromPath('file', filePath, filename: fileName),
      );

      final body = await _api.parseJson(
        () => _api.postMultipart(
          '${ApiConstants.trucks}/$truckId/documents',
          request,
          companyId: companyId,
        ),
        onSuccess: (b) => b,
      );
      final data = ApiParse.asMap(ApiParse.unwrapData(body)) ?? {};
      return ApiResult.ok(TruckDocumentModel.fromJson(data));
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to upload document.');
    }
  }

  /// Replaces/edits an existing document — mirrors the web's
  /// `updateTruckDocument` (PUT with optional new file).
  Future<ApiResult<TruckDocumentModel>> updateDocument({
    required int truckId,
    required int documentId,
    required String vinNumber,
    String? documentType,
    String? documentCategory,
    String? location,
    String? issueDate,
    String? expiryDate,
    String? documentNumber,
    String? notes,
    String? filePath,
    String? fileName,
    String? companyId,
  }) async {
    try {
      final request = http.MultipartRequest('PUT', Uri.parse('dummy'))
        ..fields['vin_number'] = vinNumber;

      if (documentType != null && documentType.isNotEmpty) {
        request.fields['documentType'] = documentType;
      }
      if (documentCategory != null && documentCategory.isNotEmpty) {
        request.fields['documentCategory'] = documentCategory;
      }
      if (location != null && location.isNotEmpty) {
        request.fields['location'] = location;
      }
      if (issueDate != null && issueDate.isNotEmpty) {
        request.fields['issue_date'] = issueDate;
      }
      if (expiryDate != null && expiryDate.isNotEmpty) {
        request.fields['expiry_date'] = expiryDate;
      }
      if (documentNumber != null) {
        request.fields['document_number'] = documentNumber;
      }
      if (notes != null) {
        request.fields['notes'] = notes;
      }
      if (filePath != null && filePath.isNotEmpty) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'file',
            filePath,
            filename: fileName,
          ),
        );
      }

      final body = await _api.parseJson(
        () => _api.postMultipart(
          '${ApiConstants.trucks}/$truckId/documents/$documentId',
          request,
          companyId: companyId,
        ),
        onSuccess: (b) => b,
      );
      final data = ApiParse.asMap(ApiParse.unwrapData(body)) ?? {};
      return ApiResult.ok(TruckDocumentModel.fromJson(data));
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to update document.');
    }
  }
}

/// A generated compliance QR code — a base64 PNG data URL plus the signed
/// download link it points to.
class TruckQrCode {
  const TruckQrCode({required this.qrCodeDataUrl, required this.downloadUrl});

  final String qrCodeDataUrl;
  final String downloadUrl;
}
