import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/core/constants/app_strings.dart';
import 'package:rapide_nforce/core/enums/app_route.dart';
import 'package:rapide_nforce/models/dashboard_model.dart';
import 'package:rapide_nforce/models/inventory_item_model.dart';
import 'package:rapide_nforce/models/work_order_model.dart';
import 'package:rapide_nforce/core/utils/role_utils.dart';
import 'package:rapide_nforce/services/auth_service.dart';
import 'package:rapide_nforce/services/dashboard_service.dart';
import 'package:rapide_nforce/ui/dashboard/dashboard_analytics_cards.dart';
import 'package:rapide_nforce/ui/widgets/screen_state_builder.dart';
import 'package:rapide_nforce/ui/widgets/web_ui.dart';
import 'package:rapide_nforce/ui/work_orders/work_order_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.onNavigate});

  final ValueChanged<AppRoute>? onNavigate;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DashboardModel? _data;
  bool _loading = true;
  String? _error;

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
    final result = await DashboardService.instance.fetchDashboard();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result.isSuccess && result.data != null) {
        _data = result.data;
      } else {
        _data = null;
        _error = result.message ?? 'Failed to load dashboard';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return ScreenStateBuilder(
      loading: _loading,
      error: _error,
      onRetry: _load,
      child: data == null ? const SizedBox.shrink() : _buildContent(data),
    );
  }

  Widget _buildContent(DashboardModel data) {
    final isLead = isLeadTechnicianRole(AuthService.instance.currentUser?.role);
    return WebListPage(
      title: '',
      onRefresh: _load,
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.38,
            children: [
              WebStatCard(
                label: isLead ? 'Team Open WOs' : AppStrings.openWorkOrders,
                value: '${data.openWorkOrders}',
                linkLabel: 'View work orders',
                icon: Icons.build_outlined,
                gradientStart: AppColors.statBlueBgStart,
                gradientEnd: AppColors.statBlueBgEnd,
                borderColor: AppColors.statBlueBorder,
                labelColor: AppColors.statBlueText,
                valueColor: AppColors.statBlueValue,
                iconBg: AppColors.statBlueBorder,
                iconColor: Colors.white,
                linkColor: AppColors.statBlueText,
                onTap: () => widget.onNavigate?.call(AppRoute.maintenance),
              ),
              WebStatCard(
                label: AppStrings.partsInStock,
                value: '${data.partsInStock}',
                linkLabel: 'View inventory',
                icon: Icons.inventory_2_outlined,
                gradientStart: AppColors.statOrangeBgStart,
                gradientEnd: AppColors.statOrangeBgEnd,
                borderColor: AppColors.statOrangeBorder,
                labelColor: AppColors.statOrangeText,
                valueColor: AppColors.statOrangeValue,
                iconBg: AppColors.statOrangeBorder,
                iconColor: Colors.white,
                linkColor: AppColors.statOrangeText,
                onTap: () => widget.onNavigate?.call(AppRoute.inventory),
              ),
              WebStatCard(
                label: isLead ? 'Pending Approvals' : AppStrings.pendingRequests,
                value: '${data.pendingRequests}',
                linkLabel: isLead ? 'Review approvals' : 'View requests',
                icon: Icons.assignment_outlined,
                gradientStart: AppColors.statRoseBgStart,
                gradientEnd: AppColors.statRoseBgEnd,
                borderColor: AppColors.statRoseBorder,
                labelColor: AppColors.statRoseText,
                valueColor: AppColors.statRoseValue,
                iconBg: AppColors.statRoseBorder,
                iconColor: Colors.white,
                linkColor: AppColors.statRoseText,
                onTap: () => widget.onNavigate?.call(AppRoute.requests),
              ),
              WebStatCard(
                label: AppStrings.completedMtd,
                value: '${data.completedMtd}',
                linkLabel: 'View history',
                icon: Icons.check_circle_outline,
                gradientStart: AppColors.statEmeraldBgStart,
                gradientEnd: AppColors.statEmeraldBgEnd,
                borderColor: AppColors.statEmeraldBorder,
                labelColor: AppColors.statEmeraldText,
                valueColor: AppColors.statEmeraldValue,
                iconBg: AppColors.statEmeraldBorder,
                iconColor: Colors.white,
                linkColor: AppColors.statEmeraldText,
                onTap: () => widget.onNavigate?.call(AppRoute.maintenance),
              ),
            ],
          ),
          const SizedBox(height: 24),
          WebSectionCard(
            title: isLead ? 'Team Work Orders' : 'Recent Work Orders',
            action: TextButton(
              onPressed: () => widget.onNavigate?.call(AppRoute.maintenance),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'View All',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.chromeBlue,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: AppColors.chromeBlue,
                  ),
                ],
              ),
            ),
            child: data.recentWorkOrders.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'No recent work orders',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : Column(
                    children: data.recentWorkOrders.map((order) {
                      return _WorkOrderTile(
                        order: order,
                        onTap: () async {
                          if (order.id > 0) {
                            final result =
                                await Navigator.of(context).push<bool>(
                              MaterialPageRoute(
                                builder: (_) =>
                                    WorkOrderDetailScreen(workOrderId: order.id),
                              ),
                            );
                            if (result == true || mounted) {
                              _load();
                            }
                          } else {
                            widget.onNavigate?.call(AppRoute.maintenance);
                          }
                        },
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 24),
          WebSectionCard(
            title: 'Inventory Usage Status',
            action: TextButton(
              onPressed: () => widget.onNavigate?.call(AppRoute.inventory),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'View All',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.chromeBlue,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: AppColors.chromeBlue,
                  ),
                ],
              ),
            ),
            child: data.inventoryItems.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'No inventory data',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : Column(
                    children: data.inventoryItems.map((item) {
                      return _InventoryTile(
                        item: item,
                        onTap: () =>
                            widget.onNavigate?.call(AppRoute.inventory),
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 24),
          WorkOrderStatusDistributionCard(workOrders: data.allWorkOrders),
          const SizedBox(height: 24),
          WorkActivityOverviewCard(workOrders: data.allWorkOrders),
          const SizedBox(height: 24),
          PartsInventoryStatusCard(
            inventoryItems: data.allInventoryItems,
            onManage: () => widget.onNavigate?.call(AppRoute.inventory),
          ),
          const SizedBox(height: 24),
          PerformanceMetricsCard(
            workOrders: data.allWorkOrders,
            isLead: isLead,
          ),
          const SizedBox(height: 56),
        ]),
      ),
    );
  }
}

class _WorkOrderTile extends StatelessWidget {
  const _WorkOrderTile({required this.order, this.onTap});

  final WorkOrderModel order;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final priority = order.priority ?? WorkOrderPriority.medium;
    final titleText = order.workOrderNumber.isNotEmpty
        ? order.workOrderNumber
        : (order.unitName.isNotEmpty ? order.unitName : 'WO #${order.id}');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: AppColors.border.withValues(alpha: 0.5),
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 38,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: priority.accentColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            titleText,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (order.unitName.isNotEmpty &&
                            order.workOrderNumber.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            order.unitName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      order.description.isNotEmpty
                          ? order.description
                          : 'No description provided',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: order.status.backgroundColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: order.status.textColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  order.statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: order.status.textColor,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InventoryTile extends StatelessWidget {
  const _InventoryTile({required this.item, this.onTap});

  final InventoryItemModel item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (iconBg, iconColor, statusBg, statusColor, statusLabel) =
        switch (item.stockLevel) {
      StockLevel.inStock => (
          const Color(0xFFDCFCE7),
          const Color(0xFF15803D),
          const Color(0xFFDCFCE7),
          const Color(0xFF15803D),
          'In Stock'
        ),
      StockLevel.low => (
          const Color(0xFFFEF3C7),
          const Color(0xFFB45309),
          const Color(0xFFFEF3C7),
          const Color(0xFFB45309),
          'Low Stock'
        ),
      StockLevel.outOfStock => (
          const Color(0xFFFEE2E2),
          const Color(0xFFB91C1C),
          const Color(0xFFFEE2E2),
          const Color(0xFFB91C1C),
          'Out of Stock'
        ),
    };

    final hasCode = item.code.isNotEmpty && item.code != item.name;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: AppColors.border.withValues(alpha: 0.4),
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  item.stockLevel == StockLevel.low
                      ? Icons.warning_amber_rounded
                      : item.stockLevel == StockLevel.outOfStock
                          ? Icons.error_outline_rounded
                          : Icons.inventory_2_rounded,
                  size: 20,
                  color: iconColor,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (hasCode) ...[
                          Text(
                            item.code,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          if (item.lowStockTrigger > 0)
                            Text(
                              ' • ',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textTertiary,
                              ),
                            ),
                        ],
                        if (item.lowStockTrigger > 0)
                          Text(
                            'Min alert: ${item.lowStockTrigger}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.quantity} in stock',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

