import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/core/utils/api_feedback.dart';
import 'package:rapide_nforce/core/utils/app_toast.dart';
import 'package:rapide_nforce/core/utils/date_format.dart';
import 'package:rapide_nforce/models/work_order_model.dart';
import 'package:rapide_nforce/services/auth_service.dart';
import 'package:rapide_nforce/services/maintenance_service.dart';
import 'package:rapide_nforce/ui/work_orders/work_order_detail_screen.dart';
import 'package:rapide_nforce/ui/work_orders/work_order_form_screen.dart';
import 'package:rapide_nforce/ui/work_orders/work_order_pdf_export.dart';

class WorkOrdersScreen extends StatefulWidget {
  const WorkOrdersScreen({super.key});

  @override
  State<WorkOrdersScreen> createState() => _WorkOrdersScreenState();
}

class _WorkOrdersScreenState extends State<WorkOrdersScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;

  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  List<WorkOrderModel> _items = [];
  int _page = 1;
  int _totalPages = 1;
  int _totalItems = 0;
  final Set<int> _statusFilters = {};
  String _searchTerm = '';
  String? _sortKey;
  String? _sortOrder;

  static const int _pageSize = 15;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loading || _loadingMore) return;
    if (_page >= _totalPages) return;
    if (_scrollController.position.pixels <
        _scrollController.position.maxScrollExtent - 300) {
      return;
    }
    _loadMore();
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    await _fetch(page: _page + 1, append: true);
  }

  /// The list endpoint only accepts a single `status` value per request. With
  /// 0 or 1 statuses checked in the filter sheet, this is a normal
  /// server-paginated fetch. With 2+ statuses checked, there's no server-side
  /// OR, so each selected status is fetched in full (capped, single page) and
  /// merged/sorted client-side — infinite scroll is not available in that
  /// mode since everything up to the cap is already loaded.
  Future<void> _fetch({required int page, required bool append}) async {
    final effectiveFilters =
        _statusFilters.length == WorkOrderStatus.values.length
        ? const <int>{}
        : _statusFilters;

    if (effectiveFilters.length <= 1) {
      final result = await MaintenanceService.instance.getWorkOrders(
        page: page,
        limit: _pageSize,
        search: _searchTerm.isEmpty ? null : _searchTerm,
        status: effectiveFilters.isEmpty ? null : effectiveFilters.first,
        companyId: AuthService.instance.selectedCompanyIdInt,
        sortKey: _sortKey ?? 'createdOn',
        sortOrder: _sortOrder ?? 'desc',
      );

      if (!mounted) return;

      if (!result.isSuccess) {
        setState(() {
          _loading = false;
          _loadingMore = false;
          if (!append) {
            _error = ApiFeedback.errorMessage(
              result,
              fallback: 'Failed to load work orders',
            );
          }
        });
        return;
      }

      final data = result.data!;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = null;
        _page = data.page;
        _totalPages = data.totalPages;
        _totalItems = data.total;
        final merged = append ? [..._items, ...data.items] : data.items;
        // Re-applied client-side (not just relied on the backend's sortKey
        // handling) so newer sort keys (priority/dueDate/unit/company) are
        // guaranteed correct even if the backend only honors a subset, and
        // so the order stays consistent across paginated-in batches.
        merged.sort(_compareForSort);
        _items = merged;
      });
      return;
    }

    // Multi-status mode: nothing further to page through, everything was
    // already fetched up front.
    if (append) {
      setState(() => _loadingMore = false);
      return;
    }

    final results = await Future.wait(
      effectiveFilters.map(
        (status) => MaintenanceService.instance.getWorkOrders(
          page: 1,
          limit: 100,
          search: _searchTerm.isEmpty ? null : _searchTerm,
          status: status,
          companyId: AuthService.instance.selectedCompanyIdInt,
          sortKey: _sortKey ?? 'createdOn',
          sortOrder: _sortOrder ?? 'desc',
        ),
      ),
    );

    if (!mounted) return;

    final succeeded = results.where((r) => r.isSuccess).toList();
    if (succeeded.isEmpty) {
      setState(() {
        _loading = false;
        _error = ApiFeedback.errorMessage(
          results.first,
          fallback: 'Failed to load work orders',
        );
      });
      return;
    }

    final merged = <WorkOrderModel>[for (final r in succeeded) ...r.data!.items]
      ..sort(_compareForSort);

    setState(() {
      _loading = false;
      _error = null;
      _page = 1;
      _totalPages = 1;
      _totalItems = merged.length;
      _items = merged;
    });
  }

  int _compareForSort(WorkOrderModel a, WorkOrderModel b) {
    final desc = (_sortOrder ?? 'desc') == 'desc';
    int cmp;
    switch (_sortKey ?? 'createdOn') {
      case 'workOrderNumber':
        cmp = a.workOrderNumber.compareTo(b.workOrderNumber);
        break;
      case 'status':
        cmp = a.status.code.compareTo(b.status.code);
        break;
      case 'priority':
        // Priority codes are 1=high/2=medium/3=low, so a lower code should
        // sort first for "highest priority first" — invert the raw compare
        // so 'desc' (the default direction) reads as high-to-low priority.
        cmp = (b.priority?.code ?? 99).compareTo(a.priority?.code ?? 99);
        break;
      case 'dueDate':
        cmp = (a.workOrderDetails?.dueDate ?? '').compareTo(
          b.workOrderDetails?.dueDate ?? '',
        );
        break;
      case 'unitNumber':
        cmp = a.unitNumber.toLowerCase().compareTo(b.unitNumber.toLowerCase());
        break;
      case 'companyName':
        cmp = (a.companyName ?? '').toLowerCase().compareTo(
          (b.companyName ?? '').toLowerCase(),
        );
        break;
      default:
        cmp = (a.createdOn ?? '').compareTo(b.createdOn ?? '');
    }
    return desc ? -cmp : cmp;
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      final next = _searchController.text.trim();
      if (next == _searchTerm) return;
      _searchTerm = next;
      _load(page: 1);
    });
  }

  Future<void> _load({int? page}) async {
    final targetPage = page ?? _page;
    setState(() {
      _loading = true;
      _error = null;
    });
    await _fetch(page: targetPage, append: false);
  }

  Future<void> _openDetail(WorkOrderModel order) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => WorkOrderDetailScreen(workOrderId: order.id),
      ),
    );
    if (changed == true) _load(page: 1);
  }

  Future<void> _openEdit(WorkOrderModel order) async {
    if (!order.status.canEdit) return;
    // The list row only carries summary data (no repair lines) — fetch the
    // full detail so the Repairs section isn't blank in the edit form.
    final result = await MaintenanceService.instance.getWorkOrderById(order.id);
    if (!mounted) return;
    final fullOrder = result.isSuccess && result.data != null
        ? result.data!
        : order;
    if (!result.isSuccess) {
      ApiFeedback.showError(result, fallback: 'Failed to load work order');
    }
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => WorkOrderFormScreen(existing: fullOrder),
      ),
    );
    if (changed == true) _load(page: 1);
  }

  Future<void> _confirmDelete(WorkOrderModel order) async {
    if (!order.status.canEdit) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(
          'Delete work order?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Remove ${order.workOrderNumber.isNotEmpty ? order.workOrderNumber : 'WO #${order.id}'}? This cannot be undone.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final result = await MaintenanceService.instance.deleteWorkOrder(order.id);
    if (!mounted) return;
    if (!result.isSuccess) {
      ApiFeedback.showError(result, fallback: 'Delete failed');
      return;
    }
    AppToast.showSuccess('Work order deleted');
    _load(page: 1);
  }

  Future<void> _exportOrder(WorkOrderModel order) async {
    final result = await MaintenanceService.instance.getWorkOrderById(order.id);
    if (!mounted) return;
    if (!result.isSuccess || result.data == null) {
      ApiFeedback.showError(result, fallback: 'Failed to load work order');
      return;
    }
    await exportWorkOrderPdf(context: context, order: result.data!);
  }

  void _clearSearch() {
    _searchController.clear();
    _searchTerm = '';
    _load(page: 1);
  }

  /// Filter-sheet chip with a light-blue selected state, shared by the
  /// Status / Order / Sort By sections.
  Widget _filterChip({
    required String label,
    required bool selected,
    required ValueChanged<bool> onSelected,
  }) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      showCheckmark: true,
      checkmarkColor: AppColors.chromeBlue,
      backgroundColor: AppColors.surfaceTertiary,
      selectedColor: AppColors.chromeBlue.withValues(alpha: 0.15),
      side: BorderSide(
        color: selected ? AppColors.chromeBlue : AppColors.border,
      ),
      labelStyle: TextStyle(
        color: selected ? AppColors.chromeBlue : AppColors.textPrimary,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
    );
  }

  void _showFiltersBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                20,
                24,
                32 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Filters & Sorting',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setSheetState(() {
                              _sortKey = null;
                              _sortOrder = null;
                              _statusFilters.clear();
                            });
                            setState(() {});
                            Navigator.pop(context);
                            _load(page: 1);
                          },
                          child: const Text('Reset'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Status',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _filterChip(
                          label: 'All',
                          selected: _statusFilters.isEmpty,
                          onSelected: (_) {
                            setSheetState(() => _statusFilters.clear());
                          },
                        ),
                        for (final s in WorkOrderStatus.values)
                          _filterChip(
                            label: s.label,
                            selected: _statusFilters.contains(s.code),
                            onSelected: (checked) {
                              setSheetState(() {
                                if (checked) {
                                  _statusFilters.add(s.code);
                                } else {
                                  _statusFilters.remove(s.code);
                                }
                              });
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sort By',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final entry in const {
                          'createdOn': 'Created Date',
                          'workOrderNumber': 'WO Number',
                          'status': 'Status',
                          'priority': 'Priority',
                          'dueDate': 'Due Date',
                          'unitNumber': 'Unit',
                          'companyName': 'Company',
                        }.entries)
                          _filterChip(
                            label: entry.value,
                            selected: (_sortKey ?? 'createdOn') == entry.key,
                            onSelected: (_) {
                              setSheetState(() => _sortKey = entry.key);
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Order',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        _filterChip(
                          label: 'Newest First',
                          selected: _sortOrder == 'desc',
                          onSelected: (val) {
                            setSheetState(() {
                              _sortOrder = val ? 'desc' : null;
                            });
                          },
                        ),
                        _filterChip(
                          label: 'Oldest First',
                          selected: _sortOrder == 'asc',
                          onSelected: (val) {
                            setSheetState(() {
                              _sortOrder = val ? 'asc' : null;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {});
                          Navigator.pop(context);
                          _load(page: 1);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF990000),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Apply Filters',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () => _load(page: 1),
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(fontSize: 13.5),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Search Work Order or Vehicle...',
                        hintStyle: TextStyle(
                          fontSize: 13.5,
                          color: AppColors.textTertiary,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 0,
                        ),
                        suffixIcon: _searchTerm.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: _clearSearch,
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      onSubmitted: (val) {
                        _searchTerm = val.trim();
                        _load(page: 1);
                      },
                    ),
                  ),
                  Container(height: 20, width: 1, color: AppColors.border),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _showFiltersBottomSheet,
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(14),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.tune_rounded,
                              size: 16,
                              color: AppColors.chromeBlue,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Filter',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.chromeBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'My Work Orders',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 19,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '$_totalItems Total',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.chromeBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Container(
                padding: const EdgeInsets.all(24),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cloud_off_rounded,
                      size: 40,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    _BlackButton(
                      label: 'Retry',
                      icon: Icons.refresh,
                      onPressed: () => _load(),
                    ),
                  ],
                ),
              )
            else if (_items.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  _searchTerm.isNotEmpty || _statusFilters.isNotEmpty
                      ? 'No work orders match your filters'
                      : 'No work orders yet',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              )
            else
              ...(_items.map(
                (order) => WorkOrderCard(
                  order: order,
                  onTap: () => _openDetail(order),
                  onEdit: () => _openEdit(order),
                  onDelete: () => _confirmDelete(order),
                  onExport: () => _exportOrder(order),
                ),
              )),
            if (!_loading && _error == null && _items.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${_items.length} of $_totalItems',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              if (_loadingMore)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Work order card — compact style: colored left stripe by priority, status +
// priority badges, tap to open full detail (Edit/Delete/PDF live there).
// ---------------------------------------------------------------------------

class WorkOrderCard extends StatelessWidget {
  const WorkOrderCard({
    super.key,
    required this.order,
    required this.onTap,
    this.onEdit,
    this.onDelete,
    this.onExport,
  });

  final WorkOrderModel order;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) {
    final priority = order.priority ?? WorkOrderPriority.medium;
    final displayNum = order.workOrderNumber.isNotEmpty
        ? order.workOrderNumber
        : 'WO #${order.id}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow.withValues(alpha: 0.3),
            blurRadius: 12,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 5, color: priority.accentColor),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 10, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _PriorityBadge(priority: priority),
                            const Spacer(),
                            if (onExport != null &&
                                order.status == WorkOrderStatus.completed)
                              _IconOnlyButton(
                                icon: Icons.picture_as_pdf_outlined,
                                onTap: onExport,
                              ),
                            if (onEdit != null) ...[
                              const SizedBox(width: 4),
                              _IconOnlyButton(
                                icon: Icons.edit,
                                color: AppColors.chromeBlue,
                                onTap: onEdit,
                              ),
                            ],
                            if (onDelete != null) ...[
                              const SizedBox(width: 2),
                              _IconOnlyButton(
                                icon: Icons.delete_outline,
                                onTap: onDelete,
                                danger: true,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayNum,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  RichText(
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    text: TextSpan(
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: AppColors.textSecondary,
                                      ),
                                      children: [
                                        const TextSpan(text: 'Vehicle: '),
                                        TextSpan(
                                          text: order.unitNumber.isNotEmpty
                                              ? order.unitNumber
                                              : '—',
                                          style: TextStyle(
                                            color: AppColors.chromeBlue,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    order.entityTypeName ?? '—',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 6,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _GridCell(
                                      label: 'Status',
                                      child: _MiniBadge(
                                        label: order.status.label,
                                        bgColor: order.status.backgroundColor,
                                        textColor: order.status.textColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: _GridCell(
                                      label:
                                          order.status ==
                                              WorkOrderStatus.completed
                                          ? 'End Date'
                                          : 'ETA',
                                      child: Text(
                                        formatDateMMDDYYYY(
                                              order.status ==
                                                      WorkOrderStatus.completed
                                                  ? order
                                                        .workOrderDetails
                                                        ?.endDate
                                                  : order
                                                        .workOrderDetails
                                                        ?.dueDate,
                                            ) ??
                                            '—',
                                        maxLines: 1,
                                        softWrap: false,
                                        overflow: TextOverflow.visible,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 20,
                              color: AppColors.textSecondary,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IconOnlyButton extends StatelessWidget {
  const _IconOnlyButton({
    required this.icon,
    required this.onTap,
    this.danger = false,
    this.color,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool danger;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final resolvedColor = !enabled
        ? AppColors.textSecondary.withValues(alpha: 0.3)
        : danger
        ? AppColors.danger
        : color ?? AppColors.textSecondary;

    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 19, color: resolvedColor),
        ),
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.priority});

  final WorkOrderPriority priority;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 4, right: 9, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: priority.backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 15,
            height: 15,
            decoration: BoxDecoration(
              color: priority.accentColor,
              shape: BoxShape.circle,
            ),
            child: Icon(priority.trendIcon, size: 9, color: Colors.white),
          ),
          const SizedBox(width: 5),
          Text(
            priority.label.toUpperCase(),
            style: TextStyle(
              color: priority.textColor,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _GridCell extends StatelessWidget {
  const _GridCell({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 5),
        child,
      ],
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({
    required this.label,
    required this.bgColor,
    required this.textColor,
  });

  final String label;
  final Color bgColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _BlackButton extends StatelessWidget {
  const _BlackButton({
    required this.label,
    required this.onPressed,
    required this.icon,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
