import 'package:rapide_nforce/core/models/api_result.dart';
import 'package:rapide_nforce/core/models/paginated_result.dart';
import 'package:rapide_nforce/core/utils/api_parse.dart';
import 'package:rapide_nforce/models/dvir_defect_model.dart';
import 'package:rapide_nforce/models/dvir_report_model.dart';
import 'package:rapide_nforce/services/api_client.dart';
import 'package:rapide_nforce/services/auth_service.dart';

class DvirService {
  DvirService._();

  static final DvirService instance = DvirService._();
  final ApiClient _api = ApiClient.instance;

  Future<ApiResult<PaginatedResult<DvirReportModel>>> fetchReports({
    int page = 1,
    int limit = 10,
    String? search,
    String? reportedFrom,
    String? reportedTo,
    String? inspectionType,
    String? reportStatus,
    int? companyId,
  }) async {
    final cid = companyId ?? AuthService.instance.selectedCompanyIdInt;
    try {
      final body = await _api.parseJson(
        () => _api.get(
          '/synced-dvir-reports',
          params: {
            'page': page,
            'limit': limit,
            if (search != null && search.trim().isNotEmpty) 'search': search,
            if (reportedFrom != null && reportedFrom.isNotEmpty) 'reportedFrom': reportedFrom,
            if (reportedTo != null && reportedTo.isNotEmpty) 'reportedTo': reportedTo,
            if (inspectionType != null && inspectionType.isNotEmpty)
              'inspectionType': inspectionType,
            if (reportStatus != null && reportStatus.isNotEmpty)
              'reportStatus': reportStatus,
            'companyId': ?cid,
          },
          companyId: cid?.toString(),
        ),
        onSuccess: (b) => b,
      );

      final items = ApiParse.listItems(body)
          .map(DvirReportModel.fromJson)
          .toList();
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
      return ApiResult.fail('Failed to load DVIR reports.');
    }
  }

  Future<ApiResult<DvirReportModel>> fetchReportById(String id) async {
    try {
      final body = await _api.parseJson(
        () => _api.get('/synced-dvir-reports/$id'),
        onSuccess: (b) => b,
      );
      final data = ApiParse.asMap(ApiParse.unwrapData(body));
      if (data == null) {
        return ApiResult.fail('Invalid DVIR report response.');
      }
      return ApiResult.ok(DvirReportModel.fromJson(data));
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to load DVIR report.');
    }
  }

  Future<ApiResult<PaginatedResult<DvirDefectModel>>> fetchDefects({
    int page = 1,
    int limit = 10,
    String? search,
    String? defectStatus,
    String? severity,
    int? companyId,
  }) async {
    final cid = companyId ?? AuthService.instance.selectedCompanyIdInt;
    try {
      final body = await _api.parseJson(
        () => _api.get(
          '/synced-dvir-defects',
          params: {
            'page': page,
            'limit': limit,
            if (search != null && search.trim().isNotEmpty) 'search': search,
            if (defectStatus != null && defectStatus.isNotEmpty)
              'defectStatus': defectStatus,
            if (severity != null && severity.isNotEmpty) 'severity': severity,
            'companyId': ?cid,
          },
          companyId: cid?.toString(),
        ),
        onSuccess: (b) => b,
      );

      final items = ApiParse.listItems(body)
          .map(DvirDefectModel.fromJson)
          .toList();
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
      return ApiResult.fail('Failed to load DVIR defects.');
    }
  }

  Future<ApiResult<DvirDefectModel>> fetchDefectById(String id) async {
    try {
      final body = await _api.parseJson(
        () => _api.get('/synced-dvir-defects/$id'),
        onSuccess: (b) => b,
      );
      final data = ApiParse.asMap(ApiParse.unwrapData(body));
      if (data == null) {
        return ApiResult.fail('Invalid DVIR defect response.');
      }
      return ApiResult.ok(DvirDefectModel.fromJson(data));
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to load DVIR defect.');
    }
  }
}
