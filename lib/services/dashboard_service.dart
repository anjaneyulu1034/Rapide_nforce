import 'package:rapide_nforce/core/constants/api_constants.dart';

import 'package:rapide_nforce/core/models/api_result.dart';

import 'package:rapide_nforce/core/utils/api_parse.dart';

import 'package:rapide_nforce/models/dashboard_model.dart';

import 'package:rapide_nforce/models/inventory_item_model.dart';

import 'package:rapide_nforce/models/maintenance_request_model.dart';

import 'package:rapide_nforce/models/work_order_model.dart';

import 'package:rapide_nforce/services/api_client.dart';

import 'package:rapide_nforce/services/auth_service.dart';

import 'package:rapide_nforce/services/maintenance_service.dart';

import 'package:rapide_nforce/services/request_service.dart';

/// Technician dashboard — aggregates same APIs as web `TechnicianDashboard`.

class DashboardService {
  DashboardService._();

  static final DashboardService instance = DashboardService._();

  final ApiClient _api = ApiClient.instance;

  Future<ApiResult<DashboardModel>> fetchDashboard({int? companyId}) async {
    try {
      final cid = companyId ?? AuthService.instance.selectedCompanyIdInt;

      final summaryRes = await MaintenanceService.instance.getWorkOrders(
        limit: 50,
        companyId: cid,
      );

      final workOrders = summaryRes.data?.items ?? [];
      final openCount = workOrders
          .where(
            (w) =>
                w.status == WorkOrderStatus.notStarted ||
                w.status == WorkOrderStatus.inProgress,
          )
          .length;

      final now = DateTime.now();
      final completedMtd = workOrders.where((w) {
        if (w.status != WorkOrderStatus.completed) return false;
        final created = DateTime.tryParse(w.createdOn ?? '');
        return created != null &&
            created.year == now.year &&
            created.month == now.month;
      }).length;

      var partsInStock = 0;

      var inventoryItems = <InventoryItemModel>[];

      try {
        final partTypesRes = await _api.parseJson(
          () => _api.get(
            ApiConstants.partTypes,

            params: {'page': 1, 'limit': 1000, 'companyId': ?cid},

            companyId: cid?.toString(),
          ),

          onSuccess: (body) => body,
        );

        final types = ApiParse.listItems(partTypesRes);

        inventoryItems = types
            .map(InventoryItemModel.fromPartTypeJson)
            .where((i) => i.id > 0)
            .toList();

        partsInStock = inventoryItems.fold<int>(
          0,

          (sum, item) => sum + (item.quantity > 0 ? item.quantity : 0),
        );
      } catch (_) {}

      var pendingRequests = 0;

      try {
        final reqRes = await RequestService.instance.fetchRequests();

        pendingRequests = (reqRes.data ?? [])
            .where(
              (r) => r.approvalStatusEnum != RequestApprovalStatus.approved,
            )
            .length;
      } catch (_) {}

      return ApiResult.ok(
        DashboardModel(
          openWorkOrders: openCount,

          partsInStock: partsInStock,

          pendingRequests: pendingRequests,

          completedMtd: completedMtd,

          recentWorkOrders: workOrders.take(5).toList(),

          inventoryItems: inventoryItems.take(5).toList(),
        ),
      );
    } catch (_) {
      return ApiResult.fail('Failed to load dashboard.');
    }
  }
}
