import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/core/constants/app_strings.dart';
import 'package:rapide_nforce/core/utils/app_toast.dart';
import 'package:rapide_nforce/core/utils/role_utils.dart';
import 'package:rapide_nforce/models/maintenance_request_model.dart';
import 'package:rapide_nforce/services/auth_service.dart';
import 'package:rapide_nforce/services/request_service.dart';
import 'package:rapide_nforce/ui/approvals/approval_card.dart';
import 'package:rapide_nforce/ui/widgets/screen_state_builder.dart';
import 'package:rapide_nforce/ui/widgets/web_ui.dart';
import 'package:rapide_nforce/ui/work_orders/work_order_detail_screen.dart';

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

  Future<void> _load({bool isRefresh = false}) async {
    // A pull-to-refresh keeps the current list on screen and only shows the
    // RefreshIndicator's own spinner — blanking the whole screen back to the
    // full loading state on every refresh is what made this screen feel slow.
    if (!isRefresh) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    final isLead = isLeadTechnicianRole(AuthService.instance.currentUser?.role);
    final result = isLead
        ? await RequestService.instance.fetchApprovals()
        : await RequestService.instance.fetchRequests();
    if (!mounted) return;

    if (result.isSuccess) {
      setState(() {
        _loading = false;
        _error = null;
        _items = result.data ?? [];
      });
      return;
    }

    if (isRefresh) {
      // Keep whatever is already on screen; a full-page error state would
      // otherwise erase a perfectly good list just because a refresh failed.
      setState(() => _loading = false);
      AppToast.showError(result.message ?? 'Failed to refresh requests');
      return;
    }

    setState(() {
      _loading = false;
      _error = result.message ?? 'Failed to load requests';
    });
  }

  Future<void> _refresh() => _load(isRefresh: true);

  int _countFor(RequestApprovalStatus? status) {
    if (status == null) return _items.length;
    return _items.where((r) => r.approvalStatusEnum == status).length;
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
        final matchesIssue = r.issueDescription.toLowerCase().contains(
          searchLower,
        );
        final matchesTech = (r.technicianName ?? '').toLowerCase().contains(
          searchLower,
        );
        return matchesTitle || matchesUnit || matchesIssue || matchesTech;
      }
      return true;
    }).toList();

    return ScreenStateBuilder(
      loading: _loading,
      error: _error,
      onRetry: _load,
      onRefresh: _refresh,
      isEmpty: _items.isEmpty,
      emptyMessage: AppStrings.noData,
      emptyIcon: Icons.handyman_outlined,
      child: WebListPage(
        title: '',
        onRefresh: _refresh,
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
            : SliverToBoxAdapter(
                child: ActionCardFlow(
                  cards: [
                    for (final req in filtered)
                      Builder(
                        builder: (context) {
                          final status = req.approvalStatusEnum;
                          return ActionCard(
                            icon: Icons.handyman_outlined,
                            iconBg: _avatarBg(status),
                            iconColor: _avatarFg(status),
                            title: req.title,
                            subtitle: req.issueDescription,
                            statusLabel: status.label,
                            statusBg: _avatarBg(status),
                            statusFg: _avatarFg(status),
                            stripeColor: _avatarFg(status),
                            metaChips: [
                              MetaChip(
                                icon: Icons.local_shipping_outlined,
                                label: req.unitNumber,
                              ),
                              MetaChip(
                                icon: Icons.calendar_today_outlined,
                                label: req.requestedOn,
                              ),
                              if ((req.technicianName ?? '').trim().isNotEmpty)
                                MetaChip(
                                  icon: Icons.person_outline,
                                  label: req.technicianName!,
                                ),
                            ],
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => WorkOrderDetailScreen(
                                    workOrderId: req.id,
                                  ),
                                ),
                              );
                            },
                            viewLabel: 'View',
                          );
                        },
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
          border: Border.all(color: selected ? color : AppColors.border),
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
