import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/models/work_order_pm_model.dart';

/// Builds one [PmInspectionResultModel] per checklist item, preserving any
/// already-filled-in results (matched by item id) when re-opening a saved WO.
List<PmInspectionResultModel> mergePmResults({
  required List<PmInspectionCategory> categories,
  required List<PmInspectionResultModel> existing,
}) {
  final byItemId = {for (final r in existing) r.itemId: r};
  return [
    for (final category in categories)
      for (final item in category.items)
        byItemId[item.id] ??
            PmInspectionResultModel(itemId: item.id, itemName: item.itemName),
  ];
}

/// Default axle/tire positions when a work order has no saved measurements yet.
/// Trucks get a steer axle + one drive axle; trailers get two axles — the
/// mobile app has no per-vehicle axle-count data, so this is a sensible
/// starting set the technician can still fill in freely.
List<PmTireMeasurementModel> defaultTirePositions({required bool isTrailer}) {
  if (isTrailer) {
    return [
      for (final axle in [1, 2])
        for (final pos in ['leftOuter', 'leftInner', 'rightInner', 'rightOuter'])
          PmTireMeasurementModel(position: 'axle${axle}_$pos', axleNo: axle),
    ];
  }
  return [
    PmTireMeasurementModel(position: 'FRONT_LEFT'),
    PmTireMeasurementModel(position: 'FRONT_RIGHT'),
    for (final pos in ['leftOuter', 'leftInner', 'rightInner', 'rightOuter'])
      PmTireMeasurementModel(position: 'axle1_$pos', axleNo: 1),
  ];
}

/// Category accordions + checklist rows for the PM inspection.
class PmInspectionSection extends StatelessWidget {
  const PmInspectionSection({
    super.key,
    required this.categories,
    required this.results,
    required this.isTrailer,
    required this.onChanged,
  });

  final List<PmInspectionCategory> categories;
  final List<PmInspectionResultModel> results;
  final bool isTrailer;
  final VoidCallback onChanged;

  PmInspectionResultModel? _resultFor(int itemId) {
    for (final r in results) {
      if (r.itemId == itemId) return r;
    }
    return null;
  }

  Future<void> _pickRepairDate(
    BuildContext context,
    PmInspectionResultModel result,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(result.repairDate ?? '') ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      result.repairDate =
          '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final category in categories)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                title: Text(
                  '${category.code}. ${category.name}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                children: [
                  for (final item in category.items)
                    _ItemRow(
                      item: item,
                      result: _resultFor(item.id),
                      isTrailer: isTrailer,
                      onChanged: onChanged,
                      onPickDate: (r) => _pickRepairDate(context, r),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.result,
    required this.isTrailer,
    required this.onChanged,
    required this.onPickDate,
  });

  final PmInspectionItem item;
  final PmInspectionResultModel? result;
  final bool isTrailer;
  final VoidCallback onChanged;
  final ValueChanged<PmInspectionResultModel> onPickDate;

  @override
  Widget build(BuildContext context) {
    final r = result;
    if (r == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Checkbox(
            value: r.isChecked,
            onChanged: (v) {
              r.isChecked = v ?? false;
              onChanged();
            },
          ),
          Expanded(
            child: Text(item.itemName, style: const TextStyle(fontSize: 13)),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 130,
            child: DropdownButtonFormField<PmResultCode>(
              initialValue: r.code,
              isDense: true,
              decoration: const InputDecoration(isDense: true),
              items: PmResultCode.values
                  .map(
                    (c) => DropdownMenuItem(
                      value: c,
                      child: Text(c.label, style: const TextStyle(fontSize: 12)),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                r.code = v;
                onChanged();
              },
            ),
          ),
          if (!isTrailer) ...[
            const SizedBox(width: 6),
            IconButton(
              icon: Icon(Icons.event_outlined,
                  size: 18,
                  color: r.repairDate != null
                      ? AppColors.primary
                      : AppColors.textSecondary),
              tooltip: r.repairDate ?? 'Set repair date',
              onPressed: () => onPickDate(r),
            ),
          ],
        ],
      ),
    );
  }
}

/// Tire + brake measurement grid, one row per axle position.
class TireBrakeGrid extends StatelessWidget {
  const TireBrakeGrid({
    super.key,
    required this.measurements,
    required this.onChanged,
  });

  final List<PmTireMeasurementModel> measurements;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Table(
          defaultColumnWidth: const FixedColumnWidth(100),
          columnWidths: const {0: FixedColumnWidth(140)},
          border: TableBorder.symmetric(
            inside: BorderSide(color: AppColors.border),
          ),
          children: [
            TableRow(
              decoration: BoxDecoration(color: AppColors.surfaceTertiary),
              children: [
                _headCell('POSITION'),
                _headCell('PSI'),
                _headCell('TREAD 32nds'),
                _headCell('PUSHROD (in)'),
                _headCell('LINING %'),
              ],
            ),
            for (final m in measurements)
              TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 10),
                    child: Text(
                      m.position,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  _numCell(
                    value: m.tireAirPsi,
                    onChanged: (v) {
                      m.tireAirPsi = v;
                      onChanged();
                    },
                  ),
                  _numCell(
                    value: m.treadDepth32nds,
                    onChanged: (v) {
                      m.treadDepth32nds = v;
                      onChanged();
                    },
                  ),
                  _numCell(
                    value: m.pushrodMeasurementIn,
                    onChanged: (v) {
                      m.pushrodMeasurementIn = v;
                      onChanged();
                    },
                  ),
                  _numCell(
                    value: m.brakeLiningPercent,
                    onChanged: (v) {
                      m.brakeLiningPercent = v;
                      onChanged();
                    },
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _headCell(String label) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 0.3,
          ),
        ),
      );

  Widget _numCell({
    required num? value,
    required ValueChanged<num?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: TextFormField(
        initialValue: value?.toString() ?? '',
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(fontSize: 12),
        decoration: const InputDecoration(isDense: true),
        onChanged: (v) => onChanged(num.tryParse(v)),
      ),
    );
  }
}

/// Defects table — capped at [maxRows] rows, matching the web form's limit.
class PmDefectsTable extends StatelessWidget {
  const PmDefectsTable({
    super.key,
    required this.defects,
    required this.onAdd,
    required this.onRemove,
    required this.onChanged,
    this.maxRows = 20,
  });

  final List<PmDefectModel> defects;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final VoidCallback onChanged;
  final int maxRows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < defects.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      initialValue: defects[i].defectDescription ?? '',
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: 'Defect description',
                      ),
                      style: const TextStyle(fontSize: 12),
                      onChanged: (v) {
                        defects[i].defectDescription = v;
                        onChanged();
                      },
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextFormField(
                      initialValue: defects[i].quantity?.toString() ?? '',
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(isDense: true, hintText: 'Qty'),
                      style: const TextStyle(fontSize: 12),
                      onChanged: (v) {
                        defects[i].quantity = num.tryParse(v);
                        onChanged();
                      },
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      initialValue: defects[i].actionTaken ?? '',
                      decoration:
                          const InputDecoration(isDense: true, hintText: 'Action'),
                      style: const TextStyle(fontSize: 12),
                      onChanged: (v) {
                        defects[i].actionTaken = v;
                        onChanged();
                      },
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 18, color: AppColors.danger),
                    onPressed: () => onRemove(i),
                  ),
                ],
              ),
            ),
          if (defects.length < maxRows)
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add defect row'),
            )
          else
            Text(
              'Maximum of $maxRows defect rows reached',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
        ],
      ),
    );
  }
}
