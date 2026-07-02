import 'package:rapide_nforce/core/models/api_result.dart';
import 'package:rapide_nforce/models/visit_model.dart';

class VisitService {
  VisitService._();

  static final VisitService instance = VisitService._();

  Future<ApiResult<List<VisitModel>>> fetchVisits() async {
    return ApiResult.fail('Visits are not available in the technician app.');
  }
}
