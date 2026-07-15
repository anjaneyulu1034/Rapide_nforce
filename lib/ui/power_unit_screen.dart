import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/core/utils/api_feedback.dart';
import 'package:rapide_nforce/core/utils/app_toast.dart';
import 'package:rapide_nforce/core/utils/compact_date_picker.dart';
import 'package:rapide_nforce/core/utils/role_utils.dart';
import 'package:rapide_nforce/models/power_unit_model.dart';
import 'package:rapide_nforce/services/auth_service.dart';
import 'package:rapide_nforce/services/power_unit_service.dart';
import 'package:rapide_nforce/ui/power_unit_detail_screen.dart';
import 'package:rapide_nforce/ui/power_unit_form_screen.dart';
import 'package:rapide_nforce/ui/widgets/api_error_banner.dart';
import 'package:rapide_nforce/ui/widgets/list_empty_state.dart';
import 'package:rapide_nforce/ui/widgets/status_chip.dart';
import 'package:rapide_nforce/ui/widgets/web_ui.dart';

class PowerUnitScreen extends StatefulWidget {
  const PowerUnitScreen({super.key});

  @override
  State<PowerUnitScreen> createState() => _PowerUnitScreenState();
}

class _PowerUnitScreenState extends State<PowerUnitScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;

  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  List<PowerUnitModel> _items = [];
  int? _selectedId;
  int _page = 1;
  final int _limit = 10;
  int _total = 0;
  int _totalPages = 1;
  String _search = '';

  // Filters — the backend's /trucks list endpoint has no status/date query
  // params, so these are applied client-side over a larger fetched batch.
  String _statusFilter = 'all'; // all | active | inactive
  DateTime? _startDateFrom;
  DateTime? _startDateTo;

  bool get _isSuperAdmin =>
      isSuperAdminRole(AuthService.instance.currentUser?.role);

  bool get _hasActiveFilters =>
      _statusFilter != 'all' || _startDateFrom != null || _startDateTo != null;

  int get _effectiveLimit => _hasActiveFilters ? 500 : _limit;

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

  List<PowerUnitModel> get _visibleItems {
    if (!_hasActiveFilters) return _items;
    return _items.where((u) {
      if (_statusFilter == 'active' && !u.isActive) return false;
      if (_statusFilter == 'inactive' && u.isActive) return false;
      final start = _parseDate(u.startDate);
      if (_startDateFrom != null &&
          (start == null || start.isBefore(_startDateFrom!))) {
        return false;
      }
      if (_startDateTo != null &&
          (start == null ||
              start.isAfter(_startDateTo!.add(const Duration(days: 1))))) {
        return false;
      }
      return true;
    }).toList();
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

  Future<void> _openFilterSheet() async {
    String tempStatus = _statusFilter;
    DateTime? tempFrom = _startDateFrom;
    DateTime? tempTo = _startDateTo;

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
            Future<void> pickDate({required bool isFrom}) async {
              final now = DateTime.now();
              final picked = await showCompactDatePicker(
                context: sheetContext,
                initialDate: (isFrom ? tempFrom : tempTo) ?? now,
                firstDate: DateTime(2015),
                lastDate: DateTime(now.year + 5),
              );
              if (picked == null) return;
              setSheetState(() {
                if (isFrom) {
                  tempFrom = picked;
                } else {
                  tempTo = picked;
                }
              });
            }

            Widget dateField(String label, DateTime? value, bool isFrom) {
              return Expanded(
                child: InkWell(
                  onTap: () => pickDate(isFrom: isFrom),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.inputFill,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_month_outlined,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            value != null
                                ? '${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}-${value.year}'
                                : label,
                            style: TextStyle(
                              fontSize: 13,
                              color: value != null
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (value != null)
                          InkWell(
                            onTap: () => setSheetState(() {
                              if (isFrom) {
                                tempFrom = null;
                              } else {
                                tempTo = null;
                              }
                            }),
                            child: Icon(
                              Icons.close,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }

            Widget statusChip(String value, String label) {
              final selected = tempStatus == value;
              return ChoiceChip(
                label: Text(label),
                selected: selected,
                onSelected: (_) => setSheetState(() => tempStatus = value),
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
                      'Filter Power Units',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'STATUS',
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
                        statusChip('all', 'All'),
                        statusChip('active', 'Active'),
                        statusChip('inactive', 'Inactive'),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'START DATE RANGE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        dateField('From', tempFrom, true),
                        const SizedBox(width: 12),
                        dateField('To', tempTo, false),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setSheetState(() {
                                tempStatus = 'all';
                                tempFrom = null;
                                tempTo = null;
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textPrimary,
                              side: BorderSide(color: AppColors.border),
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('Clear'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: WebPrimaryButton(
                            label: 'Apply Filters',
                            expand: false,
                            onPressed: () {
                              setState(() {
                                _statusFilter = tempStatus;
                                _startDateFrom = tempFrom;
                                _startDateTo = tempTo;
                              });
                              Navigator.pop(sheetContext);
                              _load();
                            },
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

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _page = 1;
      _items = [];
    });

    final result = await PowerUnitService.instance.fetchPowerUnits(
      page: 1,
      limit: _effectiveLimit,
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
          fallback: 'Failed to load power units',
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
    if (_loading ||
        _loadingMore ||
        _page >= _totalPages ||
        _hasActiveFilters) {
      return;
    }

    setState(() {
      _loadingMore = true;
    });

    final nextPage = _page + 1;
    final result = await PowerUnitService.instance.fetchPowerUnits(
      page: nextPage,
      limit: _effectiveLimit,
      search: _search.isEmpty ? null : _search,
      sortBy: 'id',
      sortOrder: 'desc',
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
      MaterialPageRoute(builder: (_) => const PowerUnitFormScreen()),
    );
    if (changed == true) _load();
  }

  Future<void> _openDetail(PowerUnitModel unit) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PowerUnitDetailScreen(powerUnitId: unit.id),
      ),
    );
    if (changed == true) _load();
  }

  Future<void> _openEdit(PowerUnitModel unit) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PowerUnitFormScreen(powerUnitId: unit.id),
      ),
    );
    if (changed == true) _load();
  }

  Future<void> _confirmDelete(PowerUnitModel unit) async {
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
                // Warning icon
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
                  'Delete Power Unit',
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
                        text: '"${unit.unitNumber}"',
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
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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
                        icon: const Icon(Icons.delete_outline_rounded, size: 16),
                        label: const Text(
                          'Delete',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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

    final result = await PowerUnitService.instance.deletePowerUnit(unit.id);
    if (!mounted) return;
    if (result.isSuccess) {
      AppToast.showSuccess('Power unit deleted');
      _load();
    } else {
      ApiFeedback.showError(result, fallback: 'Failed to delete power unit');
    }
  }

  Color? _expiryColor(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;
    DateTime? expiry;
    try {
      expiry = DateTime.parse(dateStr);
    } catch (_) {
      try {
        final p = dateStr.split('-');
        if (p.length == 3) {
          expiry = DateTime(int.parse(p[2]), int.parse(p[0]), int.parse(p[1]));
        }
      } catch (_) {}
    }
    if (expiry == null) return null;
    final today = DateTime.now();
    final days = DateTime(
      expiry.year,
      expiry.month,
      expiry.day,
    ).difference(DateTime(today.year, today.month, today.day)).inDays;
    if (days < 0) return const Color(0xFFBA1A1A);
    if (days <= 30) return const Color(0xFFEA580C);
    return null;
  }

  int? _daysUntilExpiry(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;
    DateTime? expiry;
    try {
      expiry = DateTime.parse(dateStr);
    } catch (_) {
      try {
        final p = dateStr.split('-');
        if (p.length == 3) {
          expiry = DateTime(int.parse(p[2]), int.parse(p[0]), int.parse(p[1]));
        }
      } catch (_) {}
    }
    if (expiry == null) return null;
    final today = DateTime.now();
    return DateTime(
      expiry.year,
      expiry.month,
      expiry.day,
    ).difference(DateTime(today.year, today.month, today.day)).inDays;
  }

  Widget _buildCard(PowerUnitModel u) {
    final bool isMaintenance = u.isMaintenance;
    final bool isSelected = _selectedId == u.id;

    final subtitleStr = u.vinNumber ?? '';

    String? contextText;
    if (isMaintenance && u.registrationExpiry != null) {
      contextText = 'Exp: ${u.registrationExpiry}';
    }

    final expiryDays = _daysUntilExpiry(u.registrationExpiry);
    String? badgeLabel;
    Color? badgeBg;
    Color? badgeText;
    if (expiryDays != null && expiryDays <= 30) {
      if (expiryDays < 0) {
        badgeLabel = 'OVERDUE';
        badgeBg = const Color(0xFFBA1A1A).withValues(alpha: 0.14);
        badgeText = const Color(0xFFBA1A1A);
      } else if (expiryDays == 0) {
        badgeLabel = 'DUE TODAY';
        badgeBg = const Color(0xFFBA1A1A).withValues(alpha: 0.14);
        badgeText = const Color(0xFFBA1A1A);
      } else {
        badgeLabel = '$expiryDays DAYS';
        badgeBg = const Color(0xFFEA580C).withValues(alpha: 0.14);
        badgeText = const Color(0xFFC2410C);
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

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        splashColor: AppColors.danger.withValues(alpha: 0.06),
        highlightColor: AppColors.danger.withValues(alpha: 0.03),
        onTap: () => setState(() {
          _selectedId = isSelected ? null : u.id;
        }),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            u.unitNumber,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (subtitleStr.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitleStr,
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (u.isOos)
                          const StatusChip(
                            label: 'OOS',
                            tone: StatusChipTone.danger,
                          )
                        else if (isMaintenance)
                          const StatusChip(
                            label: 'MAINTENANCE',
                            tone: StatusChipTone.warning,
                          )
                        else if (u.isActive)
                          Text(
                            'ACTIVE',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.statusCompleted,
                            ),
                          )
                        else
                          StatusChip.inactive('INACTIVE'),
                        if (contextText != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            contextText,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFFEA580C),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        if (badgeLabel != null) ...[
                          const SizedBox(height: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: badgeBg,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              badgeLabel,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: badgeText,
                              ),
                            ),
                          ),
                        ],
                      ],
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
                // ── Data rows ──
                dataRow(
                  _isSuperAdmin ? 'Company' : 'License Plate',
                  _isSuperAdmin ? u.companyName : u.licensePlate,
                ),
                dataRow(
                  'Registration Expiry',
                  u.registrationExpiry,
                  valueColor: _expiryColor(u.registrationExpiry),
                ),
                const SizedBox(height: 6),
                // ── Action row: View | Edit | Delete ──
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _openDetail(u),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: BorderSide(
                            color: AppColors.textSecondary.withValues(
                              alpha: 0.3,
                            ),
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
                        onPressed: () => _openEdit(u),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: BorderSide(
                            color: AppColors.textSecondary.withValues(
                              alpha: 0.3,
                            ),
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
                        onPressed: () => _confirmDelete(u),
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
                    hintText: 'Search by Unit',
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
                        onTap: _openFilterSheet,
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
                            color: _hasActiveFilters
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    if (_hasActiveFilters)
                      Positioned(
                        top: -2,
                        right: -2,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.card,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  _hasActiveFilters ? 'Filtered Results' : 'Total Units',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _hasActiveFilters ? '${_visibleItems.length}' : '$_total',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (_hasActiveFilters) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _statusFilter = 'all';
                        _startDateFrom = null;
                        _startDateTo = null;
                      });
                      _load();
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Clear filters',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
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
            else if (_visibleItems.isEmpty)
              ListEmptyState(
                message: _hasActiveFilters
                    ? 'No power units match these filters'
                    : _search.isNotEmpty
                    ? 'No power units match your search'
                    : 'No power units yet',
                icon: Icons.local_shipping_outlined,
                actionLabel: _hasActiveFilters ? null : 'Add Power Unit',
                onAction: _hasActiveFilters ? null : _openAdd,
              )
            else ...[
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 600) {
                    return Column(
                      children: _visibleItems.map((u) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _buildCard(u),
                        );
                      }).toList(),
                    );
                  } else {
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _visibleItems.length,
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 500,
                            mainAxisExtent: 310,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                      itemBuilder: (context, i) {
                        return _buildCard(_visibleItems[i]);
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
              else if (_page >= _totalPages && _visibleItems.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      _hasActiveFilters
                          ? '${_visibleItems.length} power units match these filters'
                          : 'All $_total power units loaded',
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
