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

/// A `products` row (`itemCategoryId: 1`) — backs the "Part Type Name"
/// dropdown on Add Part. `products` and `part_types` are two unrelated
/// tables (no FK between them, matched only by name), which is why creating
/// a new part type from Add Part must upsert both — see
/// `InventoryService.createProduct`/`createPartType`.
class ProductModel {
  const ProductModel({
    required this.id,
    required this.name,
    this.itemCategoryId,
    this.companyId,
    this.itemType,
    this.isActive = true,
  });

  final int id;
  final String name;
  final int? itemCategoryId;
  final int? companyId;
  final String? itemType;
  final bool isActive;

  factory ProductModel.fromJson(Map<String, dynamic> json) => ProductModel(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: json['name'] as String? ?? '',
        itemCategoryId: (json['itemCategoryId'] as num?)?.toInt() ??
            (json['item_category_id'] as num?)?.toInt(),
        companyId: (json['companyId'] as num?)?.toInt() ??
            (json['company_id'] as num?)?.toInt(),
        itemType: json['itemType'] as String? ?? json['item_type'] as String?,
        isActive: json['isActive'] as bool? ?? json['is_active'] as bool? ?? true,
      );
}

/// A `part_vendors` row, from `GET /reports/vendors` — note this endpoint
/// does not return address fields, so a selected vendor can only populate
/// `vendorName`/`partVendorId` on Add Part, not Origin Country/State.
class VendorModel {
  const VendorModel({required this.id, required this.name, this.code, this.companyId});

  final int id;
  final String name;
  final String? code;
  final int? companyId;

  factory VendorModel.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] as num?)?.toInt() ?? 0;
    return VendorModel(
      id: id,
      name: json['name'] as String? ??
          json['vendorName'] as String? ??
          json['vendor_name'] as String? ??
          'Vendor $id',
      code: json['code'] as String?,
      companyId: (json['companyId'] as num?)?.toInt() ??
          (json['company_id'] as num?)?.toInt(),
    );
  }
}

/// One row from `GET /parts-tax-rates` — the authoritative tax-rate catalog
/// used for the client-side "Estimated Tax Summary" preview
/// (`PartTaxEstimator`). `aliases` lets a region be matched by an alternate
/// name/spelling in addition to its 2-letter `regionCode`.
class PartTaxRateModel {
  const PartTaxRateModel({
    required this.country,
    required this.regionCode,
    required this.taxType,
    required this.totalRate,
    this.aliases = const [],
    this.combinedMaxRate,
  });

  final String country;
  final String regionCode;
  final String taxType;
  final double totalRate;
  final List<String> aliases;
  final double? combinedMaxRate;

  factory PartTaxRateModel.fromJson(Map<String, dynamic> json) {
    final aliasList = <String>[];
    final rawAliases = json['aliases'];
    if (rawAliases is List) {
      for (final a in rawAliases) {
        if (a is Map && a['alias'] != null) aliasList.add(a['alias'].toString());
      }
    }
    return PartTaxRateModel(
      country: json['country'] as String? ?? '',
      regionCode: json['regionCode'] as String? ?? json['region_code'] as String? ?? '',
      taxType: json['taxType'] as String? ?? json['tax_type'] as String? ?? 'TAX',
      totalRate: (json['totalRate'] as num?)?.toDouble() ??
          (json['total_rate'] as num?)?.toDouble() ??
          0,
      aliases: aliasList,
      combinedMaxRate: (json['combinedMaxRate'] as num?)?.toDouble() ??
          (json['combined_max_rate'] as num?)?.toDouble(),
    );
  }
}

/// One row of the Add Part submit payload — mirrors web's
/// `CreatePartPayload` (`maintenance.service.ts`), posted as a plain JSON
/// array to `POST /maintenance/parts` (see `InventoryService.createParts`).
class PartDraft {
  const PartDraft({
    required this.typeId,
    required this.code,
    required this.quantity,
    required this.destinationCountry,
    required this.destinationState,
    this.cost,
    this.totalCost,
    this.invoiceNumber,
    this.vendorName,
    this.partVendorId,
    this.companyId,
    this.originCountry,
    this.originState,
    this.taxExempt = false,
    this.additionalLocalRate,
    this.labourCost,
  });

  final int typeId;
  final String code;
  final int quantity;
  final String destinationCountry;
  final String destinationState;
  final double? cost;
  final double? totalCost;
  final String? invoiceNumber;
  final String? vendorName;
  final int? partVendorId;
  final int? companyId;
  final String? originCountry;
  final String? originState;
  final bool taxExempt;
  final double? additionalLocalRate;
  final double? labourCost;

  Map<String, dynamic> toJson() => {
        'typeId': typeId,
        'code': code,
        'quantity': quantity,
        if (cost != null) 'cost': cost,
        if (totalCost != null) 'totalCost': totalCost,
        if (invoiceNumber != null && invoiceNumber!.isNotEmpty)
          'invoiceNumber': invoiceNumber,
        if (vendorName != null && vendorName!.isNotEmpty) 'vendorName': vendorName,
        if (partVendorId != null) 'partVendorId': partVendorId,
        if (companyId != null) 'company_id': companyId,
        'destinationCountry': destinationCountry,
        'destinationState': destinationState,
        if (originCountry != null && originCountry!.isNotEmpty)
          'originCountry': originCountry,
        if (originState != null && originState!.isNotEmpty) 'originState': originState,
        'taxExempt': taxExempt,
        if (additionalLocalRate != null) 'additionalLocalRate': additionalLocalRate,
        if (labourCost != null && labourCost! > 0) ...{
          'labourCost': labourCost!.toStringAsFixed(2),
          'labour_cost': labourCost!.toStringAsFixed(2),
        },
      };
}

/// One `inventory.byCategory` entry from `GET /reports/maintenance-analytics`
/// — used by the "Top Categories by Value" stat box above the Inventory
/// tabs (mirrors web's `InventoryValueSummary.tsx`).
class InventoryCategoryValue {
  const InventoryCategoryValue({
    required this.category,
    required this.quantity,
    required this.value,
  });

  final String category;
  final double quantity;
  final double value;

  factory InventoryCategoryValue.fromJson(Map<String, dynamic> json) => InventoryCategoryValue(
        category: json['category'] as String? ?? 'Uncategorised',
        quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
        value: (json['value'] as num?)?.toDouble() ?? 0,
      );
}

/// The `inventory` sub-object of `GET /reports/maintenance-analytics` —
/// backs the three stat boxes (Total Stock Value, Units In Stock, Top
/// Categories by Value) shown above the Inventory tabs, matching web's
/// `InventoryValueSummary.tsx`, which reuses this same analytics endpoint
/// rather than a dedicated aggregation.
class InventoryValueSummaryModel {
  const InventoryValueSummaryModel({
    required this.partCount,
    required this.totalQuantityInStock,
    required this.totalStockValue,
    this.byCategory = const [],
  });

  final int partCount;
  final double totalQuantityInStock;
  final double totalStockValue;
  final List<InventoryCategoryValue> byCategory;

  factory InventoryValueSummaryModel.fromJson(Map<String, dynamic> json) =>
      InventoryValueSummaryModel(
        partCount: (json['partCount'] as num?)?.toInt() ?? 0,
        totalQuantityInStock: (json['totalQuantityInStock'] as num?)?.toDouble() ?? 0,
        totalStockValue: (json['totalStockValue'] as num?)?.toDouble() ?? 0,
        byCategory: (json['byCategory'] as List?)
                ?.whereType<Map>()
                .map((e) => InventoryCategoryValue.fromJson(Map<String, dynamic>.from(e)))
                .toList() ??
            const [],
      );
}

class PartUsedInWorkOrder {
  const PartUsedInWorkOrder({
    required this.id,
    required this.number,
  });

  final int id;
  final String number;

  factory PartUsedInWorkOrder.fromJson(Map<String, dynamic> json) {
    final idVal = (json['id'] as num?)?.toInt() ?? 0;
    final numVal = json['number'] as String? ??
        json['work_order_number'] as String? ??
        json['wo_number'] as String? ??
        (idVal > 0 ? 'WO-${idVal.toString().padLeft(4, '0')}' : '—');
    return PartUsedInWorkOrder(id: idVal, number: numVal);
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
    this.usedInWorkOrders = const [],
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
  final List<PartUsedInWorkOrder> usedInWorkOrders;
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
      usedInWorkOrders.isNotEmpty ||
      (usedInWorkOrder != null && usedInWorkOrder! > 0);

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

    final rawIsUsed = json['isUsed'] ?? json['usedInWorkOrders'] ?? json['used_in_work_orders'];
    final List<PartUsedInWorkOrder> usedInList = [];
    if (rawIsUsed is List) {
      for (final item in rawIsUsed) {
        if (item is Map<String, dynamic>) {
          usedInList.add(PartUsedInWorkOrder.fromJson(item));
        } else if (item is Map) {
          usedInList.add(
            PartUsedInWorkOrder.fromJson(Map<String, dynamic>.from(item)),
          );
        } else if (item is num) {
          final idVal = item.toInt();
          usedInList.add(
            PartUsedInWorkOrder(
              id: idVal,
              number: 'WO-${idVal.toString().padLeft(4, '0')}',
            ),
          );
        }
      }
    }

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
      usedInWorkOrders: usedInList,
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
