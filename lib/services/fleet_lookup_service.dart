import 'package:rapide_nforce/core/constants/api_constants.dart';
import 'package:rapide_nforce/core/models/api_result.dart';
import 'package:rapide_nforce/core/utils/api_parse.dart';
import 'package:rapide_nforce/models/truck_permit_model.dart';
import 'package:rapide_nforce/services/api_client.dart';
import 'package:rapide_nforce/services/auth_service.dart';

class FleetLookupService {
  FleetLookupService._();

  static final FleetLookupService instance = FleetLookupService._();
  final ApiClient _api = ApiClient.instance;

  Future<ApiResult<List<LookupOption>>> fetchCountries() async {
    return _fetchList(ApiConstants.countries);
  }

  Future<ApiResult<List<LookupOption>>> fetchStates({int? countryId}) async {
    return _fetchList(
      ApiConstants.states,
      params: countryId != null ? {'countryId': countryId} : null,
    );
  }

  Future<ApiResult<List<LookupOption>>> fetchCities({int? stateId}) async {
    return _fetchList(
      ApiConstants.cities,
      params: stateId != null ? {'stateId': stateId} : null,
    );
  }

  Future<ApiResult<List<LookupOption>>> fetchFuelTypes() async {
    return _fetchList(ApiConstants.fuelTypes, params: {'isActive': true});
  }

  Future<ApiResult<List<LookupOption>>> fetchMaintenancePolicies({
    int? companyId,
  }) async {
    final cid = companyId ?? AuthService.instance.selectedCompanyIdInt;
    return _fetchList(
      ApiConstants.maintenancePolicies,
      params: {'isActive': true, 'companyId': ?cid},
      companyId: cid?.toString(),
    );
  }

  Future<ApiResult<List<LookupOption>>> fetchPermitTypes() async {
    return _fetchList(ApiConstants.permitTypes, params: {'isActive': true});
  }

  Future<ApiResult<List<String>>> fetchComplianceDocumentCategories({
    bool isVehicle = true,
  }) async {
    // API name → display name (matches web VEHICLE_COMPLIANCE_CATEGORY_API_TO_DISPLAY)
    const apiToDisplay = <String, String>{
      'Unit-Specific Permits': 'Permits',
    };
    const truckAllowed = {
      'Carrier Authority Documents',
      'Lease & Ownership Documents',
      'Permits',
      'Vehicle-Specific Documents',
    };
    try {
      final body = await _api.parseJson(
        () => _api.get(
          ApiConstants.documentCategories,
          params: {'isActive': true},
        ),
        onSuccess: (b) => b,
      );
      final items = ApiParse.listItems(body)
          .map((e) => (e['name'] as String? ?? '').trim())
          .where((n) => n.isNotEmpty)
          .map((n) => apiToDisplay[n] ?? n)
          .where((n) => !isVehicle || truckAllowed.contains(n))
          .toSet() // deduplicate in case two API names map to the same display name
          .toList()
        ..sort((a, b) => a.compareTo(b));
      return ApiResult.ok(items);
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to load document categories.');
    }
  }

  Future<ApiResult<List<String>>> fetchComplianceDocumentTypes({
    int entityTypeId = 1,
    String? documentCategory,
  }) async {
    try {
      final params = <String, dynamic>{
        'isActive': true,
        'entityTypeId': entityTypeId,
        if (documentCategory != null && documentCategory.isNotEmpty)
          'documentCategory': documentCategory,
      };
      final body = await _api.parseJson(
        () => _api.get(ApiConstants.complianceDocumentTypes, params: params),
        onSuccess: (b) => b,
      );
      final items = ApiParse.listItems(body)
          .map((e) => (e['name'] as String? ?? '').trim())
          .where((n) => n.isNotEmpty)
          .where((n) => n != 'Other')
          .toList()
        ..sort((a, b) => a.compareTo(b));
      items.add('Other');
      return ApiResult.ok(items);
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to load document types.');
    }
  }

  Future<ApiResult<List<LookupOption>>> fetchDrivers({int? companyId}) async {
    final cid = companyId ?? AuthService.instance.selectedCompanyIdInt;
    return _fetchList(
      ApiConstants.drivers,
      params: {'page': 1, 'limit': 200, 'companyId': ?cid},
      companyId: cid?.toString(),
      labelKey: 'fullName',
    );
  }

  Future<ApiResult<List<LookupOption>>> _fetchList(
    String path, {
    Map<String, dynamic>? params,
    String? companyId,
    String labelKey = 'name',
  }) async {
    try {
      final body = await _api.parseJson(
        () => _api.get(path, params: params, companyId: companyId),
        onSuccess: (b) => b,
      );
      final items = ApiParse.listItems(body)
          .map((e) {
            final name =
                (e[labelKey] as String? ??
                        e['name'] as String? ??
                        e['label'] as String? ??
                        '')
                    .trim();
            return LookupOption(
              id: e['id'] as int? ?? 0,
              name: name,
              extra: e['code'] as String?,
            );
          })
          .where((o) => o.id > 0 && o.name.isNotEmpty)
          .toList();
      return ApiResult.ok(items);
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to load options.');
    }
  }
}
