import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/models/inventory_item_model.dart';
import 'package:rapide_nforce/services/inventory_service.dart';
import 'package:rapide_nforce/ui/widgets/list_empty_state.dart';
import 'package:rapide_nforce/ui/widgets/web_ui.dart';

enum MaintenanceLogTab { workOrders, inventory }

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key, this.initialTab = MaintenanceLogTab.workOrders});

  final MaintenanceLogTab initialTab;

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  late MaintenanceLogTab _tab = widget.initialTab;
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _search = '';

  bool _loading = true;
  String? _error;
  List<MaintenanceLogModel> _items = [];

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
      if (next == _search) return;
      setState(() => _search = next);
      _load();
    });
  }

  int get _logSourceFilter => _tab == MaintenanceLogTab.workOrders ? 1 : 2;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await InventoryService.instance.fetchLogs(
      page: 1,
      limit: 100,
      search: _search.isEmpty ? null : _search,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result.isSuccess) {
        final all = result.data ?? [];
        _items = all.where((l) => l.logSource == _logSourceFilter).toList();
      } else {
        _error = result.message ?? 'Failed to load logs';
        _items = [];
      }
    });
  }

  void _setTab(MaintenanceLogTab tab) {
    setState(() => _tab = tab);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: WebPageBody(
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: WebPageHeader(
                title: 'Maintenance Logs',
                subtitle: _tab == MaintenanceLogTab.workOrders
                    ? 'Work order change history'
                    : 'Inventory change history',
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: WebTabPills(
                  child: Row(
                    children: [
                      Expanded(
                        child: _LogTabButton(
                          label: 'Work Order Logs',
                          selected: _tab == MaintenanceLogTab.workOrders,
                          onTap: () => _setTab(MaintenanceLogTab.workOrders),
                        ),
                      ),
                      Expanded(
                        child: _LogTabButton(
                          label: 'Inventory Logs',
                          selected: _tab == MaintenanceLogTab.inventory,
                          onTap: () => _setTab(MaintenanceLogTab.inventory),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: WebSearchField(
                  controller: _searchController,
                  hintText: 'Search username or description…',
                  showClear: _search.isNotEmpty,
                  onClear: () {
                    _searchController.clear();
                    setState(() => _search = '');
                    _load();
                  },
                ),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SliverFillRemaining(child: Center(child: Text(_error!)))
            else if (_items.isEmpty)
              SliverFillRemaining(
                child: ListEmptyState(
                  message: _tab == MaintenanceLogTab.workOrders
                      ? 'No work order logs'
                      : 'No inventory logs',
                  icon: Icons.history_rounded,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final log = _items[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        child: ListTile(
                          leading: Icon(
                            Icons.history_rounded,
                            color: AppColors.primary,
                          ),
                          title: Text(
                            log.subject,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${log.changedField} · ${log.changedBy}\n${log.changedDate}',
                          ),
                          isThreeLine: true,
                        ),
                      );
                    },
                    childCount: _items.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LogTabButton extends StatelessWidget {
  const _LogTabButton({
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
