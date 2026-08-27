import 'package:http/http.dart' as http;
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

  /// Stat-box data above the Inventory tabs (Total Stock Value / Units In
  /// Stock / Top Categories by Value) — reads the existing
  /// `GET /reports/maintenance-analytics` endpoint's `inventory` sub-object,
  /// matching web's `InventoryValueSummary.tsx`, which reuses this same
  /// analytics endpoint rather than a dedicated aggregation.
  Future<ApiResult<InventoryValueSummaryModel>> fetchInventoryValueSummary({
    int? companyId,
  }) async {
    final cid = companyId ?? _companyId;
    if (cid == null) return ApiResult.fail('No company selected.');
    try {
      final body = await _api.parseJson(
        () => _api.get(
          ApiConstants.reportsMaintenanceAnalytics,
          params: {'companyId': cid, 'days': 30, 'topN': 5},
          companyId: cid.toString(),
        ),
        onSuccess: (b) => b,
      );
      final data = ApiParse.asMap(ApiParse.unwrapData(body));
      final inventory = ApiParse.asMap(data?['inventory']);
      if (inventory == null) return ApiResult.fail('No inventory summary available.');
      return ApiResult.ok(InventoryValueSummaryModel.fromJson(inventory));
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to load inventory summary.');
    }
  }

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

  /// Creates the `products` row backing web's "Part Type Name" dropdown on
  /// the Add Part form (`AddPartTypeModal.tsx`) — `products` and
  /// `part_types` are two unrelated tables (no FK between them), matched
  /// only by name client-side, so a part type created without this call is
  /// invisible in that dropdown even though it appears fine in the Parts
  /// Overview grid (which reads `part_types` directly). Tolerates a
  /// duplicate-name conflict the same way web does — the type still gets
  /// created either way.
  Future<void> _ensureProductForPartType({
    required String name,
    int? companyId,
  }) async {
    try {
      await _api.parseJson(
        () => _api.post(
          ApiConstants.products,
          body: {
            'itemCategoryId': 1,
            'name': name,
            'itemType': 'NON_INVENTORY',
            'isActive': true,
            'companyId': ?companyId,
            'company_id': ?companyId,
          },
          companyId: companyId?.toString(),
        ),
        onSuccess: (b) => b,
      );
    } on ApiClientException catch (e) {
      if (!e.message.toLowerCase().contains('already exists')) rethrow;
    }
  }

  /// Public counterpart of [_ensureProductForPartType] — creates (or, on a
  /// duplicate-name conflict, resolves) the `products` row backing the "Part
  /// Type Name" dropdown on Add Part. Used both by the row-level "+ Add
  /// Part Type" action and by Add Part's submit step when a row was typed
  /// as a free-text new type name.
  Future<ApiResult<ProductModel>> createProduct({
    required String name,
    int? companyId,
  }) async {
    final cid = companyId ?? _companyId;
    try {
      final body = await _api.parseJson(
        () => _api.post(
          ApiConstants.products,
          body: {
            'itemCategoryId': 1,
            'name': name,
            'itemType': 'NON_INVENTORY',
            'isActive': true,
            'companyId': ?cid,
            'company_id': ?cid,
          },
          companyId: cid?.toString(),
        ),
        onSuccess: (b) => b,
      );
      final data = ApiParse.unwrapData(body);
      if (data is Map) {
        return ApiResult.ok(ProductModel.fromJson(Map<String, dynamic>.from(data)));
      }
      return ApiResult.ok(ProductModel(id: 0, name: name));
    } on ApiClientException catch (e) {
      if (e.message.toLowerCase().contains('already exists')) {
        final existing = await fetchProducts(companyId: cid, search: name);
        final match = existing.data
            ?.where((p) => p.name.toLowerCase() == name.toLowerCase())
            .firstOrNull;
        if (match != null) return ApiResult.ok(match);
      }
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to create part type.');
    }
  }

  /// "Part Type Name" dropdown source on Add Part — `GET /products` scoped
  /// to `itemCategoryId: 1` (parts), matching web's `maintenanceService.getProducts`.
  Future<ApiResult<List<ProductModel>>> fetchProducts({
    int? companyId,
    String? search,
  }) async {
    final cid = companyId ?? _companyId;
    try {
      final body = await _api.parseJson(
        () => _api.get(
          ApiConstants.products,
          params: {
            'itemCategoryId': 1,
            'all': true,
            'companyId': ?cid,
            if (search != null && search.isNotEmpty) 'search': search,
          },
          companyId: cid?.toString(),
        ),
        onSuccess: (b) => b,
      );
      final items = ApiParse.listItems(body).map(ProductModel.fromJson).toList();
      return ApiResult.ok(items);
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to load part types.');
    }
  }

  /// Vendor dropdown source on Add Part — `GET /reports/vendors`. Note: the
  /// response has no address fields, so a selected vendor can only set
  /// `vendorName`/`partVendorId`, not Origin Country/State.
  Future<ApiResult<List<VendorModel>>> fetchVendors({int? companyId}) async {
    final cid = companyId ?? _companyId;
    try {
      final body = await _api.parseJson(
        () => _api.get(
          ApiConstants.reportsVendors,
          params: {'companyId': ?cid},
          companyId: cid?.toString(),
        ),
        onSuccess: (b) => b,
      );
      final items = ApiParse.listItems(body).map(VendorModel.fromJson).toList();
      return ApiResult.ok(items);
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to load vendors.');
    }
  }

  /// Tax-rate catalog backing the "Estimated Tax Summary" preview on Add
  /// Part (`PartTaxEstimator`) — `GET /parts-tax-rates`.
  Future<ApiResult<List<PartTaxRateModel>>> fetchPartTaxRates() async {
    try {
      final body = await _api.parseJson(
        () => _api.get(
          ApiConstants.partsTaxRates,
          params: {'isActive': true, 'includeAliases': true},
        ),
        onSuccess: (b) => b,
      );
      final items = ApiParse.listItems(body).map(PartTaxRateModel.fromJson).toList();
      return ApiResult.ok(items);
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to load tax rates.');
    }
  }

  Future<ApiResult<PartTypeModel>> createPartType({
    required String name,
    required int lowStockTrigger,
    int? companyId,
  }) async {
    final cid = companyId ?? _companyId;
    try {
      await _ensureProductForPartType(name: name, companyId: cid);
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
    String? invoiceFilePath,
  }) async {
    final cid = companyId ?? _companyId;
    try {
      dynamic body;
      if (invoiceFilePath != null && invoiceFilePath.isNotEmpty) {
        final request = http.MultipartRequest('POST', Uri.parse('dummy'));
        request.fields['typeId'] = '$typeId';
        request.fields['code'] = code;
        if (quantity != null) request.fields['quantity'] = '$quantity';
        if (cost != null) request.fields['cost'] = '$cost';
        if (totalCost != null) request.fields['totalCost'] = '$totalCost';
        if (invoiceNumber != null && invoiceNumber.isNotEmpty) {
          request.fields['invoiceNumber'] = invoiceNumber;
        }
        if (cid != null) request.fields['company_id'] = '$cid';
        request.files.add(
          await http.MultipartFile.fromPath('file', invoiceFilePath),
        );
        request.files.add(
          await http.MultipartFile.fromPath('invoice', invoiceFilePath),
        );
        request.files.add(
          await http.MultipartFile.fromPath('invoiceFile', invoiceFilePath),
        );
        body = await _api.parseJson(
          () => _api.postMultipart(
            ApiConstants.parts,
            request,
            companyId: cid?.toString(),
          ),
          onSuccess: (b) => b,
        );
      } else {
        body = await _api.parseJson(
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
      }
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
    String? invoiceFilePath,
  }) async {
    final cid = companyId ?? _companyId;
    try {
      dynamic body;
      if (invoiceFilePath != null && invoiceFilePath.isNotEmpty) {
        final request = http.MultipartRequest('PUT', Uri.parse('dummy'));
        request.fields['typeId'] = '$typeId';
        request.fields['code'] = code;
        if (quantity != null) request.fields['quantity'] = '$quantity';
        if (cost != null) request.fields['cost'] = '$cost';
        if (totalCost != null) request.fields['totalCost'] = '$totalCost';
        if (invoiceNumber != null) {
          request.fields['invoiceNumber'] = invoiceNumber;
        }
        if (cid != null) request.fields['company_id'] = '$cid';
        request.files.add(
          await http.MultipartFile.fromPath('file', invoiceFilePath),
        );
        request.files.add(
          await http.MultipartFile.fromPath('invoice', invoiceFilePath),
        );
        request.files.add(
          await http.MultipartFile.fromPath('invoiceFile', invoiceFilePath),
        );
        body = await _api.parseJson(
          () => _api.postMultipart(
            '${ApiConstants.parts}/$id',
            request,
            companyId: cid?.toString(),
          ),
          onSuccess: (b) => b,
        );
      } else {
        body = await _api.parseJson(
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
      }
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

  /// Batch "Add Part" submit — posts one or more [PartDraft] rows to
  /// `POST /maintenance/parts` in a single request (a plain JSON array,
  /// matching web's `maintenanceService.createPart(payload: CreatePartPayload[])`),
  /// or one multipart request per row when a raw invoice file is still held
  /// locally (mirrors the existing [createPart]/[updatePart] file-attach
  /// path). Returns the number of parts created/updated.
  Future<ApiResult<int>> createParts({
    required List<PartDraft> parts,
    String? invoiceFilePath,
    int? invoiceFileUploadId,
    int? companyId,
  }) async {
    if (parts.isEmpty) return ApiResult.fail('No parts to submit.');
    final cid = companyId ?? _companyId;
    try {
      if (invoiceFilePath != null && invoiceFilePath.isNotEmpty) {
        var created = 0;
        for (final part in parts) {
          final request = http.MultipartRequest('POST', Uri.parse('dummy'));
          part.toJson().forEach((key, value) {
            request.fields[key] = value.toString();
          });
          request.files.add(
            await http.MultipartFile.fromPath('file', invoiceFilePath),
          );
          request.files.add(
            await http.MultipartFile.fromPath('invoice', invoiceFilePath),
          );
          request.files.add(
            await http.MultipartFile.fromPath('invoiceFile', invoiceFilePath),
          );
          await _api.parseJson(
            () => _api.postMultipart(
              ApiConstants.parts,
              request,
              companyId: cid?.toString(),
            ),
            onSuccess: (b) => b,
          );
          created++;
        }
        return ApiResult.ok(created);
      }

      final payload = parts.map((p) {
        final json = p.toJson();
        if (invoiceFileUploadId != null) {
          json['invoiceFileUploadId'] = invoiceFileUploadId;
        }
        return json;
      }).toList();

      final body = await _api.parseJson(
        () => _api.post(ApiConstants.parts, body: payload, companyId: cid?.toString()),
        onSuccess: (b) => b,
      );
      final data = ApiParse.unwrapData(body);
      final count = data is List ? data.length : parts.length;
      return ApiResult.ok(count);
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to create parts.');
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
