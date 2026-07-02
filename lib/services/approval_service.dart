import 'package:rapide_nforce/core/constants/api_constants.dart';

import 'package:rapide_nforce/core/models/api_result.dart';

import 'package:rapide_nforce/core/utils/api_parse.dart';

import 'package:rapide_nforce/models/maintenance_request_model.dart';

import 'package:rapide_nforce/services/api_client.dart';

class ApprovalService {
  ApprovalService._();

  static final ApprovalService instance = ApprovalService._();

  final ApiClient _api = ApiClient.instance;

  Future<ApiResult<List<MaintenanceRequestModel>>> fetchApprovals({
    int page = 1,

    int limit = 50,

    String? search,
  }) async {
    try {
      final body = await _api.parseJson(
        () => _api.get(
          ApiConstants.maintenanceApprovals,

          params: {
            'page': page,

            'limit': limit,

            if (search != null && search.isNotEmpty) 'search': search,
          },
        ),

        onSuccess: (b) => b,
      );

      final items = ApiParse.listItems(
        body,
      ).map(MaintenanceRequestModel.fromJson).toList();

      return ApiResult.ok(items);
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to load approvals.');
    }
  }

  Future<ApiResult<void>> approveRequest({
    required int id,

    required int status,

    String? notes,
  }) async {
    try {
      await _api.parseJson(
        () => _api.put(
          '${ApiConstants.maintenanceApprovals}/$id',

          body: {'status': status, 'notes': ?notes},
        ),

        onSuccess: (b) => b,
      );

      return ApiResult.ok(null);
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to update approval.');
    }
  }
}
