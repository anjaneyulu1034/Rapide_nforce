import 'package:rapide_nforce/core/constants/api_constants.dart';
import 'package:rapide_nforce/core/models/api_result.dart';
import 'package:rapide_nforce/core/models/paginated_result.dart';
import 'package:rapide_nforce/core/utils/api_parse.dart';
import 'package:rapide_nforce/models/fault_code_model.dart';
import 'package:rapide_nforce/services/api_client.dart';
import 'package:rapide_nforce/services/auth_service.dart';

class FaultCodesService {
  FaultCodesService._();

  static final FaultCodesService instance = FaultCodesService._();
  final ApiClient _api = ApiClient.instance;

  Future<ApiResult<PaginatedResult<FaultCodeModel>>> fetchFaultCodes({
    int page = 1,
    int limit = 10,
    String? search,
    String? faultStatus,
    String? severity,
    int? companyId,
  }) async {
    final cid = companyId ?? AuthService.instance.selectedCompanyIdInt;
    try {
      final body = await _api.parseJson(
        () => _api.get(
          ApiConstants.syncedFaultCodes,
          params: {
            'page': page,
            'limit': limit,
            if (search != null && search.isNotEmpty) 'search': search,
            'companyId': ?cid,
            if (faultStatus != null && faultStatus.isNotEmpty)
              'faultStatus': faultStatus,
            if (severity != null && severity.isNotEmpty) 'severity': severity,
          },
          companyId: cid?.toString(),
        ),
        onSuccess: (b) => b,
      );

      final parsed = _parsePaginated(body, page, limit);
      return ApiResult.ok(parsed);
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to load fault codes.');
    }
  }

  PaginatedResult<FaultCodeModel> _parsePaginated(
    dynamic body,
    int page,
    int limit,
  ) {
    final rows = ApiParse.listItems(body);
    if (rows.isNotEmpty) {
      final items = rows.map(FaultCodeModel.fromJson).toList();
      return PaginatedResult(
        items: items,
        total: items.length,
        page: page,
        limit: limit,
        totalPages: 1,
      );
    }

    final root = ApiParse.asMap(body);
    final data = ApiParse.asMap(root?['data']);
    final nestedItems = data?['data'];
    final pagination = ApiParse.asMap(data?['pagination']);

    final list = nestedItems is List
        ? nestedItems
              .whereType<Map>()
              .map((m) => FaultCodeModel.fromJson(Map<String, dynamic>.from(m)))
              .toList()
        : <FaultCodeModel>[];

    final total = (pagination?['total'] as num?)?.toInt() ?? list.length;
    final currentLimit = (pagination?['limit'] as num?)?.toInt() ?? limit;
    final currentPage = (pagination?['page'] as num?)?.toInt() ?? page;
    final totalPages =
        (pagination?['totalPages'] as num?)?.toInt() ??
        (total / (currentLimit == 0 ? 1 : currentLimit)).ceil().clamp(
          1,
          999999,
        );

    return PaginatedResult(
      items: list,
      total: total,
      page: currentPage,
      limit: currentLimit,
      totalPages: totalPages,
    );
  }
}
