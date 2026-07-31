import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/core/utils/api_feedback.dart';
import 'package:rapide_nforce/core/utils/app_toast.dart';
import 'package:rapide_nforce/core/utils/role_utils.dart';
import 'package:rapide_nforce/models/trailer_model.dart';
import 'package:rapide_nforce/services/auth_service.dart';
import 'package:rapide_nforce/services/trailer_service.dart';
import 'package:rapide_nforce/ui/trailer_detail_screen.dart';
import 'package:rapide_nforce/ui/trailers/trailer_form_screen.dart';
import 'package:rapide_nforce/ui/trailers/trailer_import_screen.dart';
import 'package:rapide_nforce/ui/widgets/api_error_banner.dart';
import 'package:rapide_nforce/ui/widgets/icon_only_button.dart';
import 'package:rapide_nforce/ui/widgets/list_empty_state.dart';
import 'package:rapide_nforce/ui/widgets/status_badge.dart';
import 'package:rapide_nforce/ui/widgets/web_ui.dart';

class TrailersScreen extends StatefulWidget {
  const TrailersScreen({super.key});

  @override
  State<TrailersScreen> createState() => _TrailersScreenState();
}

class _TrailersScreenState extends State<TrailersScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;

  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  List<TrailerModel> _items = [];
  int _page = 1;
  final int _limit = 10;
  int _total = 0;
  int _totalPages = 1;
  String _search = '';

  bool get _isSuperAdmin =>
      isSuperAdminRole(AuthService.instance.currentUser?.role);
  bool get _isAdminOrSuperAdmin =>
      isAdminRole(AuthService.instance.currentUser?.role);

  // Column sort — applied client-side over the fetched batch, mirroring the
  // web list's clickable-column-header sort (which is also client-side).
  String? _sortColumn;
  bool _sortAscending = true;

  static const Map<String, String> _sortColumns = {
    'trailerNumber': 'Unit #',
    'startDate': 'Start Date',
    'vinNumber': 'VIN',
    'licensePlate': 'Plate',
    'registrationExpiry': 'Registration Expiry',
    'status': 'Status',
  };

  DateTime? _parseDate(String? s) {
    if (s == null || s.isEmpty) return null;
    final parsed = DateTime.tryParse(s);
    if (parsed != null) return parsed;
    final parts = s.split('-');
    if (parts.length == 3) {
      final m = int.tryParse(parts[0]);
      final d = int.tryParse(parts[1]);
      final y = int.tryParse(parts[2]);
      if (m != null && d != null && y != null) return DateTime(y, m, d);
    }
    return null;
  }

  List<TrailerModel> get _visibleItems {
    final column = _sortColumn;
    if (column == null) return _items;
    int compareStrings(String? a, String? b) =>
        (a ?? '').toLowerCase().compareTo((b ?? '').toLowerCase());
    int compareDates(String? a, String? b) {
      final da = _parseDate(a)?.millisecondsSinceEpoch ?? 0;
      final db = _parseDate(b)?.millisecondsSinceEpoch ?? 0;
      return da.compareTo(db);
    }

    int cmp(TrailerModel a, TrailerModel b) {
      switch (column) {
        case 'trailerNumber':
          return compareStrings(a.trailerNumber, b.trailerNumber);
        case 'startDate':
          return compareDates(a.startDate, b.startDate);
        case 'vinNumber':
          return compareStrings(a.vinNumber, b.vinNumber);
        case 'licensePlate':
          return compareStrings(a.licensePlate, b.licensePlate);
        case 'registrationExpiry':
          return compareDates(a.registrationExpiry, b.registrationExpiry);
        case 'status':
          return (a.isActive ? 1 : 0).compareTo(b.isActive ? 1 : 0);
        default:
          return 0;
      }
    }

    final sorted = [..._items];
    sorted.sort((a, b) => _sortAscending ? cmp(a, b) : cmp(b, a));
    return sorted;
  }

  Future<void> _openSortSheet() async {
    String? tempColumn = _sortColumn;
    bool tempAscending = _sortAscending;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            Widget columnChip(String value, String label) {
              final selected = tempColumn == value;
              return ChoiceChip(
                label: Text(label),
                selected: selected,
                onSelected: (_) =>
                    setSheetState(() => tempColumn = selected ? null : value),
                selectedColor: AppColors.primary.withValues(alpha: 0.15),
                labelStyle: TextStyle(
                  color: selected ? AppColors.primary : AppColors.textPrimary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13,
                ),
                side: BorderSide(
                  color: selected ? AppColors.primary : AppColors.border,
                ),
                backgroundColor: AppColors.inputFill,
              );
            }

            Widget directionChip(String label, bool ascending) {
              final selected = tempAscending == ascending;
              return ChoiceChip(
                label: Text(label),
                selected: selected,
                onSelected: (_) =>
                    setSheetState(() => tempAscending = ascending),
                selectedColor: AppColors.primary.withValues(alpha: 0.15),
                labelStyle: TextStyle(
                  color: selected ? AppColors.primary : AppColors.textPrimary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13,
                ),
                side: BorderSide(
                  color: selected ? AppColors.primary : AppColors.border,
                ),
                backgroundColor: AppColors.inputFill,
              );
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: 20 + MediaQuery.of(sheetContext).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sort Trailers',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'SORT BY COLUMN',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final entry in _sortColumns.entries)
                          columnChip(entry.key, entry.value),
                      ],
                    ),
                    if (tempColumn != null) ...[
                      const SizedBox(height: 18),
                      Text(
                        'ORDER',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          directionChip('Ascending', true),
                          directionChip('Descending', false),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setSheetState(() {
                                tempColumn = null;
                                tempAscending = true;
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textPrimary,
                              side: BorderSide(color: AppColors.border),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('Clear'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              final columnChanged = tempColumn != _sortColumn;
                              setState(() {
                                _sortColumn = tempColumn;
                                _sortAscending = tempAscending;
                              });
                              Navigator.pop(sheetContext);
                              if (columnChanged) _load();
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF4B633D),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'Apply',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

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

  int get _effectiveLimit => _sortColumn != null ? 500 : _limit;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _page = 1;
      _items = [];
    });

    final result = await TrailerService.instance.fetchTrailers(
      page: 1,
      limit: _effectiveLimit,
      search: _search.isEmpty ? null : _search,
    );

    if (!mounted) return;

    if (!result.isSuccess) {
      setState(() {
        _loading = false;
        _error = ApiFeedback.errorMessage(
          result,
          fallback: 'Failed to load trailers',
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
    final result = await TrailerService.instance.fetchTrailers(
      page: nextPage,
      limit: _effectiveLimit,
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

    final changed = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const TrailerFormScreen()));
    if (changed == true) _load();
  }

  Future<void> _openImport() async {
    if (_isSuperAdmin && AuthService.instance.selectedCompanyIdInt == null) {
      AppToast.showError('Select a company from the header first');
      return;
    }

    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const TrailerImportScreen()),
    );
    if (changed == true) _load();
  }

  Future<void> _openDetail(TrailerModel trailer) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TrailerDetailScreen(trailerId: trailer.id),
      ),
    );
    if (changed == true) _load();
  }

  Future<void> _openEdit(TrailerModel trailer) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TrailerFormScreen(trailerId: trailer.id),
      ),
    );
    if (changed == true) _load();
  }

  Future<void> _confirmDelete(TrailerModel trailer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 36),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 32,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.report_problem_rounded,
                    color: AppColors.danger,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Delete Trailer',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text.rich(
                  TextSpan(
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                    children: [
                      const TextSpan(text: 'Are you sure you want to delete '),
                      TextSpan(
                        text: '"${trailer.trailerNumber}"',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const TextSpan(text: '? This action cannot be undone.'),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: BorderSide(color: AppColors.border, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.danger,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 16,
                        ),
                        label: const Text(
                          'Delete',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
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
    if (confirmed != true) return;

    final result = await TrailerService.instance.deleteTrailer(trailer.id);
    if (!mounted) return;
    if (result.isSuccess) {
      AppToast.showSuccess('Trailer deleted');
      _load();
    } else {
      ApiFeedback.showError(result, fallback: 'Failed to delete trailer');
    }
  }

  String? _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return iso;
    return DateFormat('MM-dd-yyyy').format(parsed.toLocal());
  }

  int? _daysUntilExpiry(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return null;
    final today = DateTime.now();
    return DateTime(
      parsed.year,
      parsed.month,
      parsed.day,
    ).difference(DateTime(today.year, today.month, today.day)).inDays;
  }

  Widget _buildCard(TrailerModel t) {
    final bool isActive = t.isActive;
    final expiryDays = _daysUntilExpiry(t.registrationExpiry);
    final bool isOverdue = expiryDays != null && expiryDays < 0;
    String? badgeLabel;
    BadgeTone? badgeTone;
    if (expiryDays != null && expiryDays <= 30) {
      if (expiryDays < 0) {
        badgeLabel = 'OVERDUE';
        badgeTone = BadgeTone.danger;
      } else if (expiryDays == 0) {
        badgeLabel = 'DUE TODAY';
        badgeTone = BadgeTone.danger;
      } else {
        badgeLabel = '$expiryDays DAYS';
        badgeTone = BadgeTone.warning;
      }
    }

    final BadgeTone cardTone = isOverdue
        ? BadgeTone.danger
        : !isActive
        ? BadgeTone.danger
        : BadgeTone.success;

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
          onTap: () => _openDetail(t),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 5, color: StatusBadgeColors.accent(cardTone)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 10, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Top Header Row (Badges + Action Icons) ──
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            isActive
                                ? const MiniStatusBadge(
                                    label: 'ACTIVE',
                                    tone: BadgeTone.success,
                                    dense: true,
                                  )
                                : const MiniStatusBadge(
                                    label: 'INACTIVE',
                                    tone: BadgeTone.danger,
                                    dense: true,
                                  ),
                            const Spacer(),
                            if (badgeLabel != null && badgeTone != null) ...[
                              MiniStatusBadge(
                                label: badgeLabel,
                                tone: badgeTone,
                                dense: true,
                                borderColor: badgeTone == BadgeTone.danger
                                    ? StatusBadgeColors.dangerBorderLight
                                    : null,
                              ),
                              const SizedBox(width: 6),
                            ],
                            IconOnlyButton(
                              icon: Icons.edit,
                              color: AppColors.chromeBlue,
                              onTap: () => _openEdit(t),
                            ),
                            const SizedBox(width: 2),
                            IconOnlyButton(
                              icon: Icons.delete_outline,
                              danger: true,
                              onTap: () => _confirmDelete(t),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // ── Main Content Row ──
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t.trailerNumber,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  if (t.vinNumber != null &&
                                      t.vinNumber!.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      t.vinNumber!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                  if (t.licensePlate != null &&
                                      t.licensePlate!.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    RichText(
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      text: TextSpan(
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                        children: [
                                          const TextSpan(text: 'Plate: '),
                                          TextSpan(
                                            text: t.licensePlate!,
                                            style: TextStyle(
                                              color: AppColors.chromeBlue,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ] else if (t.companyName != null &&
                                      t.companyName!.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      t.companyName!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 6,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: _GridCell(
                                      label: 'Status',
                                      child: isActive
                                          ? const MiniStatusBadge(
                                              label: 'Active',
                                              tone: BadgeTone.success,
                                            )
                                          : const MiniStatusBadge(
                                              label: 'Inactive',
                                              tone: BadgeTone.danger,
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: _GridCell(
                                      label: 'Reg. Expiry',
                                      child: Text(
                                        _formatDate(t.registrationExpiry) ?? '—',
                                        maxLines: 1,
                                        softWrap: false,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: isOverdue
                                              ? StatusBadgeColors.text(
                                                  BadgeTone.danger,
                                                )
                                              : AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    size: 18,
                                    color: AppColors.textTertiary,
                                  ),
                                ],
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
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WebPageBody(
        onRefresh: _load,
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: WebSearchField(
                    controller: _searchController,
                    hintText: 'Search by Unit #, VIN, or Plate',
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
                ),
                const SizedBox(width: 8),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Material(
                      color: AppColors.inputFill,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _openSortSheet,
                        child: Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Icon(
                            Icons.tune_rounded,
                            color: _sortColumn != null
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    if (_sortColumn != null)
                      Positioned(
                        top: -2,
                        right: -2,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.card, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'My Trailers',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (_isAdminOrSuperAdmin)
                  TextButton.icon(
                    onPressed: _openImport,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.file_upload_outlined, size: 16),
                    label: const Text(
                      'Import Excel',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                Text(
                  '$_total Total',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.chromeBlue,
                  ),
                ),
              ],
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
                    ? 'No matching trailers'
                    : 'Add your first trailer or import a workbook to populate this list.',
                icon: Icons.inventory_2_outlined,
                actionLabel: 'Add Trailer',
                onAction: _openAdd,
              )
            else ...[
              LayoutBuilder(
                builder: (context, constraints) {
                  final visible = _visibleItems;
                  if (constraints.maxWidth < 600) {
                    return Column(
                      children: visible.map((t) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildCard(t),
                        );
                      }).toList(),
                    );
                  } else {
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: visible.length,
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 500,
                            mainAxisExtent: 140,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                      itemBuilder: (context, i) => _buildCard(visible[i]),
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
                      'All $_total trailers loaded',
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

class _GridCell extends StatelessWidget {
  const _GridCell({
    required this.label,
    required this.child,
  });

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
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}

