import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/models/inventory_item_model.dart';
import 'package:rapide_nforce/models/work_order_model.dart';
import 'package:rapide_nforce/ui/widgets/web_ui.dart';

/// The "Enhanced Analytics" section of web's `TechnicianDashboard.tsx` —
/// Work Order Status Distribution, Work Activity Overview, Parts Inventory
/// Status and (Individual/Team) Performance Metrics. All four are ported
/// from web's hand-rolled SVG charts to plain Flutter widgets (no chart
/// library on either side), and all numbers are derived client-side from
/// the same [WorkOrderModel]/[InventoryItemModel] lists the rest of the
/// dashboard already fetches — mirrors web's client-side aggregation
/// exactly, quirks included (e.g. "Completion Rate (MTD)" is actually
/// completed/total across the whole fetched batch, not month-filtered;
/// "Total Active WOs" is the fetched batch size, not just open ones).
class WorkOrderStatusBreakdown {
  const WorkOrderStatusBreakdown({
    required this.notStarted,
    required this.inProgress,
    required this.onHold,
    required this.completed,
  });

  factory WorkOrderStatusBreakdown.from(List<WorkOrderModel> workOrders) {
    return WorkOrderStatusBreakdown(
      notStarted: workOrders
          .where((w) => w.status == WorkOrderStatus.notStarted)
          .length,
      inProgress: workOrders
          .where((w) => w.status == WorkOrderStatus.inProgress)
          .length,
      onHold:
          workOrders.where((w) => w.status == WorkOrderStatus.onHold).length,
      completed: workOrders
          .where((w) => w.status == WorkOrderStatus.completed)
          .length,
    );
  }

  final int notStarted;
  final int inProgress;
  final int onHold;
  final int completed;

  int get total => notStarted + inProgress + onHold + completed;
}

// ---------------------------------------------------------------------------
// Work Order Status Distribution
// ---------------------------------------------------------------------------

class WorkOrderStatusDistributionCard extends StatelessWidget {
  const WorkOrderStatusDistributionCard({super.key, required this.workOrders});

  final List<WorkOrderModel> workOrders;

  static List<(String, Color)> get _statuses => [
        ('Not Started', AppColors.statBlueValue),
        ('In Progress', AppColors.statOrangeValue),
        ('On Hold', AppColors.statRoseValue),
        ('Completed', AppColors.statEmeraldValue),
      ];

  @override
  Widget build(BuildContext context) {
    final statuses = _statuses;
    final breakdown = WorkOrderStatusBreakdown.from(workOrders);
    final values = [
      breakdown.notStarted,
      breakdown.inProgress,
      breakdown.onHold,
      breakdown.completed,
    ];

    return WebSectionCard(
      title: 'Work Order Status Distribution',
      action: Text(
        'Current Breakdown',
        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                for (var i = 0; i < statuses.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: _MiniStatBox(
                      label: statuses[i].$1,
                      value: values[i],
                      color: statuses[i].$2,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: _DonutChart(
                values: values,
                colors: statuses.map((s) => s.$2).toList(),
                total: breakdown.total,
              ),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < statuses.length; i++)
              _LegendRow(
                label: statuses[i].$1,
                value: values[i],
                percent: breakdown.total == 0
                    ? 0
                    : ((values[i] / breakdown.total) * 100).round(),
                color: statuses[i].$2,
              ),
          ],
        ),
      ),
    );
  }
}

class _MiniStatBox extends StatelessWidget {
  const _MiniStatBox({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 9.5, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.label,
    required this.value,
    required this.percent,
    required this.color,
  });

  final String label;
  final int value;
  final int percent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 12.5, color: AppColors.textPrimary),
            ),
          ),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 34,
            child: Text(
              '$percent%',
              textAlign: TextAlign.end,
              style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutChart extends StatelessWidget {
  const _DonutChart({
    required this.values,
    required this.colors,
    required this.total,
  });

  final List<int> values;
  final List<Color> colors;
  final int total;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 168,
      height: 168,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(168, 168),
            painter: _DonutPainter(values: values, colors: colors),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'TOTAL WOS',
                style: TextStyle(
                  fontSize: 9,
                  letterSpacing: 0.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$total',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.values, required this.colors});

  final List<int> values;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<int>(0, (a, b) => a + math.max(0, b));
    final center = Offset(size.width / 2, size.height / 2);
    final outerR = size.width / 2 - 4;
    const strokeWidth = 26.0;
    final ringR = outerR - strokeWidth / 2;

    if (total == 0) {
      final bg = Paint()
        ..color = AppColors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      canvas.drawCircle(center, ringR, bg);
      return;
    }

    var startAngle = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final value = math.max(0, values[i]);
      if (value == 0) continue;
      final sweep = (value / total) * 2 * math.pi;
      final paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: ringR),
        startAngle,
        sweep,
        false,
        paint,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.colors != colors;
}

// ---------------------------------------------------------------------------
// Work Activity Overview
// ---------------------------------------------------------------------------

class WorkActivityOverviewCard extends StatefulWidget {
  const WorkActivityOverviewCard({super.key, required this.workOrders});

  final List<WorkOrderModel> workOrders;

  @override
  State<WorkActivityOverviewCard> createState() =>
      _WorkActivityOverviewCardState();
}

class _WorkActivityOverviewCardState extends State<WorkActivityOverviewCard> {
  late int _year = DateTime.now().year;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  List<int> _monthlyCounts(int year) {
    final counts = List.filled(12, 0);
    for (final wo in widget.workOrders) {
      final created = DateTime.tryParse(wo.createdOn ?? '');
      if (created == null || created.year != year) continue;
      counts[created.month - 1]++;
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    final counts = _monthlyCounts(_year);
    final years = List.generate(3, (i) => DateTime.now().year - i);

    return WebSectionCard(
      title: 'Work Activity Overview',
      action: DropdownButton<int>(
        value: _year,
        isDense: true,
        underline: const SizedBox.shrink(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        items: years
            .map((y) => DropdownMenuItem(value: y, child: Text('FY $y')))
            .toList(),
        onChanged: (v) => setState(() => _year = v ?? _year),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _BarChart(
              values: counts.map((c) => c.toDouble()).toList(),
              labels: _months,
              color: AppColors.chromeBlue,
              height: 150,
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.statusCompleted,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'MONTHLY WORK LOAD TREND',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Plain-widget bar chart — a Flutter port of web's hand-rolled inline SVG
/// bar charts (`SimpleBarChart`/`PartsInventoryBarChart`), used for both the
/// monthly trend and the parts stock-level breakdown.
class _BarChart extends StatelessWidget {
  const _BarChart({
    required this.values,
    required this.labels,
    required this.color,
    this.colors,
    this.height = 150,
  });

  final List<double> values;
  final List<String> labels;
  final Color color;
  final List<Color>? colors;
  final double height;

  @override
  Widget build(BuildContext context) {
    final max = values.isEmpty
        ? 1.0
        : values.reduce((a, b) => a > b ? a : b).clamp(1, double.infinity);

    // The bar itself is an Expanded/FractionallySizedBox rather than a
    // manually computed pixel height, so it always absorbs exactly whatever
    // space is left after the value/label text — no risk of the text's real
    // (font-metric-dependent) height silently exceeding a hardcoded budget.
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: Column(
                children: [
                  Text(
                    values[i] == 0 ? '' : values[i].toStringAsFixed(0),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          widthFactor: 1,
                          heightFactor:
                              (values[i] / max).clamp(0.015, 1.0).toDouble(),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: colors != null ? colors![i] : color,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Parts Inventory Status
// ---------------------------------------------------------------------------

class PartsInventoryStatusCard extends StatelessWidget {
  const PartsInventoryStatusCard({
    super.key,
    required this.inventoryItems,
    this.onManage,
  });

  final List<InventoryItemModel> inventoryItems;
  final VoidCallback? onManage;

  @override
  Widget build(BuildContext context) {
    final inStock =
        inventoryItems.where((i) => i.stockLevel == StockLevel.inStock).length;
    final lowStock =
        inventoryItems.where((i) => i.stockLevel == StockLevel.low).length;
    final outOfStock = inventoryItems
        .where((i) => i.stockLevel == StockLevel.outOfStock)
        .length;
    final total = inStock + lowStock + outOfStock;
    final stockHealth = total == 0 ? 0 : ((inStock / total) * 100).round();

    return WebSectionCard(
      title: 'Parts Inventory Status',
      action: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.inputFill,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          'TOTAL: $total',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: AppColors.textSecondary,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: _StockStatBox(
                    label: 'In Stock',
                    value: inStock,
                    color: AppColors.statEmeraldValue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StockStatBox(
                    label: 'Low Stock',
                    value: lowStock,
                    color: AppColors.statOrangeValue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StockStatBox(
                    label: 'Out',
                    value: outOfStock,
                    color: AppColors.statRoseValue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _BarChart(
              values: [inStock.toDouble(), lowStock.toDouble(), outOfStock.toDouble()],
              labels: const ['In Stock', 'Low Stock', 'Out of Stock'],
              color: AppColors.statEmeraldValue,
              colors: [
                AppColors.statEmeraldValue,
                AppColors.statOrangeValue,
                AppColors.statRoseValue,
              ],
              height: 140,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'STOCK HEALTH',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: AppColors.textSecondary,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.chromeBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$stockHealth% Healthy',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.chromeBlue,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: stockHealth / 100,
                minHeight: 10,
                backgroundColor: AppColors.border,
                valueColor: const AlwaysStoppedAnimation(AppColors.chromeBlue),
              ),
            ),
            const SizedBox(height: 20),
            WebPrimaryButton(
              label: 'Manage Inventory Dashboard',
              onPressed: onManage ?? () {},
            ),
          ],
        ),
      ),
    );
  }
}

class _StockStatBox extends StatelessWidget {
  const _StockStatBox({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Performance Metrics
// ---------------------------------------------------------------------------

class PerformanceMetricsCard extends StatelessWidget {
  const PerformanceMetricsCard({
    super.key,
    required this.workOrders,
    required this.isLead,
  });

  final List<WorkOrderModel> workOrders;
  final bool isLead;

  @override
  Widget build(BuildContext context) {
    final breakdown = WorkOrderStatusBreakdown.from(workOrders);
    final total = workOrders.length;
    final completionRate =
        total == 0 ? 0 : ((breakdown.completed / total) * 100).round();
    final refDensity = total == 0 ? '0' : (total / 7).toStringAsFixed(1);

    final activeCount =
        breakdown.notStarted + breakdown.inProgress + breakdown.onHold;
    final hasMultipleIssues = [
          breakdown.notStarted,
          breakdown.inProgress,
          breakdown.onHold,
        ].where((n) => n > 0).length >=
        2;

    int clamp(num v) => v.clamp(0, 100).round();
    final uptimePercent = total == 0
        ? 100
        : clamp(
            100 -
                math.min(45, activeCount * 6) -
                (hasMultipleIssues ? 10 : 0) +
                math.min(6, breakdown.completed * 0.75),
          );
    final uptimeBars = List.generate(10, (i) {
      final wobble = (i % 2 == 0 ? 1 : -1) * (3 + (i % 3));
      return clamp(uptimePercent + wobble);
    });
    final uptimeStatusLabel = total == 0
        ? 'No work orders'
        : activeCount > 0
            ? (hasMultipleIssues ? 'Multiple issues' : 'Active work order')
            : 'Completed work order';

    return WebSectionCard(
      title: isLead
          ? 'Team Efficiency Performance'
          : 'Individual Performance Metrics',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.chromeBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.chromeBlue.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'COMPLETION RATE (MTD)',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          color: AppColors.chromeBlue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      RichText(
                        text: TextSpan(
                          text: '$completionRate',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                          children: [
                            TextSpan(
                              text: '%',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.chromeBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.card,
                      border: Border.all(
                        color: AppColors.chromeBlue.withValues(alpha: 0.35),
                        width: 3,
                      ),
                    ),
                    child: Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.chromeBlue,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _MetricCell(
                    label: 'Total Active WOs',
                    value: '$total',
                    caption: 'Assignments tracked',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCell(
                    label: 'Ref Density',
                    value: refDensity,
                    caption: 'Avg WO / day',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.statEmeraldValue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.statEmeraldValue.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'UPTIME RELIABILITY',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                      color: AppColors.statEmeraldValue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      RichText(
                        text: TextSpan(
                          text: '$uptimePercent',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                          children: [
                            TextSpan(
                              text: '%',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.statEmeraldValue,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        uptimeStatusLabel.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                          color: AppColors.statEmeraldValue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 28,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (final h in uptimeBars)
                          Expanded(
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 1.5),
                              height: math.max(3, h * 0.28),
                              decoration: BoxDecoration(
                                color: AppColors.statEmeraldValue
                                    .withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCell extends StatelessWidget {
  const _MetricCell({
    required this.label,
    required this.value,
    required this.caption,
  });

  final String label;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            caption,
            style: TextStyle(fontSize: 10, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}
