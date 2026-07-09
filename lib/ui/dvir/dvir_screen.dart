import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/core/utils/api_feedback.dart';
import 'package:rapide_nforce/models/dvir_defect_model.dart';
import 'package:rapide_nforce/models/dvir_report_model.dart';
import 'package:rapide_nforce/services/dvir_service.dart';
import 'package:rapide_nforce/ui/dvir/dvir_defect_detail_screen.dart';
import 'package:rapide_nforce/ui/dvir/dvir_detail_screen.dart';
import 'package:rapide_nforce/ui/widgets/api_error_banner.dart';
import 'package:rapide_nforce/ui/widgets/list_empty_state.dart';
import 'package:rapide_nforce/ui/widgets/web_ui.dart';

String _formatDateTime(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) return iso;
  return DateFormat('MM-dd-yyyy, hh:mm a').format(parsed.toLocal());
}

(Color, Color) _typeColors(String type) {
  switch (type.toLowerCase()) {
    case 'post-trip':
      return (const Color(0xFFEDE9FE), const Color(0xFF6D28D9));
    case 'pre-trip':
      return (const Color(0xFFDBEAFE), const Color(0xFF1447E6));
    default:
      return (const Color(0xFFF1F5F9), const Color(0xFF64748B));
  }
}

(Color, Color) _safetyColors(String status) {
  return status.toLowerCase() == 'unsafe'
      ? (const Color(0xFFFEE2E2), const Color(0xFFDC2626))
      : (const Color(0xFFDCFCE7), const Color(0xFF008236));
}

(Color, Color) _defectStatusColors(String status) {
  return status.toLowerCase() == 'open'
      ? (const Color(0xFFFEE2E2), const Color(0xFFB91C1C))
      : (const Color(0xFFDCFCE7), const Color(0xFF15803D));
}

(Color, Color) _severityColors(String? severity) {
  switch (severity?.toLowerCase()) {
    case 'major':
    case 'high':
      return (const Color(0xFFFEE2E2), const Color(0xFFB91C1C));
    case 'minor':
    case 'low':
      return (const Color(0xFFFEF3C7), const Color(0xFF92400E));
    default:
      return (const Color(0xFFF1F5F9), const Color(0xFF94A3B8));
  }
}

const List<Color> _avatarPalette = [
  Color(0xFF1447E6),
  Color(0xFFB45309),
  Color(0xFFBE185D),
  Color(0xFF15803D),
  Color(0xFF7C3AED),
  Color(0xFF0F766E),
];

Color _avatarColor(String seed) {
  if (seed.isEmpty) return _avatarPalette.first;
  final hash = seed.codeUnits.fold<int>(0, (a, b) => a + b);
  return _avatarPalette[hash % _avatarPalette.length];
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
}

class DvirScreen extends StatefulWidget {
  const DvirScreen({super.key, this.initialSearch});

  final String? initialSearch;

  @override
  State<DvirScreen> createState() => _DvirScreenState();
}

class _DvirScreenState extends State<DvirScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  final _reportsScrollController = ScrollController();
  final _defectsScrollController = ScrollController();
  Timer? _debounce;

  // State common
  String _search = '';

  // State Reports
  bool _reportsLoading = true;
  bool _reportsLoadingMore = false;
  String? _reportsError;
  List<DvirReportModel> _reports = [];
  int _reportsPage = 1;
  int _reportsTotalPages = 1;
  String _typeFilter = 'all';
  String _statusFilter = 'all';
  DateTime? _fromDate;
  DateTime? _toDate;

  // State Defects
  bool _defectsLoading = true;
  bool _defectsLoadingMore = false;
  String? _defectsError;
  List<DvirDefectModel> _defects = [];
  int _defectsPage = 1;
  int _defectsTotalPages = 1;
  String _severityFilter = 'all';
  String _defectStatusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _searchController.clear();
        _search = '';
      });
      _loadCurrentTab();
    });

    final initialSearch = widget.initialSearch?.trim();
    if (initialSearch != null && initialSearch.isNotEmpty) {
      _search = initialSearch;
      _searchController.text = initialSearch;
    }

    _searchController.addListener(_onSearchChanged);
    _reportsScrollController.addListener(_onReportsScroll);
    _defectsScrollController.addListener(_onDefectsScroll);

    _loadReports();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _reportsScrollController.dispose();
    _defectsScrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      final next = _searchController.text.trim();
      if (next == _search) return;
      setState(() {
        _search = next;
      });
      _loadCurrentTab();
    });
  }

  void _loadCurrentTab() {
    if (_tabController.index == 0) {
      _loadReports();
    } else {
      _loadDefects();
    }
  }

  void _onReportsScroll() {
    if (!_reportsScrollController.hasClients) return;
    final maxScroll = _reportsScrollController.position.maxScrollExtent;
    final currentScroll = _reportsScrollController.position.pixels;
    if (maxScroll - currentScroll <= 200) {
      _loadMoreReports();
    }
  }

  void _onDefectsScroll() {
    if (!_defectsScrollController.hasClients) return;
    final maxScroll = _defectsScrollController.position.maxScrollExtent;
    final currentScroll = _defectsScrollController.position.pixels;
    if (maxScroll - currentScroll <= 200) {
      _loadMoreDefects();
    }
  }

  String? get _isoFromDate =>
      _fromDate == null ? null : DateFormat('yyyy-MM-dd').format(_fromDate!);
  String? get _isoToDate =>
      _toDate == null ? null : DateFormat('yyyy-MM-dd').format(_toDate!);

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => _fromDate = picked);
    _loadReports();
  }

  Future<void> _pickToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => _toDate = picked);
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() {
      _reportsLoading = true;
      _reportsError = null;
      _reports = [];
      _reportsPage = 1;
    });

    final result = await DvirService.instance.fetchReports(
      page: 1,
      limit: 10,
      search: _search.isEmpty ? null : _search,
      reportedFrom: _isoFromDate,
      reportedTo: _isoToDate,
      inspectionType: _typeFilter == 'all' ? null : _typeFilter,
      reportStatus: _statusFilter == 'all' ? null : _statusFilter,
    );

    if (!mounted) return;

    if (!result.isSuccess) {
      setState(() {
        _reportsLoading = false;
        _reportsError = ApiFeedback.errorMessage(result, fallback: 'Failed to load DVIR reports');
      });
      return;
    }

    final data = result.data!;
    setState(() {
      _reportsLoading = false;
      _reports = data.items;
      _reportsTotalPages = data.totalPages;
      _reportsPage = data.page;
    });
  }

  Future<void> _loadMoreReports() async {
    if (_reportsLoading || _reportsLoadingMore || _reportsPage >= _reportsTotalPages) return;

    setState(() {
      _reportsLoadingMore = true;
    });

    final nextPage = _reportsPage + 1;
    final result = await DvirService.instance.fetchReports(
      page: nextPage,
      limit: 10,
      search: _search.isEmpty ? null : _search,
      reportedFrom: _isoFromDate,
      reportedTo: _isoToDate,
      inspectionType: _typeFilter == 'all' ? null : _typeFilter,
      reportStatus: _statusFilter == 'all' ? null : _statusFilter,
    );

    if (!mounted) return;

    if (!result.isSuccess) {
      setState(() {
        _reportsLoadingMore = false;
      });
      return;
    }

    final data = result.data!;
    setState(() {
      _reportsLoadingMore = false;
      _reports.addAll(data.items);
      _reportsTotalPages = data.totalPages;
      _reportsPage = data.page;
    });
  }

  Future<void> _loadDefects() async {
    setState(() {
      _defectsLoading = true;
      _defectsError = null;
      _defects = [];
      _defectsPage = 1;
    });

    final result = await DvirService.instance.fetchDefects(
      page: 1,
      limit: 10,
      search: _search.isEmpty ? null : _search,
      defectStatus: _defectStatusFilter == 'all' ? null : _defectStatusFilter,
      severity: _severityFilter == 'all' ? null : _severityFilter,
    );

    if (!mounted) return;

    if (!result.isSuccess) {
      setState(() {
        _defectsLoading = false;
        _defectsError = ApiFeedback.errorMessage(result, fallback: 'Failed to load DVIR defects');
      });
      return;
    }

    final data = result.data!;
    setState(() {
      _defectsLoading = false;
      _defects = data.items;
      _defectsTotalPages = data.totalPages;
      _defectsPage = data.page;
    });
  }

  Future<void> _loadMoreDefects() async {
    if (_defectsLoading || _defectsLoadingMore || _defectsPage >= _defectsTotalPages) return;

    setState(() {
      _defectsLoadingMore = true;
    });

    final nextPage = _defectsPage + 1;
    final result = await DvirService.instance.fetchDefects(
      page: nextPage,
      limit: 10,
      search: _search.isEmpty ? null : _search,
      defectStatus: _defectStatusFilter == 'all' ? null : _defectStatusFilter,
      severity: _severityFilter == 'all' ? null : _severityFilter,
    );

    if (!mounted) return;

    if (!result.isSuccess) {
      setState(() {
        _defectsLoadingMore = false;
      });
      return;
    }

    final data = result.data!;
    setState(() {
      _defectsLoadingMore = false;
      _defects.addAll(data.items);
      _defectsTotalPages = data.totalPages;
      _defectsPage = data.page;
    });
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
      boxShadow: [
        BoxShadow(
          color: AppColors.cardShadow.withValues(alpha: 0.2),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  Widget _buildReportCard(DvirReportModel r) {
    final (safeBg, safeFg) = _safetyColors(r.reportStatus);
    final (typeBg, typeFg) = _typeColors(r.inspectionType);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.vehicleNumber,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.primary,
                      ),
                    ),
                    if ((r.vin ?? '').isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        r.vin!,
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _Badge(label: r.reportStatus, bg: safeBg, fg: safeFg),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: _avatarColor(r.driverName).withValues(alpha: 0.15),
                child: Text(
                  _initials(r.driverName),
                  style: TextStyle(
                    color: _avatarColor(r.driverName),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.driverName,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      r.driverExternalId,
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, thickness: 1, color: AppColors.textSecondary.withValues(alpha: 0.12)),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _GridText(
                  icon: Icons.calendar_today_outlined,
                  label: 'REPORTED',
                  value: _formatDateTime(r.reportedAt),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _GridCell(
                  icon: Icons.category_outlined,
                  label: 'TYPE',
                  child: _Badge(label: r.inspectionType, bg: typeBg, fg: typeFg, compact: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _GridText(
                  icon: Icons.business_outlined,
                  label: 'COMPANY',
                  value: r.companyName,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _GridText(
                  icon: Icons.report_problem_outlined,
                  label: 'DEFECTS',
                  value: '${r.defectCount}',
                  valueColor:
                      r.defectCount > 0 ? const Color(0xFFBA1A1A) : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _GridText(
            icon: Icons.sync_outlined,
            label: 'SOURCE',
            value: r.integrationSourceName,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DvirDetailScreen(reportId: r.id),
                  ),
                );
              },
              child: const Text('View Report'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefectCard(DvirDefectModel d) {
    final (statusBg, statusFg) = _defectStatusColors(d.defectStatus);
    final (sevBg, sevFg) = _severityColors(d.severity);
    final hasReport = (d.syncedDvirReportId ?? '').isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.defectName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.primary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Code: ${d.defectCode}',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _Badge(label: d.defectStatus, bg: statusBg, fg: statusFg),
            ],
          ),
          if ((d.defectDescription ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              d.defectDescription!,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 12),
          Divider(height: 1, thickness: 1, color: AppColors.textSecondary.withValues(alpha: 0.12)),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _GridCell(
                  icon: Icons.local_shipping_outlined,
                  label: 'VEHICLE',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d.vehicleNumber ?? '—',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      if ((d.vin ?? '').isNotEmpty)
                        Text(
                          d.vin!,
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _GridText(
                  icon: Icons.business_outlined,
                  label: 'COMPANY',
                  value: d.companyName,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _GridCell(
                  icon: Icons.warning_amber_outlined,
                  label: 'SEVERITY',
                  child: _Badge(
                    label: (d.severity ?? '').trim().isEmpty ? 'No Severity' : d.severity!,
                    bg: sevBg,
                    fg: sevFg,
                    compact: true,
                    italic: (d.severity ?? '').trim().isEmpty,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _GridText(
                  icon: Icons.sync_outlined,
                  label: 'SOURCE',
                  value: d.integrationSourceName,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _GridText(
                  icon: Icons.calendar_today_outlined,
                  label: 'REPORTED',
                  value: _formatDateTime(d.createdAt),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _GridCell(
                  icon: Icons.description_outlined,
                  label: 'DVIR REPORT',
                  child: hasReport
                      ? InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    DvirDetailScreen(reportId: d.syncedDvirReportId!),
                              ),
                            );
                          },
                          child: Text(
                            'View Report',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        )
                      : Text(
                          'No DVIR Report',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontStyle: FontStyle.italic,
                            fontSize: 13,
                          ),
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DvirDefectDetailScreen(defectId: d.id),
                  ),
                );
              },
              child: const Text('View Details'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLimitNote(String text) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 16, color: Color(0xFF92400E)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF92400E),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
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
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 14),
          tabs: const [
            Tab(text: 'DVIR Reports'),
            Tab(text: 'Defects'),
          ],
        ),
      ),
      body: WebPageBody(
        onRefresh: () async {
          _loadCurrentTab();
        },
        child: AnimatedBuilder(
          animation: _tabController,
          builder: (context, _) {
            final isReportsTab = _tabController.index == 0;
            return Column(
              children: [
                _buildLimitNote(
                  isReportsTab
                      ? 'DVIR report data view is limited to the past 30 days.'
                      : 'Defect data view is limited to the past 30 days.',
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: WebSearchField(
                    controller: _searchController,
                    hintText: isReportsTab ? 'Search Reports...' : 'Search Defects...',
                    showClear: _search.isNotEmpty,
                    onClear: () {
                      _searchController.clear();
                      setState(() {
                        _search = '';
                      });
                      _loadCurrentTab();
                    },
                  ),
                ),
                if (isReportsTab) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: _DvirDateField(
                            label: 'From',
                            value: _fromDate,
                            onTap: _pickFromDate,
                            onClear: _fromDate != null
                                ? () {
                                    setState(() => _fromDate = null);
                                    _loadReports();
                                  }
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DvirDateField(
                            label: 'To',
                            value: _toDate,
                            onTap: _pickToDate,
                            onClear: _toDate != null
                                ? () {
                                    setState(() => _toDate = null);
                                    _loadReports();
                                  }
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _typeFilter,
                            decoration:
                                const InputDecoration(labelText: 'Type', border: InputBorder.none),
                            items: const [
                              DropdownMenuItem(value: 'all', child: Text('All Types')),
                              DropdownMenuItem(value: 'pre-trip', child: Text('Pre-Trip')),
                              DropdownMenuItem(value: 'post-trip', child: Text('Post-Trip')),
                            ],
                            onChanged: (v) {
                              setState(() => _typeFilter = v ?? 'all');
                              _loadReports();
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _statusFilter,
                            decoration: const InputDecoration(
                                labelText: 'Status', border: InputBorder.none),
                            items: const [
                              DropdownMenuItem(value: 'all', child: Text('All Status')),
                              DropdownMenuItem(value: 'safe', child: Text('Safe')),
                              DropdownMenuItem(value: 'unsafe', child: Text('Unsafe')),
                            ],
                            onChanged: (v) {
                              setState(() => _statusFilter = v ?? 'all');
                              _loadReports();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _severityFilter,
                            decoration: const InputDecoration(
                                labelText: 'Severity', border: InputBorder.none),
                            items: const [
                              DropdownMenuItem(value: 'all', child: Text('All Severities')),
                              DropdownMenuItem(value: 'major', child: Text('Major')),
                              DropdownMenuItem(value: 'minor', child: Text('Minor')),
                            ],
                            onChanged: (v) {
                              setState(() => _severityFilter = v ?? 'all');
                              _loadDefects();
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _defectStatusFilter,
                            decoration: const InputDecoration(
                                labelText: 'Status', border: InputBorder.none),
                            items: const [
                              DropdownMenuItem(value: 'all', child: Text('All Status')),
                              DropdownMenuItem(value: 'open', child: Text('Open')),
                              DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
                            ],
                            onChanged: (v) {
                              setState(() => _defectStatusFilter = v ?? 'all');
                              _loadDefects();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      // Reports list
                      _reportsLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _reportsError != null
                              ? ApiErrorBanner(message: _reportsError!, onRetry: _loadReports)
                              : _reports.isEmpty
                                  ? ListEmptyState(
                                      message: 'No reports found',
                                      icon: Icons.description_outlined,
                                    )
                                  : ListView.builder(
                                      controller: _reportsScrollController,
                                      padding:
                                          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      itemCount: _reports.length + 1,
                                      itemBuilder: (context, i) {
                                        if (i == _reports.length) {
                                          return _reportsLoadingMore
                                              ? const Padding(
                                                  padding: EdgeInsets.all(16),
                                                  child:
                                                      Center(child: CircularProgressIndicator()),
                                                )
                                              : const SizedBox();
                                        }
                                        return _buildReportCard(_reports[i]);
                                      },
                                    ),
                      // Defects list
                      _defectsLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _defectsError != null
                              ? ApiErrorBanner(message: _defectsError!, onRetry: _loadDefects)
                              : _defects.isEmpty
                                  ? ListEmptyState(
                                      message: 'No defects found',
                                      icon: Icons.report_problem_outlined,
                                    )
                                  : ListView.builder(
                                      controller: _defectsScrollController,
                                      padding:
                                          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      itemCount: _defects.length + 1,
                                      itemBuilder: (context, i) {
                                        if (i == _defects.length) {
                                          return _defectsLoadingMore
                                              ? const Padding(
                                                  padding: EdgeInsets.all(16),
                                                  child:
                                                      Center(child: CircularProgressIndicator()),
                                                )
                                              : const SizedBox();
                                        }
                                        return _buildDefectCard(_defects[i]);
                                      },
                                    ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.bg,
    required this.fg,
    this.compact = false,
    this.italic = false,
  });

  final String label;
  final Color bg;
  final Color fg;
  final bool compact;
  final bool italic;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 3 : 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: compact ? 11 : 12,
          fontWeight: FontWeight.w700,
          fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        ),
      ),
    );
  }
}

class _GridText extends StatelessWidget {
  const _GridText({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return _GridCell(
      icon: icon,
      label: label,
      child: Text(
        value,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: valueColor ?? AppColors.textPrimary,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _GridCell extends StatelessWidget {
  const _GridCell({required this.icon, required this.label, required this.child});

  final IconData icon;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(
              label,
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
        child,
      ],
    );
  }
}

class _DvirDateField extends StatelessWidget {
  const _DvirDateField({
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final text = value != null ? DateFormat('MM-dd-yyyy').format(value!) : label;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_month_outlined, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 13,
                  color: value != null ? AppColors.textPrimary : AppColors.textSecondary,
                ),
              ),
            ),
            if (value != null && onClear != null)
              InkWell(
                onTap: onClear,
                child: Icon(Icons.close, size: 16, color: AppColors.textSecondary),
              ),
          ],
        ),
      ),
    );
  }
}
