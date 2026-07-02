import 'package:rapide_nforce/core/constants/api_constants.dart';
import 'package:rapide_nforce/core/models/api_result.dart';
import 'package:rapide_nforce/core/models/paginated_result.dart';
import 'package:rapide_nforce/core/utils/api_parse.dart';
import 'package:rapide_nforce/models/inventory_item_model.dart';
import 'package:rapide_nforce/models/part_models.dart';
import 'package:rapide_nforce/services/api_client.dart';
import 'package:rapide_nforce/services/auth_service.dart';

class InventoryService {
  InventoryService._();

  static final InventoryService instance = InventoryService._();
  final ApiClient _api = ApiClient.instance;

  int? get _companyId => AuthService.instance.selectedCompanyIdInt;

  Future<ApiResult<PaginatedResult<PartTypeModel>>> fetchPartTypes({
    int page = 1,
    int limit = 15,
    String? search,
    int? companyId,
    String? sortKey,
    String? sortOrder,
  }) async {
    final cid = companyId ?? _companyId;
    try {
      final body = await _api.parseJson(
        () => _api.get(
          ApiConstants.partTypes,
          params: {
            'page': page,
            'limit': limit,
            if (search != null && search.isNotEmpty) 'search': search,
            'companyId': ?cid,
            'sortKey': ?sortKey,
            'sortOrder': ?sortOrder,
          },
          companyId: cid?.toString(),
        ),
        onSuccess: (b) => b,
      );

      return ApiResult.ok(_parsePaginated(body, PartTypeModel.fromJson));
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to load part types.');
    }
  }

  Future<ApiResult<List<InventoryItemModel>>> fetchPartTypesLegacy({
    int? companyId,
  }) async {
    final result = await fetchPartTypes(
      page: 1,
      limit: 1000,
      companyId: companyId,
    );
    if (!result.isSuccess || result.data == null) {
      return ApiResult.fail(result.message ?? 'Failed to load inventory.');
    }
    final items = result.data!.items
        .where((t) => t.id > 0)
        .map(
          (t) => InventoryItemModel(
            id: t.id,
            name: t.name,
            code: t.name,
            quantity: t.count,
            lowStockTrigger: t.lowStockTrigger,
            stockLevel: t.stockLevel,
          ),
        )
        .toList();
    return ApiResult.ok(items);
  }

  Future<ApiResult<PartTypeModel>> createPartType({
    required String name,
    required int lowStockTrigger,
    int? companyId,
  }) async {
    final cid = companyId ?? _companyId;
    try {
      final body = await _api.parseJson(
        () => _api.post(
          ApiConstants.partTypes,
          body: {
            'name': name,
            'low_stock_trigger': lowStockTrigger,
            'company_id': ?cid,
          },
          companyId: cid?.toString(),
        ),
        onSuccess: (b) => b,
      );
      final data = ApiParse.unwrapData(body);
      if (data is Map) {
        return ApiResult.ok(
          PartTypeModel.fromJson(Map<String, dynamic>.from(data)),
        );
      }
      return ApiResult.ok(
        PartTypeModel(
          id: 0,
          name: name,
          count: 0,
          lowStockTrigger: lowStockTrigger,
        ),
      );
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to create part type.');
    }
  }

  Future<ApiResult<void>> updatePartType({
    required int id,
    required String name,
    required int lowStockTrigger,
    int? companyId,
  }) async {
    final cid = companyId ?? _companyId;
    try {
      await _api.parseJson(
        () => _api.put(
          '${ApiConstants.partTypes}/$id',
          body: {
            'name': name,
            'low_stock_trigger': lowStockTrigger,
            'company_id': ?cid,
          },
          companyId: cid?.toString(),
        ),
        onSuccess: (b) => b,
      );
      return ApiResult.ok(null);
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to update part type.');
    }
  }

  Future<ApiResult<void>> deletePartType(int id) async {
    final cid = _companyId;
    try {
      await _api.parseJson(
        () => _api.delete(
          '${ApiConstants.partTypes}/$id',
          companyId: cid?.toString(),
        ),
        onSuccess: (b) => b,
      );
      return ApiResult.ok(null);
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to delete part type.');
    }
  }

  Future<ApiResult<PaginatedResult<PartModel>>> fetchParts({
    int page = 1,
    int limit = 15,
    String? search,
    int? companyId,
    int? typeId,
    String? sortKey,
    String? sortOrder,
  }) async {
    final cid = companyId ?? _companyId;
    try {
      final body = await _api.parseJson(
        () => _api.get(
          ApiConstants.parts,
          params: {
            'page': page,
            'limit': limit,
            if (search != null && search.isNotEmpty) 'search': search,
            'companyId': ?cid,
            'typeId': ?typeId,
            'sortKey': ?sortKey,
            'sortOrder': ?sortOrder,
          },
          companyId: cid?.toString(),
        ),
        onSuccess: (b) => b,
      );

      return ApiResult.ok(_parsePaginated(body, PartModel.fromJson));
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to load parts.');
    }
  }

  Future<ApiResult<PartModel>> createPart({
    required int typeId,
    required String code,
    int? quantity,
    double? cost,
    double? totalCost,
    String? invoiceNumber,
    int? companyId,
  }) async {
    final cid = companyId ?? _companyId;
    try {
      final body = await _api.parseJson(
        () => _api.post(
          ApiConstants.parts,
          body: {
            'typeId': typeId,
            'code': code,
            'quantity': ?quantity,
            'cost': ?cost,
            'totalCost': ?totalCost,
            if (invoiceNumber != null && invoiceNumber.isNotEmpty)
              'invoiceNumber': invoiceNumber,
            'company_id': ?cid,
          },
          companyId: cid?.toString(),
        ),
        onSuccess: (b) => b,
      );
      final data = ApiParse.unwrapData(body);
      if (data is Map) {
        return ApiResult.ok(
          PartModel.fromJson(Map<String, dynamic>.from(data)),
        );
      }
      return ApiResult.fail('Invalid response from server.');
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to create part.');
    }
  }

  Future<ApiResult<PartModel>> updatePart({
    required int id,
    required int typeId,
    required String code,
    int? quantity,
    double? cost,
    double? totalCost,
    String? invoiceNumber,
    int? companyId,
  }) async {
    final cid = companyId ?? _companyId;
    try {
      final body = await _api.parseJson(
        () => _api.put(
          '${ApiConstants.parts}/$id',
          body: {
            'typeId': typeId,
            'code': code,
            'quantity': ?quantity,
            'cost': ?cost,
            'totalCost': ?totalCost,
            'invoiceNumber': ?invoiceNumber,
            'company_id': ?cid,
          },
          companyId: cid?.toString(),
        ),
        onSuccess: (b) => b,
      );
      final data = ApiParse.unwrapData(body);
      if (data is Map) {
        return ApiResult.ok(
          PartModel.fromJson(Map<String, dynamic>.from(data)),
        );
      }
      return ApiResult.fail('Invalid response from server.');
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to update part.');
    }
  }

  Future<ApiResult<void>> deletePart(int id) async {
    final cid = _companyId;
    try {
      await _api.parseJson(
        () => _api.delete(
          '${ApiConstants.parts}/$id',
          companyId: cid?.toString(),
        ),
        onSuccess: (b) => b,
      );
      return ApiResult.ok(null);
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to delete part.');
    }
  }

  Future<ApiResult<List<MaintenanceLogModel>>> fetchLogs({
    int page = 1,
    int limit = 50,
    int? companyId,
    String? search,
    String? startDate,
    String? endDate,
  }) async {
    final cid = companyId ?? _companyId;
    try {
      final body = await _api.parseJson(
        () => _api.get(
          ApiConstants.maintenanceLogs,
          params: {
            'page': page,
            'limit': limit,
            'companyId': ?cid,
            if (search != null && search.isNotEmpty) 'search': search,
            if (startDate != null && startDate.isNotEmpty)
              'startDate': startDate,
            if (endDate != null && endDate.isNotEmpty) 'endDate': endDate,
          },
          companyId: cid?.toString(),
        ),
        onSuccess: (b) => b,
      );

      final items = ApiParse.listItems(
        body,
      ).map(MaintenanceLogModel.fromJson).toList();
      return ApiResult.ok(items);
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to load logs.');
    }
  }

  PaginatedResult<T> _parsePaginated<T>(
    dynamic body,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final items = ApiParse.listItems(body).map(fromJson).where((item) {
      if (item is PartTypeModel) return item.id > 0;
      if (item is PartModel) return item.id > 0;
      return true;
    }).toList();

    final pagination = ApiParse.pagination(body);
    final total = pagination['total'] as int? ?? items.length;
    final page = pagination['page'] as int? ?? 1;
    final limit = pagination['limit'] as int? ?? items.length;
    final totalPages =
        pagination['totalPages'] as int? ??
        (total == 0 ? 0 : (total / (limit == 0 ? 1 : limit)).ceil());

    return PaginatedResult(
      items: items,
      total: total,
      page: page,
      limit: limit,
      totalPages: totalPages,
    );
  }
}
