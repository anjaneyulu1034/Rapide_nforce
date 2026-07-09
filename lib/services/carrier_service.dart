import 'package:rapide_nforce/core/constants/api_constants.dart';
import 'package:rapide_nforce/core/models/api_result.dart';
import 'package:rapide_nforce/core/models/paginated_result.dart';
import 'package:rapide_nforce/core/utils/api_parse.dart';
import 'package:rapide_nforce/models/carrier_model.dart';
import 'package:rapide_nforce/models/document_model.dart';
import 'package:rapide_nforce/services/api_client.dart';
import 'package:http/http.dart' as http;

class CarrierService {
  CarrierService._();

  static final CarrierService instance = CarrierService._();
  final ApiClient _api = ApiClient.instance;

  Future<ApiResult<PaginatedResult<CarrierModel>>> fetchCarriers({
    int page = 1,
    int limit = 10,
    String? search,
    String? sortBy,
    String? sortOrder,
  }) async {
    try {
      final body = await _api.parseJson(
        () => _api.get(
          ApiConstants.carriers,
          params: {
            'page': page,
            'limit': limit,
            if (search != null && search.isNotEmpty) 'search': search,
            'sortBy': ?sortBy,
            'sortOrder': ?sortOrder,
          },
        ),
        onSuccess: (b) => b,
      );

      final items = ApiParse.listItems(
        body,
      ).map(CarrierModel.fromJson).toList();
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
    } catch (_) {
      return ApiResult.fail('Failed to load carriers.');
    }
  }

  Future<ApiResult<CarrierModel>> fetchCarrierById(int id) async {
    try {
      final body = await _api.parseJson(
        () => _api.get('${ApiConstants.carriers}/$id'),
        onSuccess: (b) => b,
      );
      final data = ApiParse.asMap(ApiParse.unwrapData(body));
      if (data == null) {
        return ApiResult.fail('Invalid carrier response.');
      }
      return ApiResult.ok(CarrierModel.fromJson(data));
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to load carrier.');
    }
  }

  Future<ApiResult<CarrierModel>> createCarrier(
    Map<String, dynamic> payload,
  ) async {
    try {
      final body = await _api.parseJson(
        () => _api.post(ApiConstants.carriers, body: payload),
        onSuccess: (b) => b,
      );
      final data = ApiParse.asMap(ApiParse.unwrapData(body)) ?? {};
      return ApiResult.ok(CarrierModel.fromJson(data));
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to create carrier.');
    }
  }

  Future<ApiResult<CarrierModel>> updateCarrier(
    int id,
    Map<String, dynamic> payload,
  ) async {
    try {
      final body = await _api.parseJson(
        () => _api.put('${ApiConstants.carriers}/$id', body: payload),
        onSuccess: (b) => b,
      );
      final data = ApiParse.asMap(ApiParse.unwrapData(body)) ?? {};
      return ApiResult.ok(CarrierModel.fromJson(data));
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to update carrier.');
    }
  }

  Future<ApiResult<void>> deleteCarrier(int id) async {
    try {
      await _api.parseJson(
        () => _api.delete('${ApiConstants.carriers}/$id'),
        onSuccess: (b) => b,
      );
      return ApiResult.ok(null);
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to delete carrier.');
    }
  }

  Future<ApiResult<void>> uploadConsent({
    required int companyId,
    required String filePath,
    required String fileName,
  }) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('dummy'))
        ..fields['companyId'] = companyId.toString()
        ..fields['documentType'] = 'CONSENT'
        ..files.add(
          await http.MultipartFile.fromPath(
            'file',
            filePath,
            filename: fileName,
          ),
        );

      await _api.parseJson(
        () => _api.postMultipart(ApiConstants.consentDocuments, request),
        onSuccess: (b) => b,
      );
      return ApiResult.ok(null);
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to upload consent document.');
    }
  }

  Future<ApiResult<void>> uploadConsentForCompany({
    required int companyId,
    required String filePath,
    required String fileName,
  }) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('dummy'))
        ..files.add(
          await http.MultipartFile.fromPath(
            'file',
            filePath,
            filename: fileName,
          ),
        );

      await _api.parseJson(
        () => _api.postMultipart(
          '${ApiConstants.consentDocuments}/$companyId',
          request,
        ),
        onSuccess: (b) => b,
      );
      return ApiResult.ok(null);
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to upload consent document.');
    }
  }

  Future<ApiResult<List<PlanOption>>> fetchPlans() async {
    try {
      final body = await _api.parseJson(
        () => _api.get(ApiConstants.plans, params: {'isActive': true}),
        onSuccess: (b) => b,
      );
      final items = ApiParse.listItems(body).map(PlanOption.fromJson).toList();
      return ApiResult.ok(items);
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to load plans.');
    }
  }

  /// Fetches the carrier's uploaded logo URL (presigned S3 link), if any.
  /// Mirrors the web app's `carriersService.getLogo`.
  Future<ApiResult<String?>> getLogo(int companyId) async {
    try {
      final body = await _api.parseJson(
        () => _api.get('${ApiConstants.carriers}/$companyId/logo'),
        onSuccess: (b) => b,
      );
      final data = ApiParse.asMap(ApiParse.unwrapData(body));
      return ApiResult.ok(data?['logoUrl'] as String?);
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to load carrier logo.');
    }
  }

  Future<ApiResult<List<BillingCycleOption>>> fetchBillingCycles() async {
    try {
      final body = await _api.parseJson(
        () => _api.get(ApiConstants.billingCycles),
        onSuccess: (b) => b,
      );
      final items = ApiParse.listItems(
        body,
      ).map(BillingCycleOption.fromJson).toList();
      return ApiResult.ok(items);
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to load billing cycles.');
    }
  }

  Future<ApiResult<CarrierComplianceData>> fetchCarrierCompliance(int companyId) async {
    try {
      final body = await _api.parseJson(
        () => _api.get(
          '/carrier-fileuploads',
          params: {'companyId': companyId.toString()},
        ),
        onSuccess: (b) => b,
      );

      final items = ApiParse.listItems(body)
          .map(DocumentModel.fromJson)
          .toList();

      final dataMap = ApiParse.asMap(body) ?? {};
      final summary = ApiParse.asMap(dataMap['summary']) ?? {};

      final data = CarrierComplianceData(
        documents: items,
        totalDocuments: summary['totalDocuments'] as int? ?? items.length,
        validDocuments: summary['validDocuments'] as int? ?? 0,
        expiringDocuments: summary['expiringDocuments'] as int? ?? 0,
        expiredDocuments: summary['expiredDocuments'] as int? ?? 0,
      );

      return ApiResult.ok(data);
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to load carrier compliance.');
    }
  }

  Future<ApiResult<void>> uploadCarrierDocument({
    required int companyId,
    required String filePath,
    required String fileName,
    required String documentCategory,
    required String documentType,
    String? documentNumber,
    required String issueDate,
    String? expiryDate,
    String? notes,
  }) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('dummy'))
        ..fields['companyId'] = companyId.toString()
        ..fields['documentCategory'] = documentCategory
        ..fields['documentType'] = documentType
        ..fields['issueDate'] = issueDate;

      if (documentNumber != null) request.fields['documentNumber'] = documentNumber;
      if (expiryDate != null) request.fields['expiryDate'] = expiryDate;
      if (notes != null) request.fields['notes'] = notes;

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          filePath,
          filename: fileName,
        ),
      );

      await _api.parseJson(
        () => _api.postMultipart('/carrier-fileuploads', request),
        onSuccess: (b) => b,
      );
      return ApiResult.ok(null);
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to upload compliance document.');
    }
  }

  Future<ApiResult<String>> getDownloadUrl(int id) async {
    try {
      final body = await _api.parseJson(
        () => _api.get(
          '/carrier-fileuploads/$id/download',
          params: {'mode': 'preview'},
        ),
        onSuccess: (b) => b,
      );
      final data = ApiParse.unwrapData(body);
      final map = ApiParse.asMap(data);
      return ApiResult.ok(map?['presignedUrl'] as String? ?? '');
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to get download URL.');
    }
  }
}
