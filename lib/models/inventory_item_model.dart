enum StockLevel { inStock, low, outOfStock }

class InventoryItemModel {
  const InventoryItemModel({
    required this.id,
    required this.name,
    required this.code,
    required this.stockLevel,
    required this.quantity,
    this.lowStockTrigger = 0,
  });

  final int id;
  final String name;
  final String code;
  final StockLevel stockLevel;
  final int quantity;
  final int lowStockTrigger;

  factory InventoryItemModel.fromPartTypeJson(Map<String, dynamic> json) {
    final count = (json['count'] as num?)?.toInt() ?? 0;
    final trigger = (json['lowStockTrigger'] as num?)?.toInt() ??
        (json['low_stock_trigger'] as num?)?.toInt() ??
        0;

    return InventoryItemModel(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      code: json['name'] as String? ?? '',
      quantity: count,
      lowStockTrigger: trigger,
      stockLevel: computeStockLevel(count, trigger),
    );
  }

  factory InventoryItemModel.fromPartJson(Map<String, dynamic> json) {
    final qty = (json['quantity'] as num?)?.toInt() ?? 0;
    final typeName = json['part_type_name'] as String? ??
        (json['partType'] is Map
            ? (json['partType'] as Map)['name'] as String?
            : null) ??
        'Part';

    return InventoryItemModel(
      id: json['id'] as int? ?? 0,
      name: typeName,
      code: json['code'] as String? ?? '',
      quantity: qty,
      lowStockTrigger:
          (json['low_stock_trigger'] as num?)?.toInt() ?? 0,
      stockLevel: StockLevel.inStock,
    );
  }

  factory InventoryItemModel.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('count') || json.containsKey('lowStockTrigger')) {
      return InventoryItemModel.fromPartTypeJson(json);
    }
    return InventoryItemModel.fromPartJson(json);
  }

  static StockLevel computeStockLevel(int count, int trigger) {
    if (count <= 0) return StockLevel.outOfStock;
    if (trigger > 0 && count < trigger) return StockLevel.low;
    return StockLevel.inStock;
  }
}

class MaintenanceLogModel {
  const MaintenanceLogModel({
    required this.id,
    required this.subject,
    required this.changedField,
    required this.changedBy,
    required this.changedDate,
    this.logSource,
  });

  final int id;
  final String subject;
  final String changedField;
  final String changedBy;
  final String changedDate;
  final int? logSource;

  factory MaintenanceLogModel.fromJson(Map<String, dynamic> json) {
    return MaintenanceLogModel(
      id: json['id'] as int? ?? 0,
      subject: json['subject'] as String? ?? '',
      changedField: json['changedField'] as String? ?? '',
      changedBy: json['changedBy'] as String? ??
          (json['changer'] is Map
              ? (json['changer'] as Map)['name']?.toString()
              : null) ??
          '',
      changedDate: json['changedDate'] as String? ?? '',
      logSource: (json['logSource'] as num?)?.toInt(),
    );
  }
}
