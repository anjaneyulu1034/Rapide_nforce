import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/core/constants/app_gradients.dart';
import 'package:rapide_nforce/core/utils/app_toast.dart';
import 'package:rapide_nforce/core/utils/role_utils.dart';
import 'package:rapide_nforce/models/part_models.dart';
import 'package:rapide_nforce/services/auth_service.dart';
import 'package:rapide_nforce/services/inventory_service.dart';
import 'package:rapide_nforce/ui/inventory/part_detail_screen.dart';
import 'package:rapide_nforce/ui/inventory/part_form_screen.dart';
import 'package:rapide_nforce/ui/inventory/part_type_form_screen.dart';
import 'package:rapide_nforce/ui/inventory/widgets/inventory_stock_badge.dart';
import 'package:rapide_nforce/ui/widgets/list_empty_state.dart';
import 'package:rapide_nforce/ui/widgets/web_ui.dart';

enum InventoryTab { partsOverview, parts }

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({
    super.key,
    this.initialTab = InventoryTab.partsOverview,
  });

  final InventoryTab initialTab;

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  late InventoryTab _tab = widget.initialTab;
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      final next = _searchController.text.trim();
      if (next == _search) return;
      setState(() => _search = next);
    });
  }

  Future<void> _openAdd() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _tab == InventoryTab.partsOverview
            ? const PartTypeFormScreen()
            : const PartFormScreen(),
      ),
    );
    if (changed == true && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WebPageBody(
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppGradients.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Inventory',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Manage inventory',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _InventoryTabBar(
                    tab: _tab,
                    onChanged: (t) => setState(() => _tab = t),
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final narrow = constraints.maxWidth < 520;
                      if (narrow) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _SearchAndAddRow(
                              tab: _tab,
                              controller: _searchController,
                              search: _search,
                              onClear: () {
                                _searchController.clear();
                                setState(() => _search = '');
                              },
                              onAdd: _openAdd,
                            ),
                          ],
                        );
                      }
                       final showAdd =
                          isSuperAdminRole(AuthService.instance.currentUser?.role);
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: WebSearchField(
                              controller: _searchController,
                              hintText: _tab == InventoryTab.partsOverview
                                  ? 'Search by name or creator...'
                                  : 'Search by code, type, or creator...',
                              showClear: _search.isNotEmpty,
                              onClear: () {
                                _searchController.clear();
                                setState(() => _search = '');
                              },
                            ),
                          ),
                          if (showAdd) ...[
                            const SizedBox(width: 12),
                            _AddButton(tab: _tab, onPressed: _openAdd),
                          ],
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  if (_tab == InventoryTab.partsOverview)
                    _PartTypesTable(
                      key: ValueKey('pt-$_search'),
                      search: _search,
                      scrollController: _scrollController,
                    )
                  else
                    _PartsTable(
                      key: ValueKey('p-$_search'),
                      search: _search,
                      scrollController: _scrollController,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchAndAddRow extends StatelessWidget {
  const _SearchAndAddRow({
    required this.tab,
    required this.controller,
    required this.search,
    required this.onClear,
    required this.onAdd,
  });

  final InventoryTab tab;
  final TextEditingController controller;
  final String search;
  final VoidCallback onClear;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final showAdd = isSuperAdminRole(AuthService.instance.currentUser?.role);
    return Column(
      children: [
        WebSearchField(
          controller: controller,
          hintText: tab == InventoryTab.partsOverview
              ? 'Search by name or creator...'
              : 'Search by code, type, or creator...',
          showClear: search.isNotEmpty,
          onClear: onClear,
        ),
        if (showAdd) ...[
          const SizedBox(height: 10),
          _AddButton(tab: tab, onPressed: onAdd, expand: true),
        ],
      ],
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({
    required this.tab,
    required this.onPressed,
    this.expand = false,
  });

  final InventoryTab tab;
  final VoidCallback onPressed;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final label = tab == InventoryTab.partsOverview
        ? 'Add Part Type'
        : 'Add Part';
    final button = FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        minimumSize: const Size(0, 36),
      ),
      icon: const Icon(Icons.add, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 14)),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class _InventoryTabBar extends StatelessWidget {
  const _InventoryTabBar({required this.tab, required this.onChanged});

  final InventoryTab tab;
  final ValueChanged<InventoryTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3.5),
      decoration: BoxDecoration(
        color: AppColors.surfaceTertiary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TabChip(
            label: 'Parts Overview',
            selected: tab == InventoryTab.partsOverview,
            onTap: () => onChanged(InventoryTab.partsOverview),
          ),
          const SizedBox(width: 8),
          _TabChip(
            label: 'Parts',
            selected: tab == InventoryTab.parts,
            onTap: () => onChanged(InventoryTab.parts),
          ),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
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

class _PartTypesTable extends StatefulWidget {
  const _PartTypesTable({
    super.key,
    required this.search,
    required this.scrollController,
  });

  final String search;
  final ScrollController scrollController;

  @override
  State<_PartTypesTable> createState() => _PartTypesTableState();
}

class _PartTypesTableState extends State<_PartTypesTable> {
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  List<PartTypeModel> _items = [];
  int _page = 1;
  final int _limit = 10;
  int _total = 0;
  int _totalPages = 1;

  String get _companyFallback {
    final user = AuthService.instance.currentUser;
    return user?.territory ?? '-';
  }

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (!widget.scrollController.hasClients) return;
    final maxScroll = widget.scrollController.position.maxScrollExtent;
    final currentScroll = widget.scrollController.position.pixels;
    if (maxScroll - currentScroll <= 200) {
      _loadMore();
    }
  }

  @override
  void didUpdateWidget(covariant _PartTypesTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.search != widget.search) {
      _page = 1;
      _load();
    }
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
      search: widget.search.isEmpty ? null : widget.search,
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
        _error = result.message;
        _items = [];
      }
    });
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || _page >= _totalPages) return;
    setState(() {
      _loadingMore = true;
    });
    final nextPage = _page + 1;
    final result = await InventoryService.instance.fetchPartTypes(
      page: nextPage,
      limit: _limit,
      search: widget.search.isEmpty ? null : widget.search,
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



  Widget _buildPartTypeCard(PartTypeModel item) {
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
            color: AppColors.cardShadow,
            blurRadius: 10,
            offset: const Offset(0, 4),
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
          Container(
            height: 1,
            color: AppColors.borderLight,
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
                        const Icon(
                          Icons.inventory_2,
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
                    Text(
                      '${item.count}',
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
                        const Icon(
                          Icons.business,
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
                        const Icon(
                          Icons.calendar_today,
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
                        const Icon(
                          Icons.person,
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
          const SizedBox(height: 14),
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
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(child: Text(_error!)),
      );
    }
    if (_items.isEmpty) {
      return const ListEmptyState(
        message: 'No part types found',
        icon: Icons.inventory_2_outlined,
      );
    }

    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 600) {
              return Column(
                children: _items.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildPartTypeCard(item),
                  );
                }).toList(),
              );
            } else {
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _items.length,
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 500,
                  mainAxisExtent: 320,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemBuilder: (context, i) {
                  return _buildPartTypeCard(_items[i]);
                },
              );
            }
          },
        ),
        const SizedBox(height: 20),
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
    );
  }
}

class _PartsTable extends StatefulWidget {
  const _PartsTable({
    super.key,
    required this.search,
    required this.scrollController,
  });

  final String search;
  final ScrollController scrollController;

  @override
  State<_PartsTable> createState() => _PartsTableState();
}

class _PartsTableState extends State<_PartsTable> {
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  List<PartModel> _items = [];
  int _page = 1;
  final int _limit = 10;
  int _total = 0;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (!widget.scrollController.hasClients) return;
    final maxScroll = widget.scrollController.position.maxScrollExtent;
    final currentScroll = widget.scrollController.position.pixels;
    if (maxScroll - currentScroll <= 200) {
      _loadMore();
    }
  }

  @override
  void didUpdateWidget(covariant _PartsTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.search != widget.search) {
      _page = 1;
      _load();
    }
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
      search: widget.search.isEmpty ? null : widget.search,
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
        _error = result.message;
        _items = [];
      }
    });
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || _page >= _totalPages) return;
    setState(() {
      _loadingMore = true;
    });
    final nextPage = _page + 1;
    final result = await InventoryService.instance.fetchParts(
      page: nextPage,
      limit: _limit,
      search: widget.search.isEmpty ? null : widget.search,
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



  Widget _buildPartCard(PartModel part) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 10,
            offset: const Offset(0, 4),
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
          Container(
            height: 1,
            color: AppColors.borderLight,
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
                        const Icon(
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
                        const Icon(
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
                        const Icon(
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
                        const Icon(
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
                        const Icon(
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
                        const Icon(
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
                        const Icon(
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
                        const Icon(
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
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PartDetailScreen(part: part, onChanged: _load),
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
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton(
                  onPressed: (!part.isProtected && !part.isUsedInWorkOrder)
                      ? () => _delete(part)
                      : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: (!part.isProtected && !part.isUsedInWorkOrder)
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
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(child: Text(_error!)),
      );
    }
    if (_items.isEmpty) {
      return const ListEmptyState(
        message: 'No parts found',
        icon: Icons.build_outlined,
      );
    }

    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 600) {
              return Column(
                children: _items.map((part) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildPartCard(part),
                  );
                }).toList(),
              );
            } else {
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _items.length,
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 500,
                  mainAxisExtent: 390,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemBuilder: (context, i) {
                  return _buildPartCard(_items[i]);
                },
              );
            }
          },
        ),
        const SizedBox(height: 20),
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
    );
  }
}
