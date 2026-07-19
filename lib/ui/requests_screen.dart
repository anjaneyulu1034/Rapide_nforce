import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/core/constants/app_strings.dart';
import 'package:rapide_nforce/models/maintenance_request_model.dart';
import 'package:rapide_nforce/models/work_order_model.dart';
import 'package:rapide_nforce/services/request_service.dart';
import 'package:rapide_nforce/ui/widgets/fleet_list_card.dart';
import 'package:rapide_nforce/ui/widgets/screen_state_builder.dart';
import 'package:rapide_nforce/ui/widgets/status_chip.dart';
import 'package:rapide_nforce/ui/widgets/web_ui.dart';
import 'package:rapide_nforce/ui/work_orders/work_order_detail_screen.dart';
import 'package:rapide_nforce/ui/work_orders/widgets/work_order_status_chip.dart';

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  bool _loading = true;
  String? _error;
  List<MaintenanceRequestModel> _items = [];
  RequestApprovalStatus? _statusFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await RequestService.instance.fetchRequests();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result.isSuccess) {
        _items = result.data ?? [];
      } else {
        _error = result.message ?? 'Failed to load requests';
      }
    });
  }

  int _countFor(RequestApprovalStatus? status) {
    if (status == null) return _items.length;
    return _items.where((r) => r.approvalStatusEnum == status).length;
  }

  StatusChipTone _toneFor(RequestApprovalStatus status) {
    switch (status) {
      case RequestApprovalStatus.pending:
        return StatusChipTone.warning;
      case RequestApprovalStatus.approved:
        return StatusChipTone.success;
      case RequestApprovalStatus.rejected:
        return StatusChipTone.danger;
      case RequestApprovalStatus.unknown:
        return StatusChipTone.neutral;
    }
  }

  Color _avatarBg(RequestApprovalStatus status) {
    switch (status) {
      case RequestApprovalStatus.pending:
        return const Color(0xFFEDE9FE);
      case RequestApprovalStatus.approved:
        return AppColors.statusCompleted.withValues(alpha: 0.15);
      case RequestApprovalStatus.rejected:
        return AppColors.danger.withValues(alpha: 0.15);
      case RequestApprovalStatus.unknown:
        return AppColors.surfaceTertiary;
    }
  }

  Color _avatarFg(RequestApprovalStatus status) {
    switch (status) {
      case RequestApprovalStatus.pending:
        return const Color(0xFF6D28D9);
      case RequestApprovalStatus.approved:
        return AppColors.statusCompleted;
      case RequestApprovalStatus.rejected:
        return AppColors.danger;
      case RequestApprovalStatus.unknown:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _statusFilter == null
        ? _items
        : _items.where((r) => r.approvalStatusEnum == _statusFilter).toList();

    return ScreenStateBuilder(
      loading: _loading,
      error: _error,
      onRetry: _load,
      isEmpty: _items.isEmpty,
      emptyMessage: AppStrings.noData,
      emptyIcon: Icons.handyman_outlined,
      child: WebListPage(
        title: 'Requests',
        subtitle: '${_items.length} maintenance requests',
        onRefresh: _load,
        toolbar: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _RequestFilterChip(
                  label: 'All',
                  count: _countFor(null),
                  color: AppColors.primary,
                  selected: _statusFilter == null,
                  onTap: () => setState(() => _statusFilter = null),
                ),
                const SizedBox(width: 8),
                _RequestFilterChip(
                  label: 'Pending',
                  count: _countFor(RequestApprovalStatus.pending),
                  color: AppColors.warning,
                  selected: _statusFilter == RequestApprovalStatus.pending,
                  onTap: () => setState(
                    () => _statusFilter = RequestApprovalStatus.pending,
                  ),
                ),
                const SizedBox(width: 8),
                _RequestFilterChip(
                  label: 'Approved',
                  count: _countFor(RequestApprovalStatus.approved),
                  color: AppColors.statusCompleted,
                  selected: _statusFilter == RequestApprovalStatus.approved,
                  onTap: () => setState(
                    () => _statusFilter = RequestApprovalStatus.approved,
                  ),
                ),
                const SizedBox(width: 8),
                _RequestFilterChip(
                  label: 'Rejected',
                  count: _countFor(RequestApprovalStatus.rejected),
                  color: AppColors.danger,
                  selected: _statusFilter == RequestApprovalStatus.rejected,
                  onTap: () => setState(
                    () => _statusFilter = RequestApprovalStatus.rejected,
                  ),
                ),
              ],
            ),
          ),
        ),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) {
              final req = filtered[i];
              final status = req.approvalStatusEnum;
              return FleetListCard(
                title: req.title,
                subtitle: '${req.unitNumber} · ${req.requestedOn}',
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _avatarBg(status),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.handyman_outlined,
                    size: 20,
                    color: _avatarFg(status),
                  ),
                ),
                trailing: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    WorkOrderPriorityChip(
                      priority: WorkOrderPriority.fromCode(req.priority),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        StatusChip(
                          label: status.label,
                          tone: _toneFor(status),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ],
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          WorkOrderDetailScreen(workOrderId: req.id),
                    ),
                  );
                },
              );
            },
            childCount: filtered.length,
          ),
        ),
      ),
    );
  }
}

class _RequestFilterChip extends StatelessWidget {
  const _RequestFilterChip({
    required this.label,
    required this.count,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? color : AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : AppColors.border,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: 0.22)
                    : color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? AppColors.white : color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
