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
  bool _wasModified = false;

  List<TechnicianSummary> _technicians = [];
  List<MaintenanceIssueSummary> _events = [];
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
      _wasModified = true;
      await _load();
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(_wasModified);
      },
      child: GradientPageBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(_wasModified),
            ),
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
                          onPressed: () => Navigator.pop(context, _wasModified),
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
// Source events (read-only) — same DVIR/Fault Code filter chips as the web,
// no selection/linking since this is view-only.
// ---------------------------------------------------------------------------

class _EventsReadOnly extends StatelessWidget {
  const _EventsReadOnly({
    required this.events,
    required this.filter,
    required this.onFilterChanged,
  });

  final List<MaintenanceIssueSummary> events;
  final String filter;
  final ValueChanged<String> onFilterChanged;

  List<MaintenanceIssueSummary> get _filtered {
    if (filter == 'ALL') return events;
    return events
        .where((e) => e.issueSource.toUpperCase().contains(filter))
        .toList();
  }

  int _count(String key) {
    if (key == 'ALL') return events.length;
    return events
        .where((e) => e.issueSource.toUpperCase().contains(key))
        .length;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _FilterPill(
              label: 'All Events (${_count('ALL')})',
              selected: filter == 'ALL',
              onTap: () => onFilterChanged('ALL'),
            ),
            const SizedBox(width: 8),
            _FilterPill(
              label: 'DVIR Defects (${_count('DVIR')})',
              selected: filter == 'DVIR',
              onTap: () => onFilterChanged('DVIR'),
            ),
            const SizedBox(width: 8),
            _FilterPill(
              label: 'Fault Codes (${_count('FAULT')})',
              selected: filter == 'FAULT',
              onTap: () => onFilterChanged('FAULT'),
            ),
          ],
        ),
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
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceTertiary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.issueName ?? e.issueDescription ?? 'Issue #${e.id}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          e.issueSource,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (e.severity != null)
                    Text(
                      e.severity!,
                      style: TextStyle(fontSize: 11, color: AppColors.danger),
                    ),
                ],
              ),
            ),
      ],
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
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF1A1A1A)
                : AppColors.surfaceTertiary,
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
