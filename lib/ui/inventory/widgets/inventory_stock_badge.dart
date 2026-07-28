import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/utils/app_toast.dart';
import 'package:rapide_nforce/models/inventory_item_model.dart';
import 'package:rapide_nforce/ui/widgets/status_badge.dart';
import 'package:url_launcher/url_launcher.dart';

BadgeTone stockLevelTone(StockLevel level) {
  return switch (level) {
    StockLevel.inStock => BadgeTone.success,
    StockLevel.low => BadgeTone.warning,
    StockLevel.outOfStock => BadgeTone.danger,
  };
}

String stockLevelLabel(StockLevel level) {
  return switch (level) {
    StockLevel.inStock => 'In Stock',
    StockLevel.low => 'Low Stock',
    StockLevel.outOfStock => 'Out of Stock',
  };
}

/// Stock-level pill — routed through [MiniStatusBadge] so it uses the same
/// color system as the Work Orders / Power Unit card badges.
class InventoryStockBadge extends StatelessWidget {
  const InventoryStockBadge({
    super.key,
    required this.level,
    this.compact = false,
  });

  final StockLevel level;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return MiniStatusBadge(
      label: stockLevelLabel(level),
      tone: stockLevelTone(level),
      dense: compact,
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

/// Opens a part invoice file (image/PDF) in the device's default external
/// viewer/browser — mirrors the web app's "View Invoice" link behaviour.
Future<void> openInventoryInvoiceLink(String? url) async {
  final trimmed = url?.trim();
  if (trimmed == null || trimmed.isEmpty) return;
  final uri = Uri.tryParse(trimmed);
  if (uri == null) {
    AppToast.showError('Invalid invoice link');
    return;
  }
  try {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      AppToast.showError('Unable to open invoice');
    }
  } catch (_) {
    AppToast.showError('Unable to open invoice');
  }
}
