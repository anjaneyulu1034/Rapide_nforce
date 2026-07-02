import 'package:flutter/material.dart';
import 'package:rapide_nforce/models/inventory_item_model.dart';

class InventoryStockBadge extends StatelessWidget {
  const InventoryStockBadge({super.key, required this.level, this.compact = false});

  final StockLevel level;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (level) {
      StockLevel.inStock => ('In Stock', const Color(0xFFDCFCE7), const Color(0xFF008236)),
      StockLevel.low => ('Low Stock', const Color(0xFFFEF3C7), const Color(0xFFEA580C)),
      StockLevel.outOfStock => ('Out of Stock', const Color(0xFFFEE2E2), const Color(0xFFDC2626)),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: compact ? 11 : 12,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

String formatInventoryMoney(double? value) {
  if (value == null) return '—';
  return '\$${value.toStringAsFixed(2)}';
}

String formatInventoryDate(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  try {
    final d = DateTime.parse(iso);
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$m-$day-${d.year}';
  } catch (_) {
    return iso;
  }
}
