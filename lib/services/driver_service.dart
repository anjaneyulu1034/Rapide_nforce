import 'package:rapide_nforce/core/constants/api_constants.dart';
import 'package:rapide_nforce/core/models/api_result.dart';
import 'package:rapide_nforce/core/models/paginated_result.dart';
import 'package:rapide_nforce/core/utils/api_parse.dart';
import 'package:rapide_nforce/models/driver_model.dart';
import 'package:rapide_nforce/services/api_client.dart';
import 'package:rapide_nforce/services/auth_service.dart';

class DriverService {
  DriverService._();

  static final DriverService instance = DriverService._();
  final ApiClient _api = ApiClient.instance;

  Future<ApiResult<PaginatedResult<DriverModel>>> fetchDrivers({
    int page = 1,
    int limit = 10,
    String? search,
    int? companyId,
  }) async {
    final cid = companyId ?? AuthService.instance.selectedCompanyIdInt;
    try {
      final body = await _api.parseJson(
        () => _api.get(
          search != null && search.trim().isNotEmpty
              ? '/drivers/search'
              : ApiConstants.drivers,
          params: {
            'page': page,
            'limit': limit,
            if (search != null && search.trim().isNotEmpty) 'q': search,
            'companyId': ?cid,
          },
          companyId: cid?.toString(),
        ),
        onSuccess: (b) => b,
      );

      final items = ApiParse.listItems(body)
          .map(DriverModel.fromJson)
          .toList();
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
      return ApiResult.fail('Failed to load drivers.');
    }
  }

  Future<ApiResult<DriverModel>> fetchDriverById(int id) async {
    try {
      final body = await _api.parseJson(
        () => _api.get('${ApiConstants.drivers}/$id'),
        onSuccess: (b) => b,
      );
      final data = ApiParse.asMap(ApiParse.unwrapData(body));
      if (data == null) {
        return ApiResult.fail('Invalid driver response.');
      }
      return ApiResult.ok(DriverModel.fromJson(data));
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to load driver.');
    }
  }

  Future<ApiResult<DriverModel>> createDriver(Map<String, dynamic> payload) async {
    try {
      final body = await _api.parseJson(
        () => _api.post('/drivers/createDriver', body: payload),
        onSuccess: (b) => b,
      );
      final data = ApiParse.asMap(ApiParse.unwrapData(body)) ?? {};
      return ApiResult.ok(DriverModel.fromJson(data));
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to create driver.');
    }
  }

  Future<ApiResult<DriverModel>> updateDriver(int id, Map<String, dynamic> payload) async {
    try {
      final body = await _api.parseJson(
        () => _api.put('${ApiConstants.drivers}/$id', body: payload),
        onSuccess: (b) => b,
      );
      final data = ApiParse.asMap(ApiParse.unwrapData(body)) ?? {};
      return ApiResult.ok(DriverModel.fromJson(data));
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to update driver.');
    }
  }

  Future<ApiResult<void>> deleteDriver(int id) async {
    try {
      await _api.parseJson(
        () => _api.delete('${ApiConstants.drivers}/$id'),
        onSuccess: (b) => b,
      );
      return ApiResult.ok(null);
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to delete driver.');
    }
  }
}
