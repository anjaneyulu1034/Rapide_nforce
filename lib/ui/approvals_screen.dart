import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/core/constants/app_strings.dart';
import 'package:rapide_nforce/core/utils/api_feedback.dart';
import 'package:rapide_nforce/core/utils/app_toast.dart';
import 'package:rapide_nforce/models/maintenance_request_model.dart';
import 'package:rapide_nforce/services/approval_service.dart';
import 'package:rapide_nforce/ui/approvals/consent_approvals_tab.dart';
import 'package:rapide_nforce/ui/widgets/screen_state_builder.dart';
import 'package:rapide_nforce/ui/widgets/web_ui.dart';

class ApprovalsScreen extends StatefulWidget {
  const ApprovalsScreen({super.key});

  @override
  State<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends State<ApprovalsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;
  String? _error;
  List<MaintenanceRequestModel> _items = [];
  int? _actingId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
    final result = await ApprovalService.instance.fetchApprovals();
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

  Future<void> _act(MaintenanceRequestModel item, int status) async {
    setState(() => _actingId = item.id);
    final result = await ApprovalService.instance.approveRequest(
      id: item.id,
      status: status,
    );
    if (!mounted) return;
    setState(() => _actingId = null);

    if (!result.isSuccess) {
      ApiFeedback.showError(result, fallback: 'Action failed');
      return;
    }
    AppToast.showSuccess(
      status == 2 ? 'Request approved' : 'Request rejected',
    );
    _load();
  }

  Widget _buildLeadApprovals() {
    return ScreenStateBuilder(
      loading: _loading,
      error: _error,
      onRetry: _load,
      isEmpty: _items.isEmpty,
      emptyMessage: AppStrings.noData,
      emptyIcon: Icons.check_circle_outline,
      child: WebPageBody(
        onRefresh: _load,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _items.length,
          itemBuilder: (context, i) {
            final item = _items[i];
            final pending =
                item.approvalStatusEnum == RequestApprovalStatus.pending;
            final acting = _actingId == item.id;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderLight),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0D000000),
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.unitNumber} · ${item.issueDescription}',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (item.technicianName != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'By ${item.technicianName}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                    if (pending) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed:
                                  acting ? null : () => _act(item, 3),
                              child: const Text('Reject'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed:
                                  acting ? null : () => _act(item, 2),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary,
                              ),
                              child: acting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.white,
                                      ),
                                    )
                                  : const Text('Approve'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: TabBar(
          controller: _tabController,
          labelColor: AppColors.textPrimary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 14),
          tabs: const [
            Tab(text: 'Lead Approvals'),
            Tab(text: 'Consent Approvals'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildLeadApprovals(),
          const ConsentApprovalsTab(),
        ],
      ),
    );
  }
}

