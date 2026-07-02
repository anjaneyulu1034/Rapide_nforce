import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/core/utils/api_feedback.dart';
import 'package:rapide_nforce/core/utils/app_toast.dart';
import 'package:rapide_nforce/models/work_order_model.dart';
import 'package:rapide_nforce/services/auth_service.dart';
import 'package:rapide_nforce/services/maintenance_service.dart';
import 'package:rapide_nforce/ui/work_orders/work_order_detail_screen.dart';
import 'package:rapide_nforce/ui/work_orders/work_order_form_screen.dart';
import 'package:rapide_nforce/ui/work_orders/work_order_pdf_export.dart';
import 'package:rapide_nforce/ui/work_orders/widgets/work_order_status_chip.dart';

class WorkOrdersScreen extends StatefulWidget {
  const WorkOrdersScreen({super.key});

  @override
  State<WorkOrdersScreen> createState() => _WorkOrdersScreenState();
}

class _WorkOrdersScreenState extends State<WorkOrdersScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  bool _loading = true;
  String? _error;
  List<WorkOrderModel> _items = [];
  int _page = 1;
  int _totalPages = 1;
  int _totalItems = 0;
  int? _statusFilter;
  String _searchTerm = '';

  static const int _pageSize = 15;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
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

    final result = await MaintenanceService.instance.getWorkOrders(
      page: targetPage,
      limit: _pageSize,
      search: _searchTerm.isEmpty ? null : _searchTerm,
      status: _statusFilter,
      companyId: AuthService.instance.selectedCompanyIdInt,
      sortKey: 'createdOn',
      sortOrder: 'desc',
    );

    if (!mounted) return;

    if (!result.isSuccess) {
      final message = ApiFeedback.errorMessage(
        result,
        fallback: 'Failed to load work orders',
      );
      setState(() {
        _loading = false;
        _error = message;
      });
      return;
    }

    final data = result.data!;
    setState(() {
      _loading = false;
      _error = null;
      _page = data.page;
      _totalPages = data.totalPages;
      _totalItems = data.total;
      _items = data.items;
    });
  }

  Future<void> _openDetail(WorkOrderModel order) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => WorkOrderDetailScreen(workOrderId: order.id),
      ),
    );
    if (changed == true) _load();
  }

  Future<void> _openEdit(WorkOrderModel order) async {
    if (!order.status.canEdit) return;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => WorkOrderFormScreen(existing: order)),
    );
    if (changed == true) _load();
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
    _load();
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

  void _setStatusFilter(int? status) {
    _statusFilter = _statusFilter == status ? null : status;
    _load(page: 1);
  }

  void _clearSearch() {
    _searchController.clear();
    _searchTerm = '';
    _load(page: 1);
  }

  @override
  Widget build(BuildContext context) {
    final start = _items.isEmpty ? 0 : (_page - 1) * _pageSize + 1;
    final end = (_page - 1) * _pageSize + _items.length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () => _load(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Work Orders',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$_totalItems',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 20,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _StatusFilterChip(
                    label: 'ALL',
                    textColor: const Color(0xFF1A1A1A),
                    bgColor: const Color(0xFFF3F4F6),
                    selected: _statusFilter == null,
                    onTap: () => _setStatusFilter(null),
                  ),
                  const SizedBox(width: 8),
                  ...WorkOrderStatus.values.map(
                    (s) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _StatusFilterChip(
                        label: s.label.toUpperCase(),
                        textColor: s.textColor,
                        bgColor: s.backgroundColor,
                        selected: _statusFilter == s.code,
                        onTap: () => _setStatusFilter(s.code),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search WO #, unit, company',
                        hintStyle: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                        suffixIcon: _searchTerm.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.close,
                                  size: 18,
                                  color: AppColors.textSecondary,
                                ),
                                onPressed: _clearSearch,
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                      ),
                    ),
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
                  _searchTerm.isNotEmpty || _statusFilter != null
                      ? 'No work orders match your filters'
                      : 'No work orders yet',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              )
            else
              ...(_items.map(
                (order) => _WorkOrderCard(
                  order: order,
                  onTap: () => _openDetail(order),
                  onEdit: () => _openEdit(order),
                  onDelete: () => _confirmDelete(order),
                  onExport: () => _exportOrder(order),
                ),
              )),
            if (!_loading && _error == null && _items.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$start–$end of $_totalItems',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Row(
                      children: [
                        _PagBtn(
                          icon: Icons.chevron_left,
                          enabled: _page > 1,
                          onTap: () => _load(page: _page - 1),
                        ),
                        const SizedBox(width: 8),
                        _PagBtn(
                          icon: Icons.chevron_right,
                          enabled: _page < _totalPages,
                          onTap: () => _load(page: _page + 1),
                        ),
                      ],
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

// ---------------------------------------------------------------------------
// Status filter chip (colored, no count — matches Power Unit palette)
// ---------------------------------------------------------------------------

class _StatusFilterChip extends StatelessWidget {
  const _StatusFilterChip({
    required this.label,
    required this.textColor,
    required this.bgColor,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color textColor;
  final Color bgColor;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? textColor : Colors.transparent,
            width: 1.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: textColor,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Work order card — matches Power Unit maintenance-history card style
// ---------------------------------------------------------------------------

class _WorkOrderCard extends StatelessWidget {
  const _WorkOrderCard({
    required this.order,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onExport,
  });

  final WorkOrderModel order;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onExport;

  static String _initials(String? name) {
    if (name == null || name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  static String _fmtDate(String? s) {
    if (s == null || s.isEmpty) return '—';
    final d = DateTime.tryParse(s);
    if (d == null) return s;
    return '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}-${d.year}';
  }

  static String _fmtCost(double? v) =>
      v == null ? '—' : '\$${v.toStringAsFixed(2)}';

  static String _fmtOdo(String? v) => (v == null || v.isEmpty) ? '—' : '$v km';

  @override
  Widget build(BuildContext context) {
    final details = order.workOrderDetails;
    final tech = details?.technicianName;
    final initials = _initials(tech);
    final displayNum = order.workOrderNumber.isNotEmpty
        ? order.workOrderNumber
        : 'WO #${order.id}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow.withValues(alpha: 0.35),
            blurRadius: 16,
            spreadRadius: 1,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        displayNum,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceTertiary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        order.isPreventativeMaintenance ? 'PM' : 'REPAIR',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: order.status.backgroundColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        order.status.label,
                        style: TextStyle(
                          color: order.status.textColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  [
                    'Unit: ${order.unitNumber}',
                    order.issueDescription,
                  ].where((s) => s.isNotEmpty).join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: AppColors.textSecondary.withValues(alpha: 0.12),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _InfoCell(
                        label: 'COST',
                        value: _fmtCost(details?.estimatedCost),
                      ),
                    ),
                    Expanded(
                      child: _InfoCell(
                        label: 'ODOMETER',
                        value: _fmtOdo(
                          details?.odometer ?? details?.startOdometer,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _InfoCell(
                        label: 'START DATE',
                        value: _fmtDate(details?.startDate),
                      ),
                    ),
                    Expanded(
                      child: _InfoCell(
                        label: 'DUE DATE',
                        value: _fmtDate(details?.dueDate),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: AppColors.textSecondary.withValues(alpha: 0.12),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1A1A1A),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tech ?? 'Unassigned',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (order.priority != null) ...[
                      WorkOrderPriorityChip(priority: order.priority!),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                // ── Action Buttons ──
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onTap,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: BorderSide(
                            color: AppColors.textSecondary.withValues(alpha: 0.3),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          minimumSize: const Size(0, 36),
                          padding: EdgeInsets.zero,
                        ),
                        child: const Text(
                          'View',
                          style: TextStyle(
                            letterSpacing: 0.8,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: order.status.canEdit ? onEdit : null,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: BorderSide(
                            color: AppColors.textSecondary.withValues(alpha: 0.3),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          minimumSize: const Size(0, 36),
                          padding: EdgeInsets.zero,
                        ),
                        child: const Text(
                          'Edit',
                          style: TextStyle(
                            letterSpacing: 0.8,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: order.status.canEdit ? onDelete : null,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: order.status.canEdit ? AppColors.danger : AppColors.textSecondary.withValues(alpha: 0.3),
                          backgroundColor: Colors.transparent,
                          side: BorderSide(
                            color: order.status.canEdit ? AppColors.danger.withValues(alpha: 0.4) : AppColors.textSecondary.withValues(alpha: 0.3),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          minimumSize: const Size(0, 36),
                          padding: EdgeInsets.zero,
                        ),
                        child: const Text(
                          'Delete',
                          style: TextStyle(
                            letterSpacing: 0.8,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    if (order.status == WorkOrderStatus.completed) ...[
                      const SizedBox(width: 6),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onExport,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0E7490),
                            side: const BorderSide(
                              color: Color(0xFF0E7490),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            minimumSize: const Size(0, 36),
                            padding: EdgeInsets.zero,
                          ),
                          child: const Text(
                            'PDF',
                            style: TextStyle(
                              letterSpacing: 0.8,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoCell extends StatelessWidget {
  const _InfoCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _PagBtn extends StatelessWidget {
  const _PagBtn({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(
            icon,
            size: 18,
            color: enabled
                ? AppColors.textPrimary
                : AppColors.textSecondary.withValues(alpha: 0.4),
          ),
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
