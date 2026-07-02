import 'package:flutter/material.dart';
import 'package:rapide_nforce/ui/inventory_screen.dart';
import 'package:rapide_nforce/ui/logs_screen.dart';
import 'package:rapide_nforce/ui/work_orders/work_orders_screen.dart';
import 'package:rapide_nforce/ui/widgets/gradient_page_background.dart';
import 'package:rapide_nforce/ui/widgets/web_ui.dart';

/// Maintenance hub — matches web `/maintenance` with Work Orders | Inventory | Logs tabs.
class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  late int _index = widget.initialIndex;

  @override
  Widget build(BuildContext context) {
    return GradientPageBackground(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: WebTabPills(
              child: Row(
                children: [
                  Expanded(
                    child: _HubTab(
                      label: 'Work Orders',
                      selected: _index == 0,
                      onTap: () => setState(() => _index = 0),
                    ),
                  ),
                  Expanded(
                    child: _HubTab(
                      label: 'Inventory',
                      selected: _index == 1,
                      onTap: () => setState(() => _index = 1),
                    ),
                  ),
                  Expanded(
                    child: _HubTab(
                      label: 'Logs',
                      selected: _index == 2,
                      onTap: () => setState(() => _index = 2),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _index,
              children: const [
                WorkOrdersScreen(),
                InventoryScreen(),
                LogsScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HubTab extends StatelessWidget {
  const _HubTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return WebTabPill(label: label, selected: selected, onTap: onTap);
  }
}
