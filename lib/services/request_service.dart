import 'package:rapide_nforce/core/constants/api_constants.dart';

import 'package:rapide_nforce/core/models/api_result.dart';

import 'package:rapide_nforce/core/utils/api_parse.dart';

import 'package:rapide_nforce/models/maintenance_request_model.dart';

import 'package:rapide_nforce/services/api_client.dart';



class RequestService {

  RequestService._();



  static final RequestService instance = RequestService._();

  final ApiClient _api = ApiClient.instance;



  Future<ApiResult<List<MaintenanceRequestModel>>> fetchRequests({

    int page = 1,

    int limit = 50,

    String? search,

  }) async {

    try {

      final body = await _api.parseJson(

        () => _api.get(

          ApiConstants.myRequests,

          params: {

            'page': page,

            'limit': limit,

            if (search != null && search.isNotEmpty) 'search': search,

          },

        ),

        onSuccess: (b) => b,

      );



      final items = ApiParse.listItems(body)

          .map(MaintenanceRequestModel.fromJson)

          .toList();

      return ApiResult.ok(items);

    } on ApiClientException catch (e) {

      return ApiResult.fail(e.message, statusCode: e.statusCode);

    } catch (_) {

      return ApiResult.fail('Failed to load requests.');

    }

  }



  /// Mirrors web's `requestService.getApprovals()` — the Lead Technician

  /// view of the team's pending maintenance requests, as opposed to

  /// [fetchRequests] which only returns the current user's own requests.

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



      final items = ApiParse.listItems(body)

          .map(MaintenanceRequestModel.fromJson)

          .toList();

      return ApiResult.ok(items);

    } on ApiClientException catch (e) {

      return ApiResult.fail(e.message, statusCode: e.statusCode);

    } catch (_) {

      return ApiResult.fail('Failed to load approvals.');

    }

  }

}

