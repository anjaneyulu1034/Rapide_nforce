import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/core/utils/api_feedback.dart';
import 'package:rapide_nforce/core/utils/app_toast.dart';
import 'package:rapide_nforce/ui/work_orders/widgets/work_order_section_header.dart';
import 'package:rapide_nforce/ui/work_orders/widgets/pm_inspection_widgets.dart';
import 'package:rapide_nforce/ui/work_orders/work_order_upload_attachment_sheet.dart';
import 'package:rapide_nforce/ui/widgets/gradient_page_background.dart';
import 'package:rapide_nforce/models/work_order_model.dart';
import 'package:rapide_nforce/services/maintenance_service.dart';

class WorkOrderFormScreen extends StatefulWidget {
  const WorkOrderFormScreen({super.key, this.existing});

  final WorkOrderModel? existing;

  bool get isEdit => existing != null;

  @override
  State<WorkOrderFormScreen> createState() => _WorkOrderFormScreenState();
}

class _WorkOrderFormScreenState extends State<WorkOrderFormScreen> {
  final _formKey = GlobalKey<FormState>();

  bool _loadingMeta = true;
  bool _submitting = false;
  bool _fetchingOdometer = false;

  List<EntityTypeModel> _entityTypes = [];
  List<EntityModel> _entities = [];
  List<TechnicianSummary> _technicians = [];
  List<PartTypeSummary> _partTypes = [];
  List<PartSummary> _parts = [];

  int? _entityTypeId;
  int? _selectedEntityId;
  int? _assigneeId;
  WorkOrderStatus _status = WorkOrderStatus.notStarted;
  WorkOrderPriority _priority = WorkOrderPriority.medium;
  bool _isPm = false;

  final _issueController = TextEditingController();
  final _locationController = TextEditingController();
  final _odometerController = TextEditingController();
  final _endOdometerController = TextEditingController();
  final _costController = TextEditingController();
  final _hoursController = TextEditingController();
  final _notesController = TextEditingController();
  final _resolutionController = TextEditingController();

  DateTime? _startDate;
  DateTime? _dueDate;
  DateTime? _endDate;

  final List<_PartLineForm> _partLines = [];

  bool _pmLoading = false;
  List<PmInspectionCategory> _pmCategories = [];
  List<PmInspectionResultModel> _pmResults = [];
  List<PmTireMeasurementModel> _tireMeasurements = [];
  List<PmDefectModel> _defects = [];

  bool _eventsLoading = false;
  List<MaintenanceIssueSummary> _events = [];
  final Set<int> _linkedEventIds = {};

  EntityModel? get _selectedEntity {
    if (_selectedEntityId == null) return null;
    try {
      return _entities.firstWhere((e) => e.id == _selectedEntityId);
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _startDate = DateTime.now();
    _dueDate = DateTime.now().add(const Duration(days: 7));
    _prefillFromExisting();
    _loadMeta();
  }

  void _prefillFromExisting() {
    final order = widget.existing;
    if (order == null) return;

    _entityTypeId = order.entityTypeId;
    _status = order.status;
    _isPm = order.isPreventativeMaintenance;
    _issueController.text = order.issueDescription;
    _locationController.text = order.workOrderDetails?.location ?? '';
    _odometerController.text =
        order.workOrderDetails?.startOdometer ??
        order.workOrderDetails?.odometer ??
        '';
    _costController.text =
        order.workOrderDetails?.estimatedCost?.toString() ?? '';
    _hoursController.text = order.workOrderDetails?.hours ?? '';
    _assigneeId = order.workOrderDetails?.assignee;
    _priority = order.priority ?? WorkOrderPriority.medium;

    _startDate = DateTime.tryParse(order.workOrderDetails?.startDate ?? '');
    _dueDate = DateTime.tryParse(order.workOrderDetails?.dueDate ?? '');
    _endDate = DateTime.tryParse(order.workOrderDetails?.endDate ?? '');

    _resolutionController.text = order.resolutionNotes ?? '';

    for (final part in order.workOrderParts) {
      _partLines.add(
        _PartLineForm(
          id: part.id,
          partTypeId: part.partTypeId,
          partId: part.partId,
          quantity: part.quantityUsed?.toString() ?? '1',
          description: part.description ?? '',
          vendorName: part.vendorName ?? '',
          repairNotes: part.repairNotes ?? '',
          repairStatus: part.repairStatus,
          repairPerformedBy: part.repairPerformedBy,
          assignedTechnicianId: part.assignedTechnicianId,
        ),
      );
    }

    if (order.isPreventativeMaintenance) {
      _loadPmChecklist(order.entityTypeId ?? 1, existingOrder: order);
    }
  }

  @override
  void dispose() {
    _issueController.dispose();
    _locationController.dispose();
    _odometerController.dispose();
    _endOdometerController.dispose();
    _costController.dispose();
    _hoursController.dispose();
    _notesController.dispose();
    _resolutionController.dispose();
    for (final line in _partLines) {
      line.dispose();
    }
    super.dispose();
  }

  Future<void> _loadMeta() async {
    final typesRes = await MaintenanceService.instance.getEntityTypes();
    final techRes = await MaintenanceService.instance.getTechnicians();
    final partsRes = await MaintenanceService.instance.getPartsSummary();

    if (!mounted) return;

    if (!typesRes.isSuccess) {
      setState(() => _loadingMeta = false);
      ApiFeedback.showError(typesRes, fallback: 'Failed to load form data');
      return;
    }
    if (!techRes.isSuccess) {
      setState(() => _loadingMeta = false);
      ApiFeedback.showError(techRes, fallback: 'Failed to load technicians');
      return;
    }
    if (!partsRes.isSuccess) {
      setState(() => _loadingMeta = false);
      ApiFeedback.showError(partsRes, fallback: 'Failed to load parts');
      return;
    }

    setState(() {
      _entityTypes = typesRes.data ?? [];
      _technicians = techRes.data ?? [];
      final partsData = partsRes.data;
      _partTypes = partsData?.types ?? [];
      _parts = partsData?.parts ?? [];
      _loadingMeta = false;

      if (_entityTypeId == null && _entityTypes.isNotEmpty) {
        _entityTypeId = _entityTypes.first.id;
      }

      if (_assigneeId != null &&
          !_technicians.any(
            (t) => (t.userId != 0 ? t.userId : t.id) == _assigneeId,
          )) {
        _assigneeId = null;
      }
    });

    if (_entityTypeId != null) {
      await _loadEntities(_entityTypeId!);
    }

    final existing = widget.existing;
    if (existing != null && mounted) {
      final match = _entities.where((e) => e.name == existing.unitNumber);
      if (match.isNotEmpty) {
        setState(() => _selectedEntityId = match.first.id);
      }
    }
  }

  Future<void> _loadEntities(int typeId) async {
    final result = await MaintenanceService.instance.getEntities(typeId);
    if (!mounted) return;
    if (!result.isSuccess) {
      ApiFeedback.showError(result, fallback: 'Failed to load units');
      return;
    }
    setState(() {
      _entities = result.data ?? [];
      if (_selectedEntityId != null &&
          !_entities.any((e) => e.id == _selectedEntityId)) {
        _selectedEntityId = null;
      }
    });
  }

  Future<void> _loadPmChecklist(int entityTypeId, {WorkOrderModel? existingOrder}) async {
    setState(() => _pmLoading = true);
    final result =
        await MaintenanceService.instance.getPMInspectionItems(entityTypeId: entityTypeId);
    if (!mounted) return;
    setState(() {
      _pmLoading = false;
      if (result.isSuccess) {
        _pmCategories = result.data ?? [];
        _pmResults = mergePmResults(
          categories: _pmCategories,
          existing: existingOrder?.pmInspectionResults ?? const [],
        );
      }
      final existingTires = existingOrder?.pmTireMeasurements ?? const [];
      _tireMeasurements = existingTires.isNotEmpty
          ? List.of(existingTires)
          : defaultTirePositions(isTrailer: entityTypeId == 2);
      _defects = List.of(existingOrder?.pmDefects ?? const []);
    });
  }

  Future<void> _loadEvents() async {
    final unit = _selectedEntity;
    if (unit == null) return;
    setState(() => _eventsLoading = true);
    final result = await MaintenanceService.instance.getMaintenanceIssues(
      unitNumber: unit.name,
      vin: unit.vinNumber,
    );
    if (!mounted) return;
    setState(() {
      _eventsLoading = false;
      _events = result.data ?? [];
    });
  }

  Future<void> _linkEvent(MaintenanceIssueSummary issue) async {
    final description = issue.issueDescription ?? issue.issueName ?? '';
    if (description.isEmpty) return;

    setState(() => _linkedEventIds.add(issue.id));

    final current = _issueController.text.trim();
    if (current.isEmpty) {
      _issueController.text = description;
      return;
    }

    final append = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('Issue description already has text',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Append this event\'s description, or replace the existing text?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Replace'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Append'),
          ),
        ],
      ),
    );

    if (append == true) {
      _issueController.text = '$current\n$description';
    } else {
      _issueController.text = description;
    }
  }

  Future<void> _uploadAttachment() async {
    final existing = widget.existing;
    if (existing == null) return;
    await showWorkOrderUploadAttachmentSheet(
      context: context,
      workOrderId: existing.id,
    );
  }

  Future<void> _fetchOdometer() async {
    final unit = _selectedEntity;
    if (unit == null) return;

    setState(() => _fetchingOdometer = true);
    final result = await MaintenanceService.instance.fetchSamsaraOdometer(
      unitNumber: unit.name,
      entityTypeId: _entityTypeId,
      vin: unit.vinNumber,
    );
    if (!mounted) return;

    setState(() => _fetchingOdometer = false);

    if (result.isSuccess && result.data != null) {
      _odometerController.text = result.data!;
    } else if (mounted) {
      ApiFeedback.showError(result, fallback: 'Failed to load odometer');
    }
  }

  Future<void> _pickDate({
    required DateTime? initial,
    required ValueChanged<DateTime?> onPicked,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) onPicked(picked);
  }

  WorkOrderFormPayload _buildPayload() {
    return WorkOrderFormPayload(
      unitNumber: _selectedEntity!.name,
      issueDescription: _issueController.text.trim(),
      status: _status.code,
      isPreventativeMaintenance: _isPm,
      entityTypeId: _entityTypeId!,
      priority: _priority.code,
      assignee: _assigneeId!,
      estimatedCost: double.tryParse(_costController.text.trim()) ?? 0,
      startDate: _startDate,
      dueDate: _dueDate,
      endDate: _endDate,
      vin: _selectedEntity?.vinNumber,
      location: _locationController.text.trim(),
      startOdometer: _odometerController.text.trim(),
      endOdometer: _endOdometerController.text.trim().isEmpty
          ? null
          : _endOdometerController.text.trim(),
      hours: _hoursController.text.trim(),
      notes: _notesController.text.trim(),
      resolutionNotes: _resolutionController.text.trim().isEmpty
          ? null
          : _resolutionController.text.trim(),
      parts: _partLines
          .where((l) => l.partId != null)
          .map(
            (l) => WorkOrderPartPayload(
              id: l.id,
              usedPart: l.partId,
              usageDescription: l.descriptionController.text.trim(),
              quantity: num.tryParse(l.quantityController.text.trim()) ?? 1,
              partTypeId: l.partTypeId,
              repairStatus: l.repairStatus,
              repairPerformedBy: l.repairPerformedBy,
              assignedTechnicianId: l.assignedTechnicianId,
              vendorName: l.vendorNameController.text.trim().isEmpty
                  ? null
                  : l.vendorNameController.text.trim(),
              repairNotes: l.repairNotesController.text.trim().isEmpty
                  ? null
                  : l.repairNotesController.text.trim(),
            ),
          )
          .toList(),
      pmInspectionResults: _isPm ? _pmResults : const [],
      pmTireMeasurements: _isPm ? _tireMeasurements : const [],
      pmDefects: _isPm ? _defects : const [],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_entityTypeId == null ||
        _selectedEntity == null ||
        _assigneeId == null) {
      AppToast.showError('Complete all required fields');
      return;
    }

    setState(() => _submitting = true);
    final payload = _buildPayload();

    final result = widget.isEdit
        ? await MaintenanceService.instance.updateWorkOrder(
            widget.existing!.id,
            payload,
          )
        : await MaintenanceService.instance.createWorkOrder(payload);

    if (!mounted) return;
    setState(() => _submitting = false);

    if (!result.isSuccess) {
      ApiFeedback.showError(result, fallback: 'Save failed');
      return;
    }

    AppToast.showSuccess(
      widget.isEdit ? 'Work order updated' : 'Work order created',
    );
    Navigator.of(context).pop(true);
  }

  void _addPartLine() {
    setState(() => _partLines.add(_PartLineForm()));
  }

  @override
  Widget build(BuildContext context) {
    return GradientPageBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(widget.isEdit ? 'Edit Work Order' : 'Create Work Order'),
        ),
        body: _loadingMeta
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    _SectionCard(
                      number: 1,
                      title: 'Work Order Source',
                      subtitle:
                          'Select a unit to load source events for that vehicle.',
                      children: [
                        _DropdownField<int>(
                          label: 'Unit Type *',
                          value: _entityTypeId,
                          items: _entityTypes
                              .map(
                                (t) => DropdownMenuItem(
                                  value: t.id,
                                  child: Text(t.name),
                                ),
                              )
                              .toList(),
                          onChanged: (v) async {
                            setState(() {
                              _entityTypeId = v;
                              _selectedEntityId = null;
                            });
                            if (v != null) await _loadEntities(v);
                          },
                          validator: (v) => v == null ? 'Required' : null,
                        ),
                        _DropdownField<int>(
                          label: 'Unit Number *',
                          value: _selectedEntityId,
                          items: _entities
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e.id,
                                  child: Text(e.name),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            setState(() => _selectedEntityId = v);
                            if (v != null) _loadEvents();
                          },
                          validator: (v) => v == null ? 'Required' : null,
                        ),
                        if (_selectedEntityId != null) ...[
                          const SizedBox(height: 8),
                          _EventsSection(
                            loading: _eventsLoading,
                            events: _events,
                            linkedIds: _linkedEventIds,
                            onTap: _linkEvent,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 14),
                    _SectionCard(
                      number: 2,
                      title: 'Work Order Details',
                      children: [
                        _DropdownField<WorkOrderStatus>(
                          label: 'Status *',
                          value: _status,
                          items:
                              (widget.isEdit
                                      ? WorkOrderStatus.values
                                      : [
                                          WorkOrderStatus.notStarted,
                                          WorkOrderStatus.inProgress,
                                        ])
                                  .map(
                                    (s) => DropdownMenuItem(
                                      value: s,
                                      child: Text(s.label),
                                    ),
                                  )
                                  .toList(),
                          onChanged: widget.isEdit
                              ? (v) => setState(() => _status = v!)
                              : (v) {
                                  if (v != null) setState(() => _status = v);
                                },
                        ),
                        _DropdownField<WorkOrderPriority>(
                          label: 'Priority *',
                          value: _priority,
                          items: WorkOrderPriority.values
                              .map(
                                (p) => DropdownMenuItem(
                                    value: p, child: Text(p.label)),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _priority = v ?? _priority),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment(
                                  value: false, label: Text('Repair')),
                              ButtonSegment(value: true, label: Text('PM')),
                            ],
                            selected: {_isPm},
                            onSelectionChanged: (s) {
                              setState(() => _isPm = s.first);
                              if (_isPm && _pmCategories.isEmpty) {
                                _loadPmChecklist(_entityTypeId ?? 1);
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: 10),
                        _DateField(
                          label: 'Start Date *',
                          value: _startDate,
                          onTap: () => _pickDate(
                            initial: _startDate,
                            onPicked: (d) => setState(() => _startDate = d),
                          ),
                        ),
                        _DateField(
                          label: 'Due Date *',
                          value: _dueDate,
                          onTap: () => _pickDate(
                            initial: _dueDate,
                            onPicked: (d) => setState(() => _dueDate = d),
                          ),
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _odometerController,
                                decoration: const InputDecoration(
                                  labelText: 'Start Odometer',
                                  suffixText: 'km',
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filledTonal(
                              onPressed:
                                  _fetchingOdometer ? null : _fetchOdometer,
                              icon: _fetchingOdometer
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.gps_fixed_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _endOdometerController,
                          decoration: const InputDecoration(
                            labelText: 'End Odometer',
                            suffixText: 'km',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _hoursController,
                          decoration:
                              const InputDecoration(labelText: 'Total Hours'),
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _SectionCard(
                      number: 3,
                      title: 'Issue Description',
                      children: [
                        TextFormField(
                          controller: _issueController,
                          decoration: const InputDecoration(
                            hintText: 'Describe the issue...',
                          ),
                          maxLines: 4,
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Required'
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _SectionCard(
                      number: 4,
                      title: 'Notes',
                      children: [
                        TextFormField(
                          controller: _notesController,
                          decoration: const InputDecoration(
                            hintText: 'Enter any additional notes...',
                          ),
                          maxLines: 3,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _SectionCard(
                      number: 5,
                      title: 'Repairs',
                      trailing: IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF1A1A1A),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _addPartLine,
                        icon: const Icon(Icons.add),
                      ),
                      children: [
                        _DropdownField<int>(
                          label: 'Assign To *',
                          value: _assigneeId,
                          items: _technicians
                              .map(
                                (t) => DropdownMenuItem(
                                  value: t.userId != 0 ? t.userId : t.id,
                                  child: Text(t.name),
                                ),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _assigneeId = v),
                          validator: (v) => v == null ? 'Required' : null,
                        ),
                        if (_partLines.isEmpty)
                          Text(
                            'No repair lines yet — tap + to add one',
                            style:
                                TextStyle(color: AppColors.textSecondary),
                          )
                        else
                          ..._partLines.map(_buildPartLine),
                      ],
                    ),
                    if (_isPm) ...[
                      const SizedBox(height: 14),
                      _SectionCard(
                        number: 6,
                        title: 'PM Inspection',
                        children: [
                          if (_pmLoading)
                            const Center(child: CircularProgressIndicator())
                          else if (_pmCategories.isEmpty)
                            Text(
                              'No PM checklist available for this unit type',
                              style:
                                  TextStyle(color: AppColors.textSecondary),
                            )
                          else ...[
                            PmInspectionSection(
                              categories: _pmCategories,
                              results: _pmResults,
                              isTrailer: (_entityTypeId ?? 1) == 2,
                              onChanged: () => setState(() {}),
                            ),
                            const SizedBox(height: 12),
                            Text('Tire & Brake Measurements',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary)),
                            const SizedBox(height: 8),
                            TireBrakeGrid(
                              measurements: _tireMeasurements,
                              onChanged: () => setState(() {}),
                            ),
                            const SizedBox(height: 16),
                            Text('Defects',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary)),
                            const SizedBox(height: 8),
                            PmDefectsTable(
                              defects: _defects,
                              onAdd: () => setState(
                                () => _defects.add(
                                    PmDefectModel(rowNo: _defects.length + 1)),
                              ),
                              onRemove: (i) =>
                                  setState(() => _defects.removeAt(i)),
                              onChanged: () => setState(() {}),
                            ),
                          ],
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),
                    _SectionCard(
                      number: 7,
                      title: 'Attachments',
                      children: [
                        if (widget.isEdit) ...[
                          if (widget.existing!.attachments.isEmpty)
                            Text(
                              'No attachments yet',
                              style:
                                  TextStyle(color: AppColors.textSecondary),
                            )
                          else
                            for (final a in widget.existing!.attachments)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  children: [
                                    Icon(Icons.insert_drive_file_outlined,
                                        size: 18,
                                        color: AppColors.textSecondary),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(a.displayName,
                                          overflow: TextOverflow.ellipsis,
                                          style:
                                              const TextStyle(fontSize: 13)),
                                    ),
                                  ],
                                ),
                              ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _uploadAttachment,
                            icon: const Icon(Icons.upload_rounded),
                            label: const Text('Upload attachment'),
                          ),
                        ] else
                          Text(
                            'Save the work order first, then attach files from its detail screen.',
                            style:
                                TextStyle(color: AppColors.textSecondary),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _SectionCard(
                      number: 8,
                      title: 'Estimated Cost',
                      children: [
                        TextFormField(
                          controller: _costController,
                          decoration: const InputDecoration(
                            labelText: 'Estimated Cost *',
                            prefixText: '\$ ',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Required'
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _SectionCard(
                      number: 9,
                      title: 'Resolution (Completed Work Orders)',
                      children: [
                        TextFormField(
                          controller: _resolutionController,
                          enabled: _status == WorkOrderStatus.completed,
                          decoration: InputDecoration(
                            hintText: _status == WorkOrderStatus.completed
                                ? 'Enter resolution notes...'
                                : 'Available when work order is completed',
                          ),
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
        bottomNavigationBar: _loadingMeta
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
                          onPressed: _submitting
                              ? null
                              : () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          onPressed: _submitting ? null : _submit,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            backgroundColor: const Color(0xFF1A1A1A),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: _submitting
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  widget.isEdit
                                      ? 'Save changes'
                                      : 'Create Work Order',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700),
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

  Widget _buildPartLine(_PartLineForm line) {
    final filteredParts = _parts
        .where((p) => line.partTypeId == null || p.typeId == line.partTypeId)
        .toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    decoration: const InputDecoration(labelText: 'Part type'),
                    initialValue: line.partTypeId,
                    items: _partTypes
                        .map(
                          (t) => DropdownMenuItem(
                            value: t.id,
                            child: Text(t.name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() {
                      line.partTypeId = v;
                      line.partId = null;
                    }),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => setState(() {
                    line.dispose();
                    _partLines.remove(line);
                  }),
                ),
              ],
            ),
            DropdownButtonFormField<int>(
              decoration: const InputDecoration(labelText: 'Part'),
              initialValue: line.partId,
              items: filteredParts
                  .map(
                    (p) => DropdownMenuItem(
                      value: p.id,
                      child: Text('${p.code} (${p.quantity ?? 0})'),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => line.partId = v),
            ),
            TextFormField(
              controller: line.hoursController,
              decoration: const InputDecoration(labelText: 'Hours *'),
              keyboardType: TextInputType.number,
            ),
            TextFormField(
              controller: line.quantityController,
              decoration: const InputDecoration(labelText: 'Quantity *'),
              keyboardType: TextInputType.number,
            ),
            TextFormField(
              controller: line.descriptionController,
              decoration: const InputDecoration(
                labelText: 'Repair description',
              ),
            ),
            DropdownButtonFormField<RepairStatus>(
              decoration: const InputDecoration(labelText: 'Repair status'),
              initialValue: line.repairStatus,
              items: RepairStatus.values
                  .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                  .toList(),
              onChanged: (v) =>
                  setState(() => line.repairStatus = v ?? line.repairStatus),
            ),
            DropdownButtonFormField<int>(
              decoration:
                  const InputDecoration(labelText: 'Assigned technician'),
              initialValue: _technicians.any(
                (t) =>
                    (t.userId != 0 ? t.userId : t.id) ==
                    line.assignedTechnicianId,
              )
                  ? line.assignedTechnicianId
                  : null,
              items: _technicians
                  .map(
                    (t) => DropdownMenuItem(
                      value: t.userId != 0 ? t.userId : t.id,
                      child: Text(t.name),
                    ),
                  )
                  .toList(),
              onChanged: (v) =>
                  setState(() => line.assignedTechnicianId = v),
            ),
            DropdownButtonFormField<RepairPerformedBy>(
              decoration: const InputDecoration(labelText: 'Performed by'),
              initialValue: line.repairPerformedBy,
              items: RepairPerformedBy.values
                  .map((p) => DropdownMenuItem(value: p, child: Text(p.label)))
                  .toList(),
              onChanged: (v) => setState(
                  () => line.repairPerformedBy = v ?? line.repairPerformedBy),
            ),
            if (line.repairPerformedBy == RepairPerformedBy.external)
              TextFormField(
                controller: line.vendorNameController,
                decoration: const InputDecoration(labelText: 'Vendor name'),
              ),
            TextFormField(
              controller: line.repairNotesController,
              decoration: const InputDecoration(labelText: 'Repair notes'),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}

class _EventsSection extends StatelessWidget {
  const _EventsSection({
    required this.loading,
    required this.events,
    required this.linkedIds,
    required this.onTap,
  });

  final bool loading;
  final List<MaintenanceIssueSummary> events;
  final Set<int> linkedIds;
  final ValueChanged<MaintenanceIssueSummary> onTap;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (events.isEmpty) {
      return Text(
        'No linked DVIR defects or fault codes for this unit',
        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tap an event to pull its description into Issue Description',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        for (final e in events)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: linkedIds.contains(e.id)
                    ? AppColors.primary
                    : AppColors.border,
                width: linkedIds.contains(e.id) ? 1.6 : 1.0,
              ),
            ),
            child: ListTile(
              dense: true,
              leading: Icon(
                e.issueSource.toUpperCase().contains('FAULT')
                    ? Icons.report_gmailerrorred_outlined
                    : Icons.assignment_late_outlined,
                size: 18,
                color: AppColors.textSecondary,
              ),
              title: Text(
                e.issueName ?? e.issueDescription ?? 'Issue #${e.id}',
                style: const TextStyle(fontSize: 13),
              ),
              subtitle: Text(
                e.issueSource,
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              trailing: linkedIds.contains(e.id)
                  ? Icon(Icons.check_circle, size: 18, color: AppColors.primary)
                  : null,
              onTap: () => onTap(e),
            ),
          ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.number,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.children,
  });

  final int number;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: WorkOrderSectionHeader(
                  number: number,
                  title: title,
                  subtitle: subtitle,
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.validator,
  });

  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? Function(T?)? validator;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DropdownButtonFormField<T>(
        decoration: InputDecoration(labelText: label),
        initialValue: value,
        items: items,
        onChanged: onChanged,
        validator: validator,
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = value != null
        ? DateFormat('MM-dd-yyyy').format(value!)
        : 'Select date';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: const Icon(Icons.calendar_month_outlined),
          ),
          child: Text(text),
        ),
      ),
    );
  }
}

class _PartLineForm {
  _PartLineForm({
    this.id,
    this.partTypeId,
    this.partId,
    String quantity = '0',
    String hours = '0',
    String description = '',
    String vendorName = '',
    String repairNotes = '',
    this.repairStatus = RepairStatus.notStarted,
    this.repairPerformedBy = RepairPerformedBy.internal,
    this.assignedTechnicianId,
  }) : quantityController = TextEditingController(text: quantity),
       hoursController = TextEditingController(text: hours),
       descriptionController = TextEditingController(text: description),
       vendorNameController = TextEditingController(text: vendorName),
       repairNotesController = TextEditingController(text: repairNotes);

  int? id;
  int? partTypeId;
  int? partId;
  RepairStatus repairStatus;
  RepairPerformedBy repairPerformedBy;
  int? assignedTechnicianId;
  final TextEditingController quantityController;
  final TextEditingController hoursController;
  final TextEditingController descriptionController;
  final TextEditingController vendorNameController;
  final TextEditingController repairNotesController;

  void dispose() {
    quantityController.dispose();
    hoursController.dispose();
    descriptionController.dispose();
    vendorNameController.dispose();
    repairNotesController.dispose();
  }
}
