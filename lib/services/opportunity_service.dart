import 'package:rapide_nforce/core/constants/api_constants.dart';
import 'package:rapide_nforce/core/models/api_result.dart';
import 'package:rapide_nforce/models/opportunity_model.dart';
import 'package:rapide_nforce/services/api_client.dart';
import 'package:rapide_nforce/core/utils/api_parse.dart';

/// Manages opportunity list and detail fetching.
class OpportunityService {
  OpportunityService._();

  static final OpportunityService instance = OpportunityService._();
  final ApiClient _api = ApiClient.instance;

  Future<ApiResult<List<OpportunityModel>>> fetchOpportunities({
    OpportunityStatus? statusFilter,
  }) async {
    try {
      final body = await _api.parseJson(
        () => _api.get(
          ApiConstants.opportunities,
          params: {
            if (statusFilter != null) 'status': statusFilter.name,
          },
        ),
        onSuccess: (b) => b,
      );

      final items = ApiParse.listItems(body)
          .map((e) => OpportunityModel.fromJson(e))
          .toList();
      return ApiResult.ok(items);
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Network error. Please try again.');
    }
  }
}
