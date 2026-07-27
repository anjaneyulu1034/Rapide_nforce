import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/core/utils/api_feedback.dart';
import 'package:rapide_nforce/models/fault_code_model.dart';
import 'package:rapide_nforce/services/auth_service.dart';
import 'package:rapide_nforce/services/fault_codes_service.dart';
import 'package:rapide_nforce/ui/widgets/api_error_banner.dart';
import 'package:rapide_nforce/ui/widgets/status_badge.dart';
import 'package:rapide_nforce/ui/widgets/web_ui.dart';

class FaultCodesScreen extends StatefulWidget {
  const FaultCodesScreen({super.key, this.initialSearch});

  final String? initialSearch;

  @override
  State<FaultCodesScreen> createState() => _FaultCodesScreenState();
}

class _FaultCodesScreenState extends State<FaultCodesScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;

  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  List<FaultCodeModel> _items = [];
  int _page = 1;
  final int _pageSize = 10;
  int _totalPages = 1;
  int _totalItems = 0;
  String _searchTerm = '';
  String _statusFilter = 'all';
  String _severityFilter = 'all';

  // Counts across the *entire* search-matched set (not just the loaded
  // page) — fetched separately via lightweight limit:1 requests that read
  // the total from pagination metadata.
  int _activeTotal = 0;
  int _criticalTotal = 0;
  int _clearedTotal = 0;

  @override
  void initState() {
    super.initState();
    final initialSearch = widget.initialSearch?.trim();
    if (initialSearch != null && initialSearch.isNotEmpty) {
      _searchTerm = initialSearch;
      _searchController.text = initialSearch;
    }
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
      if (next == _searchTerm) return;
      setState(() => _searchTerm = next);
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

    final result = await FaultCodesService.instance.fetchFaultCodes(
      page: 1,
      limit: _pageSize,
      search: _searchTerm.isEmpty ? null : _searchTerm,
      faultStatus: _statusFilter == 'all' ? null : _statusFilter,
      severity: _severityFilter == 'all' ? null : _severityFilter,
      companyId: AuthService.instance.selectedCompanyIdInt,
    );

    if (!mounted) return;

    if (!result.isSuccess) {
      setState(() {
        _loading = false;
        _items = [];
        _totalItems = 0;
        _totalPages = 1;
        _error = ApiFeedback.errorMessage(
          result,
          fallback: 'Failed to load fault codes',
        );
      });
      return;
    }

    final data = result.data!;
    setState(() {
      _loading = false;
      _items = data.items;
      _totalItems = data.total;
      _totalPages = data.totalPages;
      _page = data.page;
    });
    unawaited(_loadStats());
  }

  /// Refreshes the Active/Critical/Cleared stat tiles against the full
  /// search-matched set (independent of the status/severity dropdowns, so
  /// all three tiles stay meaningful together), using cheap limit:1 requests
  /// that only need the `total` from pagination metadata.
  Future<void> _loadStats() async {
    final search = _searchTerm.isEmpty ? null : _searchTerm;
    final companyId = AuthService.instance.selectedCompanyIdInt;
    final results = await Future.wait([
      FaultCodesService.instance.fetchFaultCodes(
        page: 1,
        limit: 1,
        search: search,
        faultStatus: 'active',
        companyId: companyId,
      ),
      FaultCodesService.instance.fetchFaultCodes(
        page: 1,
        limit: 1,
        search: search,
        faultStatus: 'cleared',
        companyId: companyId,
      ),
      FaultCodesService.instance.fetchFaultCodes(
        page: 1,
        limit: 1,
        search: search,
        severity: 'critical',
        companyId: companyId,
      ),
      FaultCodesService.instance.fetchFaultCodes(
        page: 1,
        limit: 1,
        search: search,
        severity: 'high',
        companyId: companyId,
      ),
    ]);
    if (!mounted) return;
    setState(() {
      _activeTotal = results[0].data?.total ?? 0;
      _clearedTotal = results[1].data?.total ?? 0;
      _criticalTotal =
          (results[2].data?.total ?? 0) + (results[3].data?.total ?? 0);
    });
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || _page >= _totalPages) return;

    setState(() => _loadingMore = true);

    final nextPage = _page + 1;
    final result = await FaultCodesService.instance.fetchFaultCodes(
      page: nextPage,
      limit: _pageSize,
      search: _searchTerm.isEmpty ? null : _searchTerm,
      faultStatus: _statusFilter == 'all' ? null : _statusFilter,
      severity: _severityFilter == 'all' ? null : _severityFilter,
      companyId: AuthService.instance.selectedCompanyIdInt,
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
      _totalItems = data.total;
      _totalPages = data.totalPages;
      _page = data.page;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    return WebListPage(
      title: 'Fault Codes',
      subtitle:
          'Synced vehicle diagnostic trouble codes from connected fleet integrations.',
      onRefresh: _load,
      controller: _scrollController,
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          _StatsRow(
            total: _totalItems,
            active: _activeTotal,
            critical: _criticalTotal,
            cleared: _clearedTotal,
          ),
          const SizedBox(height: 16),
          _FiltersBar(
            searchController: _searchController,
            statusFilter: _statusFilter,
            severityFilter: _severityFilter,
            onStatusChanged: (v) {
              setState(() => _statusFilter = v);
              _load();
            },
            onSeverityChanged: (v) {
              setState(() => _severityFilter = v);
              _load();
            },
          ),
          const SizedBox(height: 16),
          if (_error != null) ApiErrorBanner(message: _error!, onRetry: _load),
          WebSectionCard(
            title: 'Fault codes',
            action: _totalItems > 0
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$_totalItems total',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  )
                : null,
            child: _loading
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : _items.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 32,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _error != null
                                ? 'No fault codes available'
                                : 'No fault codes found',
                            style: TextStyle(color: AppColors.textSecondary),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
                    child: Column(
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth < 600) {
                              return Column(
                                children: [
                                  for (final item in _items)
                                    _FaultCodeRow(item: item),
                                ],
                              );
                            }
                            return GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: EdgeInsets.zero,
                              itemCount: _items.length,
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 500,
                                    mainAxisExtent: 200,
                                    crossAxisSpacing: 4,
                                    mainAxisSpacing: 4,
                                  ),
                              itemBuilder: (context, i) =>
                                  _FaultCodeRow(item: _items[i]),
                            );
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
                                'All $_totalItems fault codes loaded',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ]),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.total,
    required this.active,
    required this.critical,
    required this.cleared,
  });

  final int total;
  final int active;
  final int critical;
  final int cleared;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoCol = constraints.maxWidth < 600;
        final children = [
          _SimpleStatCard(
            label: 'Total fault codes',
            value: '$total',
            hint: 'Across selected filters',
            icon: Icons.confirmation_number_outlined,
            accentColor: AppColors.primary,
          ),
          _SimpleStatCard(
            label: 'Active',
            value: '$active',
            hint: 'Open / active, matching search',
            icon: Icons.bolt_outlined,
            accentColor: const Color(0xFF16A34A),
          ),
          _SimpleStatCard(
            label: 'Critical / high',
            value: '$critical',
            hint: 'High-priority, matching search',
            icon: Icons.warning_amber_rounded,
            accentColor: const Color(0xFFD97706),
          ),
          _SimpleStatCard(
            label: 'Cleared',
            value: '$cleared',
            hint: 'Resolved, matching search',
            icon: Icons.check_circle_outline,
            accentColor: const Color(0xFF2563EB),
          ),
        ];

        if (twoCol) {
          return Column(
            children: [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: children[0]),
                    const SizedBox(width: 10),
                    Expanded(child: children[1]),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: children[2]),
                    const SizedBox(width: 10),
                    Expanded(child: children[3]),
                  ],
                ),
              ),
            ],
          );
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                Expanded(child: children[i]),
                if (i < children.length - 1) const SizedBox(width: 10),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SimpleStatCard extends StatelessWidget {
  const _SimpleStatCard({
    required this.label,
    required this.value,
    required this.hint,
    required this.icon,
    required this.accentColor,
  });

  final String label;
  final String value;
  final String hint;
  final IconData icon;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              accentColor.withValues(alpha: 0.20),
              AppColors.cardElevated,
            ),
            Color.alphaBlend(
              accentColor.withValues(alpha: 0.06),
              AppColors.card,
            ),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: accentColor),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.1,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            hint,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _FiltersBar extends StatelessWidget {
  const _FiltersBar({
    required this.searchController,
    required this.statusFilter,
    required this.severityFilter,
    required this.onStatusChanged,
    required this.onSeverityChanged,
  });

  final TextEditingController searchController;
  final String statusFilter;
  final String severityFilter;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onSeverityChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        WebSearchField(
          controller: searchController,
          hintText: 'Search vehicle, code, description, company...',
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _FilterDropdown(
                label: 'Status',
                value: statusFilter,
                items: const {
                  'all': 'All',
                  'active': 'Active',
                  'cleared': 'Cleared',
                },
                onChanged: onStatusChanged,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _FilterDropdown(
                label: 'Severity',
                value: severityFilter,
                items: const {
                  'all': 'All',
                  'critical': 'Critical',
                  'high': 'High',
                  'medium': 'Medium',
                  'low': 'Low',
                },
                onChanged: onSeverityChanged,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String value;
  final Map<String, String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.surfaceTertiary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: value,
          items: items.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

class _FaultCodeRow extends StatelessWidget {
  const _FaultCodeRow({required this.item});

  final FaultCodeModel item;

  @override
  Widget build(BuildContext context) {
    final severityTone = _severityTone(item.severity);
    final accent = StatusBadgeColors.accent(severityTone);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: accent),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Icon(
                            Icons.report_gmailerrorred_rounded,
                            size: 16,
                            color: accent,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              item.faultCode,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.faultDescription,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (item.severity != null && item.severity!.isNotEmpty)
                          MiniStatusBadge(
                            label: item.severity!,
                            tone: severityTone,
                          ),
                        MiniStatusBadge(
                          label: _formatStatus(item.faultStatus),
                          tone: _statusTone(item.faultStatus),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          Icons.local_shipping_outlined,
                          size: 13,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${item.vehicleNumber} · ${item.companyName ?? '—'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatStatus(String status) {
    final n = status.toLowerCase();
    if (n == 'active' || n == 'open') return 'Active';
    if (n == 'cleared' || n == 'resolved' || n == 'closed') return 'Cleared';
    if (status.isEmpty) return 'Unknown';
    return status[0].toUpperCase() + status.substring(1);
  }

  BadgeTone _severityTone(String? severity) {
    final n = (severity ?? '').toLowerCase();
    if (n == 'critical' || n == 'high') return BadgeTone.danger;
    if (n == 'medium') return BadgeTone.warning;
    if (n == 'low') return BadgeTone.info;
    return BadgeTone.neutral;
  }

  BadgeTone _statusTone(String status) {
    final n = status.toLowerCase();
    if (n == 'active' || n == 'open') return BadgeTone.success;
    if (n == 'cleared' || n == 'resolved' || n == 'closed') {
      return BadgeTone.success;
    }
    return BadgeTone.neutral;
  }
}
