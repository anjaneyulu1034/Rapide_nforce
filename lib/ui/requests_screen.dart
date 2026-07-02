import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/core/constants/app_strings.dart';
import 'package:rapide_nforce/models/maintenance_request_model.dart';
import 'package:rapide_nforce/services/request_service.dart';
import 'package:rapide_nforce/ui/work_orders/work_order_detail_screen.dart';
import 'package:rapide_nforce/ui/widgets/fleet_list_card.dart';
import 'package:rapide_nforce/ui/widgets/screen_state_builder.dart';
import 'package:rapide_nforce/ui/widgets/web_ui.dart';

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  bool _loading = true;
  String? _error;
  List<MaintenanceRequestModel> _items = [];

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

  Color _color(RequestApprovalStatus status) {
    switch (status) {
      case RequestApprovalStatus.pending:
        return AppColors.warning;
      case RequestApprovalStatus.approved:
        return AppColors.primary;
      case RequestApprovalStatus.rejected:
        return AppColors.danger;
      case RequestApprovalStatus.unknown:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
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
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) {
              final req = _items[i];
              return FleetListCard(
                title: req.title,
                subtitle: '${req.unitNumber} · ${req.requestedOn}',
                trailing: Text(
                  req.approvalStatusEnum.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _color(req.approvalStatusEnum),
                    fontSize: 12,
                  ),
                ),
                leading: const Icon(Icons.handyman_outlined),
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
            childCount: _items.length,
          ),
        ),
      ),
    );
  }
}
