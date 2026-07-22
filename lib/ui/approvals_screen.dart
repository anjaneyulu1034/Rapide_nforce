import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/core/constants/app_gradients.dart';
import 'package:rapide_nforce/core/utils/api_feedback.dart';
import 'package:rapide_nforce/core/utils/app_toast.dart';
import 'package:rapide_nforce/core/utils/role_utils.dart';
import 'package:rapide_nforce/models/deferred_repair_model.dart';
import 'package:rapide_nforce/services/approval_service.dart';
import 'package:rapide_nforce/services/auth_service.dart';
import 'package:rapide_nforce/ui/approvals/approval_card.dart';
import 'package:rapide_nforce/ui/approvals/consent_approvals_tab.dart';
import 'package:rapide_nforce/ui/widgets/gradient_page_background.dart';
import 'package:rapide_nforce/ui/widgets/screen_state_builder.dart';
import 'package:rapide_nforce/ui/widgets/web_ui.dart';

class ApprovalsScreen extends StatefulWidget {
  const ApprovalsScreen({super.key});

  @override
  State<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends State<ApprovalsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;
  String? _error;
  List<DeferredRepairModel> _items = [];
  int? _actingId;

  // Consent Approvals is admin-only — Lead Technicians only deal with
  // deferred-repair approvals, matching web's separate, permission-gated
  // /consent-document-approvals route.
  bool get _showConsentTab =>
      isAdminRole(AuthService.instance.currentUser?.role);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _showConsentTab ? 2 : 1,
      vsync: this,
    );
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await ApprovalService.instance.fetchDeferredRepairs();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result.isSuccess) {
        _items = result.data ?? [];
      } else {
        _error = result.message ?? 'Failed to load approvals';
      }
    });
  }

  Future<void> _act(DeferredRepairModel item, bool approve) async {
    final notesController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${approve ? 'Approve' : 'Reject'} Deferred Repair',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to ${approve ? 'approve' : 'reject'} this deferred repair?',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              Text(
                'Notes (Optional)',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Add any relevant notes...',
                  filled: true,
                  fillColor: AppColors.inputFill,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: BorderSide(color: AppColors.border, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: approve
                            ? const Color(0xFF4B633D)
                            : AppColors.danger,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(approve ? 'Approve' : 'Reject'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true) return;

    setState(() => _actingId = item.id);
    final result = await ApprovalService.instance.updateDeferredRepairStatus(
      id: item.id,
      approve: approve,
      notes: notesController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _actingId = null);

    if (!result.isSuccess) {
      ApiFeedback.showError(result, fallback: 'Action failed');
      return;
    }
    AppToast.showSuccess(
      approve ? 'Deferred repair approved' : 'Deferred repair rejected',
    );
    _load();
  }

  static ({Color bg, Color fg}) _statusColors(String status) {
    switch (status) {
      case 'APPROVED':
        return (bg: AppColors.statEmeraldBgEnd, fg: AppColors.statEmeraldText);
      case 'REJECTED':
        return (bg: AppColors.danger.withValues(alpha: 0.12), fg: AppColors.danger);
      default:
        return (bg: AppColors.statOrangeBgEnd, fg: AppColors.statOrangeText);
    }
  }

  Widget _buildLeadApprovals() {
    return ScreenStateBuilder(
      loading: _loading,
      error: _error,
      onRetry: _load,
      isEmpty: _items.isEmpty,
      emptyMessage: 'No deferred repairs found',
      emptyIcon: Icons.check_circle_outline,
      child: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.card,
        onRefresh: _load,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          itemCount: _items.length,
          itemBuilder: (context, i) {
            final item = _items[i];
            final acting = _actingId == item.id;
            final colors = _statusColors(item.approvalStatus);
            final issue = (item.issueDescription ?? '').trim();

            return ApprovalCard(
              icon: Icons.build_rounded,
              iconBg: AppColors.statOrangeBorder,
              iconColor: AppColors.statOrangeText,
              title: item.workOrderLabel,
              subtitle: issue.isNotEmpty ? issue : 'No issue description',
              statusLabel: item.approvalStatus,
              statusBg: colors.bg,
              statusFg: colors.fg,
              metaChips: [
                if ((item.unitNumber ?? '').trim().isNotEmpty)
                  MetaChip(
                    icon: Icons.local_shipping_outlined,
                    label: item.unitNumber!,
                  ),
                if ((item.odometer ?? '').trim().isNotEmpty)
                  MetaChip(icon: Icons.speed_outlined, label: '${item.odometer} km'),
                if ((item.invoiceNumber ?? '').trim().isNotEmpty)
                  MetaChip(
                    icon: Icons.receipt_long_outlined,
                    label: item.invoiceNumber!,
                  ),
                if ((item.usageDescription ?? '').trim().isNotEmpty)
                  MetaChip(icon: Icons.notes_outlined, label: item.usageDescription!),
                MetaChip(icon: Icons.build_circle_outlined, label: item.repairStatus),
              ],
              pending: item.isPending,
              acting: acting,
              onApprove: () => _act(item, true),
              onReject: () => _act(item, false),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GradientPageBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const WebPageHeader(
                title: 'Approvals',
                subtitle: 'Manage and approve deferred repairs.',
              ),
              if (_showConsentTab) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: _ApprovalsTabBar(controller: _tabController),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildLeadApprovals(),
                      const ConsentApprovalsTab(),
                    ],
                  ),
                ),
              ] else ...[
                const SizedBox(height: 12),
                Expanded(child: _buildLeadApprovals()),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ApprovalsTabBar extends StatelessWidget {
  const _ApprovalsTabBar({required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: TabBar(
        controller: controller,
        splashBorderRadius: BorderRadius.circular(10),
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          gradient: AppGradients.selectedTab,
          borderRadius: BorderRadius.circular(10),
        ),
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        tabs: const [
          Tab(text: 'Lead Approvals'),
          Tab(text: 'Consent Approvals'),
        ],
      ),
    );
  }
}
