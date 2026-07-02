import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:rapide_nforce/core/constants/api_constants.dart';
import 'package:rapide_nforce/core/models/api_result.dart';
import 'package:rapide_nforce/core/models/paginated_result.dart';
import 'package:rapide_nforce/models/work_order_model.dart';
import 'package:rapide_nforce/services/api_client.dart';

class MaintenanceService {
  MaintenanceService._();

  static final MaintenanceService instance = MaintenanceService._();

  final ApiClient _api = ApiClient.instance;

  Future<ApiResult<PaginatedResult<WorkOrderModel>>> getWorkOrders({
    int page = 1,
    int limit = 15,
    String? search,
    int? status,
    int? companyId,
    String? sortKey,
    String? sortOrder,
  }) async {
    try {
      final data = await _api.parseJson(
        () => _api.get(
          ApiConstants.workOrders,
          params: {
            'page': page,
            'limit': limit,
            if (search != null && search.isNotEmpty) 'search': search,
            'status': ?status,
            'companyId': ?companyId,
            'sortKey': ?sortKey,
            'sortOrder': ?sortOrder,
          },
          companyId: companyId?.toString(),
        ),
        onSuccess: (body) => body,
      );

      final root = data as Map<String, dynamic>? ?? {};
      final inner = root['data'] as Map<String, dynamic>? ?? root;
      final list = inner['data'] as List<dynamic>? ?? [];
      final pagination =
          inner['pagination'] as Map<String, dynamic>? ?? const {};

      final items = list
          .map((e) => WorkOrderModel.fromSummaryJson(e as Map<String, dynamic>))
          .toList();

      final total = pagination['total'] as int? ?? items.length;
      final currentPage = pagination['page'] as int? ?? page;
      final currentLimit = pagination['limit'] as int? ?? limit;
      final totalPages =
          pagination['totalPages'] as int? ??
          (total == 0 ? 0 : (total / currentLimit).ceil());

      return ApiResult.ok(
        PaginatedResult(
          items: items,
          total: total,
          page: currentPage,
          limit: currentLimit,
          totalPages: totalPages,
        ),
      );
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to load work orders.');
    }
  }

  Future<ApiResult<WorkOrderModel>> getWorkOrderById(int id) async {
    try {
      final data = await _api.parseJson(
        () => _api.get('${ApiConstants.workOrders}/$id'),
        onSuccess: (body) => body,
      );
      final root = data as Map<String, dynamic>? ?? {};
      final detail = root['data'] as Map<String, dynamic>? ?? root;
      return ApiResult.ok(WorkOrderModel.fromDetailJson(detail));
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to load work order.');
    }
  }

  Future<ApiResult<int>> createWorkOrder(WorkOrderFormPayload payload) async {
    try {
      final data = await _api.parseJson(
        () => _api.post(ApiConstants.workOrders, body: payload.toJson()),
        onSuccess: (body) => body,
      );
      final root = data as Map<String, dynamic>? ?? {};
      final inner = root['data'];
      final id = inner is Map
          ? inner['id'] as int? ?? inner['workOrderId'] as int?
          : root['id'] as int?;
      return ApiResult.ok(id ?? 0);
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to create work order.');
    }
  }

  Future<ApiResult<void>> updateWorkOrder(
    int id,
    WorkOrderFormPayload payload,
  ) async {
    try {
      await _api.parseJson(
        () =>
            _api.put('${ApiConstants.workOrders}/$id', body: payload.toJson()),
        onSuccess: (body) => body,
      );
      return ApiResult.ok(null);
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to update work order.');
    }
  }

  Future<ApiResult<void>> deleteWorkOrder(int id) async {
    try {
      await _api.parseJson(
        () => _api.put(
          '${ApiConstants.workOrders}/$id',
          body: {'deleted_at': DateTime.now().toUtc().toIso8601String()},
        ),
        onSuccess: (body) => body,
      );
      return ApiResult.ok(null);
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to delete work order.');
    }
  }

  Future<ApiResult<List<TechnicianSummary>>> getTechnicians({
    int? companyId,
  }) async {
    try {
      final data = await _api.parseJson(
        () => _api.get(
          ApiConstants.techniciansSummary,
          params: {'companyId': ?companyId},
          companyId: companyId?.toString(),
        ),
        onSuccess: (body) => body,
      );
      final root = data as Map<String, dynamic>? ?? {};
      final list = root['data'] as List<dynamic>? ?? [];
      return ApiResult.ok(
        list
            .map((e) => TechnicianSummary.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to load technicians.');
    }
  }

  Future<ApiResult<List<EntityTypeModel>>> getEntityTypes() async {
    try {
      final data = await _api.parseJson(
        () => _api.get(ApiConstants.entityTypes),
        onSuccess: (body) => body,
      );
      final root = data as Map<String, dynamic>? ?? {};
      final list = root['data'] as List<dynamic>? ?? [];
      return ApiResult.ok(
        list
            .map((e) => EntityTypeModel.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to load unit types.');
    }
  }

  Future<ApiResult<List<EntityModel>>> getEntities(int entityTypeId) async {
    try {
      final data = await _api.parseJson(
        () => _api.get(
          ApiConstants.entities,
          params: {'entityTypeId': entityTypeId},
        ),
        onSuccess: (body) => body,
      );
      final root = data as Map<String, dynamic>? ?? {};
      final list = root['data'] as List<dynamic>? ?? [];
      return ApiResult.ok(
        list
            .map((e) => EntityModel.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to load units.');
    }
  }

  Future<ApiResult<({List<PartTypeSummary> types, List<PartSummary> parts})>>
  getPartsSummary({int? companyId}) async {
    try {
      final typesRes = await _api.get(
        ApiConstants.partTypesSummary,
        params: {'companyId': ?companyId},
        companyId: companyId?.toString(),
      );
      final partsRes = await _api.get(
        ApiConstants.parts,
        params: {'limit': 1000, 'companyId': ?companyId},
        companyId: companyId?.toString(),
      );

      final typesBody = jsonDecode(typesRes.body);
      final partsBody = jsonDecode(partsRes.body);

      final typesRoot = typesBody is Map ? typesBody['data'] : typesBody;
      final typesList = typesRoot is List ? typesRoot : <dynamic>[];

      final partsRoot = partsBody is Map ? partsBody['data'] : partsBody;
      final partsListRaw = partsRoot is Map
          ? partsRoot['data'] ?? partsRoot
          : partsRoot;
      final partsList = partsListRaw is List ? partsListRaw : <dynamic>[];

      return ApiResult.ok((
        types: typesList
            .map((e) => PartTypeSummary.fromJson(e as Map<String, dynamic>))
            .toList(),
        parts: partsList
            .map((e) => PartSummary.fromJson(e as Map<String, dynamic>))
            .toList(),
      ));
    } catch (_) {
      return ApiResult.fail('Failed to load parts.');
    }
  }

  Future<ApiResult<String?>> fetchSamsaraOdometer({
    required String unitNumber,
    int? entityTypeId,
    String? vin,
    int? companyId,
  }) async {
    try {
      final data = await _api.parseJson(
        () => _api.get(
          ApiConstants.samsaraOdometer,
          params: {
            'unitNumber': unitNumber,
            'vin': ?vin,
            'entity_type_id': entityTypeId ?? 1,
            'companyId': ?companyId,
          },
          companyId: companyId?.toString(),
        ),
        onSuccess: (body) => body,
      );
      final root = data as Map<String, dynamic>? ?? {};
      final inner = root['data'] as Map<String, dynamic>? ?? root;
      return ApiResult.ok(inner['value']?.toString());
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to fetch odometer.');
    }
  }

  /// Legacy alias used by older maintenance screen.
  Future<ApiResult<List<WorkOrderModel>>> fetchMaintenanceItems() async {
    final result = await getWorkOrders();
    if (!result.isSuccess) {
      return ApiResult.fail(
        result.message ?? 'Failed',
        statusCode: result.statusCode,
      );
    }
    return ApiResult.ok(result.data?.items ?? []);
  }

  Future<ApiResult<List<WorkOrderModel>>> getMaintenanceHistoryByUnit({
    required String unitNumber,
    int limit = 50,
    int? companyId,
  }) async {
    try {
      final data = await _api.parseJson(
        () => _api.get(
          ApiConstants.maintenanceSummary,
          params: {
            'unitnumber': unitNumber,
            'limit': limit,
            'companyId': ?companyId,
          },
          companyId: companyId?.toString(),
        ),
        onSuccess: (body) => body,
      );
      final list =
          (data is List ? data : (data as Map?)?['data'] as List?) ?? [];
      final items = list
          .map((e) => WorkOrderModel.fromJson(e as Map<String, dynamic>))
          .toList();
      return ApiResult.ok(items);
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to load maintenance history.');
    }
  }

  Future<ApiResult<List<PmInspectionCategory>>> getPMInspectionItems({
    required int entityTypeId,
  }) async {
    try {
      final data = await _api.parseJson(
        () => _api.get(
          ApiConstants.pmInspectionItems,
          params: {'entity_type_id': entityTypeId},
        ),
        onSuccess: (body) => body,
      );
      final root = data as Map<String, dynamic>? ?? {};
      final inner = root['data'] ?? root;
      final list = (inner is Map ? inner['categories'] : inner)
              as List<dynamic>? ??
          [];
      return ApiResult.ok(
        list
            .map((e) =>
                PmInspectionCategory.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to load PM inspection checklist.');
    }
  }

  Future<ApiResult<List<MaintenanceIssueSummary>>> getMaintenanceIssues({
    required String unitNumber,
    String? vin,
    int? companyId,
  }) async {
    try {
      final data = await _api.parseJson(
        () => _api.get(
          ApiConstants.maintenanceIssues,
          params: {
            'vehicleNumber': unitNumber,
            'vin': ?vin,
            'companyId': ?companyId,
          },
          companyId: companyId?.toString(),
        ),
        onSuccess: (body) => body,
      );
      final root = data as Map<String, dynamic>? ?? {};
      final rawList = root['data'] ?? (data is List ? data : const []);
      final list = rawList is List ? rawList : const <dynamic>[];
      return ApiResult.ok(
        list
            .map((e) =>
                MaintenanceIssueSummary.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to load linked maintenance issues.');
    }
  }

  Future<ApiResult<List<WorkOrderAttachment>>> uploadWorkOrderAttachments({
    required int workOrderId,
    required List<String> filePaths,
    String? companyId,
  }) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('dummy'));
      for (final path in filePaths) {
        request.files.add(
          await http.MultipartFile.fromPath('attachments[]', path),
        );
      }
      final body = await _api.parseJson(
        () => _api.postMultipart(
          '${ApiConstants.workOrders}/$workOrderId/attachments',
          request,
          companyId: companyId,
        ),
        onSuccess: (b) => b,
      );
      final root = body as Map<String, dynamic>? ?? {};
      final inner = root['data'] ?? root;
      final list = (inner is Map ? inner['attachments'] : inner)
              as List<dynamic>? ??
          [];
      return ApiResult.ok(WorkOrderAttachment.listFromDynamic(list));
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to upload attachment.');
    }
  }

  Future<ApiResult<List<WorkOrderLabourEntry>>> getLabourEntries({
    required int workOrderId,
  }) async {
    try {
      final data = await _api.parseJson(
        () => _api.get(
          ApiConstants.workOrderLabourEntries,
          params: {'workOrderId': workOrderId},
        ),
        onSuccess: (body) => body,
      );
      final root = data as Map<String, dynamic>? ?? {};
      final rawList = root['data'] ?? (data is List ? data : const []);
      final list = rawList is List ? rawList : const <dynamic>[];
      return ApiResult.ok(
        list
            .map((e) =>
                WorkOrderLabourEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to load labour entries.');
    }
  }

  Future<ApiResult<WorkOrderLabourEntry>> startLabourTimer({
    required int workOrderId,
    int? workOrderPartId,
  }) async {
    try {
      final data = await _api.parseJson(
        () => _api.post(
          '${ApiConstants.workOrderLabourTimerLogs}/start',
          body: {
            'workOrderId': workOrderId,
            'workOrderPartId': ?workOrderPartId,
          },
        ),
        onSuccess: (body) => body,
      );
      final root = data as Map<String, dynamic>? ?? {};
      final inner = root['data'] as Map<String, dynamic>? ?? root;
      return ApiResult.ok(WorkOrderLabourEntry.fromJson(inner));
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to start timer.');
    }
  }

  Future<ApiResult<WorkOrderLabourEntry>> stopLabourTimer({
    required int timerLogId,
  }) async {
    try {
      final data = await _api.parseJson(
        () => _api.post(
          '${ApiConstants.workOrderLabourTimerLogs}/stop',
          body: {'id': timerLogId},
        ),
        onSuccess: (body) => body,
      );
      final root = data as Map<String, dynamic>? ?? {};
      final inner = root['data'] as Map<String, dynamic>? ?? root;
      return ApiResult.ok(WorkOrderLabourEntry.fromJson(inner));
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to stop timer.');
    }
  }
}
