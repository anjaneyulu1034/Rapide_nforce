import 'package:rapide_nforce/core/constants/api_constants.dart';
import 'package:rapide_nforce/core/models/api_result.dart';
import 'package:rapide_nforce/core/utils/api_parse.dart';
import 'package:rapide_nforce/models/company_model.dart';
import 'package:rapide_nforce/services/api_client.dart';

class CompanyService {
  CompanyService._();

  static final CompanyService instance = CompanyService._();
  final ApiClient _api = ApiClient.instance;

  Future<ApiResult<List<CompanyModel>>> fetchCompanies({
    int page = 1,
    int limit = 200,
  }) async {
    try {
      final body = await _api.parseJson(
        () => _api.get(
          ApiConstants.companies,
          params: {'page': page, 'limit': limit},
        ),
        onSuccess: (b) => b,
      );

      final items = ApiParse.listItems(body)
          .map(CompanyModel.fromJson)
          .where((c) => c.id > 0 && c.name.isNotEmpty)
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      return ApiResult.ok(items);
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to load companies.');
    }
  }

  Future<ApiResult<CompanyModel>> fetchCompanyById(int id) async {
    try {
      final body = await _api.parseJson(
        () => _api.get('${ApiConstants.companies}/$id'),
        onSuccess: (b) => b,
      );
      final data = ApiParse.unwrapData(body);
      final map = ApiParse.asMap(data) ?? ApiParse.asMap(body) ?? {};
      final company = CompanyModel.fromJson(map);
      if (company.id <= 0) {
        return ApiResult.fail('Company not found.');
      }
      return ApiResult.ok(company);
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to load company.');
    }
  }
}
