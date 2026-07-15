import 'package:http/http.dart' as http;
import 'package:rapide_nforce/core/constants/api_constants.dart';
import 'package:rapide_nforce/core/models/api_result.dart';
import 'package:rapide_nforce/core/models/paginated_result.dart';
import 'package:rapide_nforce/core/utils/api_parse.dart';
import 'package:rapide_nforce/models/import_result_model.dart';
import 'package:rapide_nforce/models/trailer_model.dart';
import 'package:rapide_nforce/models/truck_document_model.dart';
import 'package:rapide_nforce/services/api_client.dart';
import 'package:rapide_nforce/services/auth_service.dart';

class TrailerService {
  TrailerService._();

  static final TrailerService instance = TrailerService._();

  final ApiClient _api = ApiClient.instance;

  Future<ApiResult<PaginatedResult<TrailerModel>>> fetchTrailers({
    int page = 1,
    int limit = 50,
    int? companyId,
    String? search,
  }) async {
    final cid = companyId ?? AuthService.instance.selectedCompanyIdInt;
    try {
      final body = await _api.parseJson(
        () => _api.get(
          ApiConstants.trailers,
          params: {
            'page': page,
            'limit': limit,
            'companyId': ?cid,
            if (search != null && search.isNotEmpty) 'search': search,
          },
          companyId: cid?.toString(),
        ),
        onSuccess: (b) => b,
      );
      final items = ApiParse.listItems(body).map(TrailerModel.fromJson).toList();
      final pagination = ApiParse.pagination(body);
      return ApiResult.ok(PaginatedResult(
        items: items,
        total: pagination['total'] as int? ?? items.length,
        page: pagination['page'] as int? ?? page,
        limit: pagination['limit'] as int? ?? limit,
        totalPages: pagination['totalPages'] as int? ?? 1,
      ));
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (e) {
      return ApiResult.fail('Failed to load trailers: $e');
    }
  }

  Future<ApiResult<TrailerModel>> fetchTrailerById(int id) async {
    try {
      final body = await _api.parseJson(
        () => _api.get('${ApiConstants.trailers}/$id'),
        onSuccess: (b) => b,
      );
      final data = ApiParse.asMap(ApiParse.unwrapData(body));
      if (data == null) return ApiResult.fail('Invalid trailer response.');
      return ApiResult.ok(TrailerModel.fromJson(data));
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to load trailer.');
    }
  }

  Future<ApiResult<TrailerModel>> createTrailer(
    Map<String, dynamic> payload, {
    String? companyId,
  }) async {
    try {
      final body = await _api.parseJson(
        () => _api.post(
          ApiConstants.trailers,
          body: payload,
          companyId: companyId,
        ),
        onSuccess: (b) => b,
      );
      final data = ApiParse.asMap(ApiParse.unwrapData(body)) ?? {};
      return ApiResult.ok(TrailerModel.fromJson(data));
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to create trailer.');
    }
  }

  Future<ApiResult<TrailerModel>> updateTrailer(
    int id,
    Map<String, dynamic> payload,
  ) async {
    try {
      final body = await _api.parseJson(
        () => _api.put('${ApiConstants.trailers}/$id', body: payload),
        onSuccess: (b) => b,
      );
      final data = ApiParse.asMap(ApiParse.unwrapData(body)) ?? {};
      return ApiResult.ok(TrailerModel.fromJson(data));
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to update trailer.');
    }
  }

  Future<ApiResult<void>> deleteTrailer(int id) async {
    try {
      await _api.parseJson(
        () => _api.delete('${ApiConstants.trailers}/$id'),
        onSuccess: (b) => b,
      );
      return ApiResult.ok(null);
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to delete trailer.');
    }
  }

  Future<ApiResult<bool>> checkVinExists({
    required String vin,
    int? excludeTrailerId,
  }) async {
    try {
      final body = await _api.parseJson(
        () => _api.get(
          ApiConstants.vehiclesVinExists,
          params: {'vin': vin, 'excludeTrailerId': ?excludeTrailerId},
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

  Future<ApiResult<ImportResult>> importExcel({
    required String filePath,
    required String fileName,
    String? companyId,
  }) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('dummy'))
        ..fields['importType'] = 'trailer';
      if (companyId != null && companyId.isNotEmpty) {
        request.fields['companyId'] = companyId;
      }
      request.files.add(
        await http.MultipartFile.fromPath('file', filePath, filename: fileName),
      );

      final body = await _api.parseJson(
        () => _api.postMultipart(
          ApiConstants.importsExcel,
          request,
          companyId: companyId,
        ),
        onSuccess: (b) => b,
      );
      final data = ApiParse.asMap(ApiParse.unwrapData(body)) ?? {};
      return ApiResult.ok(ImportResult.fromJson(data));
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to import file.');
    }
  }

  Future<ApiResult<List<TruckDocumentModel>>> fetchDocuments(int trailerId) async {
    try {
      final body = await _api.parseJson(
        () => _api.get('${ApiConstants.trailers}/$trailerId/documents'),
        onSuccess: (b) => b,
      );
      final items = ApiParse.listItems(body)
          .map((e) => TruckDocumentModel.fromJson(e))
          .toList();
      return ApiResult.ok(items);
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to load documents.');
    }
  }

  Future<ApiResult<TruckDocumentModel>> uploadDocumentFull({
    required int trailerId,
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
          '${ApiConstants.trailers}/$trailerId/documents',
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
    required int trailerId,
    required int documentId,
  }) async {
    try {
      await _api.parseJson(
        () => _api.delete(
          '${ApiConstants.trailers}/$trailerId/documents/$documentId',
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
}
