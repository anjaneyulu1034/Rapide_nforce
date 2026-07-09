import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/core/utils/app_toast.dart';
import 'package:rapide_nforce/core/utils/role_utils.dart';
import 'package:rapide_nforce/models/part_models.dart';
import 'package:rapide_nforce/services/auth_service.dart';
import 'package:rapide_nforce/services/inventory_service.dart';
import 'package:rapide_nforce/services/permission_service.dart';
import 'package:rapide_nforce/ui/inventory/part_detail_screen.dart';
import 'package:rapide_nforce/ui/inventory/part_form_screen.dart';
import 'package:rapide_nforce/ui/inventory/part_type_form_screen.dart';
import 'package:rapide_nforce/ui/inventory/widgets/inventory_stock_badge.dart';
import 'package:rapide_nforce/ui/widgets/list_empty_state.dart';
import 'package:rapide_nforce/ui/widgets/web_ui.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
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
            Tab(text: 'Inventory'),
            Tab(text: 'Parts'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _PartTypesTab(onViewParts: _viewPartsForType),
          _PartsTab(
            key: ValueKey('$_partsInitialTypeId|$_partsInitialSearch'),
            initialSearch: _partsInitialSearch,
            initialTypeId: _partsInitialTypeId,
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
  const _PartTypesTab({required this.onViewParts});

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
  final int _limit = 10;
  int _total = 0;
  int _totalPages = 1;
  String _search = '';
  String? _sortKey;
  String? _sortOrder;

  bool get _isAdminOrAbove =>
      isAdminRole(AuthService.instance.currentUser?.role);

  MenuPermissions _permissions = const MenuPermissions();

  bool get _canCreate => _isAdminOrAbove || _permissions.canCreate;
  bool get _canDelete => _isAdminOrAbove || _permissions.canDelete;

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
    if (maxScroll - currentScroll <= 200) {
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

  Future<void> _openAdd() async {
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

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filters & Sorting',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setSheetState(() {
                            _sortKey = null;
                            _sortOrder = null;
                          });
                          setState(() {});
                          Navigator.pop(context);
                          _load();
                        },
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Sort By',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Name'),
                        selected: _sortKey == 'name',
                        onSelected: (val) {
                          setSheetState(() => _sortKey = val ? 'name' : null);
                        },
                      ),
                      ChoiceChip(
                        label: const Text('Parts Count'),
                        selected: _sortKey == 'count',
                        onSelected: (val) {
                          setSheetState(() => _sortKey = val ? 'count' : null);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Order',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Ascending'),
                        selected: _sortOrder == 'ASC',
                        onSelected: (val) {
                          setSheetState(() => _sortOrder = val ? 'ASC' : null);
                        },
                      ),
                      ChoiceChip(
                        label: const Text('Descending'),
                        selected: _sortOrder == 'DESC',
                        onSelected: (val) {
                          setSheetState(() => _sortOrder = val ? 'DESC' : null);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {});
                        Navigator.pop(context);
                        _load();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF990000),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Apply Filters',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCard(PartTypeModel item) {
    final company = item.companyName?.trim().isNotEmpty == true
        ? item.companyName!
        : _companyFallback;
    return Container(
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                'PART TYPE # ',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                  letterSpacing: 0.5,
                ),
              ),
              Expanded(
                child: Text(
                  item.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              InventoryStockBadge(level: item.stockLevel, compact: true),
            ],
          ),
          const SizedBox(height: 12),
          Divider(
            height: 1,
            thickness: 1,
            color: AppColors.textSecondary.withValues(alpha: 0.12),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 12,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'COUNT',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () => widget.onViewParts(item.name, item.id),
                      child: Text(
                        '${item.count}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                          decoration: TextDecoration.underline,
                          decorationColor: AppColors.primary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.layers_outlined,
                          size: 12,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'QUANTITY',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${item.totalQuantity ?? item.count}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.monetization_on_outlined,
                          size: 12,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'TOTAL COST',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '\$${(item.totalCost ?? 0).toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.business_outlined,
                          size: 12,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'COMPANY',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      company,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 12,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'CREATED ON',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      formatInventoryDate(item.createdOn),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 12,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'CREATED BY',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.createdByUsername ?? '—',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PartTypeDetailScreen(
                          partType: item,
                          onChanged: _load,
                          canDelete: _canDelete,
                        ),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: BorderSide(
                      color: AppColors.textSecondary.withValues(alpha: 0.3),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    minimumSize: const Size(0, 36),
                    padding: EdgeInsets.zero,
                  ),
                  child: const Text(
                    'View',
                    style: TextStyle(
                      letterSpacing: 0.8,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final ok = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => PartTypeFormScreen(partType: item),
                      ),
                    );
                    if (ok == true) _load();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: BorderSide(
                      color: AppColors.textSecondary.withValues(alpha: 0.3),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    minimumSize: const Size(0, 36),
                    padding: EdgeInsets.zero,
                  ),
                  child: const Text(
                    'Edit',
                    style: TextStyle(
                      letterSpacing: 0.8,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              if (_canDelete) ...[
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _delete(item),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      backgroundColor: Colors.transparent,
                      side: BorderSide(
                        color: AppColors.danger.withValues(alpha: 0.4),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      minimumSize: const Size(0, 36),
                      padding: EdgeInsets.zero,
                    ),
                    child: const Text(
                      'Delete',
                      style: TextStyle(
                        letterSpacing: 0.8,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ],
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
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Inventory',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                  color: AppColors.textPrimary,
                ),
              ),
              if (_total > 0) ...[
                const SizedBox(width: 8),
                Text(
                  '$_total',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 20,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
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
              IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: _showFilters,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.card,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: AppColors.border),
                  ),
                  padding: const EdgeInsets.all(12),
                ),
              ),
              if (_canCreate) ...[
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _openAdd,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    minimumSize: const Size(0, 36),
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text(
                    'Add Part Type',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
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
  final int _limit = 10;
  int _total = 0;
  int _totalPages = 1;
  String _search = '';
  int? _typeId;
  String? _sortKey;
  String? _sortOrder;

  bool get _isAdminOrAbove =>
      isAdminRole(AuthService.instance.currentUser?.role);

  MenuPermissions _permissions = const MenuPermissions();

  bool get _canCreate => _isAdminOrAbove || _permissions.canCreate;
  bool get _canDelete => _isAdminOrAbove || _permissions.canDelete;

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
    if (maxScroll - currentScroll <= 200) {
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

  Future<void> _openAdd() async {
    final changed = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const PartFormScreen()));
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

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filters & Sorting',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setSheetState(() {
                            _sortKey = null;
                            _sortOrder = null;
                          });
                          setState(() {});
                          Navigator.pop(context);
                          _load();
                        },
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Sort By',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Part Code'),
                        selected: _sortKey == 'code',
                        onSelected: (val) {
                          setSheetState(() => _sortKey = val ? 'code' : null);
                        },
                      ),
                      ChoiceChip(
                        label: const Text('Quantity'),
                        selected: _sortKey == 'quantity',
                        onSelected: (val) {
                          setSheetState(
                            () => _sortKey = val ? 'quantity' : null,
                          );
                        },
                      ),
                      ChoiceChip(
                        label: const Text('Cost'),
                        selected: _sortKey == 'cost',
                        onSelected: (val) {
                          setSheetState(() => _sortKey = val ? 'cost' : null);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Order',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Ascending'),
                        selected: _sortOrder == 'ASC',
                        onSelected: (val) {
                          setSheetState(() => _sortOrder = val ? 'ASC' : null);
                        },
                      ),
                      ChoiceChip(
                        label: const Text('Descending'),
                        selected: _sortOrder == 'DESC',
                        onSelected: (val) {
                          setSheetState(() => _sortOrder = val ? 'DESC' : null);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {});
                        Navigator.pop(context);
                        _load();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF990000),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Apply Filters',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCard(PartModel part) {
    return Container(
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                'PART # ',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                  letterSpacing: 0.5,
                ),
              ),
              Expanded(
                child: Text(
                  part.code,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              InventoryStockBadge(level: part.stockLevel, compact: true),
            ],
          ),
          const SizedBox(height: 12),
          Divider(
            height: 1,
            thickness: 1,
            color: AppColors.textSecondary.withValues(alpha: 0.12),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.category_outlined,
                          size: 12,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'TYPE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      part.partTypeName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.layers_outlined,
                          size: 12,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'QUANTITY',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${part.quantity ?? 0}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.monetization_on_outlined,
                          size: 12,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'COST',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      formatInventoryMoney(part.cost),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.business_outlined,
                          size: 12,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'COMPANY',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      part.companyDisplay,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 12,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'INVOICE #',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      part.invoiceNumber ?? '—',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.description_outlined,
                          size: 12,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'INVOICE FILE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      part.hasInvoiceFile ? 'View Invoice' : 'No Invoice',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 12,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'CREATED ON',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      formatInventoryDate(part.createdOn),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 12,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'CREATED BY',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      part.createdByUsername ?? '—',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PartDetailScreen(
                          part: part,
                          onChanged: _load,
                          canDelete: _canDelete,
                        ),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: BorderSide(
                      color: AppColors.textSecondary.withValues(alpha: 0.3),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    minimumSize: const Size(0, 36),
                    padding: EdgeInsets.zero,
                  ),
                  child: const Text(
                    'View',
                    style: TextStyle(
                      letterSpacing: 0.8,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton(
                  onPressed: !part.isProtected
                      ? () async {
                          final ok = await Navigator.of(context).push<bool>(
                            MaterialPageRoute(
                              builder: (_) => PartFormScreen(part: part),
                            ),
                          );
                          if (ok == true) _load();
                        }
                      : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: BorderSide(
                      color: AppColors.textSecondary.withValues(alpha: 0.3),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    minimumSize: const Size(0, 36),
                    padding: EdgeInsets.zero,
                  ),
                  child: const Text(
                    'Edit',
                    style: TextStyle(
                      letterSpacing: 0.8,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              if (_canDelete) ...[
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton(
                    onPressed: (!part.isProtected && !part.isUsedInWorkOrder)
                        ? () => _delete(part)
                        : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                          (!part.isProtected && !part.isUsedInWorkOrder)
                          ? AppColors.danger
                          : AppColors.textSecondary.withValues(alpha: 0.3),
                      backgroundColor: Colors.transparent,
                      side: BorderSide(
                        color: (!part.isProtected && !part.isUsedInWorkOrder)
                            ? AppColors.danger.withValues(alpha: 0.4)
                            : AppColors.textSecondary.withValues(alpha: 0.3),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      minimumSize: const Size(0, 36),
                      padding: EdgeInsets.zero,
                    ),
                    child: const Text(
                      'Delete',
                      style: TextStyle(
                        letterSpacing: 0.8,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ],
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
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Parts',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                  color: AppColors.textPrimary,
                ),
              ),
              if (_total > 0) ...[
                const SizedBox(width: 8),
                Text(
                  '$_total',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 20,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
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
              IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: _showFilters,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.card,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: AppColors.border),
                  ),
                  padding: const EdgeInsets.all(12),
                ),
              ),
              if (_canCreate) ...[
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _openAdd,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    minimumSize: const Size(0, 36),
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Part', style: TextStyle(fontSize: 14)),
                ),
              ],
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
