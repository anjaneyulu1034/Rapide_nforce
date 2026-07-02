import 'package:rapide_nforce/models/inventory_item_model.dart';
import 'package:rapide_nforce/models/work_order_model.dart';

class DashboardModel {
  const DashboardModel({
    required this.openWorkOrders,
    required this.partsInStock,
    required this.pendingRequests,
    required this.completedMtd,
    required this.recentWorkOrders,
    required this.inventoryItems,
  });

  final int openWorkOrders;
  final int partsInStock;
  final int pendingRequests;
  final int completedMtd;
  final List<WorkOrderModel> recentWorkOrders;
  final List<InventoryItemModel> inventoryItems;

  factory DashboardModel.fromJson(Map<String, dynamic> json) {
    return DashboardModel(
      openWorkOrders: json['open_work_orders'] as int? ?? 0,
      partsInStock: json['parts_in_stock'] as int? ?? 0,
      pendingRequests: json['pending_requests'] as int? ?? 0,
      completedMtd: json['completed_mtd'] as int? ?? 0,
      recentWorkOrders: (json['recent_work_orders'] as List<dynamic>?)
              ?.map((e) => WorkOrderModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      inventoryItems: (json['inventory_items'] as List<dynamic>?)
              ?.map(
                (e) => InventoryItemModel.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
    );
  }
}
