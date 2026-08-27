import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/models/part_models.dart';
import 'package:rapide_nforce/services/inventory_service.dart';

final NumberFormat _currencyFormat =
    NumberFormat.currency(locale: 'en_US', symbol: r'$', decimalDigits: 2);
final NumberFormat _quantityFormat = NumberFormat('#,##0.##', 'en_US');

/// Three stat boxes above the Inventory tabs — Total Stock Value, Units In
/// Stock, and Top Categories by Value — mirroring web's
/// `InventoryValueSummary.tsx`, which reads the existing
/// `/reports/maintenance-analytics` endpoint's `inventory` sub-object rather
/// than a dedicated aggregation (see `InventoryService.fetchInventoryValueSummary`).
class InventoryValueSummaryStrip extends StatefulWidget {
  const InventoryValueSummaryStrip({super.key});

  @override
  State<InventoryValueSummaryStrip> createState() => _InventoryValueSummaryStripState();
}

class _InventoryValueSummaryStripState extends State<InventoryValueSummaryStrip> {
  InventoryValueSummaryModel? _value;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await InventoryService.instance.fetchInventoryValueSummary();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _value = result.data;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
        child: SizedBox(
          height: 74,
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    final value = _value;
    if (value == null) return const SizedBox.shrink();

    final topCategories = value.byCategory.take(3).toList();

    // Reuses the app's existing stat-card color tokens (see WebStatCard on
    // the Dashboard) — "Units In Stock" keeps the same orange the Dashboard
    // already uses for its "Parts In Stock" tile.
    final moneyPalette = _BoxPalette(
      gradientStart: AppColors.statEmeraldBgStart,
      gradientEnd: AppColors.statEmeraldBgEnd,
      borderColor: AppColors.statEmeraldBorder,
      labelColor: AppColors.statEmeraldText,
      valueColor: AppColors.statEmeraldValue,
    );
    final unitsPalette = _BoxPalette(
      gradientStart: AppColors.statOrangeBgStart,
      gradientEnd: AppColors.statOrangeBgEnd,
      borderColor: AppColors.statOrangeBorder,
      labelColor: AppColors.statOrangeText,
      valueColor: AppColors.statOrangeValue,
    );
    final categoriesPalette = _BoxPalette(
      gradientStart: AppColors.statBlueBgStart,
      gradientEnd: AppColors.statBlueBgEnd,
      borderColor: AppColors.statBlueBorder,
      labelColor: AppColors.statBlueText,
      valueColor: AppColors.statBlueValue,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _Box(
                label: 'Total Stock Value',
                palette: moneyPalette,
                child: Text(
                  _currencyFormat.format(value.totalStockValue),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: moneyPalette.valueColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Box(
                label: 'Units In Stock',
                palette: unitsPalette,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _quantityFormat.format(value.totalQuantityInStock),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: unitsPalette.valueColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${value.partCount} part records',
                      style: TextStyle(fontSize: 10, color: unitsPalette.labelColor),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Box(
                label: 'Top Categories by Value',
                palette: categoriesPalette,
                child: topCategories.isEmpty
                    ? Text(
                        'No parts in stock',
                        style: TextStyle(fontSize: 10.5, color: categoriesPalette.labelColor),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final c in topCategories)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      c.category,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: categoriesPalette.valueColor,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _currencyFormat.format(c.value),
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: categoriesPalette.valueColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Gradient/border/text color set for one stat box — mirrors the color
/// groups `WebStatCard` uses on the Dashboard (`AppColors.stat*`).
class _BoxPalette {
  const _BoxPalette({
    required this.gradientStart,
    required this.gradientEnd,
    required this.borderColor,
    required this.labelColor,
    required this.valueColor,
  });

  final Color gradientStart;
  final Color gradientEnd;
  final Color borderColor;
  final Color labelColor;
  final Color valueColor;
}

class _Box extends StatelessWidget {
  const _Box({required this.label, required this.palette, required this.child});

  final String label;
  final _BoxPalette palette;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.gradientStart, palette.gradientEnd],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: palette.borderColor.withValues(alpha: 0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: palette.labelColor,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}
