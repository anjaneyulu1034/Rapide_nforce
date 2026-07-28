import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/core/utils/api_feedback.dart';
import 'package:rapide_nforce/core/utils/app_toast.dart';
import 'package:rapide_nforce/core/utils/compact_date_picker.dart';
import 'package:rapide_nforce/models/dvir_defect_model.dart';
import 'package:rapide_nforce/models/dvir_report_model.dart';
import 'package:rapide_nforce/models/work_order_model.dart';
import 'package:rapide_nforce/services/dvir_service.dart';
import 'package:rapide_nforce/services/maintenance_service.dart';
import 'package:rapide_nforce/ui/dvir/dvir_defect_detail_screen.dart';
import 'package:rapide_nforce/ui/dvir/dvir_detail_screen.dart';
import 'package:rapide_nforce/ui/widgets/api_error_banner.dart';
import 'package:rapide_nforce/ui/widgets/list_empty_state.dart';
import 'package:rapide_nforce/ui/widgets/web_ui.dart';
import 'package:rapide_nforce/ui/work_orders/work_order_form_screen.dart';

String _formatDateTime(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) return iso;
  return DateFormat('MM-dd-yyyy, hh:mm a').format(parsed.toLocal());
}

// Raw `inspectionType`/`reportStatus` values come straight from whichever
// telematics provider synced them (Samsara, GoMotive, ...) and are not
// normalized server-side, so casing/separators vary ("pretrip", "PRE_TRIP",
// "Pre-Trip", ...). Normalize here for both display and client-side
// filtering — mirrors the web app's formatInspectionType/formatReportStatus.
String _formatInspectionType(String? type) {
  if (type == null || type.trim().isEmpty) return 'No Type';
  final normalized = type.replaceAll(RegExp(r'[_-]'), '').toLowerCase();
  if (normalized == 'pretrip') return 'Pre-Trip';
  if (normalized == 'posttrip') return 'Post-Trip';
  final t = type.trim();
  return t[0].toUpperCase() + t.substring(1);
}

String _formatReportStatus(String? status) {
  if (status == null || status.trim().isEmpty) return 'Unknown';
  final normalized = status.trim().toLowerCase();
  if (normalized == 'safe' || normalized == 'acceptable') return 'Safe';
  if (normalized == 'unsafe' || normalized == 'unsatisfactory') return 'Unsafe';
  final s = status.trim();
  return s[0].toUpperCase() + s.substring(1);
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
  switch (status.trim().toLowerCase()) {
    case 'unsafe':
    case 'unsatisfactory':
      return (const Color(0xFFFEE2E2), const Color(0xFFDC2626));
    case 'safe':
    case 'acceptable':
      return (const Color(0xFFDCFCE7), const Color(0xFF008236));
    default:
      return (const Color(0xFFF1F5F9), const Color(0xFF64748B));
  }
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

/// Left-stripe accent for a report card — mirrors the Work Order card's
/// priority accent stripe, keyed off safety status instead of priority.
Color _reportAccentColor(String statusLabel) {
  switch (statusLabel.trim().toLowerCase()) {
    case 'unsafe':
      return const Color(0xFFDC2626);
    case 'safe':
      return const Color(0xFF16A34A);
    default:
      return const Color(0xFF94A3B8);
  }
}

/// Left-stripe accent for a defect card. Open defects read as urgent
/// (red/amber by severity, matching the Work Order card's high/medium
/// priority accents); resolved defects read as settled (green).
Color _defectAccentColor(String? severity, String status) {
  if (status.trim().toLowerCase() != 'open') {
    return const Color(0xFF16A34A);
  }
  switch (severity?.toLowerCase()) {
    case 'major':
    case 'high':
      return const Color(0xFFDC2626);
    case 'minor':
    case 'low':
      return const Color(0xFFF59E0B);
    default:
      return const Color(0xFFDC2626);
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
  String _typeFilter = 'all';
  String _statusFilter = 'all';
  String _reportedFrom = '';
  String _reportedTo = '';

  // State Defects
  bool _defectsLoading = true;
  bool _defectsLoadingMore = false;
  String? _defectsError;
  List<DvirDefectModel> _defects = [];
  int _defectsPage = 1;
  int _defectsTotalPages = 1;
  String _severityFilter = 'all';
  String _defectStatusFilter = 'open';
  String _sourceFilter = 'all';

  // Multi-select state for bundling several open defects (same vehicle)
  // into one work order — mirrors the web app's Defects grid checkboxes.
  final Set<String> _selectedDefectIds = {};
  final Set<String> _blockedDefectIds = {};
  final Set<String> _checkingWorkOrderIds = {};

  // inspectionType/reportStatus are not reliably exact-match filterable
  // server-side (raw provider casing varies), so Type/Status are applied
  // client-side against the normalized display labels — mirrors the web
  // app's own client-side filtering for these two fields.
  List<DvirReportModel> get _visibleReports {
    var list = _reports;
    if (_typeFilter != 'all') {
      list = list
          .where((r) => _formatInspectionType(r.inspectionType) == _typeFilter)
          .toList();
    }
    if (_statusFilter != 'all') {
      list = list
          .where((r) => _formatReportStatus(r.reportStatus) == _statusFilter)
          .toList();
    }
    return list;
  }

  // Mirrors the web app's `hasRequiredVehicleIdentity` rule (DvirDefectsPage.tsx) —
  // hides grid rows when either vehicle number or VIN is missing/null/empty.
  bool _hasRequiredVehicleIdentity(DvirDefectModel d) {
    String normalize(String? val) {
      final trimmed = (val ?? '').trim();
      if (trimmed.isEmpty || trimmed == '—') return '';
      final lower = trimmed.toLowerCase();
      if (lower == 'null' ||
          lower == 'undefined' ||
          lower == 'n/a' ||
          lower == 'na' ||
          lower.startsWith('no ')) {
        return '';
      }
      return trimmed;
    }

    final vehicle = normalize(d.vehicleNumber);
    final vin = normalize(d.vin);
    return vehicle.isNotEmpty && vin.isNotEmpty;
  }

  // Mirrors the web app's DvirDefectsPage filtering — hides rows without valid
  // vehicle identity, and applies status, severity, and source filters.
  List<DvirDefectModel> get _visibleDefects {
    var list = _defects.where(_hasRequiredVehicleIdentity).toList();
    if (_defectStatusFilter != 'all') {
      list = list.where((d) {
        if (_defectStatusFilter == 'open') return d.isOpen;
        if (_defectStatusFilter == 'resolved') return d.isResolved;
        if (_defectStatusFilter == 'unresolved') return !d.isResolved;
        return d.defectStatus.trim().toLowerCase() == _defectStatusFilter;
      }).toList();
    }
    if (_severityFilter != 'all') {
      list = list.where((d) {
        return (d.severity ?? '').trim().toLowerCase() == _severityFilter;
      }).toList();
    }
    if (_sourceFilter != 'all') {
      list = list
          .where((d) => d.integrationSourceName == _sourceFilter)
          .toList();
    }
    return list;
  }

  List<String> get _availableSources {
    final sources = <String>{};
    for (final d in _defects.where(_hasRequiredVehicleIdentity)) {
      if (d.integrationSourceName.trim().isNotEmpty) {
        sources.add(d.integrationSourceName.trim());
      }
    }
    final list = sources.toList()..sort();
    return list;
  }

  bool get _hasActiveReportFilters =>
      _search.isNotEmpty ||
      _typeFilter != 'all' ||
      _statusFilter != 'all' ||
      _reportedFrom.isNotEmpty ||
      _reportedTo.isNotEmpty;

  bool get _hasActiveDefectFilters =>
      _search.isNotEmpty ||
      _severityFilter != 'all' ||
      _defectStatusFilter != 'open' ||
      _sourceFilter != 'all';

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

  void _showDefectFiltersBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        String tempSeverity = _severityFilter;
        String tempStatus = _defectStatusFilter;
        String tempSource = _sourceFilter;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bottomInset =
                MediaQuery.of(context).viewInsets.bottom +
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
                            'Filter Defects',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setSheetState(() {
                                tempSeverity = 'all';
                                tempStatus = 'open';
                                tempSource = 'all';
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
                            onSelected: (_) =>
                                setSheetState(() => tempStatus = 'all'),
                          ),
                          _filterChip(
                            label: 'Open',
                            selected: tempStatus == 'open',
                            onSelected: (_) =>
                                setSheetState(() => tempStatus = 'open'),
                          ),
                          _filterChip(
                            label: 'Resolved',
                            selected: tempStatus == 'resolved',
                            onSelected: (_) =>
                                setSheetState(() => tempStatus = 'resolved'),
                          ),
                          _filterChip(
                            label: 'Unresolved',
                            selected: tempStatus == 'unresolved',
                            onSelected: (_) =>
                                setSheetState(() => tempStatus = 'unresolved'),
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
                            onSelected: (_) =>
                                setSheetState(() => tempSeverity = 'all'),
                          ),
                          _filterChip(
                            label: 'Major',
                            selected: tempSeverity == 'major',
                            onSelected: (_) =>
                                setSheetState(() => tempSeverity = 'major'),
                          ),
                          _filterChip(
                            label: 'Minor',
                            selected: tempSeverity == 'minor',
                            onSelected: (_) =>
                                setSheetState(() => tempSeverity = 'minor'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Source filter section
                      if (_availableSources.isNotEmpty) ...[
                        Text(
                          'Source',
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
                              selected: tempSource == 'all',
                              onSelected: (_) =>
                                  setSheetState(() => tempSource = 'all'),
                            ),
                            for (final src in _availableSources)
                              _filterChip(
                                label: src,
                                selected: tempSource == src,
                                onSelected: (_) =>
                                    setSheetState(() => tempSource = src),
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],

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
                              _severityFilter = tempSeverity;
                              _defectStatusFilter = tempStatus;
                              _sourceFilter = tempSource;
                            });
                            _loadDefects();
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

  void _showReportFiltersBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        String tempType = _typeFilter;
        String tempStatus = _statusFilter;
        String tempFrom = _reportedFrom;
        String tempTo = _reportedTo;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bottomInset =
                MediaQuery.of(context).viewInsets.bottom +
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
                            'Filter Inspection Reports',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setSheetState(() {
                                tempType = 'all';
                                tempStatus = 'all';
                                tempFrom = '';
                                tempTo = '';
                              });
                            },
                            child: const Text('Reset All'),
                          ),
                        ],
                      ),
                      const Divider(height: 20),

                      // Inspection Type filter section
                      Text(
                        'Inspection Type',
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
                            selected: tempType == 'all',
                            onSelected: (_) =>
                                setSheetState(() => tempType = 'all'),
                          ),
                          _filterChip(
                            label: 'Pre-Trip',
                            selected: tempType == 'Pre-Trip',
                            onSelected: (_) =>
                                setSheetState(() => tempType = 'Pre-Trip'),
                          ),
                          _filterChip(
                            label: 'Post-Trip',
                            selected: tempType == 'Post-Trip',
                            onSelected: (_) =>
                                setSheetState(() => tempType = 'Post-Trip'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Status filter section
                      Text(
                        'Condition / Status',
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
                            onSelected: (_) =>
                                setSheetState(() => tempStatus = 'all'),
                          ),
                          _filterChip(
                            label: 'Safe',
                            selected: tempStatus == 'Safe',
                            onSelected: (_) =>
                                setSheetState(() => tempStatus = 'Safe'),
                          ),
                          _filterChip(
                            label: 'Unsafe',
                            selected: tempStatus == 'Unsafe',
                            onSelected: (_) =>
                                setSheetState(() => tempStatus = 'Unsafe'),
                          ),
                          _filterChip(
                            label: 'Unknown',
                            selected: tempStatus == 'Unknown',
                            onSelected: (_) =>
                                setSheetState(() => tempStatus = 'Unknown'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Date Range filter section
                      Text(
                        'Date Range',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _DateFilterButton(
                              label: 'Reported From',
                              value: tempFrom,
                              lastDate: DateTime.now(),
                              onChanged: (v) {
                                setSheetState(() {
                                  tempFrom = v;
                                  if (tempTo.isNotEmpty &&
                                      v.isNotEmpty &&
                                      tempTo.compareTo(v) < 0) {
                                    tempTo = '';
                                  }
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _DateFilterButton(
                              label: 'Reported To',
                              value: tempTo,
                              firstDate: tempFrom.isEmpty
                                  ? null
                                  : DateTime.tryParse(tempFrom),
                              lastDate: DateTime.now(),
                              onChanged: (v) {
                                setSheetState(() => tempTo = v);
                              },
                            ),
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
                              _typeFilter = tempType;
                              _statusFilter = tempStatus;
                              _reportedFrom = tempFrom;
                              _reportedTo = tempTo;
                            });
                            _loadReports();
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

  bool _canSelectDefect(DvirDefectModel d) =>
      d.isOpen && !_blockedDefectIds.contains(d.id);

  // Only defects for the same vehicle can be bundled into one work order —
  // mirrors the web app's `selectedDefectsHaveSameVin` guard.
  bool get _selectedDefectsShareSameVin {
    final selected = _defects
        .where((d) => _selectedDefectIds.contains(d.id))
        .toList();
    if (selected.length < 2) return true;

    final firstVin = (selected.first.vin ?? '').trim().toLowerCase();
    final firstVehicle = (selected.first.vehicleNumber ?? '')
        .trim()
        .toLowerCase();

    for (final d in selected) {
      final vin = (d.vin ?? '').trim().toLowerCase();
      final vehicle = (d.vehicleNumber ?? '').trim().toLowerCase();

      if (firstVin.isNotEmpty && vin.isNotEmpty && vin != firstVin) {
        return false;
      }
      if (firstVehicle.isNotEmpty &&
          vehicle.isNotEmpty &&
          vehicle != firstVehicle) {
        return false;
      }
    }
    return true;
  }

  // Toggles one defect's selection, running the same "does an open work
  // order already exist for this defect" guard the web app runs before
  // allowing a checkbox to be checked.
  Future<void> _toggleDefectSelection(DvirDefectModel d) async {
    if (_selectedDefectIds.contains(d.id)) {
      setState(() => _selectedDefectIds.remove(d.id));
      return;
    }
    if (!await _passesExistingWorkOrderCheck(d)) return;
    if (!mounted) return;
    setState(() => _selectedDefectIds.add(d.id));
  }

  Future<bool> _passesExistingWorkOrderCheck(DvirDefectModel d) async {
    if (_checkingWorkOrderIds.contains(d.id)) return false;
    setState(() => _checkingWorkOrderIds.add(d.id));
    final result = await MaintenanceService.instance.checkExistingWorkOrder(
      sourceId: d.id,
      unitNumber: d.vehicleNumber ?? '',
    );
    if (!mounted) return false;
    setState(() => _checkingWorkOrderIds.remove(d.id));

    if (!result.isSuccess) {
      AppToast.showError(
        'Could not verify existing work orders. Please try again.',
      );
      return false;
    }
    final check = result.data!;
    if (check.exists) {
      setState(() => _blockedDefectIds.add(d.id));
      AppToast.showError(
        'A work order already exists for this defect'
        '${check.workOrderNumber != null ? ' (${check.workOrderNumber})' : ''}'
        '${check.statusLabel != null ? ', status: ${check.statusLabel}' : ''}.',
      );
      return false;
    }
    setState(() => _blockedDefectIds.remove(d.id));
    return true;
  }

  Future<void> _createWorkOrderForDefects(List<DvirDefectModel> defects) async {
    if (defects.isEmpty) return;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => WorkOrderFormScreen(
          linkedDefects: defects
              .map(
                (d) => WorkOrderLinkedDefect(
                  defectId: d.id,
                  description:
                      'DVIR Defect: ${d.defectName} (Code: ${d.defectCode})',
                  vin: d.vin,
                  unitNumber: d.vehicleNumber,
                ),
              )
              .toList(),
        ),
      ),
    );
    if (!mounted) return;
    if (changed == true) {
      setState(() {
        for (final d in defects) {
          _selectedDefectIds.remove(d.id);
        }
      });
    }
  }

  Future<void> _createWorkOrderForSingle(DvirDefectModel d) async {
    if (_blockedDefectIds.contains(d.id)) {
      AppToast.showError('A work order already exists for this defect');
      return;
    }
    if (!await _passesExistingWorkOrderCheck(d)) return;
    await _createWorkOrderForDefects([d]);
  }

  Future<void> _createWorkOrderForSelected() async {
    if (_selectedDefectIds.isEmpty) return;
    if (!_selectedDefectsShareSameVin) {
      AppToast.showError(
        'The selected defects belong to different vehicles. Please select '
        'defects with the same VIN to create a work order.',
      );
      return;
    }
    final selected = _defects
        .where((d) => _selectedDefectIds.contains(d.id))
        .toList();
    await _createWorkOrderForDefects(selected);
  }

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
      reportedFrom: _reportedFrom.isEmpty ? null : _reportedFrom,
      reportedTo: _reportedTo.isEmpty ? null : _reportedTo,
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
      reportedFrom: _reportedFrom.isEmpty ? null : _reportedFrom,
      reportedTo: _reportedTo.isEmpty ? null : _reportedTo,
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

  Widget _buildReportCard(DvirReportModel r) {
    final statusLabel = _formatReportStatus(r.reportStatus);
    final typeLabel = _formatInspectionType(r.inspectionType);
    final (safeBg, safeFg) = _safetyColors(statusLabel);
    final (typeBg, typeFg) = _typeColors(typeLabel);
    final avColor = _avatarColor(r.driverName);
    final initials = _initials(r.driverName);
    final accent = _reportAccentColor(statusLabel);

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
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DvirDetailScreen(reportId: r.id),
              ),
            );
          },
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 5, color: accent),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                r.vehicleNumber,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            _MiniBadge(
                              label: statusLabel.toUpperCase(),
                              bgColor: safeBg,
                              textColor: safeFg,
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
                            Expanded(
                              child: Text(
                                r.driverName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            _MiniBadge(
                              label: typeLabel,
                              bgColor: typeBg,
                              textColor: typeFg,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${r.companyName} · ${r.integrationSourceName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _GridCell(
                                label: 'REPORTED',
                                child: Text(
                                  _formatDateTime(r.reportedAt),
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
                                label: 'DEFECTS',
                                child: Text(
                                  '${r.defectCount}',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: r.defectCount > 0
                                        ? AppColors.danger
                                        : AppColors.textPrimary,
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

  Widget _buildDefectCard(DvirDefectModel d) {
    final (statusBg, statusFg) = _defectStatusColors(d.defectStatus);
    final (sevBg, sevFg) = _severityColors(d.severity);
    final accent = _defectAccentColor(d.severity, d.defectStatus);
    final isSelected = _selectedDefectIds.contains(d.id);

    final vehicleDisplay = (d.vehicleNumber ?? '').trim().isNotEmpty
        ? d.vehicleNumber!.trim()
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
          onTap: () async {
            final changed = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => DvirDefectDetailScreen(defectId: d.id),
              ),
            );
            if (changed == true) _loadDefects();
          },
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
                        // Top row: Status badge (Left) | Checkbox & + Create Work Order Button (Right)
                        Row(
                          children: [
                            _MiniBadge(
                              label: d.defectStatus.toUpperCase(),
                              bgColor: statusBg,
                              textColor: statusFg,
                            ),
                            const Spacer(),
                            if (d.isOpen) ...[
                              if (isSelected &&
                                  !_blockedDefectIds.contains(d.id)) ...[
                                _CreateWorkOrderButton(
                                  loading: _checkingWorkOrderIds.contains(d.id),
                                  onPressed: () => _createWorkOrderForSingle(d),
                                ),
                                const SizedBox(width: 8),
                              ],
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: _checkingWorkOrderIds.contains(d.id)
                                    ? const Padding(
                                        padding: EdgeInsets.all(3),
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Checkbox(
                                        value: isSelected,
                                        onChanged: _canSelectDefect(d)
                                            ? (_) => _toggleDefectSelection(d)
                                            : null,
                                        visualDensity: VisualDensity.compact,
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                              ),
                            ],
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
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Defect Name & Code
                        RichText(
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                            children: [
                              const TextSpan(text: 'Defect: '),
                              TextSpan(
                                text: d.defectName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              if (d.defectCode.trim().isNotEmpty) ...[
                                TextSpan(
                                  text: ' (Code: ${d.defectCode})',
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
                        const SizedBox(height: 10),

                        // Bottom Grid: Source | Severity | Reported Date
                        Row(
                          children: [
                            Expanded(
                              child: _GridCell(
                                label: 'SOURCE',
                                child: Text(
                                  d.integrationSourceName.trim().isNotEmpty
                                      ? d.integrationSourceName
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
                                child:
                                    d.severity != null &&
                                        d.severity!.trim().isNotEmpty
                                    ? _MiniBadge(
                                        label: d.severity!,
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
                                  _formatDateTime(d.createdAt),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WebPageBody(
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            // SliverToBoxAdapter(
            //   child: WebPageHeader(
            //     title: 'DVIR Inspection Reports',
            //     subtitle:
            //         'Driver vehicle inspection reports, defect tracking, and safety compliance.',
            //   ),
            // ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: WebTabPills(
                  child: Row(
                    children: [
                      Expanded(
                        child: WebTabPill(
                          label: 'Reports',
                          selected: _tabController.index == 0,
                          onTap: () => _tabController.animateTo(0),
                        ),
                      ),
                      Expanded(
                        child: WebTabPill(
                          label: 'Defects',
                          selected: _tabController.index == 1,
                          onTap: () => _tabController.animateTo(1),
                        ),
                      ),
                    ],
                  ),
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
                    Row(
                      children: [
                        Expanded(
                          child: WebSearchField(
                            controller: _searchController,
                            hintText: 'Search report, vehicle, driver...',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _showReportFiltersBottomSheet,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              height: 44,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.card,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _hasActiveReportFilters
                                      ? const Color(0xFF0E7490)
                                      : AppColors.border,
                                  width: _hasActiveReportFilters ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.filter_list_rounded,
                                    size: 20,
                                    color: _hasActiveReportFilters
                                        ? const Color(0xFF0E7490)
                                        : AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Filter',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _hasActiveReportFilters
                                          ? const Color(0xFF0E7490)
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
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
                    else if (_visibleReports.isEmpty)
                      const ListEmptyState(
                        message:
                            'No DVIR inspection reports match your criteria.',
                        icon: Icons.assignment_outlined,
                      )
                    else
                      ..._visibleReports.map(_buildReportCard),
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
                    Row(
                      children: [
                        Expanded(
                          child: WebSearchField(
                            controller: _searchController,
                            hintText: 'Search defect, code, vehicle...',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _showDefectFiltersBottomSheet,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              height: 44,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.card,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _hasActiveDefectFilters
                                      ? const Color(0xFF0E7490)
                                      : AppColors.border,
                                  width: _hasActiveDefectFilters ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.filter_list_rounded,
                                    size: 20,
                                    color: _hasActiveDefectFilters
                                        ? const Color(0xFF0E7490)
                                        : AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Filter',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _hasActiveDefectFilters
                                          ? const Color(0xFF0E7490)
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (_selectedDefectIds.length > 1) ...[
                      _SelectionBar(
                        count: _selectedDefectIds.length,
                        sameVin: _selectedDefectsShareSameVin,
                        onClear: () =>
                            setState(() => _selectedDefectIds.clear()),
                        onCreate: _createWorkOrderForSelected,
                      ),
                      const SizedBox(height: 12),
                    ],
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
                    else if (_visibleDefects.isEmpty)
                      const ListEmptyState(
                        message: 'No vehicle defects match your criteria.',
                        icon: Icons.warning_amber_rounded,
                      )
                    else
                      ..._visibleDefects.map(_buildDefectCard),
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

// ---------------------------------------------------------------------------
// Small shared building blocks for the report/defect cards above — same
// spec as the Work Order card's `_GridCell`/`_MiniBadge` (work_orders_screen
// .dart) so DVIR cards read as visually consistent with Work Orders.
// ---------------------------------------------------------------------------

class _GridCell extends StatelessWidget {
  const _GridCell({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 5),
        child,
      ],
    );
  }
}

/// Selection summary shown once 2+ defects are checked — same information
/// as the web app's fixed bottom footer (count, clear, bulk create), just
/// laid out inline in the scroll flow instead of pinned to the screen edge.
class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.count,
    required this.sameVin,
    required this.onClear,
    required this.onCreate,
  });

  final int count;
  final bool sameVin;
  final VoidCallback onClear;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    children: [
                      TextSpan(
                        text: '$count ',
                        style: const TextStyle(
                          color: _CreateWorkOrderButton._teal,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const TextSpan(text: 'selected'),
                    ],
                  ),
                ),
                if (count > 0 && !sameVin) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Different vehicles — select same-vehicle defects only',
                    style: TextStyle(fontSize: 11, color: AppColors.danger),
                  ),
                ],
                if (count > 0)
                  GestureDetector(
                    onTap: onClear,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Clear Selection',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _CreateWorkOrderButton._teal,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _CreateWorkOrderButton(
            onPressed: (count > 0 && sameVin) ? onCreate : null,
          ),
        ],
      ),
    );
  }
}

/// Solid teal "+ Create Work Order" pill — matches the web app's per-row
/// action button color (`#0E7490`) so the two apps read as the same feature.
class _CreateWorkOrderButton extends StatelessWidget {
  const _CreateWorkOrderButton({required this.onPressed, this.loading = false});

  final VoidCallback? onPressed;
  final bool loading;

  static const _teal = Color(0xFF0E7490);

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || loading;
    return Material(
      color: disabled ? _teal.withValues(alpha: 0.5) : _teal,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: disabled ? null : onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                const SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else
                const Icon(Icons.add, size: 15, color: Colors.white),
              const SizedBox(width: 5),
              const Text(
                'Create Work Order',
                maxLines: 1,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Compact date filter button — opens [showCompactDatePicker] and reports
/// the picked date back as `yyyy-MM-dd` (matching the API's `reportedFrom`/
/// `reportedTo` query param format). Pass an empty string for "no date".
class _DateFilterButton extends StatelessWidget {
  const _DateFilterButton({
    required this.label,
    required this.value,
    required this.onChanged,
    this.firstDate,
    this.lastDate,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;

  @override
  Widget build(BuildContext context) {
    final parsed = value.isEmpty ? null : DateTime.tryParse(value);
    final display = parsed == null
        ? label
        : DateFormat('MM-dd-yyyy').format(parsed);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final now = DateTime.now();
        final picked = await showCompactDatePicker(
          context: context,
          initialDate: parsed ?? firstDate ?? now,
          firstDate: firstDate ?? DateTime(now.year - 5),
          lastDate: lastDate ?? DateTime(now.year + 5),
        );
        if (picked != null) {
          onChanged(DateFormat('yyyy-MM-dd').format(picked));
        }
      },
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceTertiary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 15,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                display,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: parsed == null
                      ? FontWeight.w500
                      : FontWeight.w700,
                  color: parsed == null
                      ? AppColors.textSecondary
                      : AppColors.textPrimary,
                ),
              ),
            ),
            if (parsed != null)
              InkWell(
                onTap: () => onChanged(''),
                child: Icon(
                  Icons.close,
                  size: 15,
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
