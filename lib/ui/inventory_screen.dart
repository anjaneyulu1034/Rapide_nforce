import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/core/utils/app_toast.dart';
import 'package:rapide_nforce/core/utils/role_utils.dart';
import 'package:rapide_nforce/models/part_models.dart';
import 'package:rapide_nforce/services/auth_service.dart';
import 'package:rapide_nforce/services/inventory_service.dart';
import 'package:rapide_nforce/services/permission_service.dart';
import 'package:rapide_nforce/ui/inventory/add_part_screen.dart';
import 'package:rapide_nforce/ui/inventory/part_detail_screen.dart';
import 'package:rapide_nforce/ui/inventory/part_form_screen.dart';
import 'package:rapide_nforce/ui/inventory/part_type_form_screen.dart';
import 'package:rapide_nforce/ui/inventory/widgets/inventory_stock_badge.dart';
import 'package:rapide_nforce/ui/inventory/widgets/inventory_value_summary_strip.dart';
import 'package:rapide_nforce/ui/widgets/icon_only_button.dart';
import 'package:rapide_nforce/ui/widgets/list_empty_state.dart';
import 'package:rapide_nforce/ui/widgets/status_badge.dart';
import 'package:rapide_nforce/ui/widgets/web_ui.dart';
import 'package:rapide_nforce/ui/work_orders/work_order_detail_screen.dart';

/// One labeled value in a Parts/Part Types card's info grid — mirrors the
/// Work Order card's `_GridCell` pattern (icon + small caps label, then the
/// bold value). Callers skip this entirely when there's nothing to show
/// rather than rendering a placeholder like "—" — a genuinely missing value
/// is not information worth a whole grid cell. Shared (top-level, not a
/// method) since both the Parts and Part Types tabs use it from separate
/// State classes.
Widget _partInfoCell({
  required IconData icon,
  required String label,
  required String value,
  Color? valueColor,
  bool isLink = false,
  VoidCallback? onTap,
  // Set by the caller when this cell is the second (right) slot of a pair —
  // pins the value to the cell's right edge instead of its left, so the
  // first field reads flush-left and the second reads flush-right (matching
  // the card header's Stock/Part-# corners), with whatever's unused in the
  // middle left as open space rather than looking accidental.
  bool alignEnd = false,
}) {
  final content = Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        mainAxisAlignment: alignEnd
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          Icon(icon, size: 11, color: AppColors.primary),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: alignEnd ? TextAlign.right : TextAlign.left,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 3),
      Align(
        alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
        child: Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color:
                valueColor ??
                (isLink ? AppColors.chromeBlue : AppColors.textPrimary),
            decoration: isLink ? TextDecoration.underline : null,
            decorationColor: AppColors.chromeBlue,
          ),
        ),
      ),
    ],
  );
  if (onTap == null) return content;
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(6),
    child: content,
  );
}

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<InventoryScreen> createState() => InventoryScreenState();
}

class InventoryScreenState extends State<InventoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey<_PartTypesTabState> _typesKey =
      GlobalKey<_PartTypesTabState>();
  final GlobalKey<_PartsTabState> _partsKey = GlobalKey<_PartsTabState>();

  String? _partsInitialSearch;
  int? _partsInitialTypeId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void openCurrentAdd() {
    if (_tabController.index == 0) {
      _typesKey.currentState?.openAdd();
    } else {
      _partsKey.currentState?.openAdd();
    }
  }

  void _viewPartsForType(String name, int id) {
    setState(() {
      _partsInitialSearch = name;
      _partsInitialTypeId = id;
    });
    _tabController.animateTo(1);
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
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.normal,
            fontSize: 14,
          ),
          tabs: const [
            Tab(text: 'Parts Overview'),
            Tab(text: 'Parts'),
          ],
        ),
      ),
      body: Column(
        children: [
          const InventoryValueSummaryStrip(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _PartTypesTab(key: _typesKey, onViewParts: _viewPartsForType),
                _PartsTab(
                  key: _partsKey,
                  initialSearch: _partsInitialSearch,
                  initialTypeId: _partsInitialTypeId,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 1. PARTS OVERVIEW TAB (Part Types)
// ---------------------------------------------------------------------------

class _PartTypesTab extends StatefulWidget {
  const _PartTypesTab({super.key, required this.onViewParts});

  final void Function(String name, int id) onViewParts;

  @override
  State<_PartTypesTab> createState() => _PartTypesTabState();
}

class _PartTypesTabState extends State<_PartTypesTab> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;

  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  List<PartTypeModel> _items = [];
  int _page = 1;
  final int _limit = 15;
  int _total = 0;
  int _totalPages = 1;
  String _search = '';
  String? _sortKey;
  String? _sortOrder;

  bool get _isAdminOrAbove =>
      isAdminRole(AuthService.instance.currentUser?.role);

  MenuPermissions _permissions = const MenuPermissions();

  bool get _canCreate => AuthService.instance.currentUser != null;
  bool get _canUpdate => _isAdminOrAbove || _permissions.canUpdate;
  bool get _canDelete => _isAdminOrAbove || _permissions.canDelete;

  static const Map<String, String> _sortOptions = {
    'name': 'Name',
    'count': 'Quantity',
    'status': 'Status',
    'lowStockTrigger': 'Low Stock Trigger',
    'createdOn': 'Created On',
    'createdBy': 'Created By',
  };

  String get _companyFallback {
    final user = AuthService.instance.currentUser;
    return user?.territory ?? '-';
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
    _load();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    final result = await PermissionService.instance.getMenuPermissions(
      menuUrl: '/inventory',
      menuName: 'Inventory',
    );
    if (!mounted) return;
    if (result.isSuccess && result.data != null) {
      setState(() => _permissions = result.data!);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (maxScroll - currentScroll <= 400) {
      _loadMore();
    }
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      final next = _searchController.text.trim();
      if (next == _search) return;
      setState(() {
        _search = next;
        _page = 1;
      });
      _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _page = 1;
      _items = [];
    });
    final result = await InventoryService.instance.fetchPartTypes(
      page: 1,
      limit: _limit,
      search: _search.isEmpty ? null : _search,
      sortKey: _sortKey,
      sortOrder: _sortOrder,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result.isSuccess && result.data != null) {
        _items = result.data!.items;
        _total = result.data!.total;
        _totalPages = result.data!.totalPages;
        _page = result.data!.page;
      } else {
        _error = result.message ?? 'Failed to load part types';
      }
    });
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || _page >= _totalPages) return;
    setState(() => _loadingMore = true);
    final nextPage = _page + 1;
    final result = await InventoryService.instance.fetchPartTypes(
      page: nextPage,
      limit: _limit,
      search: _search.isEmpty ? null : _search,
      sortKey: _sortKey,
      sortOrder: _sortOrder,
    );
    if (!mounted) return;
    setState(() {
      _loadingMore = false;
      if (result.isSuccess && result.data != null) {
        _items.addAll(result.data!.items);
        _total = result.data!.total;
        _totalPages = result.data!.totalPages;
        _page = result.data!.page;
      }
    });
  }

  Future<void> openAdd() async {
    if (!_canCreate) {
      AppToast.showError('You do not have permission to add part types.');
      return;
    }
    final changed = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const PartTypeFormScreen()));
    if (changed == true) _load();
  }

  Future<void> _delete(PartTypeModel item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(
          'Delete part type?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Remove "${item.name}"? This cannot be undone.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final result = await InventoryService.instance.deletePartType(item.id);
    if (!result.isSuccess) {
      AppToast.showError(result.message ?? 'Delete failed');
      return;
    }
    AppToast.showSuccess('Deleted');
    _load();
  }

  void _onSortSelected(String key) {
    setState(() {
      if (key.isEmpty) {
        _sortKey = null;
        _sortOrder = null;
      } else if (_sortKey == key) {
        _sortOrder = _sortOrder == 'asc' ? 'desc' : 'asc';
      } else {
        _sortKey = key;
        _sortOrder = 'asc';
      }
      _page = 1;
    });
    _load();
  }

  Widget _buildSortButton() {
    final hasSort = _sortKey != null;
    return PopupMenuButton<String>(
      tooltip: 'Sort',
      onSelected: _onSortSelected,
      icon: Icon(
        hasSort && _sortOrder == 'desc'
            ? Icons.arrow_downward
            : Icons.arrow_upward,
        size: 18,
        color: hasSort ? AppColors.primary : AppColors.textSecondary,
      ),
      itemBuilder: (context) => [
        if (hasSort)
          const PopupMenuItem<String>(value: '', child: Text('Clear sort')),
        ..._sortOptions.entries.map((e) {
          final selected = _sortKey == e.key;
          return PopupMenuItem<String>(
            value: e.key,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  e.value,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                    color: selected ? AppColors.primary : null,
                  ),
                ),
                if (selected)
                  Icon(
                    _sortOrder == 'desc'
                        ? Icons.arrow_downward
                        : Icons.arrow_upward,
                    size: 14,
                    color: AppColors.primary,
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCard(PartTypeModel item) {
    final company = item.companyName?.trim().isNotEmpty == true
        ? item.companyName!
        : _companyFallback;
    final tone = stockLevelTone(item.stockLevel);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow.withValues(alpha: 0.35),
            blurRadius: 16,
            spreadRadius: 1,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PartTypeDetailScreen(
                  partType: item,
                  onChanged: _load,
                  canDelete: _canDelete,
                  canUpdate: _canUpdate,
                ),
              ),
            );
          },
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 5, color: StatusBadgeColors.accent(tone)),
                Expanded(child: _partTypeCardBody(item, company)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _partTypeCardBody(PartTypeModel item, String company) {
    final toneColor = StatusBadgeColors.text(stockLevelTone(item.stockLevel));
    final cellBuilders = <Widget Function({required bool alignEnd})>[
      ({required alignEnd}) => _partInfoCell(
        icon: Icons.inventory_2_outlined,
        label: 'COUNT',
        value: '${item.count}',
        isLink: true,
        onTap: () => widget.onViewParts(item.name, item.id),
        alignEnd: alignEnd,
      ),
      ({required alignEnd}) => _partInfoCell(
        icon: Icons.monetization_on_outlined,
        label: 'TOTAL COST',
        value: '\$${(item.totalCost ?? 0).toStringAsFixed(2)}',
        alignEnd: alignEnd,
      ),
      ({required alignEnd}) => _partInfoCell(
        icon: Icons.business_outlined,
        label: 'COMPANY',
        value: company,
        alignEnd: alignEnd,
      ),
      ({required alignEnd}) => _partInfoCell(
        icon: Icons.warning_amber_outlined,
        label: 'LOW STOCK TRIGGER',
        value: '${item.lowStockTrigger}',
        alignEnd: alignEnd,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: stock status, with the actual quantity right under it.
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  InventoryStockBadge(level: item.stockLevel, compact: true),
                  const SizedBox(height: 4),
                  Text(
                    'Qty: ${item.totalQuantity ?? item.count}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: toneColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              // Right: actions, with the part type name right under them —
              // pinned to the card's full right edge.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_canUpdate)
                          IconOnlyButton(
                            icon: Icons.edit,
                            color: AppColors.chromeBlue,
                            onTap: () async {
                              final ok = await Navigator.of(context).push<bool>(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      PartTypeFormScreen(partType: item),
                                ),
                              );
                              if (ok == true) _load();
                            },
                          ),
                        if (_canDelete)
                          IconOnlyButton(
                            icon: Icons.delete_outline,
                            danger: true,
                            onTap: () => _delete(item),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    RichText(
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'PART TYPE # ',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                              letterSpacing: 0.3,
                            ),
                          ),
                          TextSpan(
                            text: item.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(
            height: 1,
            thickness: 1,
            color: AppColors.textSecondary.withValues(alpha: 0.12),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < cellBuilders.length; i += 2)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // First field pins left, second pins right (its value is
                  // right-aligned via `alignEnd`) — matching the card
                  // header's Stock/Part-# corners — with whatever's unused
                  // between them left as open space instead of the second
                  // field just sitting wherever the halfway mark falls.
                  Expanded(child: cellBuilders[i](alignEnd: false)),
                  if (i + 1 < cellBuilders.length) ...[
                    const SizedBox(width: 12),
                    Expanded(child: cellBuilders[i + 1](alignEnd: true)),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WebPageBody(
      onRefresh: _load,
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: WebSearchField(
                  controller: _searchController,
                  hintText: 'Search by name or creator...',
                  showClear: _search.isNotEmpty,
                  onClear: () {
                    _searchController.clear();
                    setState(() {
                      _search = '';
                      _page = 1;
                    });
                    _load();
                  },
                ),
              ),
              const SizedBox(width: 8),
              _buildSortButton(),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Parts Overview',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '$_total Total',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            )
          else if (_items.isEmpty)
            ListEmptyState(
              message: _search.isNotEmpty
                  ? 'No part types match your search'
                  : 'No part types found',
              icon: Icons.inventory_2_outlined,
            )
          else ...[
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 600) {
                  return Column(
                    children: _items.map((item) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildCard(item),
                      );
                    }).toList(),
                  );
                } else {
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _items.length,
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 500,
                          mainAxisExtent: 310,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                    itemBuilder: (context, i) {
                      return _buildCard(_items[i]);
                    },
                  );
                }
              },
            ),
            const SizedBox(height: 12),
            if (_loadingMore)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_page >= _totalPages && _items.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'All $_total part types loaded',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2. PARTS TAB
// ---------------------------------------------------------------------------

class _PartsTab extends StatefulWidget {
  const _PartsTab({super.key, this.initialSearch, this.initialTypeId});

  final String? initialSearch;
  final int? initialTypeId;

  @override
  State<_PartsTab> createState() => _PartsTabState();
}

class _PartsTabState extends State<_PartsTab> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;

  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  List<PartModel> _items = [];
  int _page = 1;
  final int _limit = 15;
  int _total = 0;
  int _totalPages = 1;
  String _search = '';
  int? _typeId;
  String? _sortKey;
  String? _sortOrder;

  bool get _isAdminOrAbove =>
      isAdminRole(AuthService.instance.currentUser?.role);

  MenuPermissions _permissions = const MenuPermissions();

  bool get _canCreate => AuthService.instance.currentUser != null;
  bool get _canUpdate => _isAdminOrAbove || _permissions.canUpdate;
  bool get _canDelete => _isAdminOrAbove || _permissions.canDelete;

  static const Map<String, String> _sortOptions = {
    'part_type_name': 'Part Type',
    'code': 'Code',
    'createdOn': 'Created On',
    'createdBy': 'Created By',
  };

  @override
  void initState() {
    super.initState();
    _search = widget.initialSearch ?? '';
    _typeId = widget.initialTypeId;
    _searchController.text = _search;
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
    _load();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    final result = await PermissionService.instance.getMenuPermissions(
      menuUrl: '/inventory',
      menuName: 'Inventory',
    );
    if (!mounted) return;
    if (result.isSuccess && result.data != null) {
      setState(() => _permissions = result.data!);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (maxScroll - currentScroll <= 400) {
      _loadMore();
    }
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      final next = _searchController.text.trim();
      if (next == _search) return;
      setState(() {
        _search = next;
        _typeId = null;
        _page = 1;
      });
      _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _page = 1;
      _items = [];
    });
    final result = await InventoryService.instance.fetchParts(
      page: 1,
      limit: _limit,
      search: _search.isEmpty ? null : _search,
      typeId: _typeId,
      sortKey: _sortKey,
      sortOrder: _sortOrder,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result.isSuccess && result.data != null) {
        _items = result.data!.items;
        _total = result.data!.total;
        _totalPages = result.data!.totalPages;
        _page = result.data!.page;
      } else {
        _error = result.message ?? 'Failed to load parts';
      }
    });
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || _page >= _totalPages) return;
    setState(() => _loadingMore = true);
    final nextPage = _page + 1;
    final result = await InventoryService.instance.fetchParts(
      page: nextPage,
      limit: _limit,
      search: _search.isEmpty ? null : _search,
      typeId: _typeId,
      sortKey: _sortKey,
      sortOrder: _sortOrder,
    );
    if (!mounted) return;
    setState(() {
      _loadingMore = false;
      if (result.isSuccess && result.data != null) {
        _items.addAll(result.data!.items);
        _total = result.data!.total;
        _totalPages = result.data!.totalPages;
        _page = result.data!.page;
      }
    });
  }

  Future<void> openAdd() async {
    if (!_canCreate) {
      AppToast.showError('You do not have permission to add parts.');
      return;
    }
    final changed = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const AddPartScreen()));
    if (changed == true) _load();
  }

  Future<void> _delete(PartModel part) async {
    if (part.isUsedInWorkOrder) {
      AppToast.showError('Cannot delete — used in work order');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(
          'Delete part?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Remove "${part.code}"? This cannot be undone.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final result = await InventoryService.instance.deletePart(part.id);
    if (!result.isSuccess) {
      AppToast.showError(result.message ?? 'Delete failed');
      return;
    }
    AppToast.showSuccess('Deleted');
    _load();
  }

  void _onSortSelected(String key) {
    setState(() {
      if (key.isEmpty) {
        _sortKey = null;
        _sortOrder = null;
      } else if (_sortKey == key) {
        _sortOrder = _sortOrder == 'asc' ? 'desc' : 'asc';
      } else {
        _sortKey = key;
        _sortOrder = 'asc';
      }
      _page = 1;
    });
    _load();
  }

  Widget _buildSortButton() {
    final hasSort = _sortKey != null;
    return PopupMenuButton<String>(
      tooltip: 'Sort',
      onSelected: _onSortSelected,
      icon: Icon(
        hasSort && _sortOrder == 'desc'
            ? Icons.arrow_downward
            : Icons.arrow_upward,
        size: 18,
        color: hasSort ? AppColors.primary : AppColors.textSecondary,
      ),
      itemBuilder: (context) => [
        if (hasSort)
          const PopupMenuItem<String>(value: '', child: Text('Clear sort')),
        ..._sortOptions.entries.map((e) {
          final selected = _sortKey == e.key;
          return PopupMenuItem<String>(
            value: e.key,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  e.value,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                    color: selected ? AppColors.primary : null,
                  ),
                ),
                if (selected)
                  Icon(
                    _sortOrder == 'desc'
                        ? Icons.arrow_downward
                        : Icons.arrow_upward,
                    size: 14,
                    color: AppColors.primary,
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCard(PartModel part) {
    final tone = stockLevelTone(part.stockLevel);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow.withValues(alpha: 0.35),
            blurRadius: 16,
            spreadRadius: 1,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PartDetailScreen(
                  part: part,
                  onChanged: _load,
                  canDelete: _canDelete,
                  canUpdate: _canUpdate,
                ),
              ),
            );
          },
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 5, color: StatusBadgeColors.accent(tone)),
                Expanded(child: _partCardBody(part)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _partCardBody(PartModel part) {
    final toneColor = StatusBadgeColors.text(stockLevelTone(part.stockLevel));
    final hasCompany =
        part.companyDisplay.trim().isNotEmpty &&
        part.companyDisplay.trim() != '-';

    // Only fields with real data get a grid cell — a part with no cost,
    // no company, or no invoice on file simply shows fewer cells instead of
    // a row of "—" placeholders. Each entry is deferred (not a built Widget)
    // so the render loop below can decide `alignEnd` once it knows whether
    // a cell landed in the row's first or second slot.
    final cellBuilders = <Widget Function({required bool alignEnd})>[
      ({required alignEnd}) => _partInfoCell(
        icon: Icons.category_outlined,
        label: 'TYPE',
        value: part.partTypeName,
        alignEnd: alignEnd,
      ),
      if (part.cost != null)
        ({required alignEnd}) => _partInfoCell(
          icon: Icons.monetization_on_outlined,
          label: 'COST',
          value: formatInventoryMoney(part.cost),
          alignEnd: alignEnd,
        ),
      if (hasCompany)
        ({required alignEnd}) => _partInfoCell(
          icon: Icons.business_outlined,
          label: 'COMPANY',
          value: part.companyDisplay,
          alignEnd: alignEnd,
        ),
      if ((part.invoiceNumber ?? '').trim().isNotEmpty)
        ({required alignEnd}) => _partInfoCell(
          icon: Icons.receipt_long_outlined,
          label: 'INVOICE #',
          value: part.invoiceNumber!.trim(),
          alignEnd: alignEnd,
        ),
      if (part.hasInvoiceFile)
        ({required alignEnd}) => _partInfoCell(
          icon: Icons.description_outlined,
          label: 'INVOICE FILE',
          value: 'View Invoice',
          isLink: true,
          onTap: () => openInventoryInvoiceLink(part.invoiceLink),
          alignEnd: alignEnd,
        ),
      if (part.isUsedInWorkOrder)
        ({required alignEnd}) =>
            _usedInWorkOrdersCell(part, alignEnd: alignEnd),
    ];

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: stock status, with the actual quantity right under it.
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  InventoryStockBadge(level: part.stockLevel, compact: true),
                  const SizedBox(height: 4),
                  Text(
                    'Qty: ${part.quantity ?? 0}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: toneColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              // Right: actions, with the part code right under them — pinned
              // to the card's full right edge, not just after the left block.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_canUpdate)
                          IconOnlyButton(
                            icon: Icons.edit,
                            color: AppColors.chromeBlue,
                            onTap: !part.isProtected
                                ? () async {
                                    final ok = await Navigator.of(context)
                                        .push<bool>(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                PartFormScreen(part: part),
                                          ),
                                        );
                                    if (ok == true) _load();
                                  }
                                : null,
                          ),
                        if (_canDelete)
                          IconOnlyButton(
                            icon: Icons.delete_outline,
                            danger: true,
                            onTap:
                                (!part.isProtected && !part.isUsedInWorkOrder)
                                ? () => _delete(part)
                                : null,
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    RichText(
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'PART # ',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                              letterSpacing: 0.3,
                            ),
                          ),
                          TextSpan(
                            text: part.code,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(
            height: 1,
            thickness: 1,
            color: AppColors.textSecondary.withValues(alpha: 0.12),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < cellBuilders.length; i += 2)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // First field pins left, second pins right (its value is
                  // right-aligned via `alignEnd`) — matching the card
                  // header's Stock/Part-# corners — with whatever's unused
                  // between them left as open space instead of the second
                  // field just sitting wherever the halfway mark falls.
                  Expanded(child: cellBuilders[i](alignEnd: false)),
                  if (i + 1 < cellBuilders.length) ...[
                    const SizedBox(width: 12),
                    Expanded(child: cellBuilders[i + 1](alignEnd: true)),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Same icon+label+value shape as [_partInfoCell], but the value is the
  /// tappable work-order chip(s) rather than plain text — kept as a grid
  /// cell (not a separate full-width block) so it pairs side by side with
  /// whatever field precedes it, same as every other field. [alignEnd]
  /// mirrors [_partInfoCell]'s: true when this cell lands in the row's
  /// second (right) slot, pinning the chip to the cell's right edge.
  Widget _usedInWorkOrdersCell(PartModel part, {bool alignEnd = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: alignEnd
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            Icon(
              Icons.build_circle_outlined,
              size: 11,
              color: AppColors.primary,
            ),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                'USED IN WORK ORDERS',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: alignEnd ? TextAlign.right : TextAlign.left,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        _buildUsedInCell(part, alignEnd: alignEnd),
      ],
    );
  }

  Widget _buildUsedInCell(PartModel part, {bool alignEnd = false}) {
    final list = part.usedInWorkOrders;
    if (list.isEmpty &&
        (part.usedInWorkOrder == null || part.usedInWorkOrder == 0)) {
      return Text(
        '—',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      );
    }

    final firstNum = list.isNotEmpty
        ? list.first.number
        : 'WO-${part.usedInWorkOrder.toString().padLeft(4, '0')}';
    final extraCount = list.length > 1 ? list.length - 1 : 0;

    // A compact chip pinned to this cell's right edge when it's the row's
    // second slot — matching every other right-slot field — rather than
    // stretched full width, so a short chip doesn't drag a big colored
    // block across empty space that isn't actually part of it.
    return Align(
      alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
      child: InkWell(
        onTap: () => _showUsedInWorkOrdersModal(part),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primaryLight.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.build_circle_outlined,
                size: 12,
                color: AppColors.primary,
              ),
              const SizedBox(width: 4),
              Text(
                firstNum,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              if (extraCount > 0) ...[
                const SizedBox(width: 3),
                Text(
                  '(+$extraCount more)',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showUsedInWorkOrdersModal(PartModel part) {
    final list = part.usedInWorkOrders;
    final displayList = list.isNotEmpty
        ? list
        : (part.usedInWorkOrder != null && part.usedInWorkOrder! > 0
              ? [
                  PartUsedInWorkOrder(
                    id: part.usedInWorkOrder!,
                    number:
                        'WO-${part.usedInWorkOrder!.toString().padLeft(4, '0')}',
                  ),
                ]
              : <PartUsedInWorkOrder>[]);

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: AppColors.card,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.7,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Used in Work Orders',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  Text(
                    'Part: ${part.partTypeName.isNotEmpty ? part.partTypeName : part.code}',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: SingleChildScrollView(
                      child: displayList.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Text('No work orders linked.'),
                            )
                          : Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: displayList.map((wo) {
                                return InkWell(
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => WorkOrderDetailScreen(
                                          workOrderId: wo.id,
                                        ),
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryLight.withValues(
                                        alpha: 0.5,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: AppColors.primary.withValues(
                                          alpha: 0.2,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          wo.number,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '#${wo.id}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return WebPageBody(
      onRefresh: _load,
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: WebSearchField(
                  controller: _searchController,
                  hintText: 'Search by code, type, or creator...',
                  showClear: _search.isNotEmpty,
                  onClear: () {
                    _searchController.clear();
                    setState(() {
                      _search = '';
                      _page = 1;
                    });
                    _load();
                  },
                ),
              ),
              const SizedBox(width: 8),
              _buildSortButton(),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Parts',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '$_total Total',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_typeId != null || _search.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Text(
                    'Active Filter: ',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Chip(
                    backgroundColor: AppColors.primaryLight.withValues(
                      alpha: 0.5,
                    ),
                    side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.2),
                    ),
                    label: Text(
                      _search.isNotEmpty
                          ? 'Search: $_search'
                          : 'Part Type ID: $_typeId',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    deleteIcon: Icon(
                      Icons.close,
                      size: 14,
                      color: AppColors.primary,
                    ),
                    onDeleted: () {
                      setState(() {
                        _typeId = null;
                        _search = '';
                        _searchController.clear();
                        _page = 1;
                      });
                      _load();
                    },
                  ),
                ],
              ),
            ),
          ],
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            )
          else if (_items.isEmpty)
            ListEmptyState(
              message: _search.isNotEmpty
                  ? 'No parts match your search'
                  : 'No parts found',
              icon: Icons.build_outlined,
            )
          else ...[
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 600) {
                  return Column(
                    children: _items.map((part) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildCard(part),
                      );
                    }).toList(),
                  );
                } else {
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _items.length,
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 500,
                          mainAxisExtent: 380,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                    itemBuilder: (context, i) {
                      return _buildCard(_items[i]);
                    },
                  );
                }
              },
            ),
            const SizedBox(height: 12),
            if (_loadingMore)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_page >= _totalPages && _items.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'All $_total parts loaded',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
