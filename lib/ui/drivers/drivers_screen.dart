import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/core/utils/api_feedback.dart';
import 'package:rapide_nforce/core/utils/app_toast.dart';
import 'package:rapide_nforce/core/utils/role_utils.dart';
import 'package:rapide_nforce/models/driver_model.dart';
import 'package:rapide_nforce/services/auth_service.dart';
import 'package:rapide_nforce/services/driver_service.dart';
import 'package:rapide_nforce/ui/drivers/driver_detail_screen.dart';
import 'package:rapide_nforce/ui/drivers/driver_form_screen.dart';
import 'package:rapide_nforce/ui/widgets/api_error_banner.dart';
import 'package:rapide_nforce/ui/widgets/list_empty_state.dart';
import 'package:rapide_nforce/ui/widgets/status_chip.dart';
import 'package:rapide_nforce/ui/widgets/web_ui.dart';

class DriversScreen extends StatefulWidget {
  const DriversScreen({super.key});

  @override
  State<DriversScreen> createState() => _DriversScreenState();
}

class _DriversScreenState extends State<DriversScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;

  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  List<DriverModel> _items = [];
  int? _selectedId;
  int _page = 1;
  final int _limit = 10;
  int _total = 0;
  int _totalPages = 1;
  String _search = '';

  bool get _isSuperAdmin =>
      isSuperAdminRole(AuthService.instance.currentUser?.role);

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

    final result = await DriverService.instance.fetchDrivers(
      page: 1,
      limit: _limit,
      search: _search.isEmpty ? null : _search,
    );

    if (!mounted) return;

    if (!result.isSuccess) {
      setState(() {
        _loading = false;
        _error = ApiFeedback.errorMessage(
          result,
          fallback: 'Failed to load drivers',
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

    setState(() {
      _loadingMore = true;
    });

    final nextPage = _page + 1;
    final result = await DriverService.instance.fetchDrivers(
      page: nextPage,
      limit: _limit,
      search: _search.isEmpty ? null : _search,
    );

    if (!mounted) return;

    if (!result.isSuccess) {
      setState(() {
        _loadingMore = false;
      });
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
    if (_isSuperAdmin && AuthService.instance.selectedCompanyIdInt == null) {
      AppToast.showError('Select a company from the header first');
      return;
    }

    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const DriverFormScreen()),
    );
    if (changed == true) _load();
  }

  Future<void> _openDetail(DriverModel driver) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DriverDetailScreen(driverId: driver.id),
      ),
    );
    if (changed == true) _load();
  }

  Future<void> _openEdit(DriverModel driver) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DriverFormScreen(driverId: driver.id),
      ),
    );
    if (changed == true) _load();
  }

  Future<void> _confirmDelete(DriverModel driver) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 40,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.danger,
                  size: 34,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Delete Driver',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Are you sure you want to delete\n"${driver.fullName}"?\nThis action cannot be undone.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: BorderSide(color: AppColors.border, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Delete',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true) return;

    final result = await DriverService.instance.deleteDriver(driver.id);
    if (!mounted) return;
    if (result.isSuccess) {
      AppToast.showSuccess('Driver deleted');
      _load();
    } else {
      ApiFeedback.showError(result, fallback: 'Failed to delete driver');
    }
  }

  Widget dataRow(String label, String? value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          Expanded(
            child: Text(
              value ?? '—',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: valueColor ?? AppColors.textPrimary,
              ),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(DriverModel d) {
    final bool isSelected = _selectedId == d.id;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        splashColor: AppColors.danger.withValues(alpha: 0.06),
        highlightColor: AppColors.danger.withValues(alpha: 0.03),
        onTap: () => setState(() {
          _selectedId = isSelected ? null : d.id;
        }),
        child: Ink(
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
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            d.fullName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (d.driverId != null && d.driverId!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              d.driverId!,
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                                letterSpacing: 0.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    d.isActive == false
                        ? StatusChip.inactive('INACTIVE')
                        : Text(
                            'ACTIVE',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.statusCompleted,
                            ),
                          ),
                  ],
                ),
                const SizedBox(height: 10),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: AppColors.textSecondary.withValues(alpha: 0.12),
                ),
                const SizedBox(height: 10),
                dataRow('License Number', d.driverLicense),
                dataRow('License Class', d.licenseClass),
                dataRow('Phone', d.mobile ?? d.phoneCan),
                dataRow('Email', d.email),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _openDetail(d),
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
                        onPressed: () => _openEdit(d),
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
                        onPressed: () => _confirmDelete(d),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          backgroundColor: Colors.transparent,
                          overlayColor: Colors.transparent,
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
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: _openAdd,
        backgroundColor: const Color(0xFF990000),
        foregroundColor: Colors.white,
        elevation: 4,
        child: const Icon(Icons.add, size: 28),
      ),
      body: WebPageBody(
        onRefresh: _load,
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            WebSearchField(
              controller: _searchController,
              hintText: 'Search by Name',
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
                    ? 'No drivers match your search'
                    : 'No drivers yet',
                icon: Icons.people_outline,
                actionLabel: 'Add Driver',
                onAction: _openAdd,
              )
            else ...[
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 600) {
                    return Column(
                      children: _items.map((d) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _buildCard(d),
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
                        mainAxisExtent: 260,
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
                      'All $_total drivers loaded',
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
