import 'package:rapide_nforce/core/utils/inventory_helpers.dart';
import 'package:rapide_nforce/models/inventory_item_model.dart';

class PartTypeModel {
  const PartTypeModel({
    required this.id,
    required this.name,
    required this.count,
    required this.lowStockTrigger,
    this.totalQuantity,
    this.totalCost,
    this.createdOn,
    this.createdByUsername,
    this.modifiedOn,
    this.modifiedByUsername,
    this.companyName,
  });

  final int id;
  final String name;
  final int count;
  final int lowStockTrigger;
  final int? totalQuantity;
  final double? totalCost;
  final String? createdOn;
  final String? createdByUsername;
  final String? modifiedOn;
  final String? modifiedByUsername;
  final String? companyName;

  StockLevel get stockLevel => InventoryItemModel.computeStockLevel(
        totalQuantity ?? count,
        lowStockTrigger,
      );

  factory PartTypeModel.fromJson(Map<String, dynamic> json) {
    final count = (json['count'] as num?)?.toInt() ?? 0;
    final trigger = (json['lowStockTrigger'] as num?)?.toInt() ??
        (json['low_stock_trigger'] as num?)?.toInt() ??
        0;

    return PartTypeModel(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      count: count,
      lowStockTrigger: trigger,
      totalQuantity: (json['totalQuantity'] as num?)?.toInt(),
      totalCost: (json['totalCost'] as num?)?.toDouble(),
      createdOn: json['createdOn'] as String?,
      createdByUsername: json['createdByUsername'] as String? ??
          (json['creator'] is Map
              ? (json['creator'] as Map)['username']?.toString()
              : null),
      modifiedOn: json['modifiedOn'] as String?,
      modifiedByUsername: json['modifiedByUsername'] as String?,
      companyName: json['company_name'] as String? ??
          json['companyName'] as String?,
    );
  }
}

class PartModel {
  const PartModel({
    required this.id,
    required this.typeId,
    required this.code,
    required this.partTypeName,
    this.quantity,
    this.cost,
    this.totalCost,
    this.invoiceNumber,
    this.invoiceLink,
    this.usedInWorkOrder,
    this.createdOn,
    this.createdByUsername,
    this.lowStockTrigger = 0,
    this.companyName,
  });

  final int id;
  final int typeId;
  final String code;
  final String partTypeName;
  final int? quantity;
  final double? cost;
  final double? totalCost;
  final String? invoiceNumber;
  final String? invoiceLink;
  final int? usedInWorkOrder;
  final String? createdOn;
  final String? createdByUsername;
  final int lowStockTrigger;
  final String? companyName;

  bool get isProtected => InventoryHelpers.isProtectedPart(
        code: code,
        partTypeName: partTypeName,
        invoiceNumber: invoiceNumber,
      );

  bool get isUsedInWorkOrder =>
      usedInWorkOrder != null && usedInWorkOrder! > 0;

  bool get hasInvoiceFile =>
      invoiceLink != null && invoiceLink!.trim().isNotEmpty;

  String get companyDisplay {
    if (isProtected) return 'N/A';
    final c = companyName?.trim();
    return (c != null && c.isNotEmpty) ? c : '-';
  }

  StockLevel get stockLevel {
    final qty = quantity ?? 0;
    return InventoryItemModel.computeStockLevel(qty, lowStockTrigger);
  }

  factory PartModel.fromJson(Map<String, dynamic> json) {
    final partType = json['partType'];
    final typeName = json['part_type_name'] as String? ??
        (partType is Map ? partType['name'] as String? : null) ??
        '';

    return PartModel(
      id: json['id'] as int? ?? 0,
      typeId: (json['typeId'] as num?)?.toInt() ??
          (json['type_id'] as num?)?.toInt() ??
          0,
      code: json['code'] as String? ?? '',
      partTypeName: typeName,
      quantity: (json['quantity'] as num?)?.toInt(),
      cost: (json['cost'] as num?)?.toDouble(),
      totalCost: (json['totalCost'] as num?)?.toDouble(),
      invoiceNumber: json['invoiceNumber'] as String? ??
          json['invoice_number'] as String?,
      invoiceLink: json['invoiceLink'] as String? ?? json['invoice_url'] as String?,
      usedInWorkOrder: (json['usedInWorkOrder'] as num?)?.toInt(),
      createdOn: json['createdOn'] as String?,
      createdByUsername: json['createdByUsername'] as String? ??
          (json['creator'] is Map
              ? (json['creator'] as Map)['username']?.toString()
              : null),
      lowStockTrigger: (json['low_stock_trigger'] as num?)?.toInt() ??
          (partType is Map
              ? (partType['lowStockTrigger'] as num?)?.toInt()
              : null) ??
          0,
      companyName: json['company_name'] as String? ??
          json['companyName'] as String?,
    );
  }
}
