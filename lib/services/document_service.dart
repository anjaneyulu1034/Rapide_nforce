import 'package:rapide_nforce/core/constants/api_constants.dart';

import 'package:rapide_nforce/core/models/api_result.dart';

import 'package:rapide_nforce/core/models/paginated_result.dart';

import 'package:rapide_nforce/core/utils/api_parse.dart';

import 'package:rapide_nforce/models/document_model.dart';

import 'package:rapide_nforce/services/api_client.dart';

import 'package:rapide_nforce/services/auth_service.dart';

class DocumentService {
  DocumentService._();

  static final DocumentService instance = DocumentService._();

  final ApiClient _api = ApiClient.instance;

  Future<ApiResult<PaginatedResult<DocumentModel>>> fetchDocuments({
    int page = 1,

    int limit = 50,

    int? companyId,

    String? search,
  }) async {
    final cid = companyId ?? AuthService.instance.selectedCompanyIdInt;

    try {
      final body = await _api.parseJson(
        () => _api.get(
          ApiConstants.documents,

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

      final items = ApiParse.listItems(
        body,
      ).map(DocumentModel.fromJson).toList();

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
      return ApiResult.fail('Failed to load documents.');
    }
  }

  Future<ApiResult<String>> getDownloadUrl(int documentId) async {
    try {
      final body = await _api.parseJson(
        () => _api.get(
          '${ApiConstants.documents}/$documentId/download',

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
      return ApiResult.fail('Failed to get document URL.');
    }
  }
}
