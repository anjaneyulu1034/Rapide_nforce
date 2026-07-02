import 'package:rapide_nforce/core/models/api_result.dart';
import 'package:rapide_nforce/models/live_deal_model.dart';

class LiveDealService {
  LiveDealService._();

  static final LiveDealService instance = LiveDealService._();

  Future<ApiResult<List<LiveDealModel>>> fetchDeals() async {
    return ApiResult.fail('Deals are not available in the technician app.');
  }
}
