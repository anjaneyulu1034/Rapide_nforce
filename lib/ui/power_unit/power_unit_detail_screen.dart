import 'package:flutter/material.dart';
import 'package:rapide_nforce/ui/widgets/gradient_page_background.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/models/power_unit_model.dart';
import 'package:rapide_nforce/models/truck_document_model.dart';
import 'package:rapide_nforce/models/work_order_model.dart';
import 'package:rapide_nforce/services/auth_service.dart';
import 'package:rapide_nforce/services/maintenance_service.dart';
import 'package:rapide_nforce/services/power_unit_service.dart';
import 'package:rapide_nforce/ui/power_unit/power_unit_summary_cards.dart';
import 'package:rapide_nforce/ui/power_unit/power_unit_upload_document_sheet.dart';
import 'package:rapide_nforce/ui/power_unit_form_screen.dart';
import 'package:rapide_nforce/ui/widgets/screen_state_builder.dart';
import 'package:rapide_nforce/ui/widgets/status_chip.dart';
import 'package:rapide_nforce/ui/widgets/vehicle_info_section.dart';
import 'package:rapide_nforce/ui/work_orders/work_order_form_screen.dart';
import 'package:rapide_nforce/core/utils/api_feedback.dart';
import 'package:rapide_nforce/core/utils/app_toast.dart';
import 'package:rapide_nforce/core/utils/document_download_service.dart';

enum PowerUnitDetailTab {
  overview,
  compliance,
  documents,
  maintenance,
  specifications,
}

class PowerUnitDetailScreen extends StatefulWidget {
  const PowerUnitDetailScreen({super.key, required this.powerUnitId});

  final int powerUnitId;

  @override
  State<PowerUnitDetailScreen> createState() => _PowerUnitDetailScreenState();
}

class _PowerUnitDetailScreenState extends State<PowerUnitDetailScreen> {
  PowerUnitDetailTab _tab = PowerUnitDetailTab.overview;
  bool _loading = true;
  String? _error;
  PowerUnitModel? _unit;
  List<TruckDocumentModel> _documents = [];
  List<WorkOrderModel> _workOrders = [];
  bool _docsLoading = false;
  bool _woLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await PowerUnitService.instance.fetchPowerUnitById(
      widget.powerUnitId,
    );
    if (!mounted) return;
    if (!result.isSuccess) {
      setState(() {
        _loading = false;
        _error = result.message;
      });
      return;
    }
    setState(() {
      _loading = false;
      _unit = result.data;
    });
    _loadDocuments();
    if (_tab == PowerUnitDetailTab.maintenance) _loadMaintenance();
  }

  Future<void> _loadDocuments() async {
    setState(() => _docsLoading = true);
    final result = await PowerUnitService.instance.fetchDocuments(
      widget.powerUnitId,
    );
    if (!mounted) return;
    setState(() {
      _docsLoading = false;
      _documents = result.data ?? [];
    });
  }

  Future<void> _loadMaintenance() async {
    final unit = _unit;
    if (unit == null) return;
    setState(() => _woLoading = true);
    final result = await MaintenanceService.instance
        .getMaintenanceHistoryByUnit(
          unitNumber: unit.unitNumber,
          companyId: AuthService.instance.selectedCompanyIdInt,
        );
    if (!mounted) return;
    setState(() {
      _woLoading = false;
      _workOrders = result.data ?? [];
    });
  }

  Future<void> _openEdit() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PowerUnitFormScreen(powerUnitId: widget.powerUnitId),
      ),
    );
    if (changed == true) _load();
  }

  Future<void> _uploadDocument() async {
    final unit = _unit;
    if (unit == null) return;
    final changed = await showPowerUnitUploadDocumentSheet(
      context: context,
      truckId: widget.powerUnitId,
      unit: unit,
    );
    if (changed == true) _loadDocuments();
  }

  Future<void> _deleteDocument(TruckDocumentModel doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(
          'Delete document',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Delete "${doc.fileName}"?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final result = await PowerUnitService.instance.deleteDocument(
      truckId: widget.powerUnitId,
      documentId: doc.id,
    );
    if (!mounted) return;
    if (result.isSuccess) {
      AppToast.showSuccess('Document deleted');
      _loadDocuments();
    } else {
      ApiFeedback.showError(result);
    }
  }

  Future<void> _onCreateWorkOrder() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const WorkOrderFormScreen()));
    _loadMaintenance();
  }

  void _onTabChanged(PowerUnitDetailTab tab) {
    setState(() => _tab = tab);
    if (tab == PowerUnitDetailTab.maintenance) _loadMaintenance();
    if (tab == PowerUnitDetailTab.documents ||
        tab == PowerUnitDetailTab.compliance) {
      _loadDocuments();
    }
  }

  @override
  Widget build(BuildContext context) {
    final unit = _unit;
    return GradientPageBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: unit == null
              ? const Text('Power Unit')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          unit.unitNumber,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 8),
                        unit.isActive
                            ? StatusChip.active('Active')
                            : StatusChip.inactive('Inactive'),
                      ],
                    ),
                    Text(
                      unit.displayTitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
          actions: [
            if (unit != null)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: FilledButton.icon(
                  onPressed: _openEdit,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1A1A1A),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 36),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                  ),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text(
                    'Edit',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
        floatingActionButton: unit != null
            ? (_tab == PowerUnitDetailTab.compliance
                  ? FloatingActionButton(
                      onPressed: _uploadDocument,
                      backgroundColor: const Color(0xFF990000),
                      foregroundColor: Colors.white,
                      child: const Icon(Icons.add),
                    )
                  : _tab == PowerUnitDetailTab.maintenance
                  ? FloatingActionButton(
                      onPressed: _onCreateWorkOrder,
                      backgroundColor: const Color(0xFF990000),
                      foregroundColor: Colors.white,
                      child: const Icon(Icons.add),
                    )
                  : null)
            : null,
        body: ScreenStateBuilder(
          loading: _loading,
          error: _error,
          onRetry: _load,
          child: unit == null
              ? const SizedBox.shrink()
              : CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          PowerUnitSummaryCards(unit: unit),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                    SliverAppBar(
                      pinned: true,
                      floating: false,
                      snap: false,
                      automaticallyImplyLeading: false,
                      elevation: 0,
                      scrolledUnderElevation: 0,
                      backgroundColor: Theme.of(
                        context,
                      ).scaffoldBackgroundColor,
                      surfaceTintColor: Colors.transparent,
                      toolbarHeight: 90,
                      flexibleSpace: FlexibleSpaceBar(
                        background: _buildTabsSection(),
                        collapseMode: CollapseMode.none,
                      ),
                    ),
                    SliverFillRemaining(
                      hasScrollBody: true,
                      child: _buildTabContent(unit),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _tabTile(String label, IconData icon, PowerUnitDetailTab? tab) {
    final isSelected = tab != null && _tab == tab;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (tab != null) {
            _onTabChanged(tab);
          } else {
            AppToast.showSuccess('Photos coming soon');
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFF1A1A1A) : AppColors.border,
              width: isSelected ? 1.8 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabsSection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 36),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _tabChip(
                      'OVERVIEW',
                      Icons.notes_outlined,
                      PowerUnitDetailTab.overview,
                    ),
                    const SizedBox(width: 8),
                    _tabChip(
                      'BINDER',
                      Icons.assignment_outlined,
                      PowerUnitDetailTab.compliance,
                    ),
                    const SizedBox(width: 8),
                    _tabChip(
                      'DOCS',
                      Icons.description_outlined,
                      PowerUnitDetailTab.documents,
                    ),
                    const SizedBox(width: 8),
                    _tabChip(
                      'HISTORY',
                      Icons.access_time_outlined,
                      PowerUnitDetailTab.maintenance,
                    ),
                    const SizedBox(width: 8),
                    _tabChip(
                      'SPECS',
                      Icons.analytics_outlined,
                      PowerUnitDetailTab.specifications,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 36,
              child: Center(
                child: Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _tabChip(String label, IconData icon, PowerUnitDetailTab tab) {
    return SizedBox(width: 90, child: _tabTile(label, icon, tab));
  }

  Widget _buildTabContent(PowerUnitModel unit) {
    switch (_tab) {
      case PowerUnitDetailTab.overview:
        return _OverviewTab(unit: unit);
      case PowerUnitDetailTab.compliance:
        return _ComplianceTab(
          unit: unit,
          documents: _documents,
          loading: _docsLoading,
          onUpload: _uploadDocument,
        );
      case PowerUnitDetailTab.documents:
        return _DocumentsTab(
          unit: unit,
          documents: _documents,
          loading: _docsLoading,
          onUpload: _uploadDocument,
          onDelete: _deleteDocument,
          onRefresh: _loadDocuments,
        );
      case PowerUnitDetailTab.maintenance:
        return _MaintenanceTab(loading: _woLoading, workOrders: _workOrders);
      case PowerUnitDetailTab.specifications:
        return _SpecificationsTab(unit: unit);
    }
  }
}

// ---------------------------------------------------------------------------
// Overview Tab
// ---------------------------------------------------------------------------

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.unit});
  final PowerUnitModel unit;

  static bool _isExpired(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return false;
    DateTime? date;
    try {
      date = DateTime.parse(dateStr);
    } catch (_) {
      try {
        final p = dateStr.split('-');
        if (p.length == 3) {
          date = DateTime(int.parse(p[2]), int.parse(p[0]), int.parse(p[1]));
        }
      } catch (_) {}
    }
    if (date == null) return false;
    final today = DateTime.now();
    return DateTime(
      date.year,
      date.month,
      date.day,
    ).isBefore(DateTime(today.year, today.month, today.day));
  }

  static const _expiredRed = Color(0xFFBA1A1A);

  @override
  Widget build(BuildContext context) {
    final regExpired = _isExpired(unit.registrationExpiry);
    final cvipExpired = _isExpired(unit.expiryDate);
    final inspExpired = _isExpired(
      unit.annualInspectionDue ?? unit.nextInspectionDue,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        VehicleInfoSection(
          title: 'Basic Information',
          rows: [
            VehicleInfoRow(label: 'Unit Number', value: unit.unitNumber),
            VehicleInfoRow(
              label: 'VIN',
              value: PowerUnitModel.displayOrDash(unit.vinNumber),
            ),
            VehicleInfoRow(
              label: 'Make',
              value: PowerUnitModel.displayOrDash(unit.make),
            ),
            VehicleInfoRow(
              label: 'Model',
              value: PowerUnitModel.displayOrDash(unit.model),
            ),
            VehicleInfoRow(label: 'Year', value: unit.year?.toString() ?? '—'),
            VehicleInfoRow(
              label: 'Color',
              value: PowerUnitModel.displayOrDash(unit.color),
            ),
            VehicleInfoRow(
              label: 'Purchase Date',
              value: PowerUnitModel.displayOrDash(unit.purchaseDate),
            ),
            VehicleInfoRow(
              label: 'Purchase Price',
              value: unit.purchasePrice != null
                  ? '\$${unit.purchasePrice}'
                  : '—',
            ),
            VehicleInfoRow(label: 'Status', value: unit.status),
            VehicleInfoRow(
              label: 'Assigned Driver',
              value: PowerUnitModel.displayOrDash(unit.assignedDriver),
            ),
          ],
        ),
        const SizedBox(height: 12),
        VehicleInfoSection(
          title: 'Inspection & Maintenance',
          titleIcon: inspExpired
              ? const Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: _expiredRed,
                )
              : null,
          rows: [
            VehicleInfoRow(
              label: 'Current Odometer',
              value: unit.odometer != null ? '${unit.odometer} km' : '—',
            ),
            VehicleInfoRow(
              label: 'Last Sync (24 Hours)',
              value: PowerUnitModel.displayOrDash(unit.telematicsLastSynced),
            ),
            VehicleInfoRow(
              label: 'Next Annual Inspection Due',
              value: PowerUnitModel.displayOrDash(unit.annualInspectionDue),
              valueColor: inspExpired ? _expiredRed : null,
            ),
            VehicleInfoRow(
              label: 'Last Inspection',
              value: PowerUnitModel.displayOrDash(unit.lastInspection),
            ),
            VehicleInfoRow(
              label: 'PM Interval',
              value: unit.pmInterval != null
                  ? 'Every ${unit.pmInterval} km'
                  : '—',
            ),
            VehicleInfoRow(
              label: 'Next PM Due',
              value: PowerUnitModel.displayOrDash(unit.nextPmDue),
            ),
            VehicleInfoRow(
              label: 'Next PM Odometer',
              value: PowerUnitModel.displayOrDash(unit.nextPmOdometer),
            ),
          ],
        ),
        const SizedBox(height: 12),
        VehicleInfoSection(
          title: 'Registration & Insurance',
          titleIcon: regExpired
              ? const Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: _expiredRed,
                )
              : null,
          rows: [
            VehicleInfoRow(
              label: 'Plate Number',
              value: PowerUnitModel.displayOrDash(unit.licensePlate),
            ),
            VehicleInfoRow(
              label: 'Plate Province',
              value: PowerUnitModel.displayOrDash(unit.state),
            ),
            VehicleInfoRow(
              label: 'Registration Number',
              value: PowerUnitModel.displayOrDash(unit.registrationNumber),
            ),
            VehicleInfoRow(
              label: 'Registration Expiry',
              value: PowerUnitModel.displayOrDash(unit.registrationExpiry),
              valueColor: regExpired ? _expiredRed : null,
            ),
            VehicleInfoRow(
              label: 'IMS Number',
              value: PowerUnitModel.displayOrDash(unit.imsNumber),
            ),
          ],
        ),
        const SizedBox(height: 12),
        VehicleInfoSection(
          title: 'Annual Safety / CVIP',
          titleIcon: cvipExpired
              ? const Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: _expiredRed,
                )
              : null,
          rows: [
            VehicleInfoRow(
              label: 'Certificate Status',
              value: cvipExpired ? 'EXPIRED' : 'Valid',
              valueColor: cvipExpired ? _expiredRed : null,
            ),
            VehicleInfoRow(
              label: 'Certificate Number',
              value: PowerUnitModel.displayOrDash(unit.certificateNumber),
            ),
            VehicleInfoRow(
              label: 'Expiry Date',
              value: PowerUnitModel.displayOrDash(unit.expiryDate),
              valueColor: cvipExpired ? _expiredRed : null,
            ),
            VehicleInfoRow(
              label: 'Inspection Date',
              value: PowerUnitModel.displayOrDash(unit.inspectionDate),
            ),
            VehicleInfoRow(
              label: 'Next Inspection Due',
              value: PowerUnitModel.displayOrDash(unit.nextInspectionDue),
            ),
            VehicleInfoRow(
              label: 'Inspector Name',
              value: PowerUnitModel.displayOrDash(unit.inspectorName),
            ),
            VehicleInfoRow(
              label: 'Inspector License',
              value: PowerUnitModel.displayOrDash(unit.inspectorLicense),
            ),
            VehicleInfoRow(
              label: 'Inspection Facility',
              value: PowerUnitModel.displayOrDash(unit.inspectionFacility),
            ),
            VehicleInfoRow(
              label: 'Facility Number',
              value: PowerUnitModel.displayOrDash(unit.facilityNumber),
            ),
            VehicleInfoRow(
              label: 'Critical Defects',
              value: '${unit.criticalDefects ?? 0}',
            ),
            VehicleInfoRow(
              label: 'Major Defects',
              value: '${unit.majorDefects ?? 0}',
            ),
            VehicleInfoRow(
              label: 'Advisory Items',
              value: '${unit.advisoryItems ?? 0}',
            ),
            if (unit.inspectionSummary != null)
              VehicleInfoRow(
                label: 'Inspection Summary',
                value: unit.inspectionSummary!,
              ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Compliance Tab  — maintenance-history style
// ---------------------------------------------------------------------------

class _ComplianceTab extends StatefulWidget {
  const _ComplianceTab({
    required this.unit,
    required this.documents,
    required this.loading,
    required this.onUpload,
  });

  final PowerUnitModel unit;
  final List<TruckDocumentModel> documents;
  final bool loading;
  final VoidCallback onUpload;

  @override
  State<_ComplianceTab> createState() => _ComplianceTabState();
}

class _ComplianceTabState extends State<_ComplianceTab> {
  final _searchCtrl = TextEditingController();
  String _search = '';
  String? _filterStatus;
  int _page = 0;
  static const _pageSize = 10;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  static String _docStatus(TruckDocumentModel d) {
    final s = (d.statusLabel ?? '').toLowerCase();
    if (s == 'expired') return 'expired';
    if (s.contains('expir')) return 'expiring';
    return 'active';
  }

  int _count(String status) =>
      widget.documents.where((d) => _docStatus(d) == status).length;

  List<TruckDocumentModel> get _filtered {
    var list = widget.documents;
    if (_filterStatus != null) {
      list = list.where((d) => _docStatus(d) == _filterStatus).toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list
          .where(
            (d) =>
                (d.documentType ?? d.fileName).toLowerCase().contains(q) ||
                (d.documentNumber ?? '').toLowerCase().contains(q) ||
                (d.documentCategory ?? '').toLowerCase().contains(q),
          )
          .toList();
    }
    return list;
  }

  List<TruckDocumentModel> get _currentPage {
    final list = _filtered;
    final start = _page * _pageSize;
    if (start >= list.length) return [];
    return list.sublist(start, (start + _pageSize).clamp(0, list.length));
  }

  int get _totalPages =>
      _filtered.isEmpty ? 1 : ((_filtered.length - 1) ~/ _pageSize) + 1;

  @override
  Widget build(BuildContext context) {
    final active = _count('active');
    final expiring = _count('expiring');
    final expired = _count('expired');
    final filtered = _filtered;
    final page = _currentPage;
    final start = filtered.isEmpty ? 0 : _page * _pageSize + 1;
    final end = _page * _pageSize + page.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      children: [
        // Header
        Row(
          children: [
            Text(
              'Compliance history',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 20,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${filtered.length}',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 20,
                color: AppColors.textSecondary,
              ),
            ),
            const Spacer(),
            _BlackButton(
              label: 'PDF',
              icon: Icons.picture_as_pdf_outlined,
              onPressed: () =>
                  DocumentDownloadService.instance.downloadPdfPacket(
                    context: context,
                    truckId: widget.unit.id,
                    scope: 'compliance',
                  ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Status count boxes
        Row(
          children: [
            _ComplianceStatBox(
              label: 'ACTIVE',
              count: active,
              textColor: const Color(0xFF1B7A3E),
              bgColor: const Color(0xFFE6F4EC),
              selected: _filterStatus == 'active',
              onTap: () => setState(() {
                _page = 0;
                _filterStatus = _filterStatus == 'active' ? null : 'active';
              }),
            ),
            const SizedBox(width: 8),
            _ComplianceStatBox(
              label: 'EXPIRING',
              count: expiring,
              textColor: const Color(0xFF8B5E00),
              bgColor: const Color(0xFFFFF3E0),
              selected: _filterStatus == 'expiring',
              onTap: () => setState(() {
                _page = 0;
                _filterStatus = _filterStatus == 'expiring' ? null : 'expiring';
              }),
            ),
            const SizedBox(width: 8),
            _ComplianceStatBox(
              label: 'EXPIRED',
              count: expired,
              textColor: const Color(0xFFBA1A1A),
              bgColor: const Color(0xFFFCE8E8),
              selected: _filterStatus == 'expired',
              onTap: () => setState(() {
                _page = 0;
                _filterStatus = _filterStatus == 'expired' ? null : 'expired';
              }),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Search + filter row
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() {
                    _search = v;
                    _page = 0;
                  }),
                  decoration: InputDecoration(
                    hintText: 'Search doc #, type',
                    hintStyle: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _IconSquareBtn(icon: Icons.tune_outlined, onTap: () {}),
            const SizedBox(width: 8),
            _IconSquareBtn(icon: Icons.swap_vert_outlined, onTap: () {}),
          ],
        ),
        const SizedBox(height: 12),
        // Document cards
        if (widget.loading)
          const Center(child: CircularProgressIndicator())
        else if (page.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              'No compliance records found',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          )
        else
          ...page.map((d) => _ComplianceDocCard(doc: d)),
        // Pagination
        if (!widget.loading && filtered.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$start–$end of ${filtered.length}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                Row(
                  children: [
                    _PagBtn(
                      icon: Icons.chevron_left,
                      enabled: _page > 0,
                      onTap: () => setState(() => _page--),
                    ),
                    const SizedBox(width: 8),
                    _PagBtn(
                      icon: Icons.chevron_right,
                      enabled: _page < _totalPages - 1,
                      onTap: () => setState(() => _page++),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Documents Tab — enhanced with filter, search, detail & version history
// ---------------------------------------------------------------------------

class _DocumentsTab extends StatefulWidget {
  const _DocumentsTab({
    required this.unit,
    required this.documents,
    required this.loading,
    required this.onUpload,
    required this.onDelete,
    required this.onRefresh,
  });

  final PowerUnitModel unit;
  final List<TruckDocumentModel> documents;
  final bool loading;
  final VoidCallback onUpload;
  final ValueChanged<TruckDocumentModel> onDelete;
  final VoidCallback onRefresh;

  @override
  State<_DocumentsTab> createState() => _DocumentsTabState();
}

class _DocumentsTabState extends State<_DocumentsTab> {
  final _searchCtrl = TextEditingController();
  String _search = '';
  String? _filterStatus;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  static String _docStatus(TruckDocumentModel d) {
    final s = (d.statusLabel ?? '').toLowerCase();
    if (s == 'expired') return 'expired';
    if (s.contains('expir')) return 'expiring';
    return 'active';
  }

  int _count(String status) =>
      widget.documents.where((d) => _docStatus(d) == status).length;

  List<TruckDocumentModel> get _filtered {
    var list = widget.documents;
    if (_filterStatus != null) {
      list = list.where((d) => _docStatus(d) == _filterStatus).toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list
          .where(
            (d) =>
                (d.documentType ?? d.fileName).toLowerCase().contains(q) ||
                (d.documentNumber ?? '').toLowerCase().contains(q),
          )
          .toList();
    }
    return list;
  }

  void _showDetails(TruckDocumentModel doc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _DocumentDetailsSheet(doc: doc, unitNumber: widget.unit.unitNumber),
    );
  }

  void _showVersionHistory(TruckDocumentModel doc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _VersionHistorySheet(doc: doc, unitNumber: widget.unit.unitNumber),
    );
  }

  @override
  Widget build(BuildContext context) {
    final active = _count('active');
    final expiring = _count('expiring');
    final expired = _count('expired');
    final filtered = _filtered;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  'Documents',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${widget.documents.length}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            _BlackButton(
              label: 'PDF',
              icon: Icons.picture_as_pdf_outlined,
              onPressed: () =>
                  DocumentDownloadService.instance.downloadPdfPacket(
                    context: context,
                    truckId: widget.unit.id,
                  ),
            ),
            const SizedBox(width: 8),
            _BlackButton(
              label: 'Upload',
              onPressed: widget.onUpload,
              icon: Icons.upload_rounded,
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Status filter boxes
        Row(
          children: [
            _StatusChipBox(
              label: 'ACTIVE',
              count: active,
              textColor: const Color(0xFF1B7A3E),
              bgColor: const Color(0xFFE6F4EC),
              selected: _filterStatus == 'active',
              onTap: () => setState(
                () =>
                    _filterStatus = _filterStatus == 'active' ? null : 'active',
              ),
            ),
            const SizedBox(width: 8),
            _StatusChipBox(
              label: 'EXPIRING',
              count: expiring,
              textColor: const Color(0xFF8B5E00),
              bgColor: const Color(0xFFFFF3E0),
              selected: _filterStatus == 'expiring',
              onTap: () => setState(
                () => _filterStatus = _filterStatus == 'expiring'
                    ? null
                    : 'expiring',
              ),
            ),
            const SizedBox(width: 8),
            _StatusChipBox(
              label: 'EXPIRED',
              count: expired,
              textColor: const Color(0xFFBA1A1A),
              bgColor: const Color(0xFFFCE8E8),
              selected: _filterStatus == 'expired',
              onTap: () => setState(
                () => _filterStatus = _filterStatus == 'expired'
                    ? null
                    : 'expired',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Search bar
        Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: 'Search documents',
              hintStyle: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
              prefixIcon: Icon(
                Icons.search,
                size: 18,
                color: AppColors.textSecondary,
              ),
              suffixIcon: Icon(
                Icons.settings_outlined,
                size: 18,
                color: AppColors.textSecondary,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Document list
        if (widget.loading)
          const Center(child: CircularProgressIndicator())
        else if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text(
                'No documents found',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          )
        else
          ...filtered.map(
            (d) => _DocCard(
              doc: d,
              onView: () => _showDetails(d),
              onDelete: () => widget.onDelete(d),
              onVersionHistory: () => _showVersionHistory(d),
              onDownload: () => DocumentDownloadService.instance.downloadAndOpen(
                context: context,
                truckId: d.truckId,
                documentId: d.id,
                displayFileName: d.fileName,
              ),
            ),
          ),
        if (!widget.loading && filtered.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              '1–${filtered.length} of ${widget.documents.length}',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Maintenance Tab  — matches screenshot style
// ---------------------------------------------------------------------------

class _MaintenanceTab extends StatefulWidget {
  const _MaintenanceTab({required this.loading, required this.workOrders});

  final bool loading;
  final List<WorkOrderModel> workOrders;

  @override
  State<_MaintenanceTab> createState() => _MaintenanceTabState();
}

class _MaintenanceTabState extends State<_MaintenanceTab> {
  final _searchCtrl = TextEditingController();
  String _search = '';
  WorkOrderStatus? _filterStatus;
  int _page = 0;
  static const _pageSize = 10;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  int _count(WorkOrderStatus s) =>
      widget.workOrders.where((wo) => wo.status == s).length;

  List<WorkOrderModel> get _filtered {
    var list = widget.workOrders;
    if (_filterStatus != null) {
      list = list.where((wo) => wo.status == _filterStatus).toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list
          .where(
            (wo) =>
                wo.workOrderNumber.toLowerCase().contains(q) ||
                (wo.companyName ?? '').toLowerCase().contains(q) ||
                wo.issueDescription.toLowerCase().contains(q),
          )
          .toList();
    }
    return list;
  }

  List<WorkOrderModel> get _currentPage {
    final list = _filtered;
    final start = _page * _pageSize;
    if (start >= list.length) return [];
    return list.sublist(start, (start + _pageSize).clamp(0, list.length));
  }

  int get _totalPages =>
      _filtered.isEmpty ? 1 : ((_filtered.length - 1) ~/ _pageSize) + 1;

  void _setFilter(WorkOrderStatus s) => setState(() {
    _page = 0;
    _filterStatus = _filterStatus == s ? null : s;
  });

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final page = _currentPage;
    final start = filtered.isEmpty ? 0 : _page * _pageSize + 1;
    final end = _page * _pageSize + page.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      children: [
        // Header
        Row(
          children: [
            Text(
              'Maintenance history',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 20,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${filtered.length}',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 20,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Auto-fetch banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF9C4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.bolt,
                  color: Color(0xFFF9A825),
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Auto-fetch work orders',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Sync from Fullbay, Shop-Ware',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: () => AppToast.showSuccess('Fetching work orders…'),
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Text(
                      'FETCH',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Status boxes
        Row(
          children: [
            _ComplianceStatBox(
              label: 'IN PROGRESS',
              count: _count(WorkOrderStatus.inProgress),
              textColor: WorkOrderStatus.inProgress.textColor,
              bgColor: WorkOrderStatus.inProgress.backgroundColor,
              selected: _filterStatus == WorkOrderStatus.inProgress,
              onTap: () => _setFilter(WorkOrderStatus.inProgress),
            ),
            const SizedBox(width: 8),
            _ComplianceStatBox(
              label: 'NOT STARTED',
              count: _count(WorkOrderStatus.notStarted),
              textColor: WorkOrderStatus.notStarted.textColor,
              bgColor: WorkOrderStatus.notStarted.backgroundColor,
              selected: _filterStatus == WorkOrderStatus.notStarted,
              onTap: () => _setFilter(WorkOrderStatus.notStarted),
            ),
            const SizedBox(width: 8),
            _ComplianceStatBox(
              label: 'COMPLETED',
              count: _count(WorkOrderStatus.completed),
              textColor: WorkOrderStatus.completed.textColor,
              bgColor: WorkOrderStatus.completed.backgroundColor,
              selected: _filterStatus == WorkOrderStatus.completed,
              onTap: () => _setFilter(WorkOrderStatus.completed),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Search row
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() {
                    _search = v;
                    _page = 0;
                  }),
                  decoration: InputDecoration(
                    hintText: 'Search WO #, company',
                    hintStyle: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _IconSquareBtn(icon: Icons.tune_outlined, onTap: () {}),
            const SizedBox(width: 8),
            _IconSquareBtn(icon: Icons.swap_vert_outlined, onTap: () {}),
          ],
        ),
        const SizedBox(height: 12),
        // Cards
        if (widget.loading)
          const Center(child: CircularProgressIndicator())
        else if (page.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              'No maintenance history found',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          )
        else
          ...page.map((wo) => _WoCard(wo: wo)),
        // Pagination
        if (!widget.loading && filtered.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$start–$end of ${filtered.length}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                Row(
                  children: [
                    _PagBtn(
                      icon: Icons.chevron_left,
                      enabled: _page > 0,
                      onTap: () => setState(() => _page--),
                    ),
                    const SizedBox(width: 8),
                    _PagBtn(
                      icon: Icons.chevron_right,
                      enabled: _page < _totalPages - 1,
                      onTap: () => setState(() => _page++),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Specifications Tab
// ---------------------------------------------------------------------------

class _SpecificationsTab extends StatelessWidget {
  const _SpecificationsTab({required this.unit});
  final PowerUnitModel unit;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        VehicleInfoSection(
          title: 'Vehicle Specifications',
          rows: [
            VehicleInfoRow(
              label: 'GVWR',
              value: PowerUnitModel.displayOrDash(unit.gvwr),
            ),
            VehicleInfoRow(
              label: 'Fuel Type',
              value: PowerUnitModel.displayOrDash(unit.fuelType),
            ),
            VehicleInfoRow(
              label: 'Transmission',
              value: PowerUnitModel.displayOrDash(unit.transmission),
            ),
          ],
        ),
        const SizedBox(height: 12),
        VehicleInfoSection(
          title: 'Engine Specifications',
          rows: [
            VehicleInfoRow(
              label: 'Engine Make',
              value: PowerUnitModel.displayOrDash(unit.engineMake),
            ),
            VehicleInfoRow(
              label: 'Engine Model',
              value: PowerUnitModel.displayOrDash(unit.engineModel),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared button widget
// ---------------------------------------------------------------------------

class _BlackButton extends StatelessWidget {
  const _BlackButton({
    required this.label,
    required this.onPressed,
    required this.icon,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
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
// Status filter chip box (Active / Expiring / Expired)
// ---------------------------------------------------------------------------

class _StatusChipBox extends StatelessWidget {
  const _StatusChipBox({
    required this.label,
    required this.count,
    required this.textColor,
    required this.bgColor,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final Color textColor;
  final Color bgColor;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? textColor : textColor.withValues(alpha: 0.35),
              width: selected ? 1.8 : 1.0,
            ),
          ),
          child: Column(
            children: [
              Text(
                '$count',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: textColor,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                  letterSpacing: 0.5,
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
// Document card with action buttons
// ---------------------------------------------------------------------------

class _DocCard extends StatelessWidget {
  const _DocCard({
    required this.doc,
    required this.onView,
    required this.onDelete,
    required this.onVersionHistory,
    required this.onDownload,
  });

  final TruckDocumentModel doc;
  final VoidCallback onView;
  final VoidCallback onDelete;
  final VoidCallback onVersionHistory;
  final VoidCallback onDownload;

  static String _status(TruckDocumentModel d) {
    final s = (d.statusLabel ?? '').toLowerCase();
    if (s == 'expired') return 'expired';
    if (s.contains('expir')) return 'expiring';
    return 'active';
  }

  @override
  Widget build(BuildContext context) {
    final status = _status(doc);
    final textColor = status == 'expired'
        ? const Color(0xFFBA1A1A)
        : status == 'expiring'
        ? const Color(0xFF8B5E00)
        : const Color(0xFF1B7A3E);
    final bgColor = status == 'expired'
        ? const Color(0xFFFCE8E8)
        : status == 'expiring'
        ? const Color(0xFFFFF3E0)
        : const Color(0xFFE6F4EC);
    final expiryHighlight = status == 'expired' || status == 'expiring';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail placeholder
                Container(
                  width: 44,
                  height: 54,
                  decoration: BoxDecoration(
                    color: AppColors.border.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.description_outlined,
                    size: 24,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              doc.documentType ?? doc.fileName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: bgColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              doc.statusLabel ?? 'Active',
                              style: TextStyle(
                                color: textColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '#${doc.documentNumber ?? '—'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            'ISSUED',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            doc.issueDate ?? '—',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Text(
                            'EXPIRES',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            doc.expiryDate ?? '—',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: expiryHighlight
                                  ? const Color(0xFFBA1A1A)
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ActionBtn(
                  icon: Icons.visibility_outlined,
                  tooltip: 'View',
                  onTap: onView,
                ),
                _ActionBtn(
                  icon: Icons.download_outlined,
                  tooltip: 'Download',
                  onTap: onDownload,
                ),
                _ActionBtn(
                  icon: Icons.upload_file_outlined,
                  tooltip: 'Replace',
                  onTap: () =>
                      AppToast.showSuccess('Replace document coming soon'),
                ),
                _ActionBtn(
                  icon: Icons.history_outlined,
                  tooltip: 'Version history',
                  onTap: onVersionHistory,
                ),
                _ActionBtn(
                  icon: Icons.delete_outline,
                  tooltip: 'Delete',
                  color: const Color(0xFFBA1A1A),
                  onTap: onDelete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.color,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 20, color: color ?? AppColors.textSecondary),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Document Details bottom sheet
// ---------------------------------------------------------------------------

class _DocumentDetailsSheet extends StatelessWidget {
  const _DocumentDetailsSheet({required this.doc, required this.unitNumber});

  final TruckDocumentModel doc;
  final String unitNumber;

  static String _status(TruckDocumentModel d) {
    final s = (d.statusLabel ?? '').toLowerCase();
    if (s == 'expired') return 'expired';
    if (s.contains('expir')) return 'expiring';
    return 'active';
  }

  @override
  Widget build(BuildContext context) {
    final status = _status(doc);
    final textColor = status == 'expired'
        ? const Color(0xFFBA1A1A)
        : status == 'expiring'
        ? const Color(0xFF8B5E00)
        : const Color(0xFF1B7A3E);
    final bgColor = status == 'expired'
        ? const Color(0xFFFCE8E8)
        : status == 'expiring'
        ? const Color(0xFFFFF3E0)
        : const Color(0xFFE6F4EC);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Document details',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'View complete information and download',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: AppColors.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: AppColors.border),
            // Scrollable content
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(16),
                children: [
                  _SheetSection(
                    children: [
                      _SheetRow(
                        label: 'DOCUMENT TYPE',
                        value: doc.documentType ?? doc.fileName,
                        valueBold: true,
                        valueFontSize: 15,
                      ),
                      const SizedBox(height: 10),
                      _SheetLabel(label: 'STATUS'),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: bgColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  margin: const EdgeInsets.only(right: 5),
                                  decoration: BoxDecoration(
                                    color: textColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Text(
                                  doc.statusLabel ?? 'Active',
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _SheetSection(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _SheetRow(
                              label: 'DOCUMENT NUMBER',
                              value: doc.documentNumber ?? '—',
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _SheetRow(label: 'UPLOADED BY', value: '—'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _SheetRow(
                              label: 'ISSUE DATE',
                              value: doc.issueDate ?? '—',
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _SheetRow(
                              label: 'EXPIRY DATE',
                              value: doc.expiryDate ?? '—',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _SheetRow(
                        label: 'UPLOADED DATE',
                        value: doc.updatedOn ?? '—',
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _SheetSection(
                    children: [
                      _SheetLabel(label: 'FILE'),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.border.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFFBA1A1A),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Center(
                                child: Text(
                                  'PDF',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    doc.fileName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Tap to preview',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (doc.notes != null && doc.notes!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _SheetSection(
                      children: [
                        _SheetLabel(label: 'NOTES'),
                        const SizedBox(height: 4),
                        Text(
                          doc.notes!,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 80),
                ],
              ),
            ),
            // Bottom actions
            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                MediaQuery.of(context).padding.bottom + 16,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => DocumentDownloadService.instance
                          .downloadAndOpen(
                            context: context,
                            truckId: doc.truckId,
                            documentId: doc.id,
                            displayFileName: doc.fileName,
                          ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1A1A1A),
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.download_outlined, size: 18),
                      label: const Text('Download'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Version History bottom sheet
// ---------------------------------------------------------------------------

class _VersionHistorySheet extends StatelessWidget {
  const _VersionHistorySheet({required this.doc, required this.unitNumber});

  final TruckDocumentModel doc;
  final String unitNumber;

  static String _status(TruckDocumentModel d) {
    final s = (d.statusLabel ?? '').toLowerCase();
    if (s == 'expired') return 'expired';
    if (s.contains('expir')) return 'expiring';
    return 'active';
  }

  @override
  Widget build(BuildContext context) {
    final status = _status(doc);
    final textColor = status == 'expired'
        ? const Color(0xFFBA1A1A)
        : status == 'expiring'
        ? const Color(0xFF8B5E00)
        : const Color(0xFF1B7A3E);
    final bgColor = status == 'expired'
        ? const Color(0xFFFCE8E8)
        : status == 'expiring'
        ? const Color(0xFFFFF3E0)
        : const Color(0xFFE6F4EC);

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Version history',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '$unitNumber · ${doc.documentType ?? doc.fileName}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: AppColors.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: AppColors.border),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Version badges row
                              Row(
                                children: [
                                  _VTag(
                                    label: 'Current',
                                    color: const Color(0xFF1A56DB),
                                    bg: const Color(0xFFE8F0FE),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Version 1',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _VTag(
                                    label: 'Latest',
                                    color: AppColors.textSecondary,
                                    bg: AppColors.border.withValues(alpha: 0.4),
                                  ),
                                  const Spacer(),
                                  InkWell(
                                    onTap: () {},
                                    borderRadius: BorderRadius.circular(6),
                                    child: Padding(
                                      padding: const EdgeInsets.all(6),
                                      child: Icon(
                                        Icons.visibility_outlined,
                                        size: 18,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  InkWell(
                                    onTap: () =>
                                        DocumentDownloadService.instance
                                            .downloadAndOpen(
                                              context: context,
                                              truckId: doc.truckId,
                                              documentId: doc.id,
                                              displayFileName: doc.fileName,
                                            ),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Padding(
                                      padding: const EdgeInsets.all(6),
                                      child: Icon(
                                        Icons.download_outlined,
                                        size: 18,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: _SheetRow(
                                      label: 'DOCUMENT NUMBER',
                                      value: doc.documentNumber ?? '—',
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _SheetLabel(label: 'DOCUMENT STATUS'),
                                        const SizedBox(height: 3),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: bgColor,
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: Text(
                                            doc.statusLabel ?? 'Active',
                                            style: TextStyle(
                                              color: textColor,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _SheetRow(
                                      label: 'ISSUE DATE',
                                      value: doc.issueDate ?? '—',
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _SheetRow(
                                      label: 'EXPIRY DATE',
                                      value: doc.expiryDate ?? '—',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(
                                    Icons.person_outline,
                                    size: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: _SheetRow(
                                      label: 'UPLOADED BY',
                                      value: '—',
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Icon(
                                    Icons.calendar_today_outlined,
                                    size: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: _SheetRow(
                                      label: 'UPLOADED DATE',
                                      value: doc.updatedOn ?? '—',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Divider(height: 1, color: AppColors.border),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'No older versions',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Footer summary
            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                MediaQuery.of(context).padding.bottom + 12,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total: 1',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    'Current: 1',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    'Updated: ${doc.updatedOn ?? '—'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Version tag badge
// ---------------------------------------------------------------------------

class _VTag extends StatelessWidget {
  const _VTag({required this.label, required this.color, required this.bg});

  final String label;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sheet section container
// ---------------------------------------------------------------------------

class _SheetSection extends StatelessWidget {
  const _SheetSection({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sheet label + value row
// ---------------------------------------------------------------------------

class _SheetRow extends StatelessWidget {
  const _SheetRow({
    required this.label,
    required this.value,
    this.valueBold = false,
    this.valueFontSize = 14,
  });

  final String label;
  final String value;
  final bool valueBold;
  final double valueFontSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SheetLabel(label: label),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: valueFontSize,
            fontWeight: valueBold ? FontWeight.w700 : FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _SheetLabel extends StatelessWidget {
  const _SheetLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Work order card
// ---------------------------------------------------------------------------

class _WoCard extends StatelessWidget {
  const _WoCard({required this.wo});
  final WorkOrderModel wo;

  static String _initials(String? name) {
    if (name == null || name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  static String _fmtDate(String? s) {
    if (s == null || s.isEmpty) return '—';
    final d = DateTime.tryParse(s);
    if (d == null) return s;
    return '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}-${d.year}';
  }

  static String _fmtCost(double? v) =>
      v == null ? '—' : '\$${v.toStringAsFixed(2)}';

  static String _fmtOdo(String? v) => (v == null || v.isEmpty) ? '—' : '$v km';

  @override
  Widget build(BuildContext context) {
    final details = wo.workOrderDetails;
    final tech = details?.technicianName;
    final initials = _initials(tech);
    final displayNum = wo.workOrderNumber.toLowerCase().startsWith('wo')
        ? wo.workOrderNumber
        : 'WO-${wo.workOrderNumber}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // WO number + status chip
            Row(
              children: [
                Expanded(
                  child: Text(
                    displayNum,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: wo.status.backgroundColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    wo.status.label,
                    style: TextStyle(
                      color: wo.status.textColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              [
                wo.issueDescription,
                wo.companyName,
              ].where((s) => s != null && s.isNotEmpty).join(' · '),
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _InfoCell(
                    label: 'COST',
                    value: _fmtCost(details?.estimatedCost),
                  ),
                ),
                Expanded(
                  child: _InfoCell(
                    label: 'ODOMETER',
                    value: _fmtOdo(details?.odometer ?? details?.startOdometer),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _InfoCell(
                    label: 'START DATE',
                    value: _fmtDate(details?.startDate),
                  ),
                ),
                Expanded(
                  child: _InfoCell(
                    label: 'DUE DATE',
                    value: _fmtDate(details?.dueDate),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1A1A1A),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    tech ?? 'Unassigned',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (details?.dueDate != null) ...[
                  Icon(
                    Icons.access_time_outlined,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Due ${_fmtDate(details?.dueDate)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Compliance stat box  (label on top, large count below — matches WO style)
// ---------------------------------------------------------------------------

class _ComplianceStatBox extends StatelessWidget {
  const _ComplianceStatBox({
    required this.label,
    required this.count,
    required this.textColor,
    required this.bgColor,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final Color textColor;
  final Color bgColor;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? textColor : Colors.transparent,
              width: 1.8,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: textColor,
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
// Compliance document card  (work-order card style)
// ---------------------------------------------------------------------------

class _ComplianceDocCard extends StatelessWidget {
  const _ComplianceDocCard({required this.doc});
  final TruckDocumentModel doc;

  static String _status(TruckDocumentModel d) {
    final s = (d.statusLabel ?? '').toLowerCase();
    if (s == 'expired') return 'expired';
    if (s.contains('expir')) return 'expiring';
    return 'active';
  }

  @override
  Widget build(BuildContext context) {
    final status = _status(doc);
    final chipColor = status == 'expired'
        ? const Color(0xFFBA1A1A)
        : status == 'expiring'
        ? const Color(0xFF8B5E00)
        : const Color(0xFF1B7A3E);
    final chipBg = status == 'expired'
        ? const Color(0xFFFCE8E8)
        : status == 'expiring'
        ? const Color(0xFFFFF3E0)
        : const Color(0xFFE6F4EC);
    final expiryHighlight = status == 'expired' || status == 'expiring';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row
            Row(
              children: [
                Expanded(
                  child: Text(
                    doc.documentType ?? doc.fileName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: chipBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    doc.statusLabel ?? 'Active',
                    style: TextStyle(
                      color: chipColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (doc.documentCategory != null) ...[
              const SizedBox(height: 2),
              Text(
                doc.documentCategory!,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
            const SizedBox(height: 10),
            Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 10),
            // Data grid
            Row(
              children: [
                Expanded(
                  child: _InfoCell(
                    label: 'DOC NUMBER',
                    value: doc.documentNumber ?? '—',
                  ),
                ),
                Expanded(
                  child: _InfoCell(
                    label: 'UPLOADED',
                    value: doc.updatedOn ?? '—',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _InfoCell(
                    label: 'ISSUE DATE',
                    value: doc.issueDate ?? '—',
                  ),
                ),
                Expanded(
                  child: _InfoCell(
                    label: 'EXPIRY DATE',
                    value: doc.expiryDate ?? '—',
                    valueColor: expiryHighlight
                        ? const Color(0xFFBA1A1A)
                        : null,
                  ),
                ),
              ],
            ),
            if (doc.notes != null && doc.notes!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.notes_outlined,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      doc.notes!,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Compliance helpers
// ---------------------------------------------------------------------------

class _InfoCell extends StatelessWidget {
  const _InfoCell({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _IconSquareBtn extends StatelessWidget {
  const _IconSquareBtn({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, size: 20, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _PagBtn extends StatelessWidget {
  const _PagBtn({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(
            icon,
            size: 18,
            color: enabled
                ? AppColors.textPrimary
                : AppColors.textSecondary.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}
