import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/core/utils/app_toast.dart';
import 'package:rapide_nforce/models/part_models.dart';
import 'package:rapide_nforce/services/inventory_service.dart';
import 'package:rapide_nforce/ui/inventory/part_form_screen.dart';
import 'package:rapide_nforce/ui/inventory/part_type_form_screen.dart';
import 'package:rapide_nforce/ui/inventory/widgets/inventory_stock_badge.dart';
import 'package:rapide_nforce/ui/widgets/web_ui.dart';

class PartTypeDetailScreen extends StatelessWidget {
  const PartTypeDetailScreen({
    super.key,
    required this.partType,
    this.onChanged,
  });

  final PartTypeModel partType;
  final VoidCallback? onChanged;

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete part type?'),
        content: Text('Remove "${partType.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final result = await InventoryService.instance.deletePartType(partType.id);
    if (!context.mounted) return;
    if (!result.isSuccess) {
      AppToast.showError(result.message ?? 'Delete failed');
      return;
    }
    AppToast.showSuccess('Part type deleted');
    onChanged?.call();
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(partType.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final changed = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => PartTypeFormScreen(partType: partType),
                ),
              );
              if (changed == true) {
                onChanged?.call();
                if (context.mounted) Navigator.pop(context, true);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.danger),
            onPressed: () => _delete(context),
          ),
        ],
      ),
      body: WebPageBody(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _DetailCard(
              children: [
                _Row('Name', partType.name),
                _Row('Quantity on hand', '${partType.count}'),
                _Row('Low stock trigger', '${partType.lowStockTrigger}'),
                _Row(
                  'Status',
                  null,
                  child: InventoryStockBadge(level: partType.stockLevel),
                ),
                _Row('Created by', partType.createdByUsername ?? '—'),
                _Row('Created on', formatInventoryDate(partType.createdOn)),
                _Row('Modified on', formatInventoryDate(partType.modifiedOn)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class PartDetailScreen extends StatelessWidget {
  const PartDetailScreen({super.key, required this.part, this.onChanged});

  final PartModel part;
  final VoidCallback? onChanged;

  Future<void> _delete(BuildContext context) async {
    if (part.isUsedInWorkOrder) {
      AppToast.showError('Cannot delete — part is used in a work order');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete part?'),
        content: Text('Remove part "${part.code}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final result = await InventoryService.instance.deletePart(part.id);
    if (!context.mounted) return;
    if (!result.isSuccess) {
      AppToast.showError(result.message ?? 'Delete failed');
      return;
    }
    AppToast.showSuccess('Part deleted');
    onChanged?.call();
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = !part.isProtected;
    final canDelete = canEdit && !part.isUsedInWorkOrder;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(part.code),
        actions: [
          if (canEdit)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                final changed = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => PartFormScreen(part: part)),
                );
                if (changed == true) {
                  onChanged?.call();
                  if (context.mounted) Navigator.pop(context, true);
                }
              },
            ),
          if (canDelete)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.danger),
              onPressed: () => _delete(context),
            ),
        ],
      ),
      body: WebPageBody(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (part.isProtected)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: const Text(
                  'System part — view only (None / Shop Supplies)',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            _DetailCard(
              children: [
                _Row('Part code', part.code),
                _Row('Part type', part.partTypeName),
                _Row('Quantity', '${part.quantity ?? 0}'),
                _Row('Unit cost', formatInventoryMoney(part.cost)),
                _Row('Total cost', formatInventoryMoney(part.totalCost)),
                _Row('Invoice #', part.invoiceNumber ?? '—'),
                _Row('Created by', part.createdByUsername ?? '—'),
                _Row('Created on', formatInventoryDate(part.createdOn)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(children: children),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.child});

  final String label;
  final String? value;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.borderLight)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
          Expanded(
            flex: 3,
            child:
                child ??
                Text(
                  value ?? '—',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
          ),
        ],
      ),
    );
  }
}
