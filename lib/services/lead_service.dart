import 'package:rapide_nforce/core/models/api_result.dart';
import 'package:rapide_nforce/models/lead_model.dart';

class LeadService {
  LeadService._();

  static final LeadService instance = LeadService._();

  Future<ApiResult<List<LeadModel>>> fetchLeads() async {
    return ApiResult.fail('Leads are not available in the technician app.');
  }
}
