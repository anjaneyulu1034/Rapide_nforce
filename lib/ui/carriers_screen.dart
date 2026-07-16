import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/core/utils/api_feedback.dart';
import 'package:rapide_nforce/core/utils/app_toast.dart';
import 'package:rapide_nforce/models/carrier_model.dart';
import 'package:rapide_nforce/services/carrier_service.dart';
import 'package:rapide_nforce/ui/carrier_detail_screen.dart';
import 'package:rapide_nforce/ui/carrier_form_screen.dart';
import 'package:rapide_nforce/ui/widgets/api_error_banner.dart';
import 'package:rapide_nforce/ui/widgets/list_empty_state.dart';
import 'package:rapide_nforce/ui/widgets/status_chip.dart';
import 'package:rapide_nforce/ui/widgets/web_data_table.dart';
import 'package:rapide_nforce/ui/widgets/web_ui.dart';

class CarriersScreen extends StatefulWidget {
  const CarriersScreen({super.key});

  @override
  State<CarriersScreen> createState() => _CarriersScreenState();
}

class _CarriersScreenState extends State<CarriersScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;

  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  List<CarrierModel> _items = [];
  int _page = 1;
  final int _limit = 10;
  int _total = 0;
  int _totalPages = 1;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
    _load();
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
      setState(() => _search = next);
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

    final result = await CarrierService.instance.fetchCarriers(
      page: 1,
      limit: _limit,
      search: _search.isEmpty ? null : _search,
      sortBy: 'id',
      sortOrder: 'desc',
    );

    if (!mounted) return;

    if (!result.isSuccess) {
      setState(() {
        _loading = false;
        _error = ApiFeedback.errorMessage(
          result,
          fallback: 'Failed to load carriers',
        );
      });
      return;
    }

    final data = result.data!;
    setState(() {
      _loading = false;
      _items = data.items;
      _total = data.total;
      _totalPages = data.totalPages;
      _page = data.page;
    });
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || _page >= _totalPages) return;

    setState(() => _loadingMore = true);

    final nextPage = _page + 1;
    final result = await CarrierService.instance.fetchCarriers(
      page: nextPage,
      limit: _limit,
      search: _search.isEmpty ? null : _search,
      sortBy: 'id',
      sortOrder: 'desc',
    );

    if (!mounted) return;

    if (!result.isSuccess) {
      setState(() => _loadingMore = false);
      return;
    }

    final data = result.data!;
    setState(() {
      _loadingMore = false;
      _items.addAll(data.items);
      _total = data.total;
      _totalPages = data.totalPages;
      _page = data.page;
    });
  }

  Future<void> _openAdd() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CarrierFormScreen()),
    );
    if (changed == true) _load();
  }

  Future<void> _openDetail(CarrierModel carrier) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CarrierDetailScreen(carrierId: carrier.id),
      ),
    );
    if (changed == true) _load();
  }

  Future<void> _openEdit(CarrierModel carrier) async {
    final consent = carrier.consentStatusLabel;
    if (consent != '—' && consent.toLowerCase() != 'approved') {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.card,
          title: Text(
            'Consent not approved',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: Text(
            'The carrier consent agreement is currently in "$consent" status. '
            'Do you want to proceed with editing?',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Proceed'),
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }

    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CarrierFormScreen(carrierId: carrier.id),
      ),
    );
    if (changed == true) _load();
  }

  Future<void> _confirmDelete(CarrierModel carrier) async {
    final consent = carrier.consentStatusLabel;
    if (consent != '—' && consent.toLowerCase() != 'approved') {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.card,
          title: Text(
            'Consent not approved',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: Text(
            'The carrier consent agreement is currently in "$consent" status. '
            'Do you still want to delete this carrier?',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Proceed'),
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(
          'Delete carrier',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Delete "${carrier.displayName}"? This cannot be undone.',
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
    if (confirmed != true) return;

    final result = await CarrierService.instance.deleteCarrier(carrier.id);
    if (!mounted) return;
    if (result.isSuccess) {
      AppToast.showSuccess('Carrier deleted');
      _load();
    } else {
      ApiFeedback.showError(result, fallback: 'Failed to delete carrier');
    }
  }

  void _showActions(CarrierModel carrier) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.visibility_outlined),
              title: const Text('View'),
              onTap: () {
                Navigator.pop(ctx);
                _openDetail(carrier);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(ctx);
                _openEdit(carrier);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: AppColors.danger),
              title: Text('Delete', style: TextStyle(color: AppColors.danger)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(carrier);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAdd,
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Carrier'),
      ),
      body: WebPageBody(
        onRefresh: _load,
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          children: [
            WebPageHeader(
              title: 'Carrier',
              subtitle: _total > 0
                  ? '$_total carriers'
                  : 'Manage carrier companies',
            ),
            const SizedBox(height: 12),
            WebSearchField(
              controller: _searchController,
              hintText: 'Search carriers…',
              showClear: _search.isNotEmpty,
              onClear: () {
                _searchController.clear();
                setState(() => _search = '');
                _load();
              },
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              ApiErrorBanner(message: _error!, onRetry: _load)
            else if (_items.isEmpty)
              ListEmptyState(
                message: _search.isNotEmpty
                    ? 'No carriers match your search'
                    : 'No carriers yet',
                icon: Icons.business_outlined,
                actionLabel: 'Add Carrier',
                onAction: _openAdd,
              )
            else ...[
              WebDataTable(
                columns: const [
                  WebTableColumn(label: 'Company Name', width: 160),
                  WebTableColumn(label: 'Consent', width: 110),
                  WebTableColumn(label: 'Start Date', width: 110),
                  WebTableColumn(label: 'CVOR #', width: 100),
                  WebTableColumn(label: 'Status', width: 90),
                  WebTableColumn(label: '', width: 48, align: TextAlign.center),
                ],
                rowCount: _items.length,
                rowBuilder: (i) {
                  final c = _items[i];
                  return [
                    Text(
                      c.displayName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    StatusChip.consent(c.consentStatusLabel),
                    Text(
                      c.startDate ?? '—',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    Text(
                      c.cvorNumber ?? '—',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    c.isActive == false
                        ? StatusChip.inactive('Inactive')
                        : StatusChip.active('Active'),
                    IconButton(
                      icon: const Icon(Icons.more_vert),
                      color: AppColors.textSecondary,
                      onPressed: () => _showActions(c),
                    ),
                  ];
                },
              ),
              if (_loadingMore)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_page >= _totalPages)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      'All $_total carriers loaded',
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
      ),
    );
  }
}
