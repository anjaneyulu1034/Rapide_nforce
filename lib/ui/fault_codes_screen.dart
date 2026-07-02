import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/core/constants/app_gradients.dart';
import 'package:rapide_nforce/core/utils/api_feedback.dart';
import 'package:rapide_nforce/models/fault_code_model.dart';
import 'package:rapide_nforce/services/auth_service.dart';
import 'package:rapide_nforce/services/fault_codes_service.dart';
import 'package:rapide_nforce/ui/widgets/api_error_banner.dart';
import 'package:rapide_nforce/ui/widgets/web_pagination.dart';
import 'package:rapide_nforce/ui/widgets/web_ui.dart';

class FaultCodesScreen extends StatefulWidget {
  const FaultCodesScreen({super.key});

  @override
  State<FaultCodesScreen> createState() => _FaultCodesScreenState();
}

class _FaultCodesScreenState extends State<FaultCodesScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  bool _loading = true;
  String? _error;
  List<FaultCodeModel> _items = [];
  int _page = 1;
  int _totalPages = 1;
  int _totalItems = 0;
  int _pageSize = 10;
  String _searchTerm = '';
  String _statusFilter = 'all';
  String _severityFilter = 'all';

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
      if (next == _searchTerm) return;
      setState(() {
        _searchTerm = next;
        _page = 1;
      });
      _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await FaultCodesService.instance.fetchFaultCodes(
      page: _page,
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
  }

  int get _activeOnPage =>
      _items.where((i) => _isActiveStatus(i.faultStatus)).length;

  int get _criticalOnPage => _items
      .where((i) => _isCriticalSeverity(i.severity))
      .length;

  int get _clearedOnPage =>
      _items.where((i) => _isClearedStatus(i.faultStatus)).length;

  bool _isActiveStatus(String status) {
    final n = status.toLowerCase();
    return n == 'active' || n == 'open';
  }

  bool _isClearedStatus(String status) {
    final n = status.toLowerCase();
    return n == 'cleared' || n == 'resolved' || n == 'closed';
  }

  bool _isCriticalSeverity(String? severity) {
    final n = (severity ?? '').toLowerCase();
    return n == 'critical' || n == 'high';
  }

  @override
  Widget build(BuildContext context) {
    return WebListPage(
      title: 'Fault Codes',
      subtitle:
          'Synced vehicle diagnostic trouble codes from connected fleet integrations.',
      onRefresh: _load,
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          _StatsRow(
            total: _totalItems,
            active: _activeOnPage,
            critical: _criticalOnPage,
            cleared: _clearedOnPage,
          ),
          const SizedBox(height: 16),
          _FiltersBar(
            searchController: _searchController,
            statusFilter: _statusFilter,
            severityFilter: _severityFilter,
            onStatusChanged: (v) {
              setState(() {
                _statusFilter = v;
                _page = 1;
              });
              _load();
            },
            onSeverityChanged: (v) {
              setState(() {
                _severityFilter = v;
                _page = 1;
              });
              _load();
            },
          ),
          const SizedBox(height: 16),
          if (_error != null)
            ApiErrorBanner(message: _error!, onRetry: _load),
          WebSectionCard(
            title: 'Fault codes',
            child: _loading
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : _items.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Text(
                            _error != null
                                ? 'No fault codes available'
                                : 'No fault codes found',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          for (final item in _items) _FaultCodeRow(item: item),
                          WebPaginationBar(
                            page: _page,
                            totalPages: _totalPages,
                            total: _totalItems,
                            limit: _pageSize,
                            onPageChanged: (p) {
                              setState(() => _page = p);
                              _load();
                            },
                            onLimitChanged: (size) {
                              setState(() {
                                _pageSize = size;
                                _page = 1;
                              });
                              _load();
                            },
                          ),
                        ],
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
          ),
          _SimpleStatCard(
            label: 'Active on page',
            value: '$active',
            hint: 'Open / active codes in current view',
            valueColor: const Color(0xFF16A34A),
          ),
          _SimpleStatCard(
            label: 'Critical / high',
            value: '$critical',
            hint: 'High-priority codes in current view',
            valueColor: const Color(0xFFD97706),
          ),
          _SimpleStatCard(
            label: 'Cleared on page',
            value: '$cleared',
            hint: 'Resolved codes in current view',
            valueColor: AppColors.primary,
          ),
        ];

        if (twoCol) {
          return Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1) const SizedBox(height: 10),
              ],
            ],
          );
        }

        return Row(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              Expanded(child: children[i]),
              if (i < children.length - 1) const SizedBox(width: 10),
            ],
          ],
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
    this.valueColor,
  });

  final String label;
  final String value;
  final String hint;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppGradients.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hint,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: value,
          items: items.entries
              .map(
                (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
              )
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.borderLight)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.faultCode,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              if (item.severity != null && item.severity!.isNotEmpty)
                _Pill(
                  label: item.severity!,
                  tone: _severityTone(item.severity),
                ),
              const SizedBox(width: 6),
              _Pill(
                label: _formatStatus(item.faultStatus),
                tone: _statusTone(item.faultStatus),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            item.faultDescription,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${item.vehicleNumber} · ${item.companyName ?? '—'}',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
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

  _PillTone _severityTone(String? severity) {
    final n = (severity ?? '').toLowerCase();
    if (n == 'critical' || n == 'high') return _PillTone.danger;
    if (n == 'medium') return _PillTone.warning;
    if (n == 'low') return _PillTone.info;
    return _PillTone.neutral;
  }

  _PillTone _statusTone(String status) {
    final n = status.toLowerCase();
    if (n == 'active' || n == 'open') return _PillTone.success;
    if (n == 'cleared' || n == 'resolved' || n == 'closed') {
      return _PillTone.success;
    }
    return _PillTone.neutral;
  }
}

enum _PillTone { danger, warning, success, info, neutral }

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.tone});

  final String label;
  final _PillTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = switch (tone) {
      _PillTone.danger => (
          const Color(0xFFFEF2F2),
          const Color(0xFFDC2626),
          const Color(0xFFFECACA),
        ),
      _PillTone.warning => (
          const Color(0xFFFFFBEB),
          const Color(0xFFD97706),
          const Color(0xFFFDE68A),
        ),
      _PillTone.success => (
          const Color(0xFFF0FDF4),
          const Color(0xFF16A34A),
          const Color(0xFFBBF7D0),
        ),
      _PillTone.info => (
          const Color(0xFFEFF6FF),
          const Color(0xFF2563EB),
          const Color(0xFFBFDBFE),
        ),
      _PillTone.neutral => (
          const Color(0xFFF8FAFC),
          const Color(0xFF475569),
          const Color(0xFFE2E8F0),
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colors.$3),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: colors.$2,
        ),
      ),
    );
  }
}
