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
    int limit = 100,
    String? search,
    String? reportedFrom,
    String? reportedTo,
    String? inspectionType,
    String? reportStatus,
    int? companyId,
  }) async {
    final cid = companyId ?? AuthService.instance.selectedCompanyIdInt;
    final Map<String, dynamic> params = {
      'page': page,
      'limit': limit,
    };
    if (search != null && search.trim().isNotEmpty) {
      params['search'] = search.trim();
    }
    if (reportedFrom != null && reportedFrom.isNotEmpty) {
      params['reportedFrom'] = reportedFrom;
    }
    if (reportedTo != null && reportedTo.isNotEmpty) {
      params['reportedTo'] = reportedTo;
    }
    if (inspectionType != null && inspectionType.isNotEmpty) {
      params['inspectionType'] = inspectionType;
    }
    if (reportStatus != null && reportStatus.isNotEmpty) {
      params['reportStatus'] = reportStatus;
    }
    if (cid != null) {
      params['companyId'] = cid;
    }

    try {
      final body = await _api.parseJson(
        () => _api.get(
          '/synced-dvir-reports',
          params: params,
          companyId: cid?.toString(),
        ),
        onSuccess: (b) => b,
      );

      final items = ApiParse.listItems(body)
          .map((m) => DvirReportModel.fromJson(Map<String, dynamic>.from(m as Map)))
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
    int limit = 100,
    String? search,
    String? defectStatus,
    String? severity,
    String? syncedDvirReportId,
    int? companyId,
  }) async {
    final cid = companyId ?? AuthService.instance.selectedCompanyIdInt;
    final Map<String, dynamic> params = {
      'page': page,
      'limit': limit,
    };
    if (search != null && search.trim().isNotEmpty) {
      params['search'] = search.trim();
    }
    if (defectStatus != null && defectStatus.isNotEmpty) {
      params['defectStatus'] = defectStatus;
    }
    if (severity != null && severity.isNotEmpty) {
      params['severity'] = severity;
    }
    if (syncedDvirReportId != null && syncedDvirReportId.isNotEmpty) {
      params['syncedDvirReportId'] = syncedDvirReportId;
    }
    if (cid != null) {
      params['companyId'] = cid;
    }

    try {
      final body = await _api.parseJson(
        () => _api.get(
          '/synced-dvir-defects',
          params: params,
          companyId: cid?.toString(),
        ),
        onSuccess: (b) => b,
      );

      final items = ApiParse.listItems(body)
          .map((m) => DvirDefectModel.fromJson(Map<String, dynamic>.from(m as Map)))
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

  Future<ApiResult<void>> resolveDefect(
    String id, {
    String? mechanicNote,
    String? mechanicName,
    String? status,
  }) async {
    try {
      await _api.parseJson(
        () => _api.patch(
          '/synced-dvir-defects/$id/resolve',
          body: {
            if (mechanicNote != null && mechanicNote.isNotEmpty)
              'mechanicNote': mechanicNote,
            if (mechanicName != null && mechanicName.isNotEmpty)
              'mechanicName': mechanicName,
            if (status != null && status.isNotEmpty) 'status': status,
            'resolvedAtTime': DateTime.now().toUtc().toIso8601String(),
          },
        ),
        onSuccess: (b) => b,
      );
      return ApiResult.ok(null);
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to resolve DVIR defect.');
    }
  }
}
