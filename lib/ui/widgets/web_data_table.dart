import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/core/constants/app_gradients.dart';

class WebTableColumn {
  const WebTableColumn({
    required this.label,
    required this.width,
    this.align = TextAlign.left,
  });

  final String label;
  final double width;
  final TextAlign align;
}

class WebDataTable extends StatelessWidget {
  const WebDataTable({
    super.key,
    required this.columns,
    required this.rowCount,
    required this.rowBuilder,
  });

  final List<WebTableColumn> columns;
  final int rowCount;
  final List<Widget> Function(int index) rowBuilder;

  @override
  Widget build(BuildContext context) {
    final tableWidth = columns.fold<double>(0, (sum, c) => sum + c.width);

    return Container(
      decoration: BoxDecoration(
        gradient: AppGradients.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: tableWidth < MediaQuery.sizeOf(context).width - 40
              ? MediaQuery.sizeOf(context).width - 40
              : tableWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HeaderRow(columns: columns),
              if (rowCount == 0)
                Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      'No records found',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                )
              else
                ...List.generate(rowCount, (i) {
                  final cells = rowBuilder(i);
                  return _DataRow(
                    columns: columns,
                    cells: cells,
                    striped: i.isOdd,
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.columns});

  final List<WebTableColumn> columns;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppGradients.cardHeader,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          for (final col in columns)
            SizedBox(
              width: col.width,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        col.label,
                        textAlign: col.align,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.gold,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.unfold_more,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  const _DataRow({
    required this.columns,
    required this.cells,
    required this.striped,
  });

  final List<WebTableColumn> columns;
  final List<Widget> cells;
  final bool striped;

  @override
  Widget build(BuildContext context) {
    final bg = striped
        ? AppColors.surfaceTertiary.withValues(alpha: 0.8)
        : Colors.transparent;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < columns.length; i++)
            SizedBox(
              width: columns[i].width,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DefaultTextStyle(
                  style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                  child: cells[i],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class WebTableCell extends StatelessWidget {
  const WebTableCell(this.text, {super.key, this.align = TextAlign.left});

  final String text;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Text(text, textAlign: align);
  }
}

class WebTableActions extends StatelessWidget {
  const WebTableActions({
    super.key,
    required this.onView,
    this.onEdit,
    this.onDelete,
    this.canEdit = true,
    this.canDelete = true,
  });

  final VoidCallback onView;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool canEdit;
  final bool canDelete;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: PopupMenuButton<String>(
        icon: Icon(Icons.more_vert, color: AppColors.textSecondary),
        onSelected: (v) {
          switch (v) {
            case 'view':
              onView();
            case 'edit':
              onEdit?.call();
            case 'delete':
              onDelete?.call();
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(value: 'view', child: Text('View')),
          if (canEdit && onEdit != null)
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
          if (canDelete && onDelete != null)
            const PopupMenuItem(
              value: 'delete',
              child: Text('Delete', style: TextStyle(color: AppColors.danger)),
            ),
        ],
      ),
    );
  }
}
