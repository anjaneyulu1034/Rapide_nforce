import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';

class WebPaginationBar extends StatelessWidget {
  const WebPaginationBar({
    super.key,
    required this.page,
    required this.totalPages,
    required this.total,
    required this.limit,
    required this.onPageChanged,
    this.onLimitChanged,
    this.limitOptions = const [10, 15, 25, 50],
  });

  final int page;
  final int totalPages;
  final int total;
  final int limit;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int>? onLimitChanged;
  final List<int> limitOptions;

  int get _from => total == 0 ? 0 : ((page - 1) * limit) + 1;
  int get _to {
    final end = page * limit;
    return end > total ? total : end;
  }

  Widget _rowsPerPageControl() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Rows per page:',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(width: 8),
        DropdownButton<int>(
          value: limitOptions.contains(limit) ? limit : limitOptions.first,
          underline: const SizedBox.shrink(),
          isDense: true,
          items: limitOptions
              .map(
                (n) => DropdownMenuItem(
                  value: n,
                  child: Text('$n'),
                ),
              )
              .toList(),
          onChanged: onLimitChanged == null
              ? null
              : (v) {
                  if (v != null) onLimitChanged!(v);
                },
        ),
      ],
    );
  }

  Widget _pageControls() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            'Showing $_from to $_to of $total',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          onPressed: page > 1 ? () => onPageChanged(page - 1) : null,
          icon: const Icon(Icons.chevron_left),
        ),
        Text(
          'Page $page of ${totalPages == 0 ? 1 : totalPages}',
          style: const TextStyle(fontSize: 13),
        ),
        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          onPressed: page < totalPages ? () => onPageChanged(page + 1) : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 480;

          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _rowsPerPageControl(),
                const SizedBox(height: 8),
                _pageControls(),
              ],
            );
          }

          return Row(
            children: [
              _rowsPerPageControl(),
              const Spacer(),
              Flexible(child: _pageControls()),
            ],
          );
        },
      ),
    );
  }
}
