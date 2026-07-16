import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/core/utils/api_feedback.dart';
import 'package:rapide_nforce/core/utils/app_toast.dart';
import 'package:rapide_nforce/core/utils/document_download_service.dart';
import 'package:rapide_nforce/models/work_order_model.dart';
import 'package:rapide_nforce/services/maintenance_service.dart';
import 'package:rapide_nforce/ui/work_orders/work_order_form_screen.dart';
import 'package:rapide_nforce/ui/work_orders/work_order_pdf_export.dart';
import 'package:rapide_nforce/ui/work_orders/work_order_upload_attachment_sheet.dart';
import 'package:rapide_nforce/ui/work_orders/widgets/source_events_widgets.dart';
import 'package:rapide_nforce/ui/work_orders/widgets/work_order_section_header.dart';
import 'package:rapide_nforce/ui/widgets/api_error_banner.dart';
import 'package:rapide_nforce/ui/widgets/gradient_page_background.dart';

/// Read-only "View Work Order" screen — mirrors the web app's View drawer:
/// the same 9 numbered sections, all fields disabled, Cancel/Edit at the
/// bottom. Editing happens on [WorkOrderFormScreen], not here.
class WorkOrderDetailScreen extends StatefulWidget {
  const WorkOrderDetailScreen({super.key, required this.workOrderId});

  final int workOrderId;

  @override
  State<WorkOrderDetailScreen> createState() => _WorkOrderDetailScreenState();
}

class _WorkOrderDetailScreenState extends State<WorkOrderDetailScreen> {
  bool _loading = true;
  String? _error;
  WorkOrderModel? _order;
  bool _deleting = false;

  List<TechnicianSummary> _technicians = [];
  List<MaintenanceIssueSummary> _events = [];
  Map<int, List<MaintenanceIssueUpload>> _eventUploads = {};
  bool _eventUploadsLoading = false;
  String? _vin;
  String _eventsFilter = 'ALL';

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

    final result = await MaintenanceService.instance.getWorkOrderById(
      widget.workOrderId,
    );

    if (!mounted) return;

    if (!result.isSuccess) {
      final message = ApiFeedback.errorMessage(
        result,
        fallback: 'Failed to load work order',
      );
      setState(() {
        _loading = false;
        _error = message;
      });
      return;
    }

    final order = result.data!;
    setState(() {
      _loading = false;
      _order = order;
    });

    _loadTechnicians();
    _loadEventsAndVin(order);
  }

  Future<void> _loadTechnicians() async {
    final result = await MaintenanceService.instance.getTechnicians();
    if (!mounted || !result.isSuccess) return;
    setState(() => _technicians = result.data ?? []);
  }

  Future<void> _loadEventsAndVin(WorkOrderModel order) async {
    String? vin;
    if (order.entityTypeId != null) {
      final entitiesResult = await MaintenanceService.instance.getEntities(
        order.entityTypeId!,
      );
      if (entitiesResult.isSuccess) {
        final match = (entitiesResult.data ?? []).where(
          (e) => e.name == order.unitNumber,
        );
        if (match.isNotEmpty) vin = match.first.vinNumber;
      }
    }
    if (!mounted) return;
    final eventsResult = await MaintenanceService.instance.getMaintenanceIssues(
      unitNumber: order.unitNumber,
      vin: vin,
    );
    if (!mounted) return;
    setState(() {
      _vin = vin;
      _events = eventsResult.data ?? [];
    });
    _loadEventUploads();
  }

  Future<void> _loadEventUploads() async {
    final ids = _events.map((e) => e.id).toList();
    if (ids.isEmpty) {
      setState(() => _eventUploads = {});
      return;
    }
    setState(() => _eventUploadsLoading = true);
    final result = await MaintenanceService.instance.getMaintenanceIssueUploads(ids);
    if (!mounted) return;
    setState(() {
      _eventUploadsLoading = false;
      _eventUploads = result.data ?? {};
    });
  }

  String _technicianName(int? id) {
    if (id == null) return 'Unassigned';
    for (final t in _technicians) {
      if ((t.userId != 0 ? t.userId : t.id) == id) return t.name;
    }
    return 'Unassigned';
  }

  static String _fmtDate(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return iso;
    return DateFormat('MM-dd-yyyy').format(parsed.toLocal());
  }

  static String _fmtHours(num? hours) {
    if (hours == null) return '—';
    final totalSeconds = (hours * 3600).round();
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _edit() async {
    final order = _order;
    if (order == null || !order.status.canEdit) return;

    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => WorkOrderFormScreen(existing: order)),
    );
    if (changed == true) {
      await _load();
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  Future<void> _confirmDelete() async {
    final order = _order;
    if (order == null || !order.status.canEdit) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(
          'Delete work order?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Remove ${order.workOrderNumber.isNotEmpty ? order.workOrderNumber : 'WO #${order.id}'}? This cannot be undone.',
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

    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    final result = await MaintenanceService.instance.deleteWorkOrder(order.id);
    if (!mounted) return;

    setState(() => _deleting = false);

    if (!result.isSuccess) {
      ApiFeedback.showError(result, fallback: 'Delete failed');
      return;
    }

    AppToast.showSuccess('Work order deleted');
    Navigator.of(context).pop(true);
  }

  Future<void> _uploadAttachment() async {
    final order = _order;
    if (order == null) return;
    final uploaded = await showWorkOrderUploadAttachmentSheet(
      context: context,
      workOrderId: order.id,
    );
    if (uploaded == true) _load();
  }

  Future<void> _exportPdf() async {
    final order = _order;
    if (order == null) return;
    await exportWorkOrderPdf(context: context, order: order);
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;

    return GradientPageBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            order?.workOrderNumber.isNotEmpty == true
                ? order!.workOrderNumber
                : 'View Work Order',
          ),
          actions: [
            if (order != null && order.status == WorkOrderStatus.completed)
              IconButton(
                icon: const Icon(Icons.picture_as_pdf_outlined),
                tooltip: 'Export PDF',
                onPressed: _exportPdf,
              ),
            if (order != null && order.status.canEdit)
              IconButton(
                icon: _deleting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.delete_outline, color: AppColors.danger),
                onPressed: _deleting ? null : _confirmDelete,
                tooltip: 'Delete',
              ),
            const SizedBox(width: 4),
          ],
        ),
        body: _buildBody(),
        bottomNavigationBar: (order == null || _loading)
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: order.status.canEdit ? _edit : null,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            backgroundColor: const Color(0xFF1A1A1A),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Edit',
                            style: TextStyle(fontWeight: FontWeight.w700),
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

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ApiErrorBanner(message: _error!, onRetry: _load),
        ),
      );
    }

    final order = _order!;
    final details = order.workOrderDetails;
    var number = 0;
    Widget numbered(
      String title, {
      String? subtitle,
      String? vin,
      bool isCollapsible = false,
      required Widget child,
    }) {
      number++;
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: _SectionCard(
          number: number,
          title: title,
          subtitle: subtitle,
          vin: vin,
          isCollapsible: isCollapsible,
          child: child,
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text(
          'View a maintenance or repair work order · Created on ${_fmtDate(order.createdOn)}',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 14),
        numbered(
          'Work Order Source',
          subtitle: 'Select a unit to load source events for that vehicle.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _ReadOnlyField(
                      label: 'Unit Type',
                      value: order.entityTypeName ?? '—',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ReadOnlyField(
                      label: 'Unit Number',
                      value: order.unitNumber,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _ReadOnlyField(
                      label: 'Priority',
                      value: order.priority?.label ?? '—',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ReadOnlyField(
                      label: 'Work Order Type',
                      value: order.isPreventativeMaintenance
                          ? 'Preventive Maintenance'
                          : (order.workOrderType ?? 'Repair'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        numbered(
          'Source Events ',
          vin: _vin,
          isCollapsible: true,
          child: _EventsReadOnly(
            events: _events,
            filter: _eventsFilter,
            onFilterChanged: (f) => setState(() => _eventsFilter = f),
            uploads: _eventUploads,
            uploadsLoading: _eventUploadsLoading,
            vin: _vin,
            unitNumber: order.unitNumber,
          ),
        ),
        numbered(
          'Work Order Details',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _ReadOnlyField(
                      label: 'Status',
                      value: order.status.label,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ReadOnlyField(
                      label: 'Total Labour Hours',
                      value: _fmtHours(order.totalLabourHours),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _ReadOnlyField(
                      label: 'Total Labour Cost',
                      value: order.totalLabourCost != null
                          ? '\$${order.totalLabourCost!.toStringAsFixed(2)}'
                          : '—',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ReadOnlyField(
                      label: 'Start Date',
                      value: _fmtDate(details?.startDate),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _ReadOnlyField(
                      label: 'Due Date',
                      value: _fmtDate(details?.dueDate),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ReadOnlyField(
                      label: 'Start Odometer',
                      value:
                          (details?.startOdometer ?? details?.odometer)
                                  ?.isNotEmpty ==
                              true
                          ? '${details?.startOdometer ?? details?.odometer} km'
                          : '—',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _ReadOnlyField(
                      label: 'End Odometer',
                      value: (details?.endOdometer?.isNotEmpty ?? false)
                          ? '${details!.endOdometer} km'
                          : '—',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ReadOnlyField(
                      label: 'Location',
                      value: (details?.location?.isNotEmpty ?? false)
                          ? details!.location!
                          : '—',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        numbered(
          'Issue Description',
          child: _ReadOnlyField(
            label: '',
            value: order.issueDescription.isEmpty
                ? 'No issue description provided'
                : order.issueDescription,
            multiline: true,
          ),
        ),
        numbered(
          'Notes',
          child: _ReadOnlyField(
            label: '',
            value: order.notes.isNotEmpty
                ? order.notes.last.description
                : 'No notes added',
            multiline: true,
          ),
        ),
        numbered(
          'Repairs',
          isCollapsible: true,
          child: order.workOrderParts.isEmpty
              ? Text(
                  'No repair lines',
                  style: TextStyle(color: AppColors.textSecondary),
                )
              : Column(
                  children: order.workOrderParts
                      .map(
                        (p) => _RepairLineReadOnly(
                          line: p,
                          technicianName: _technicianName(
                            p.assignedTechnicianId,
                          ),
                          hours: _fmtHours(p.defectHours),
                        ),
                      )
                      .toList(),
                ),
        ),
        if (order.isPreventativeMaintenance)
          numbered(
            'PM Inspection Summary',
            child: _PmSummaryReadOnly(order: order),
          ),
        numbered(
          'Attachments',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppColors.border,
                    style: BorderStyle.solid,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: order.attachments.isEmpty
                    ? Text(
                        'No documents attached',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: AppColors.textSecondary,
                        ),
                      )
                    : Column(
                        children: [
                          for (final a in order.attachments)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.insert_drive_file_outlined,
                                    size: 18,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      a.displayName,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                  if (a.url != null)
                                    IconButton(
                                      icon: const Icon(
                                        Icons.download_outlined,
                                        size: 18,
                                      ),
                                      onPressed: () => DocumentDownloadService
                                          .instance
                                          .downloadAndOpenDirect(
                                            context: context,
                                            url: a.url!,
                                            displayFileName: a.displayName,
                                          ),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _uploadAttachment,
                  icon: const Icon(Icons.upload_rounded, size: 18),
                  label: const Text('Upload attachment'),
                ),
              ),
            ],
          ),
        ),
        numbered(
          'Estimated Cost',
          child: _ReadOnlyField(
            label: '',
            value: details?.estimatedCost != null
                ? '\$${details!.estimatedCost!.toStringAsFixed(2)}'
                : '\$0.00',
          ),
        ),
        numbered(
          'Resolution (Completed Work Orders)',
          child: _ReadOnlyField(
            label: '',
            value: order.status == WorkOrderStatus.completed
                ? (order.resolutionNotes?.isNotEmpty == true
                      ? order.resolutionNotes!
                      : 'No resolution notes added')
                : 'Available when work order is completed',
            multiline: true,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Section card — matches the numbered-circle header used in the Create/Edit
// form, but content is always read-only here.
// ---------------------------------------------------------------------------

class _SectionCard extends StatefulWidget {
  const _SectionCard({
    required this.number,
    required this.title,
    this.subtitle,
    this.vin,
    required this.child,
    this.isCollapsible = false,
  });

  final int number;
  final String title;
  final String? subtitle;
  final String? vin;
  final Widget child;
  final bool isCollapsible;

  @override
  State<_SectionCard> createState() => _SectionCardState();
}

class _SectionCardState extends State<_SectionCard>
    with SingleTickerProviderStateMixin {
  late bool _expanded;
  late AnimationController _controller;
  late Animation<double> _rotation;

  @override
  void initState() {
    super.initState();
    _expanded = !widget.isCollapsible;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: _expanded ? 1.0 : 0.0,
    );
    _rotation = Tween<double>(
      begin: 0.0,
      end: 0.5,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    if (!widget.isCollapsible) return;
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.isCollapsible ? _toggle : null,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: WorkOrderSectionHeader(
                          number: widget.number,
                          title: widget.title,
                          subtitle: widget.subtitle,
                          vin: widget.vin,
                        ),
                      ),
                      if (widget.isCollapsible) ...[
                        const SizedBox(width: 8),
                        RotationTransition(
                          turns: _rotation,
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: AppColors.textSecondary,
                            size: 22,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: _expanded
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: AppColors.border,
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: widget.child,
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({
    required this.label,
    required this.value,
    this.multiline = false,
  });

  final String label;
  final String value;
  final bool multiline;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
        ],
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceTertiary,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            value,
            maxLines: multiline ? null : 1,
            overflow: multiline ? null : TextOverflow.ellipsis,
            style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Source events (read-only) — mirrors the web's "Source Events for This
// Vehicle" table (Defect/Category/Type/Reference/Reported Date/Status/
// Severity/Images), just as cards instead of a table since this is view-only.
// ---------------------------------------------------------------------------

String _formatSourceEventLabel(String source) {
  switch (source.toUpperCase()) {
    case 'FAULT_CODE':
      return 'Fault Code';
    case 'DVIR':
      return 'DVIR';
    case 'GENERAL':
      return 'General';
    case 'MANUAL':
      return 'Manual';
    default:
      return source;
  }
}

String _formatSourceEventType(MaintenanceIssueSummary issue) {
  if (issue.issueSource.toUpperCase() == 'FAULT_CODE') return 'Telematics';
  return _formatSourceEventLabel(issue.issueSource);
}

String _formatSourceEventReportedDate(String? value) {
  if (value == null || value.isEmpty) return '—';
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  return DateFormat('MM-dd-yyyy hh:mm a').format(parsed.toLocal());
}

class _EventsReadOnly extends StatefulWidget {
  const _EventsReadOnly({
    required this.events,
    required this.filter,
    required this.onFilterChanged,
    required this.uploads,
    required this.uploadsLoading,
    this.vin,
    this.unitNumber,
  });

  final List<MaintenanceIssueSummary> events;
  final String filter;
  final ValueChanged<String> onFilterChanged;
  final Map<int, List<MaintenanceIssueUpload>> uploads;
  final bool uploadsLoading;
  final String? vin;
  final String? unitNumber;

  @override
  State<_EventsReadOnly> createState() => _EventsReadOnlyState();
}

class _EventsReadOnlyState extends State<_EventsReadOnly> {
  bool _isDvir(MaintenanceIssueSummary e) =>
      e.issueSource.toUpperCase().contains('DVIR');

  bool _isFaultCode(MaintenanceIssueSummary e) =>
      e.issueSource.toUpperCase().contains('FAULT');

  List<MaintenanceIssueSummary> get _filtered {
    switch (widget.filter) {
      case 'DVIR':
      case 'DEFECT_TYPES':
        return widget.events.where(_isDvir).toList();
      case 'FAULT':
        return widget.events.where(_isFaultCode).toList();
      default:
        return widget.events;
    }
  }

  int _count(String key) {
    switch (key) {
      case 'DVIR':
      case 'DEFECT_TYPES':
        return widget.events.where(_isDvir).length;
      case 'FAULT':
        return widget.events.where(_isFaultCode).length;
      default:
        return widget.events.length;
    }
  }

  void _selectFilter(String f) => widget.onFilterChanged(f);

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _FilterPill(
              label: 'All Events (${_count('ALL')})',
              selected: widget.filter == 'ALL',
              onTap: () => _selectFilter('ALL'),
            ),
            _FilterPill(
              label: 'DVIR Defects (${_count('DVIR')})',
              selected: widget.filter == 'DVIR',
              onTap: () => _selectFilter('DVIR'),
            ),
            _FilterPill(
              label: 'Fault Codes (${_count('FAULT')})',
              selected: widget.filter == 'FAULT',
              onTap: () => _selectFilter('FAULT'),
            ),
            _FilterPill(
              label: 'Defect Types (${_count('DEFECT_TYPES')})',
              selected: widget.filter == 'DEFECT_TYPES',
              onTap: () => _selectFilter('DEFECT_TYPES'),
            ),
          ],
        ),
        if (widget.events.isNotEmpty) ...[
          const SizedBox(height: 8),
          SourceEventsDetailsLink(
            events: filtered,
            vin: widget.vin,
            unitNumber: widget.unitNumber,
          ),
        ],
        const SizedBox(height: 10),
        if (filtered.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surfaceTertiary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'No issues found for this vehicle.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          )
        else
          for (final e in filtered)
            _SourceEventCard(
              issue: e,
              uploads: widget.uploads[e.id] ?? const [],
              uploadsLoading: widget.uploadsLoading,
            ),
      ],
    );
  }
}

class _SourceEventCard extends StatelessWidget {
  const _SourceEventCard({
    required this.issue,
    required this.uploads,
    required this.uploadsLoading,
  });

  final MaintenanceIssueSummary issue;
  final List<MaintenanceIssueUpload> uploads;
  final bool uploadsLoading;

  void _openImagePreview(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SourceEventImagePreviewSheet(
        uploads: uploads,
        loading: uploadsLoading,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final defectText = issue.defect?.trim().isNotEmpty == true
        ? issue.defect!.trim()
        : (issue.issueName ?? issue.issueDescription ?? 'Issue #${issue.id}');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceTertiary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  defectText,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                tooltip: 'Preview images',
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.image_outlined,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                onPressed: () => _openImagePreview(context),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if ((issue.category ?? '').isNotEmpty)
                _SourceEventChip(label: 'Category', value: issue.category!),
              _SourceEventChip(label: 'Type', value: _formatSourceEventType(issue)),
              if ((issue.status ?? '').isNotEmpty)
                _SourceEventStatusBadge(status: issue.status!),
              if ((issue.severity ?? '').isNotEmpty)
                _SourceEventSeverityBadge(severity: issue.severity!),
            ],
          ),
          if ((issue.externalReference ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Reference: ${issue.externalReference}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            'Reported: ${_formatSourceEventReportedDate(issue.reportedDate)}',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _SourceEventChip extends StatelessWidget {
  const _SourceEventChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.border.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _SourceEventStatusBadge extends StatelessWidget {
  const _SourceEventStatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    Color bg;
    Color fg;
    if (normalized.contains('progress')) {
      bg = const Color(0xFFDBEAFE);
      fg = const Color(0xFF1D4ED8);
    } else if (normalized.contains('complete') || normalized.contains('resolved')) {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF15803D);
    } else if (normalized.contains('not started') || normalized.contains('open')) {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFF92400E);
    } else {
      bg = const Color(0xFFF1F5F9);
      fg = const Color(0xFF475569);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        status,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

class _SourceEventSeverityBadge extends StatelessWidget {
  const _SourceEventSeverityBadge({required this.severity});

  final String severity;

  @override
  Widget build(BuildContext context) {
    final normalized = severity.toUpperCase();
    Color bg;
    Color fg;
    if (normalized.contains('HIGH')) {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFB91C1C);
    } else if (normalized.contains('MEDIUM')) {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFF92400E);
    } else {
      bg = const Color(0xFFF1F5F9);
      fg = const Color(0xFF475569);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        severity,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

class _SourceEventImagePreviewSheet extends StatefulWidget {
  const _SourceEventImagePreviewSheet({required this.uploads, required this.loading});

  final List<MaintenanceIssueUpload> uploads;
  final bool loading;

  @override
  State<_SourceEventImagePreviewSheet> createState() =>
      _SourceEventImagePreviewSheetState();
}

class _SourceEventImagePreviewSheetState
    extends State<_SourceEventImagePreviewSheet> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final images = widget.uploads
        .where((u) => u.isImage && (u.signedUrl ?? '').isNotEmpty)
        .toList();
    final selected =
        images.isNotEmpty ? images[_selectedIndex.clamp(0, images.length - 1)] : null;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Image preview',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: AppColors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Container(
              height: 260,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border, style: BorderStyle.solid),
              ),
              child: widget.loading
                  ? const CircularProgressIndicator()
                  : selected == null
                      ? Text(
                          'No image found',
                          style: TextStyle(color: AppColors.textSecondary),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            selected.signedUrl!,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => Text(
                              'No image found',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                        ),
            ),
            if (images.length > 1) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 64,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: images.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final isSelected = i == _selectedIndex;
                    return InkWell(
                      onTap: () => setState(() => _selectedIndex = i),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? AppColors.primary : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(images[i].signedUrl!, fit: BoxFit.cover),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1A1A1A) : AppColors.surfaceTertiary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Repair line (read-only)
// ---------------------------------------------------------------------------

class _RepairLineReadOnly extends StatelessWidget {
  const _RepairLineReadOnly({
    required this.line,
    required this.technicianName,
    required this.hours,
  });

  final WorkOrderPartLine line;
  final String technicianName;
  final String hours;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceTertiary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  line.description?.isNotEmpty == true
                      ? line.description!
                      : (line.partCode ?? line.partName ?? 'Repair'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: line.repairStatus.backgroundColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  line.repairStatus.label,
                  style: TextStyle(
                    color: line.repairStatus.textColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _KeyValue('Repaired By', line.repairPerformedBy.label),
              _KeyValue('Assign To', technicianName),
              _KeyValue('Part Type', line.partCode ?? line.partName ?? '—'),
              _KeyValue('Hours', hours),
            ],
          ),
          if (line.repairNotes?.isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Text(
              line.repairNotes!,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _KeyValue extends StatelessWidget {
  const _KeyValue(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
        children: [
          TextSpan(text: '$label: '),
          TextSpan(
            text: value,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PM inspection summary (read-only)
// ---------------------------------------------------------------------------

class _PmSummaryReadOnly extends StatelessWidget {
  const _PmSummaryReadOnly({required this.order});

  final WorkOrderModel order;

  @override
  Widget build(BuildContext context) {
    if (order.pmInspectionResults.isEmpty &&
        order.pmTireMeasurements.isEmpty &&
        order.pmDefects.isEmpty) {
      return Text(
        'No PM inspection data recorded',
        style: TextStyle(color: AppColors.textSecondary),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (order.pmInspectionResults.isNotEmpty) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: order.pmInspectionResults
                .map(
                  (r) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceTertiary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${r.itemName ?? 'Item #${r.itemId}'}: ${r.code.label}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 10),
        ],
        if (order.pmDefects.isNotEmpty) ...[
          Text(
            'Defects',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          for (final d in order.pmDefects)
            Text(
              '• ${d.defectDescription ?? '—'} (qty: ${d.quantity ?? '—'}) — ${d.actionTaken ?? '—'}',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
        ],
      ],
    );
  }
}
