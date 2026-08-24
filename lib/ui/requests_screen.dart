import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/core/constants/app_strings.dart';
import 'package:rapide_nforce/models/maintenance_request_model.dart';
import 'package:rapide_nforce/models/work_order_model.dart';
import 'package:rapide_nforce/services/request_service.dart';
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
  final _searchController = TextEditingController();
  bool _loading = true;
  String? _error;
  List<MaintenanceRequestModel> _items = [];
  RequestApprovalStatus? _statusFilter;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _search = _searchController.text;
      });
    });
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
    final searchLower = _search.trim().toLowerCase();
    final filtered = _items.where((r) {
      if (_statusFilter != null && r.approvalStatusEnum != _statusFilter) {
        return false;
      }
      if (searchLower.isNotEmpty) {
        final matchesTitle = r.title.toLowerCase().contains(searchLower);
        final matchesUnit = r.unitNumber.toLowerCase().contains(searchLower);
        final matchesIssue =
            r.issueDescription.toLowerCase().contains(searchLower);
        final matchesTech =
            (r.technicianName ?? '').toLowerCase().contains(searchLower);
        return matchesTitle || matchesUnit || matchesIssue || matchesTech;
      }
      return true;
    }).toList();

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
        toolbar: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            WebSearchField(
              controller: _searchController,
              hintText: 'Search requests by WO#, Unit#, or issue...',
              showClear: _search.isNotEmpty,
              onClear: () {
                _searchController.clear();
                setState(() => _search = '');
              },
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: SizedBox(
                height: 38,
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
                      selected:
                          _statusFilter == RequestApprovalStatus.approved,
                      onTap: () => setState(
                        () => _statusFilter = RequestApprovalStatus.approved,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _RequestFilterChip(
                      label: 'Rejected',
                      count: _countFor(RequestApprovalStatus.rejected),
                      color: AppColors.danger,
                      selected:
                          _statusFilter == RequestApprovalStatus.rejected,
                      onTap: () => setState(
                        () => _statusFilter = RequestApprovalStatus.rejected,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        sliver: filtered.isEmpty
            ? SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      'No requests match your criteria',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ),
              )
            : SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 480,
                  mainAxisExtent: 155,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final req = filtered[i];
                    final status = req.approvalStatusEnum;
                    return _RequestGridCard(
                      req: req,
                      status: status,
                      avatarBg: _avatarBg(status),
                      avatarFg: _avatarFg(status),
                      tone: _toneFor(status),
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

class _RequestGridCard extends StatelessWidget {
  const _RequestGridCard({
    required this.req,
    required this.status,
    required this.avatarBg,
    required this.avatarFg,
    required this.tone,
    required this.onTap,
  });

  final MaintenanceRequestModel req;
  final RequestApprovalStatus status;
  final Color avatarBg;
  final Color avatarFg;
  final StatusChipTone tone;
  final VoidCallback onTap;

  Color get _stripeColor {
    switch (status) {
      case RequestApprovalStatus.pending:
        return AppColors.warning;
      case RequestApprovalStatus.approved:
        return AppColors.statusCompleted;
      case RequestApprovalStatus.rejected:
        return AppColors.danger;
      case RequestApprovalStatus.unknown:
        return AppColors.border;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5, color: _stripeColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: avatarBg,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.handyman_outlined,
                              size: 19,
                              color: avatarFg,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  req.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                if (req.issueDescription.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    req.issueDescription,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              WorkOrderPriorityChip(
                                priority:
                                    WorkOrderPriority.fromCode(req.priority),
                              ),
                              const SizedBox(height: 4),
                              StatusChip(
                                label: status.label,
                                tone: tone,
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Divider(
                        height: 1,
                        color: AppColors.border.withValues(alpha: 0.6),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.local_shipping_outlined,
                                size: 14,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                req.unitNumber,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 13,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                req.requestedOn,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'View',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 16,
                                color: AppColors.primary,
                              ),
                            ],
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

