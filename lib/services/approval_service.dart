import 'package:rapide_nforce/core/constants/api_constants.dart';
import 'package:rapide_nforce/core/models/api_result.dart';
import 'package:rapide_nforce/core/utils/api_parse.dart';
import 'package:rapide_nforce/models/deferred_repair_model.dart';
import 'package:rapide_nforce/services/api_client.dart';
import 'package:rapide_nforce/services/auth_service.dart';

/// Mirrors web's `LeadApprovalsPage` — the "Approvals" screen is about
/// deferred repairs pending lead sign-off, not general work-order edits
/// (that's a separate `/maintenance/approvals` feature web doesn't surface
/// under this screen).
class ApprovalService {
  ApprovalService._();

  static final ApprovalService instance = ApprovalService._();

  final ApiClient _api = ApiClient.instance;

  /// Mirrors web's `resolveSelectedCompanyId()`: the backend's
  /// `getDeferredRepairs` query only scopes by company when an explicit
  /// `companyId` query param is given — it does NOT fall back to the
  /// `X-Company-Id` header the way most other endpoints do — so omitting
  /// it here (as the previous implementation did) returns every company's
  /// deferred repairs unfiltered.
  int? get _scopedCompanyId {
    final selected = AuthService.instance.selectedCompanyId;
    if (selected == null || selected == ApiConstants.allCarriersId) return null;
    return int.tryParse(selected);
  }

  Future<ApiResult<List<DeferredRepairModel>>> fetchDeferredRepairs({
    int page = 1,
    int limit = 50,
    String? search,
  }) async {
    try {
      final body = await _api.parseJson(
        () => _api.get(
          ApiConstants.deferredRepairs,
          params: {
            'page': page,
            'limit': limit,
            if (search != null && search.isNotEmpty) 'search': search,
            if (_scopedCompanyId != null) 'companyId': _scopedCompanyId,
          },
        ),
        onSuccess: (b) => b,
      );

      final items = ApiParse.listItems(
        body,
      ).map(DeferredRepairModel.fromJson).toList();

      return ApiResult.ok(items);
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to load approvals.');
    }
  }

  Future<ApiResult<void>> updateDeferredRepairStatus({
    required int id,
    required bool approve,
    String? notes,
  }) async {
    try {
      await _api.parseJson(
        () => _api.put(
          '${ApiConstants.deferredRepairs}/$id/status',
          body: {
            'action': approve ? 'APPROVE' : 'REJECT',
            if (notes != null && notes.isNotEmpty) 'notes': notes,
          },
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
