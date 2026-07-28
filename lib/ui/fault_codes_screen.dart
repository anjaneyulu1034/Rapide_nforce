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
      title: 'Fault Codes',
      subtitle:
          'Synced vehicle diagnostic trouble codes from connected fleet integrations.',
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
          _FiltersBar(
            searchController: _searchController,
            statusFilter: _statusFilter,
            severityFilter: _severityFilter,
            onStatusChanged: (v) {
              setState(() => _statusFilter = v);
            },
            onSeverityChanged: (v) {
              setState(() => _severityFilter = v);
            },
          ),
          const SizedBox(height: 16),
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
                  'closed': 'Closed',
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

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return '';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      return DateFormat('MM-dd-yyyy, hh:mm a').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final formattedDate = _formatDate(item.detectedAt);

    return InkWell(
      onTap: () => FaultCodeDetailSheet.show(context, item),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top bar: Last Detected & Integration Source
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (formattedDate.isNotEmpty)
                  Text(
                    formattedDate,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                    ),
                  )
                else
                  const SizedBox.shrink(),
                if (item.integrationSourceName != null && item.integrationSourceName!.isNotEmpty)
                  Text(
                    item.integrationSourceName!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xFF334155),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Vehicle number & Fault Code Pill
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.vehicleNumber,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2F6B54),
                        ),
                      ),
                      if (item.vin != null && item.vin!.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.vin!,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontFamily: 'monospace',
                            color: isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Fault Code Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F3ED),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFB8D4C8)),
                  ),
                  child: Text(
                    item.faultCode,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2F5E4E),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Description / Name
            if (item.faultName != null && item.faultName!.trim().isNotEmpty) ...[
              Text(
                item.faultName!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 2),
            ],
            if (item.faultDescription.trim().isNotEmpty) ...[
              Text(
                item.faultDescription,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 10),
            ],

            // Bottom Badges: MIL/FMI severity, Status pill, Company name
            Row(
              children: [
                _SeverityCell(item: item),
                const SizedBox(width: 8),
                _StatusPill(status: item.formattedStatus),
                const Spacer(),
                if (item.companyName != null && item.companyName!.isNotEmpty)
                  Flexible(
                    child: Text(
                      item.companyName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final n = status.toLowerCase();
    Color bg;
    Color fg;
    Color border;

    if (n == 'active' || n == 'open') {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF15803D);
      border = const Color(0xFFBBF7D0);
    } else if (n == 'resolved') {
      bg = const Color(0xFFEDE9FE);
      fg = const Color(0xFF6D28D9);
      border = const Color(0xFFDDD6FE);
    } else if (n == 'cleared') {
      bg = const Color(0xFFCFFAFE);
      fg = const Color(0xFF0E7490);
      border = const Color(0xFFA5F3FC);
    } else {
      bg = const Color(0xFFF1F5F9);
      fg = const Color(0xFF334155);
      border = const Color(0xFFE2E8F0);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }
}

class _SeverityCell extends StatelessWidget {
  const _SeverityCell({required this.item});

  final FaultCodeModel item;

  @override
  Widget build(BuildContext context) {
    final codeSev = item.parsedCodeSeverity;
    if (codeSev != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${codeSev.label} :',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              codeSev.value,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF7C3AED),
              ),
            ),
          ],
        ),
      );
    }

    final sev = item.severity?.trim();
    if (sev == null || sev.isEmpty) {
      return const SizedBox.shrink();
    }

    final n = sev.toLowerCase();
    Color bg = const Color(0xFFF1F5F9);
    Color fg = const Color(0xFF475569);
    Color border = const Color(0xFFE2E8F0);

    if (n == 'critical' || n == 'high') {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFB91C1C);
      border = const Color(0xFFFECACA);
    } else if (n == 'medium') {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFFB45309);
      border = const Color(0xFFFDE68A);
    } else if (n == 'low') {
      bg = const Color(0xFFE0F2FE);
      fg = const Color(0xFF0369A1);
      border = const Color(0xFFBAE6FD);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Text(
        sev[0].toUpperCase() + sev.substring(1),
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }
}
