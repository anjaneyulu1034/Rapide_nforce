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
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
      .toUpperCase();
}

class DvirScreen extends StatefulWidget {
  const DvirScreen({super.key, this.initialSearch});

  final String? initialSearch;

  @override
  State<DvirScreen> createState() => _DvirScreenState();
}

class _DvirScreenState extends State<DvirScreen>
    with SingleTickerProviderStateMixin {
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
  final String _typeFilter = 'all';
  final String _statusFilter = 'all';

  // State Defects
  bool _defectsLoading = true;
  bool _defectsLoadingMore = false;
  String? _defectsError;
  List<DvirDefectModel> _defects = [];
  int _defectsPage = 1;
  int _defectsTotalPages = 1;
  final String _severityFilter = 'all';
  final String _defectStatusFilter = 'all';

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

  Future<void> _loadReports() async {
    setState(() {
      _reportsLoading = true;
      _reportsError = null;
      _reports = [];
      _reportsPage = 1;
    });

    final result = await DvirService.instance.fetchReports(
      page: 1,
      limit: 100,
      search: _search.isEmpty ? null : _search,
      inspectionType: _typeFilter == 'all' ? null : _typeFilter,
      reportStatus: _statusFilter == 'all' ? null : _statusFilter,
    );

    if (!mounted) return;

    if (!result.isSuccess) {
      setState(() {
        _reportsLoading = false;
        _reportsError = ApiFeedback.errorMessage(
          result,
          fallback: 'Failed to load DVIR reports',
        );
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
    if (_reportsLoading ||
        _reportsLoadingMore ||
        _reportsPage >= _reportsTotalPages) {
      return;
    }

    setState(() {
      _reportsLoadingMore = true;
    });

    final nextPage = _reportsPage + 1;
    final result = await DvirService.instance.fetchReports(
      page: nextPage,
      limit: 100,
      search: _search.isEmpty ? null : _search,
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
      limit: 100,
      search: _search.isEmpty ? null : _search,
      defectStatus: _defectStatusFilter == 'all' ? null : _defectStatusFilter,
      severity: _severityFilter == 'all' ? null : _severityFilter,
    );

    if (!mounted) return;

    if (!result.isSuccess) {
      setState(() {
        _defectsLoading = false;
        _defectsError = ApiFeedback.errorMessage(
          result,
          fallback: 'Failed to load DVIR defects',
        );
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
    if (_defectsLoading ||
        _defectsLoadingMore ||
        _defectsPage >= _defectsTotalPages) {
      return;
    }

    setState(() {
      _defectsLoadingMore = true;
    });

    final nextPage = _defectsPage + 1;
    final result = await DvirService.instance.fetchDefects(
      page: nextPage,
      limit: 100,
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
    final avColor = _avatarColor(r.driverName);
    final initials = _initials(r.driverName);

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => DvirDetailScreen(reportId: r.id)),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    r.vehicleNumber,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: safeBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    r.reportStatus.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: safeFg,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: avColor,
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  r.driverName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: typeBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    r.inspectionType,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: typeFg,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDateTime(r.reportedAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  '${r.defectCount} defect${r.defectCount == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: r.defectCount > 0
                        ? AppColors.danger
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefectCard(DvirDefectModel d) {
    final (statusBg, statusFg) = _defectStatusColors(d.defectStatus);
    final (sevBg, sevFg) = _severityColors(d.severity);

    return InkWell(
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DvirDefectDetailScreen(defectId: d.id),
          ),
        );
        _loadDefects();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    d.defectName,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    d.defectStatus.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: statusFg,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Code: ${d.defectCode} · Vehicle: ${d.vehicleNumber ?? '—'}',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (d.severity != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: sevBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      d.severity!,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: sevFg,
                      ),
                    ),
                  ),
                const Spacer(),
                Text(
                  _formatDateTime(d.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
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
      body: WebPageBody(
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverToBoxAdapter(
              child: WebPageHeader(
                title: 'DVIR Inspection Reports',
                subtitle:
                    'Driver vehicle inspection reports, defect tracking, and safety compliance.',
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: AppColors.primary,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  tabs: const [
                    Tab(text: 'Reports'),
                    Tab(text: 'Defects'),
                  ],
                ),
              ),
            ),
          ],
          body: TabBarView(
            controller: _tabController,
            children: [
              // Tab 1: Reports
              RefreshIndicator(
                onRefresh: _loadReports,
                child: ListView(
                  controller: _reportsScrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    WebSearchField(
                      controller: _searchController,
                      hintText: 'Search report, vehicle, driver...',
                    ),
                    const SizedBox(height: 12),
                    if (_reportsError != null)
                      ApiErrorBanner(
                        message: _reportsError!,
                        onRetry: _loadReports,
                      ),
                    if (_reportsLoading)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_reports.isEmpty)
                      const ListEmptyState(
                        message:
                            'No DVIR inspection reports match your criteria.',
                        icon: Icons.assignment_outlined,
                      )
                    else
                      ..._reports.map(_buildReportCard),
                    if (_reportsLoadingMore)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                  ],
                ),
              ),

              // Tab 2: Defects
              RefreshIndicator(
                onRefresh: _loadDefects,
                child: ListView(
                  controller: _defectsScrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    WebSearchField(
                      controller: _searchController,
                      hintText: 'Search defect, code, vehicle...',
                    ),
                    const SizedBox(height: 12),
                    if (_defectsError != null)
                      ApiErrorBanner(
                        message: _defectsError!,
                        onRetry: _loadDefects,
                      ),
                    if (_defectsLoading)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_defects.isEmpty)
                      const ListEmptyState(
                        message: 'No vehicle defects match your criteria.',
                        icon: Icons.warning_amber_rounded,
                      )
                    else
                      ..._defects.map(_buildDefectCard),
                    if (_defectsLoadingMore)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
