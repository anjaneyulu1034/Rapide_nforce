import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/core/constants/app_strings.dart';
import 'package:rapide_nforce/core/enums/app_route.dart';
import 'package:rapide_nforce/models/dashboard_model.dart';
import 'package:rapide_nforce/models/inventory_item_model.dart';
import 'package:rapide_nforce/models/work_order_model.dart';
import 'package:rapide_nforce/services/dashboard_service.dart';
import 'package:rapide_nforce/ui/widgets/screen_state_builder.dart';
import 'package:rapide_nforce/ui/widgets/web_ui.dart';

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
    return WebListPage(
      title: 'Dashboard',
      subtitle: 'Overview of your work orders and inventory',
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
            childAspectRatio: 0.82,
            children: [
              WebStatCard(
                label: AppStrings.openWorkOrders,
                value: '${data.openWorkOrders}',
                linkLabel: 'View work orders',
                icon: Icons.build_outlined,
                gradientStart: AppColors.statBlueBgStart,
                gradientEnd: AppColors.statBlueBgEnd,
                borderColor: AppColors.statBlueBorder,
                labelColor: AppColors.statBlueText,
                valueColor: AppColors.statBlueValue,
                iconBg: AppColors.statBlueBorder.withValues(alpha: 0.5),
                linkColor: AppColors.gold,
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
                iconBg: AppColors.statOrangeBorder.withValues(alpha: 0.5),
                linkColor: AppColors.primary,
                onTap: () => widget.onNavigate?.call(AppRoute.inventory),
              ),
              WebStatCard(
                label: AppStrings.pendingRequests,
                value: '${data.pendingRequests}',
                linkLabel: 'View requests',
                icon: Icons.assignment_outlined,
                gradientStart: AppColors.statRoseBgStart,
                gradientEnd: AppColors.statRoseBgEnd,
                borderColor: AppColors.statRoseBorder,
                labelColor: AppColors.statRoseText,
                valueColor: AppColors.statRoseValue,
                iconBg: AppColors.statRoseBorder.withValues(alpha: 0.5),
                linkColor: const Color(0xFFFF8FAB),
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
                iconBg: AppColors.statEmeraldBorder.withValues(alpha: 0.5),
                linkColor: AppColors.statEmeraldText,
                onTap: () => widget.onNavigate?.call(AppRoute.maintenance),
              ),
            ],
          ),
          const SizedBox(height: 32),
          WebSectionCard(
            title: 'Recent Work Orders',
            child: data.recentWorkOrders.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'No recent work orders',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : Column(
                    children: data.recentWorkOrders
                        .map(_WorkOrderTile.new)
                        .toList(),
                  ),
          ),
          const SizedBox(height: 32),
          WebSectionCard(
            title: 'Inventory Usage Status',
            child: data.inventoryItems.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'No inventory data',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : Column(
                    children:
                        data.inventoryItems.map(_InventoryTile.new).toList(),
                  ),
          ),
          const SizedBox(height: 56),
        ]),
      ),
    );
  }
}

class _WorkOrderTile extends StatelessWidget {
  const _WorkOrderTile(this.order);

  final WorkOrderModel order;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.unitName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.gold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  order.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: order.status.backgroundColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              order.statusLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: order.status.textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InventoryTile extends StatelessWidget {
  const _InventoryTile(this.item);

  final InventoryItemModel item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              item.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            'Qty ${item.quantity}',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
