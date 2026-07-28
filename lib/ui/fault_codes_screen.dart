import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/core/utils/api_feedback.dart';
import 'package:rapide_nforce/models/fault_code_model.dart';
import 'package:rapide_nforce/services/auth_service.dart';
import 'package:rapide_nforce/services/fault_codes_service.dart';
import 'package:rapide_nforce/ui/fault_code_detail_sheet.dart';
import 'package:rapide_nforce/ui/widgets/api_error_banner.dart';
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
  List<FaultCodeModel> _rawItems = [];
  int _page = 1;
  final int _pageSize = 100;
  int _totalPages = 1;
  int _totalItems = 0;
  String _searchTerm = '';
  String _statusFilter = 'all';
  String _severityFilter = 'all';

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
      _rawItems = [];
    });

    final result = await FaultCodesService.instance.fetchFaultCodes(
      page: 1,
      limit: _pageSize,
      search: _searchTerm.isEmpty ? null : _searchTerm,
      companyId: AuthService.instance.selectedCompanyIdInt,
    );

    if (!mounted) return;

    if (!result.isSuccess) {
      setState(() {
        _loading = false;
        _rawItems = [];
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
      _rawItems = data.items;
      _totalItems = data.total;
      _totalPages = data.totalPages;
      _page = data.page;
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
      _rawItems.addAll(data.items);
      _totalItems = data.total;
      _totalPages = data.totalPages;
      _page = data.page;
    });
  }

  List<FaultCodeModel> get _filteredItems {
    return _rawItems.where((item) {
      if (_statusFilter == 'active' && !item.isActive) return false;
      if (_statusFilter == 'closed' && !item.isClosed) return false;

      if (_severityFilter != 'all') {
        final sev = (item.severity ?? '').trim().toLowerCase();
        if (_severityFilter == 'critical' && !item.isCritical) return false;
        if (_severityFilter == 'high' && sev != 'high') return false;
        if (_severityFilter == 'medium' && sev != 'medium') return false;
        if (_severityFilter == 'low' && sev != 'low') return false;
      }
      return true;
    }).toList();
  }

  int get _activeCount => _rawItems.where((i) => i.isActive).length;
  int get _criticalCount => _rawItems.where((i) => i.isCritical).length;
  int get _closedCount => _rawItems.where((i) => i.isClosed).length;

  bool get _hasActiveFaultFilters =>
      _searchTerm.isNotEmpty ||
      _statusFilter != 'all' ||
      _severityFilter != 'all';

  Widget _filterChip({
    required String label,
    required bool selected,
    required ValueChanged<bool> onSelected,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      selectedColor: const Color(0xFF0E7490).withValues(alpha: 0.15),
      backgroundColor: AppColors.surfaceTertiary,
      labelStyle: TextStyle(
        fontSize: 12.5,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected ? const Color(0xFF0E7490) : AppColors.textPrimary,
      ),
      side: BorderSide(
        color: selected ? const Color(0xFF0E7490) : AppColors.border,
      ),
    );
  }

  void _showFaultFiltersBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        String tempStatus = _statusFilter;
        String tempSeverity = _severityFilter;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom +
                MediaQuery.of(context).padding.bottom +
                24;

            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Filter Fault Codes',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setSheetState(() {
                                tempStatus = 'all';
                                tempSeverity = 'all';
                              });
                            },
                            child: const Text('Reset All'),
                          ),
                        ],
                      ),
                      const Divider(height: 20),

                      // Status filter section
                      Text(
                        'Status',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          _filterChip(
                            label: 'All',
                            selected: tempStatus == 'all',
                            onSelected: (_) => setSheetState(() => tempStatus = 'all'),
                          ),
                          _filterChip(
                            label: 'Active',
                            selected: tempStatus == 'active',
                            onSelected: (_) => setSheetState(() => tempStatus = 'active'),
                          ),
                          _filterChip(
                            label: 'Closed',
                            selected: tempStatus == 'closed',
                            onSelected: (_) => setSheetState(() => tempStatus = 'closed'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Severity filter section
                      Text(
                        'Severity',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          _filterChip(
                            label: 'All',
                            selected: tempSeverity == 'all',
                            onSelected: (_) => setSheetState(() => tempSeverity = 'all'),
                          ),
                          _filterChip(
                            label: 'Critical',
                            selected: tempSeverity == 'critical',
                            onSelected: (_) => setSheetState(() => tempSeverity = 'critical'),
                          ),
                          _filterChip(
                            label: 'High',
                            selected: tempSeverity == 'high',
                            onSelected: (_) => setSheetState(() => tempSeverity = 'high'),
                          ),
                          _filterChip(
                            label: 'Medium',
                            selected: tempSeverity == 'medium',
                            onSelected: (_) => setSheetState(() => tempSeverity = 'medium'),
                          ),
                          _filterChip(
                            label: 'Low',
                            selected: tempSeverity == 'low',
                            onSelected: (_) => setSheetState(() => tempSeverity = 'low'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Apply Button
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0E7490),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            setState(() {
                              _statusFilter = tempStatus;
                              _severityFilter = tempSeverity;
                            });
                          },
                          child: const Text(
                            'Apply Filters',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final filtered = _filteredItems;

    return WebListPage(
      title: '',
      subtitle: null,
      onRefresh: _load,
      controller: _scrollController,
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          _StatsRow(
            total: _rawItems.length > _totalItems ? _rawItems.length : _totalItems,
            active: _activeCount,
            critical: _criticalCount,
            closed: _closedCount,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: WebSearchField(
                  controller: _searchController,
                  hintText: 'Search vehicle, code, description, company...',
                ),
              ),
              const SizedBox(width: 8),
              UnconstrainedBox(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _showFaultFiltersBottomSheet,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _hasActiveFaultFilters
                            ? const Color(0xFF0E7490).withValues(alpha: 0.12)
                            : AppColors.surfaceTertiary,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _hasActiveFaultFilters
                              ? const Color(0xFF0E7490)
                              : AppColors.border,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.filter_list_rounded,
                            size: 18,
                            color: _hasActiveFaultFilters
                                ? const Color(0xFF0E7490)
                                : AppColors.textPrimary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Filter',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _hasActiveFaultFilters
                                  ? const Color(0xFF0E7490)
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_error != null) ApiErrorBanner(message: _error!, onRetry: _load),
          WebSectionCard(
            title: 'Fault codes',
            action: filtered.isNotEmpty
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
                      '${filtered.length} total',
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
                : filtered.isEmpty
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
                                : 'No fault codes match current filters',
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
                            return Column(
                              children: [
                                for (final item in filtered)
                                  _FaultCodeRow(item: item),
                              ],
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
                                'All ${filtered.length} fault codes loaded',
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
    required this.closed,
  });

  final int total;
  final int active;
  final int critical;
  final int closed;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoCol = constraints.maxWidth < 600;
        final children = [
          _SimpleStatCard(
            label: 'Total Fault Codes',
            value: '$total',
            hint: 'Across selected filters',
            icon: Icons.confirmation_number_outlined,
            accentColor: AppColors.primary,
          ),
          _SimpleStatCard(
            label: 'Active',
            value: '$active',
            hint: 'Open / active codes',
            icon: Icons.bolt_outlined,
            accentColor: const Color(0xFF16A34A),
          ),
          _SimpleStatCard(
            label: 'Critical / High',
            value: '$critical',
            hint: 'High-priority codes',
            icon: Icons.warning_amber_rounded,
            accentColor: const Color(0xFFD97706),
          ),
          _SimpleStatCard(
            label: 'Closed',
            value: '$closed',
            hint: 'Closed codes',
            icon: Icons.check_circle_outline,
            accentColor: const Color(0xFF0E7490),
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

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({
    required this.label,
    required this.bgColor,
    required this.textColor,
  });

  final String label;
  final Color bgColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: textColor,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _GridCell extends StatelessWidget {
  const _GridCell({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surfaceTertiary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 3),
          child,
        ],
      ),
    );
  }
}

class _FaultCodeRow extends StatelessWidget {
  const _FaultCodeRow({required this.item});

  final FaultCodeModel item;

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return '';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      return DateFormat('MM-dd-yyyy, hh:mm a').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  Color _severityAccent(FaultCodeModel item) {
    if (item.isCritical) return const Color(0xFFE11D48);
    final sev = (item.severity ?? '').trim().toLowerCase();
    if (sev == 'high') return const Color(0xFFEA580C);
    if (sev == 'medium') return const Color(0xFFD97706);
    if (sev == 'low') return const Color(0xFF2563EB);
    return item.isActive ? const Color(0xFFE11D48) : const Color(0xFF16A34A);
  }

  (Color bg, Color fg) _severityBadgeColors(String? sev) {
    final s = (sev ?? '').trim().toLowerCase();
    if (s == 'critical' || s == 'high') {
      return (const Color(0xFFFFE4E6), const Color(0xFF9F1239));
    }
    if (s == 'medium') {
      return (const Color(0xFFFEF3C7), const Color(0xFF92400E));
    }
    if (s == 'low') {
      return (const Color(0xFFDBEAFE), const Color(0xFF1E40AF));
    }
    return (AppColors.surfaceTertiary, AppColors.textSecondary);
  }

  (Color bg, Color fg) _statusBadgeColors(bool isActive) {
    if (isActive) {
      return (const Color(0xFFFFE4E6), const Color(0xFF9F1239));
    }
    return (const Color(0xFFDCFCE7), const Color(0xFF166534));
  }

  @override
  Widget build(BuildContext context) {
    final accent = _severityAccent(item);
    final (statusBg, statusFg) = _statusBadgeColors(item.isActive);
    final (sevBg, sevFg) = _severityBadgeColors(item.severity);
    final formattedDate = _formatDate(item.detectedAt);

    final vehicleDisplay = item.vehicleNumber.trim().isNotEmpty
        ? item.vehicleNumber.trim()
        : '—';

    final desc = item.faultDescription.trim().isNotEmpty
        ? item.faultDescription.trim()
        : (item.faultName != null && item.faultName!.trim().isNotEmpty)
            ? item.faultName!.trim()
            : '—';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow.withValues(alpha: 0.3),
            blurRadius: 12,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => FaultCodeDetailSheet.show(context, item),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 5, color: accent),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top row: Status badge (Left) | Fault Code Pill (Right)
                        Row(
                          children: [
                            _MiniBadge(
                              label: item.isActive ? 'ACTIVE' : 'CLOSED',
                              bgColor: statusBg,
                              textColor: statusFg,
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0E7490).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFF0E7490).withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                item.faultCode,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0E7490),
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Vehicle unit number (Bold)
                        RichText(
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                            children: [
                              const TextSpan(text: 'Vehicle: '),
                              TextSpan(
                                text: vehicleDisplay,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              if (item.vin != null && item.vin!.trim().isNotEmpty) ...[
                                TextSpan(
                                  text: ' (VIN: ${item.vin!})',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Fault Description
                        RichText(
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                            children: [
                              const TextSpan(text: 'Description: '),
                              TextSpan(
                                text: desc,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Bottom Grid: Source | Severity | Reported Date
                        Row(
                          children: [
                            Expanded(
                              child: _GridCell(
                                label: 'SOURCE',
                                child: Text(
                                  (item.integrationSourceName ?? '').trim().isNotEmpty
                                      ? item.integrationSourceName!
                                      : '—',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _GridCell(
                                label: 'SEVERITY',
                                child: (item.severity ?? '').trim().isNotEmpty
                                    ? _MiniBadge(
                                        label: item.severity!,
                                        bgColor: sevBg,
                                        textColor: sevFg,
                                      )
                                    : const Text(
                                        'No Severity',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontStyle: FontStyle.italic,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF94A3B8),
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _GridCell(
                                label: 'REPORTED',
                                child: Text(
                                  formattedDate.isNotEmpty ? formattedDate : '—',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 20,
                              color: AppColors.textSecondary,
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
        ),
      ),
    );
  }
}
