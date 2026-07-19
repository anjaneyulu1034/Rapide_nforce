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
import 'package:rapide_nforce/ui/widgets/list_empty_state.dart';
import 'package:rapide_nforce/ui/widgets/status_chip.dart';
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

    final result = await TrailerService.instance.fetchTrailers(
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
    final subtitleStr = [
      t.make,
      t.model,
    ].where((s) => s != null && s.isNotEmpty).join(' ');

    Widget infoTile({
      required IconData icon,
      required String label,
      required String value,
      required Color bgStart,
      required Color bgEnd,
      required Color border,
      required Color fg,
    }) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [bgStart, bgEnd],
            ),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(icon, size: 11, color: fg),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: fg,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                value.isEmpty ? 'N/A' : value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: fg,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      );
    }

    // EXPIRY urgency drives the tile color — a real signal, not decoration.
    final expiryDays = _daysUntilExpiry(t.registrationExpiry);
    final Color expiryBgStart, expiryBgEnd, expiryBorder, expiryFg;
    if (expiryDays == null) {
      expiryBgStart = AppColors.surfaceTertiary;
      expiryBgEnd = AppColors.surfaceTertiary;
      expiryBorder = AppColors.border;
      expiryFg = AppColors.textSecondary;
    } else if (expiryDays < 0) {
      expiryBgStart = AppColors.statRoseBgStart;
      expiryBgEnd = AppColors.statRoseBgEnd;
      expiryBorder = AppColors.statRoseBorder;
      expiryFg = AppColors.statRoseText;
    } else if (expiryDays <= 30) {
      expiryBgStart = AppColors.statOrangeBgStart;
      expiryBgEnd = AppColors.statOrangeBgEnd;
      expiryBorder = AppColors.statOrangeBorder;
      expiryFg = AppColors.statOrangeText;
    } else {
      expiryBgStart = AppColors.statEmeraldBgStart;
      expiryBgEnd = AppColors.statEmeraldBgEnd;
      expiryBorder = AppColors.statEmeraldBorder;
      expiryFg = AppColors.statEmeraldText;
    }

    Widget actionButton({
      required IconData icon,
      required String label,
      required VoidCallback onPressed,
      required Color fg,
      required Color border,
      Color? bg,
    }) {
      return Expanded(
        child: OutlinedButton.icon(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: fg,
            backgroundColor: bg,
            side: BorderSide(color: border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9),
            ),
            minimumSize: const Size(0, 38),
            padding: EdgeInsets.zero,
          ),
          icon: Icon(icon, size: 14),
          label: Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 4,
            child: ColoredBox(color: AppColors.primary),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _openDetail(t),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.rv_hookup_outlined,
                            size: 20,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                t.trailerNumber,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                  letterSpacing: -0.2,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (subtitleStr.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  subtitleStr,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        isActive
                            ? StatusChip.active('Active')
                            : StatusChip.inactive('Inactive'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        infoTile(
                          icon: Icons.category_outlined,
                          label: 'TYPE',
                          value: t.type,
                          bgStart: AppColors.statBlueBgStart,
                          bgEnd: AppColors.statBlueBgEnd,
                          border: AppColors.statBlueBorder,
                          fg: AppColors.statBlueText,
                        ),
                        const SizedBox(width: 10),
                        infoTile(
                          icon: Icons.pin_outlined,
                          label: 'PLATE',
                          value: t.licensePlate ?? '',
                          bgStart: AppColors.statOrangeBgStart,
                          bgEnd: AppColors.statOrangeBgEnd,
                          border: AppColors.statOrangeBorder,
                          fg: AppColors.statOrangeText,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        infoTile(
                          icon: Icons.fingerprint,
                          label: 'VIN',
                          value: t.vinNumber ?? '',
                          bgStart: AppColors.surfaceTertiary,
                          bgEnd: AppColors.surfaceTertiary,
                          border: AppColors.border,
                          fg: AppColors.textPrimary,
                        ),
                        const SizedBox(width: 10),
                        infoTile(
                          icon: expiryDays != null && expiryDays < 0
                              ? Icons.event_busy_outlined
                              : Icons.event_available_outlined,
                          label: 'EXPIRY',
                          value: _formatDate(t.registrationExpiry) ?? '',
                          bgStart: expiryBgStart,
                          bgEnd: expiryBgEnd,
                          border: expiryBorder,
                          fg: expiryFg,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        actionButton(
                          icon: Icons.visibility_outlined,
                          label: 'View',
                          onPressed: () => _openDetail(t),
                          fg: AppColors.textPrimary,
                          border: AppColors.border,
                        ),
                        const SizedBox(width: 8),
                        actionButton(
                          icon: Icons.edit_outlined,
                          label: 'Edit',
                          onPressed: () => _openEdit(t),
                          fg: AppColors.primary,
                          border: AppColors.primary.withValues(alpha: 0.35),
                          bg: AppColors.primary.withValues(alpha: 0.06),
                        ),
                        const SizedBox(width: 8),
                        actionButton(
                          icon: Icons.delete_outline_rounded,
                          label: 'Delete',
                          onPressed: () => _confirmDelete(t),
                          fg: AppColors.danger,
                          border: AppColors.danger.withValues(alpha: 0.35),
                          bg: AppColors.danger.withValues(alpha: 0.06),
                        ),
                      ],
                    ),
                  ],
                ),
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
      body: WebPageBody(
        onRefresh: _load,
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            WebSearchField(
              controller: _searchController,
              hintText: 'Search by Unit #, VIN',
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
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.rv_hookup_outlined,
                        size: 14,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$_total',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _total == 1 ? 'Trailer' : 'Trailers',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (_isAdminOrSuperAdmin)
                  TextButton.icon(
                    onPressed: _openImport,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
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
                  if (constraints.maxWidth < 600) {
                    return Column(
                      children: _items.map((t) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _buildCard(t),
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
                            mainAxisExtent: 352,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                      itemBuilder: (context, i) => _buildCard(_items[i]),
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
