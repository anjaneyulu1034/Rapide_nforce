import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/api_constants.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/core/constants/app_gradients.dart';
import 'package:rapide_nforce/core/utils/api_feedback.dart';
import 'package:rapide_nforce/core/utils/app_toast.dart';
import 'package:rapide_nforce/core/utils/document_download_service.dart';
import 'package:rapide_nforce/models/trailer_model.dart';
import 'package:rapide_nforce/models/truck_document_model.dart';
import 'package:rapide_nforce/models/work_order_model.dart';
import 'package:rapide_nforce/services/auth_service.dart';
import 'package:rapide_nforce/services/maintenance_service.dart';
import 'package:rapide_nforce/services/permission_service.dart';
import 'package:rapide_nforce/services/trailer_service.dart';
import 'package:rapide_nforce/ui/trailers/trailer_upload_document_sheet.dart';
import 'package:rapide_nforce/ui/widgets/document_card.dart';
import 'package:rapide_nforce/ui/widgets/gradient_page_background.dart';
import 'package:rapide_nforce/ui/widgets/qr_code_sheet.dart';
import 'package:rapide_nforce/ui/widgets/screen_state_builder.dart';
import 'package:rapide_nforce/ui/widgets/status_chip.dart';
import 'package:rapide_nforce/ui/widgets/vehicle_info_section.dart';
import 'package:rapide_nforce/ui/work_orders/work_order_form_screen.dart';

enum _Tab { overview, compliance, documents, maintenance, specifications }

class TrailerDetailScreen extends StatefulWidget {
  const TrailerDetailScreen({super.key, required this.trailerId});
  final int trailerId;

  @override
  State<TrailerDetailScreen> createState() => _TrailerDetailScreenState();
}

class _TrailerDetailScreenState extends State<TrailerDetailScreen> {
  _Tab _tab = _Tab.overview;
  bool _loading = true;
  String? _error;
  TrailerModel? _trailer;
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
    final result = await TrailerService.instance.fetchTrailerById(
      widget.trailerId,
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
      _trailer = result.data;
    });
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() => _docsLoading = true);
    final result = await TrailerService.instance.fetchDocuments(
      widget.trailerId,
    );
    if (!mounted) return;
    setState(() {
      _docsLoading = false;
      _documents = result.data ?? [];
    });
  }

  Future<void> _loadMaintenance() async {
    final t = _trailer;
    if (t == null) return;
    setState(() => _woLoading = true);
    final result = await MaintenanceService.instance
        .getMaintenanceHistoryByUnit(
          unitNumber: t.trailerNumber,
          companyId: AuthService.instance.selectedCompanyIdInt,
        );
    if (!mounted) return;
    setState(() {
      _woLoading = false;
      _workOrders = result.data ?? [];
    });
  }

  Future<void> _uploadDocument() async {
    final t = _trailer;
    if (t == null) return;
    final changed = await showTrailerUploadDocumentSheet(
      context: context,
      trailerId: widget.trailerId,
      trailer: t,
    );
    if (changed == true) _loadDocuments();
  }

  Future<void> _uploadDocumentSimple() async {
    final t = _trailer;
    if (t == null) return;
    final changed = await showTrailerDocsTabUploadSheet(
      context: context,
      trailerId: widget.trailerId,
      trailer: t,
    );
    if (changed == true) _loadDocuments();
  }

  Future<void> _replaceDocument(TruckDocumentModel doc) async {
    final t = _trailer;
    if (t == null) return;
    final changed = await showTrailerDocsTabUploadSheet(
      context: context,
      trailerId: widget.trailerId,
      trailer: t,
      doc: doc,
    );
    if (changed == true) _loadDocuments();
  }

  Future<void> _deleteDocument(TruckDocumentModel doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 40,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.danger,
                  size: 34,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Delete Document',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Delete "${doc.fileName}"?\nThis cannot be undone.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: BorderSide(color: AppColors.border, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Delete',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true) return;
    final result = await TrailerService.instance.deleteDocument(
      trailerId: widget.trailerId,
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

  void _onTabChanged(_Tab tab) {
    setState(() => _tab = tab);
    if (tab == _Tab.maintenance) _loadMaintenance();
    if (tab == _Tab.documents || tab == _Tab.compliance) _loadDocuments();
  }

  @override
  Widget build(BuildContext context) {
    final trailer = _trailer;
    return GradientPageBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: trailer == null
              ? const Text('Trailer Details')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          trailer.trailerNumber,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 8),
                        trailer.isActive
                            ? StatusChip.active('Active')
                            : StatusChip.inactive('Inactive'),
                      ],
                    ),
                    Text(
                      _displayTitle(trailer),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
        ),
        floatingActionButton: _trailer != null && _tab == _Tab.maintenance
            ? FloatingActionButton(
                onPressed: _onCreateWorkOrder,
                backgroundColor: const Color(0xFF1A1A1A),
                foregroundColor: Colors.white,
                child: const Icon(Icons.add),
              )
            : null,
        body: ScreenStateBuilder(
          loading: _loading,
          error: _error,
          onRetry: _load,
          child: trailer == null
              ? const SizedBox.shrink()
              : CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          _TrailerSummaryCards(trailer: trailer),
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
                      toolbarHeight: 0,
                      bottom: PreferredSize(
                        preferredSize: const Size.fromHeight(90),
                        child: _buildTabsBar(),
                      ),
                    ),
                    SliverFillRemaining(
                      hasScrollBody: true,
                      child: _buildTabContent(trailer),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  String _displayTitle(TrailerModel t) {
    final parts = <String>[
      if (t.make != null && t.make!.isNotEmpty) t.make!,
      if (t.model != null && t.model!.isNotEmpty) t.model!,
      if (t.year != null) '(${t.year})',
    ];
    return parts.isEmpty ? t.type : parts.join(' ');
  }

  Widget _buildTabsBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _tabChip('OVERVIEW', Icons.notes_outlined, _Tab.overview),
            const SizedBox(width: 8),
            _tabChip('COMPLIANCE', Icons.assignment_outlined, _Tab.compliance),
            const SizedBox(width: 8),
            _tabChip('DOCUMENTS', Icons.description_outlined, _Tab.documents),
            const SizedBox(width: 8),
            _tabChip('HISTORY', Icons.access_time_outlined, _Tab.maintenance),
            const SizedBox(width: 8),
            _tabChip('SPECS', Icons.analytics_outlined, _Tab.specifications),
          ],
        ),
      ),
    );
  }

  Widget _tabChip(String label, IconData icon, _Tab tab) {
    final isSelected = _tab == tab;
    return SizedBox(
      width: 90,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onTabChanged(tab),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 8),
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
                const SizedBox(height: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    letterSpacing: 0.4,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent(TrailerModel trailer) {
    switch (_tab) {
      case _Tab.overview:
        return _OverviewTab(trailer: trailer);
      case _Tab.compliance:
        return _ComplianceTab(
          trailer: trailer,
          documents: _documents,
          loading: _docsLoading,
          onUpload: _uploadDocument,
        );
      case _Tab.documents:
        return _DocumentsTab(
          trailer: trailer,
          documents: _documents,
          loading: _docsLoading,
          onUpload: _uploadDocumentSimple,
          onReplace: _replaceDocument,
          onDelete: _deleteDocument,
          onRefresh: _loadDocuments,
        );
      case _Tab.maintenance:
        return _MaintenanceTab(loading: _woLoading, workOrders: _workOrders);
      case _Tab.specifications:
        return _SpecificationsTab(trailer: trailer);
    }
  }
}

// ─── Summary Cards ─────────────────────────────────────────────────────────────

class _TrailerSummaryCards extends StatelessWidget {
  const _TrailerSummaryCards({required this.trailer});
  final TrailerModel trailer;

  int? _daysUntil(String? s) {
    if (s == null || s.isEmpty) return null;
    DateTime? d = DateTime.tryParse(s);
    if (d == null) {
      final p = s.split('-');
      if (p.length == 3) {
        final m = int.tryParse(p[0]);
        final day = int.tryParse(p[1]);
        final y = int.tryParse(p[2]);
        if (m != null && day != null && y != null) {
          d = DateTime(y, m, day);
        }
      }
    }
    return d?.difference(DateTime.now()).inDays;
  }

  @override
  Widget build(BuildContext context) {
    final inspDays = _daysUntil(trailer.annualInspectionDue);
    final pmDays = _daysUntil(trailer.pmDueDate);

    String odoStr = '—';
    if (trailer.odometer != null) {
      final re = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
      odoStr =
          '${trailer.odometer!.toString().replaceAllMapped(re, (m) => '${m[1]},')} km';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _SCard(
              label: 'ODOMETER',
              value: odoStr,
              icon: Icons.local_shipping_outlined,
              iconColor: const Color(0xFF374151),
              bg: const Color(0xFFF1F5F9),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _SCard(
              label: 'ANNUAL INSP.',
              value: trailer.annualInspectionDue ?? '—',
              icon: Icons.assignment_turned_in_outlined,
              iconColor: inspDays != null && inspDays < 0
                  ? const Color(0xFFBA1A1A)
                  : const Color(0xFF374151),
              bg: inspDays != null && inspDays < 0
                  ? const Color(0xFFFFF1F2)
                  : const Color(0xFFF1F5F9),
              sub: inspDays != null
                  ? (inspDays < 0
                        ? '${inspDays.abs()} DAYS OVERDUE'
                        : '$inspDays DAYS LEFT')
                  : null,
              subBg: inspDays != null
                  ? (inspDays < 0
                        ? const Color(0xFFFFDAD6)
                        : const Color(0xFFDCFCE7))
                  : null,
              subColor: inspDays != null
                  ? (inspDays < 0
                        ? const Color(0xFFBA1A1A)
                        : const Color(0xFF15803D))
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _SCard(
              label: 'NEXT PM DUE',
              value: trailer.pmDueDate ?? '—',
              icon: Icons.build_outlined,
              iconColor: pmDays != null && pmDays < 0
                  ? const Color(0xFFBA1A1A)
                  : const Color(0xFFF59E0B),
              bg: pmDays != null && pmDays < 0
                  ? const Color(0xFFFFF1F2)
                  : const Color(0xFFFFFBEB),
              sub: pmDays != null
                  ? (pmDays < 0
                        ? '${pmDays.abs()} DAYS OVERDUE'
                        : '$pmDays DAYS LEFT')
                  : null,
              subBg: pmDays != null
                  ? (pmDays < 0
                        ? const Color(0xFFFFDAD6)
                        : const Color(0xFFFEF3C7))
                  : null,
              subColor: pmDays != null
                  ? (pmDays < 0
                        ? const Color(0xFFBA1A1A)
                        : const Color(0xFFD97706))
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _SCard extends StatelessWidget {
  const _SCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    this.bg,
    this.sub,
    this.subBg,
    this.subColor,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color? bg;
  final String? sub;
  final Color? subBg;
  final Color? subColor;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: (isLight && bg != null) ? bg : AppColors.card,
        borderRadius: BorderRadius.circular(14),
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
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          if (sub != null) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: subBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                sub!,
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  color: subColor,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Overview Tab ───────────────────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.trailer});
  final TrailerModel trailer;

  static const _red = Color(0xFFBA1A1A);

  static bool _isExpired(String? s) {
    if (s == null || s.isEmpty) return false;
    DateTime? d = DateTime.tryParse(s);
    if (d == null) {
      final p = s.split('-');
      if (p.length == 3) {
        final m = int.tryParse(p[0]);
        final day = int.tryParse(p[1]);
        final y = int.tryParse(p[2]);
        if (m != null && day != null && y != null) d = DateTime(y, m, day);
      }
    }
    if (d == null) return false;
    final today = DateTime.now();
    return DateTime(
      d.year,
      d.month,
      d.day,
    ).isBefore(DateTime(today.year, today.month, today.day));
  }

  @override
  Widget build(BuildContext context) {
    final regExp = _isExpired(trailer.registrationExpiry);
    final cvipExp = _isExpired(trailer.cviExpiry ?? trailer.expiryDate);
    final inspExp = _isExpired(trailer.annualInspectionDue);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        VehicleInfoSection(
          title: 'Basic Information',
          initiallyExpanded: true,
          rows: [
            VehicleInfoRow(label: 'Unit Number', value: trailer.trailerNumber),
            VehicleInfoRow(
              label: 'VIN',
              value: TrailerModel.displayOrDash(trailer.vinNumber),
            ),
            VehicleInfoRow(
              label: 'Make',
              value: TrailerModel.displayOrDash(trailer.make),
            ),
            VehicleInfoRow(
              label: 'Model',
              value: TrailerModel.displayOrDash(trailer.model),
            ),
            VehicleInfoRow(label: 'Type', value: trailer.type),
            VehicleInfoRow(
              label: 'Year',
              value: trailer.year?.toString() ?? '—',
            ),
            VehicleInfoRow(
              label: 'Color',
              value: TrailerModel.displayOrDash(trailer.color),
            ),
            VehicleInfoRow(
              label: 'Purchase Date',
              value: TrailerModel.displayOrDash(trailer.purchaseDate),
            ),
            VehicleInfoRow(
              label: 'Purchase Price',
              value: trailer.purchasePrice != null
                  ? '\$${trailer.purchasePrice}'
                  : '—',
            ),
            VehicleInfoRow(label: 'Status', value: trailer.status),
          ],
        ),
        const SizedBox(height: 12),
        VehicleInfoSection(
          title: 'Registration & Insurance',
          titleIcon: regExp
              ? const Icon(Icons.warning_amber_rounded, size: 16, color: _red)
              : null,
          rows: [
            VehicleInfoRow(
              label: 'Plate Number',
              value: TrailerModel.displayOrDash(trailer.licensePlate),
            ),
            VehicleInfoRow(
              label: 'Plate Province',
              value: TrailerModel.displayOrDash(trailer.state),
            ),
            VehicleInfoRow(
              label: 'Registration Number',
              value: TrailerModel.displayOrDash(trailer.registrationNumber),
            ),
            VehicleInfoRow(
              label: 'Registration Expiry',
              value: TrailerModel.displayOrDash(trailer.registrationExpiry),
              valueColor: regExp ? _red : null,
            ),
            VehicleInfoRow(
              label: 'IMS Number',
              value: TrailerModel.displayOrDash(trailer.imsNumber),
            ),
            VehicleInfoRow(
              label: 'Ownership',
              value: TrailerModel.displayOrDash(trailer.ownership),
            ),
          ],
        ),
        const SizedBox(height: 12),
        VehicleInfoSection(
          title: 'Inspection & Maintenance',
          titleIcon: inspExp
              ? const Icon(Icons.warning_amber_rounded, size: 16, color: _red)
              : null,
          rows: [
            VehicleInfoRow(
              label: 'Annual Inspection Due',
              value: TrailerModel.displayOrDash(trailer.annualInspectionDue),
              valueColor: inspExp ? _red : null,
            ),
            VehicleInfoRow(
              label: 'PM Due Date',
              value: TrailerModel.displayOrDash(trailer.pmDueDate),
            ),
            VehicleInfoRow(
              label: 'CVI Expiry',
              value: TrailerModel.displayOrDash(trailer.cviExpiry),
              valueColor: _isExpired(trailer.cviExpiry) ? _red : null,
            ),
            VehicleInfoRow(
              label: 'Assigned Truck',
              value: TrailerModel.displayOrDash(trailer.assignedTruck),
            ),
          ],
        ),
        const SizedBox(height: 12),
        VehicleInfoSection(
          title: 'Annual Safety / CVIP',
          titleIcon: cvipExp
              ? const Icon(Icons.warning_amber_rounded, size: 16, color: _red)
              : null,
          rows: [
            VehicleInfoRow(
              label: 'Certificate Status',
              value: cvipExp ? 'EXPIRED' : 'Valid',
              valueColor: cvipExp ? _red : null,
            ),
            VehicleInfoRow(
              label: 'Certificate Number',
              value: TrailerModel.displayOrDash(trailer.certificateNumber),
            ),
            VehicleInfoRow(
              label: 'Expiry Date',
              value: TrailerModel.displayOrDash(trailer.expiryDate),
              valueColor: cvipExp ? _red : null,
            ),
            VehicleInfoRow(
              label: 'Inspection Date',
              value: TrailerModel.displayOrDash(trailer.inspectionDate),
            ),
            VehicleInfoRow(
              label: 'Next Inspection Due',
              value: TrailerModel.displayOrDash(trailer.nextInspectionDue),
            ),
            VehicleInfoRow(
              label: 'Inspector Name',
              value: TrailerModel.displayOrDash(trailer.inspectorName),
            ),
            VehicleInfoRow(
              label: 'Inspector License',
              value: TrailerModel.displayOrDash(trailer.inspectorLicense),
            ),
            VehicleInfoRow(
              label: 'Inspection Facility',
              value: TrailerModel.displayOrDash(trailer.inspectionFacility),
            ),
            VehicleInfoRow(
              label: 'Critical Defects',
              value: '${trailer.criticalDefects ?? 0}',
            ),
            VehicleInfoRow(
              label: 'Major Defects',
              value: '${trailer.majorDefects ?? 0}',
            ),
            VehicleInfoRow(
              label: 'Advisory Items',
              value: '${trailer.advisoryItems ?? 0}',
            ),
          ],
        ),
        if (trailer.ownerName != null) ...[
          const SizedBox(height: 12),
          VehicleInfoSection(
            title: 'Owner Information',
            rows: [
              VehicleInfoRow(
                label: 'Owner Name',
                value: TrailerModel.displayOrDash(trailer.ownerName),
              ),
              VehicleInfoRow(
                label: 'Owner Email',
                value: TrailerModel.displayOrDash(trailer.ownerEmail),
              ),
              VehicleInfoRow(
                label: 'Owner Phone',
                value: TrailerModel.displayOrDash(trailer.ownerPhone),
              ),
              VehicleInfoRow(
                label: 'Owner Address',
                value: TrailerModel.displayOrDash(trailer.ownerAddress),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ─── Compliance Tab ─────────────────────────────────────────────────────────────

class _ComplianceTab extends StatefulWidget {
  const _ComplianceTab({
    required this.trailer,
    required this.documents,
    required this.loading,
    required this.onUpload,
  });

  final TrailerModel trailer;
  final List<TruckDocumentModel> documents;
  final bool loading;
  final VoidCallback onUpload;

  static const _requiredDocs = [
    'Vehicle Registration',
    'Annual Safety / CVIP',
    'Proof of Insurance',
    'Operating Authority (Copy)',
    'Maintenance Records',
    'IFTA Permit',
    'KYU Permit',
    'NY HUT Permit',
    'NM Weight-Distance',
    'DTOPS Permit',
  ];

  @override
  State<_ComplianceTab> createState() => _ComplianceTabState();
}

class _ComplianceTabState extends State<_ComplianceTab> {
  bool _generatingQr = false;

  void _showDocDetails(TruckDocumentModel doc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DocumentDetailsSheet(
        doc: doc,
        unitNumber: widget.trailer.trailerNumber,
        entityBasePath: ApiConstants.trailers,
      ),
    );
  }

  Future<void> _downloadPacket() =>
      DocumentDownloadService.instance.downloadPdfPacket(
        context: context,
        truckId: widget.trailer.id,
        scope: 'compliance',
        hasDocuments: widget.documents.isNotEmpty,
        entityBasePath: ApiConstants.trailers,
      );

  Future<void> _generateQrCode() async {
    setState(() => _generatingQr = true);
    final result = await TrailerService.instance.generateQrCode(
      widget.trailer.id,
    );
    if (!mounted) return;
    setState(() => _generatingQr = false);
    if (!result.isSuccess || result.data == null) {
      ApiFeedback.showError(result, fallback: 'Failed to generate QR code');
      return;
    }

    Uint8List? bytes;
    try {
      final dataUrl = result.data!.qrCodeDataUrl;
      final base64Part = dataUrl.contains(',')
          ? dataUrl.split(',').last
          : dataUrl;
      bytes = base64Decode(base64Part);
    } catch (_) {}

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => QrCodeSheet(
        imageBytes: bytes,
        unitNumber: widget.trailer.trailerNumber,
        onDownloadPacket: _downloadPacket,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final documents = widget.documents;
    final loading = widget.loading;
    final expired = documents.where((d) {
      final s = (d.statusLabel ?? '').toLowerCase();
      return s.contains('expired');
    }).length;
    final missing = _ComplianceTab._requiredDocs.length - documents.length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Expanded(
            //   child: Text(
            //     'Vehicle Compliance Binder — ${trailer.trailerNumber}',
            //     style: TextStyle(
            //         fontWeight: FontWeight.w700,
            //         fontSize: 15,
            //         color: AppColors.textPrimary),
            //   ),
            //  ),
            const SizedBox(width: 8),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                _BlackButton(
                  label: 'Roadside Packet',
                  onPressed: _downloadPacket,
                  icon: Icons.download_outlined,
                  color: const Color(0xFF4B633D),
                ),
                _BlackButton(
                  label: 'Upload',
                  onPressed: widget.onUpload,
                  icon: Icons.upload_file_outlined,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _statBox('Total', '${documents.length}'),
            _statBox('Expired', '$expired'),
            _statBox('Missing', '${missing < 0 ? 0 : missing}'),
          ],
        ),
        const SizedBox(height: 16),
        if (loading)
          const Center(child: CircularProgressIndicator())
        else
          ..._groupDocuments(documents),
        const SizedBox(height: 16),
        Text(
          'Roadside Inspection Readiness',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        ..._ComplianceTab._requiredDocs.map((name) {
          final has = documents.any(
            (d) => (d.documentType ?? d.fileName).toLowerCase().contains(
              name.split(' ').first.toLowerCase(),
            ),
          );
          return ListTile(
            dense: true,
            leading: Icon(
              has ? Icons.check_circle_outline : Icons.error_outline,
              color: has ? AppColors.statusCompleted : AppColors.danger,
              size: 18,
            ),
            title: Text(name, style: const TextStyle(fontSize: 13)),
            trailing: Text(
              has ? 'Uploaded' : 'Missing',
              style: TextStyle(
                fontSize: 12,
                color: has ? AppColors.statusCompleted : AppColors.danger,
              ),
            ),
          );
        }),
        const SizedBox(height: 20),
        Text(
          'Digital Roadside Packet',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Generate a complete digital packet with all required documents '
          'for roadside inspections.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _downloadPacket,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF4B633D),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.download_outlined, size: 18),
            label: const Text('Download PDF Packet'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _generatingQr ? null : _generateQrCode,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1D4ED8),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(
                0xFF1D4ED8,
              ).withValues(alpha: 0.5),
              minimumSize: const Size(double.infinity, 46),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: _generatingQr
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.qr_code_2_outlined, size: 18),
            label: Text(
              _generatingQr ? 'Generating…' : 'Generate QR Code',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'QR code provides inspectors instant access to digital copies '
          'of all documents.',
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _statBox(String label, String value) => Expanded(
    child: Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: AppGradients.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    ),
  );

  List<Widget> _groupDocuments(List<TruckDocumentModel> docs) {
    final groups = <String, List<TruckDocumentModel>>{};
    for (final d in docs) {
      final key = d.documentCategory ?? d.documentType ?? 'Other';
      groups.putIfAbsent(key, () => []).add(d);
    }
    return groups.entries.map((e) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            e.key,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          ...e.value.map((d) {
            final status = documentStatus(d);
            final (textColor, bgColor) = documentStatusColors(status);
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: AppGradients.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d.documentType ?? d.fileName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${d.documentNumber ?? '—'} · ${d.issueDate ?? '—'} → ${d.expiryDate ?? '—'}',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
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
                      documentStatusLabel(status),
                      style: TextStyle(
                        color: textColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  DocActionBtn(
                    icon: Icons.visibility_outlined,
                    tooltip: 'View',
                    onTap: () => _showDocDetails(d),
                  ),
                  DocActionBtn(
                    icon: Icons.download_outlined,
                    tooltip: 'Download',
                    onTap: () => DocumentDownloadService.instance
                        .downloadAndOpen(
                          context: context,
                          truckId: d.truckId,
                          documentId: d.id,
                          displayFileName: d.fileName,
                          entityBasePath: ApiConstants.trailers,
                        ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 12),
        ],
      );
    }).toList();
  }
}

// ─── Documents Tab ──────────────────────────────────────────────────────────────

class _DocumentsTab extends StatefulWidget {
  const _DocumentsTab({
    required this.trailer,
    required this.documents,
    required this.loading,
    required this.onUpload,
    required this.onReplace,
    required this.onDelete,
    required this.onRefresh,
  });

  final TrailerModel trailer;
  final List<TruckDocumentModel> documents;
  final bool loading;
  final VoidCallback onUpload;
  final ValueChanged<TruckDocumentModel> onReplace;
  final ValueChanged<TruckDocumentModel> onDelete;
  final VoidCallback onRefresh;

  @override
  State<_DocumentsTab> createState() => _DocumentsTabState();
}

class _DocumentsTabState extends State<_DocumentsTab> {
  final _searchCtrl = TextEditingController();
  String _search = '';
  String? _filterStatus;
  bool _canUpload = false;
  bool _canReplace = false;
  bool _canDelete = false;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    final result = await PermissionService.instance.getMenuPermissions(
      menuUrl: '/documents',
      menuName: 'Documents',
    );
    if (!mounted) return;
    final perms = result.isSuccess ? result.data : null;
    setState(() {
      _canUpload = perms?.canCreate ?? false;
      _canReplace = perms?.canUpdate ?? false;
      _canDelete = perms?.canDelete ?? false;
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  int _count(String status) =>
      widget.documents.where((d) => documentStatus(d) == status).length;

  List<TruckDocumentModel> get _filtered {
    var list = widget.documents;
    if (_filterStatus != null) {
      list = list.where((d) => documentStatus(d) == _filterStatus).toList();
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
      builder: (_) => DocumentDetailsSheet(
        doc: doc,
        unitNumber: widget.trailer.trailerNumber,
        entityBasePath: ApiConstants.trailers,
      ),
    );
  }

  void _showVersionHistory(TruckDocumentModel doc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VersionHistorySheet(
        doc: doc,
        unitNumber: widget.trailer.trailerNumber,
        entityBasePath: ApiConstants.trailers,
      ),
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
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
            if (_canUpload) ...[
              const SizedBox(height: 8),
              Wrap(
                children: [
                  FilledButton.icon(
                    onPressed: widget.onUpload,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF4B633D),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                    label: const Text(
                      'Upload New',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            StatusChipBox(
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
            StatusChipBox(
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
            StatusChipBox(
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
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 12),
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
            (d) => DocCard(
              doc: d,
              canReplace: _canReplace,
              canDelete: _canDelete,
              onView: () => _showDetails(d),
              onDelete: () => widget.onDelete(d),
              onReplace: () => widget.onReplace(d),
              onVersionHistory: () => _showVersionHistory(d),
              onDownload: () =>
                  DocumentDownloadService.instance.downloadAndOpen(
                    context: context,
                    truckId: d.truckId,
                    documentId: d.id,
                    displayFileName: d.fileName,
                    entityBasePath: ApiConstants.trailers,
                  ),
            ),
          ),
      ],
    );
  }
}

// ─── Maintenance Tab ────────────────────────────────────────────────────────────

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

  void _setFilter(WorkOrderStatus s) => setState(() {
    _filterStatus = _filterStatus == s ? null : s;
  });

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      children: [
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
            _TStatBox(
              label: 'IN PROGRESS',
              count: _count(WorkOrderStatus.inProgress),
              textColor: WorkOrderStatus.inProgress.textColor,
              bgColor: WorkOrderStatus.inProgress.backgroundColor,
              selected: _filterStatus == WorkOrderStatus.inProgress,
              onTap: () => _setFilter(WorkOrderStatus.inProgress),
            ),
            const SizedBox(width: 8),
            _TStatBox(
              label: 'NOT STARTED',
              count: _count(WorkOrderStatus.notStarted),
              textColor: WorkOrderStatus.notStarted.textColor,
              bgColor: WorkOrderStatus.notStarted.backgroundColor,
              selected: _filterStatus == WorkOrderStatus.notStarted,
              onTap: () => _setFilter(WorkOrderStatus.notStarted),
            ),
            const SizedBox(width: 8),
            _TStatBox(
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
                  onChanged: (v) => setState(() => _search = v),
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
            _TIconBtn(icon: Icons.tune_outlined, onTap: () {}),
            const SizedBox(width: 8),
            _TIconBtn(icon: Icons.swap_vert_outlined, onTap: () {}),
          ],
        ),
        const SizedBox(height: 12),
        // Cards
        if (widget.loading)
          const Center(child: CircularProgressIndicator())
        else if (filtered.isEmpty)
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
          ...filtered.map((wo) => _TWoCard(wo: wo)),
      ],
    );
  }
}

// ─── Specifications Tab ─────────────────────────────────────────────────────────

class _SpecificationsTab extends StatelessWidget {
  const _SpecificationsTab({required this.trailer});
  final TrailerModel trailer;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        VehicleInfoSection(
          title: 'Trailer Specifications',
          initiallyExpanded: true,
          rows: [
            VehicleInfoRow(
              label: 'Type',
              value: TrailerModel.displayOrDash(
                trailer.specType ?? trailer.type,
              ),
            ),
            VehicleInfoRow(
              label: 'Length',
              value: TrailerModel.displayOrDash(trailer.specLength),
            ),
            VehicleInfoRow(
              label: 'Width',
              value: TrailerModel.displayOrDash(trailer.specWidth),
            ),
            VehicleInfoRow(
              label: 'Height',
              value: TrailerModel.displayOrDash(trailer.specHeight),
            ),
            VehicleInfoRow(
              label: 'Capacity',
              value: TrailerModel.displayOrDash(trailer.specCapacity),
            ),
            VehicleInfoRow(
              label: 'GVWR',
              value: TrailerModel.displayOrDash(trailer.specGvwr),
            ),
          ],
        ),
        const SizedBox(height: 12),
        VehicleInfoSection(
          title: 'Additional Info',
          rows: [
            VehicleInfoRow(
              label: 'Fuel Card',
              value: TrailerModel.displayOrDash(trailer.fuelCard),
            ),
            VehicleInfoRow(
              label: 'Bridge Transponder',
              value: TrailerModel.displayOrDash(trailer.bridgeTransponder),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Black Button ───────────────────────────────────────────────────────────────

class _BlackButton extends StatelessWidget {
  const _BlackButton({
    required this.label,
    required this.onPressed,
    required this.icon,
    this.color = const Color(0xFF1A1A1A),
  });

  final String label;
  final VoidCallback onPressed;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
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
// Trailer maintenance helpers (private to this file)
// ---------------------------------------------------------------------------

class _TStatBox extends StatelessWidget {
  const _TStatBox({
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
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? bgColor : AppColors.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? textColor.withValues(alpha: 0.5)
                  : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: selected ? textColor : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: selected ? textColor : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TIconBtn extends StatelessWidget {
  const _TIconBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, size: 18, color: AppColors.textSecondary),
      ),
    );
  }
}

class _TInfoCell extends StatelessWidget {
  const _TInfoCell({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _TWoCard extends StatelessWidget {
  const _TWoCard({required this.wo});
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
            color: Colors.black.withValues(alpha: 0.06),
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
                  child: _TInfoCell(
                    label: 'COST',
                    value: _fmtCost(details?.estimatedCost),
                  ),
                ),
                Expanded(
                  child: _TInfoCell(
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
                  child: _TInfoCell(
                    label: 'START DATE',
                    value: _fmtDate(details?.startDate),
                  ),
                ),
                Expanded(
                  child: _TInfoCell(
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
