import 'dart:io';

import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/core/utils/api_feedback.dart';
import 'package:rapide_nforce/core/utils/app_toast.dart';
import 'package:rapide_nforce/core/utils/odometer_unit.dart';
import 'package:rapide_nforce/ui/work_orders/widgets/source_events_widgets.dart';
import 'package:rapide_nforce/ui/work_orders/widgets/pm_inspection_widgets.dart';
import 'package:rapide_nforce/ui/work_orders/work_order_upload_attachment_sheet.dart';
import 'package:rapide_nforce/ui/widgets/gradient_page_background.dart';
import 'package:rapide_nforce/ui/widgets/web_form_field.dart';
import 'package:rapide_nforce/models/work_order_model.dart';
import 'package:rapide_nforce/core/utils/role_utils.dart';
import 'package:rapide_nforce/services/auth_service.dart';
import 'package:rapide_nforce/services/inventory_service.dart';
import 'package:rapide_nforce/services/maintenance_service.dart';

class WorkOrderFormScreen extends StatefulWidget {
  const WorkOrderFormScreen({
    super.key,
    this.existing,
    this.initialIssueDescription,
    this.linkedDefects,
  });

  final WorkOrderModel? existing;
  final String? initialIssueDescription;
  // When set, this work order is created via the backend's from-source
  // endpoint instead of the generic create endpoint — each entry becomes a
  // linked repair line (no inventory part attached), and the first entry's
  // vehicle is used to try to auto-select the Unit field. Mirrors the web
  // app's bulk "Create Work Order for Selected" / single defect flows.
  final List<WorkOrderLinkedDefect>? linkedDefects;

  bool get isEdit => existing != null;

  @override
  State<WorkOrderFormScreen> createState() => _WorkOrderFormScreenState();
}

class _WorkOrderFormScreenState extends State<WorkOrderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  final List<GlobalKey> _sectionKeys = List.generate(4, (_) => GlobalKey());
  int _activeNavIndex = 0;

  bool _loadingMeta = true;
  bool _submitting = false;
  bool _fetchingOdometer = false;
  bool _fetchingEndOdometer = false;
  OdometerDisplayUnit _odometerUnit = OdometerDisplayUnit.km;
  int _statusFieldGen = 0;

  List<EntityTypeModel> _entityTypes = [];
  List<EntityModel> _entities = [];
  List<TechnicianSummary> _technicians = [];
  List<PartTypeSummary> _partTypes = [];
  List<PartSummary> _parts = [];

  int? _entityTypeId;
  int? _selectedEntityId;
  int? _assigneeId;
  WorkOrderStatus _status = WorkOrderStatus.notStarted;
  WorkOrderPriority? _priority;
  bool? _isPm;

  final _issueController = TextEditingController();
  final _locationController = TextEditingController();
  final _odometerController = TextEditingController();
  final _endOdometerController = TextEditingController();
  final _costController = TextEditingController();
  // Once the user types into Estimated Cost, stop silently overwriting it
  // from the parts total on every repair-line edit — mirrors web's
  // `isEstimatedCostManual` tracking in WorkOrderViewEditDrawer.tsx.
  bool _isEstimatedCostManual = false;
  bool _settingCostProgrammatically = false;
  final _hoursController = TextEditingController();
  final _totalLabourCostController = TextEditingController();
  final _notesController = TextEditingController();
  final _resolutionController = TextEditingController();

  DateTime? _startDate;
  DateTime? _dueDate;
  DateTime? _endDate;

  final List<_PartLineForm> _partLines = [];
  final List<PlatformFile> _pendingAttachments = [];

  bool _pmLoading = false;
  List<PmInspectionCategory> _pmCategories = [];
  List<PmInspectionResultModel> _pmResults = [];
  List<PmTireMeasurementModel> _tireMeasurements = [];
  List<PmDefectModel> _defects = [];

  bool _eventsLoading = false;
  List<MaintenanceIssueSummary> _events = [];
  final Set<int> _linkedEventIds = {};
  bool _uploadsLoading = false;
  Map<int, List<MaintenanceIssueUpload>> _eventUploads = {};

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
    _dueDate = null;
    _prefillFromExisting();
    if (widget.existing == null &&
        (widget.initialIssueDescription?.trim().isNotEmpty ?? false)) {
      _issueController.text = widget.initialIssueDescription!.trim();
    } else if (widget.existing == null &&
        (widget.linkedDefects?.isNotEmpty ?? false)) {
      _issueController.text = widget.linkedDefects!
          .map((d) => d.description)
          .where((d) => d.trim().isNotEmpty)
          .join('; ');
      for (final d in widget.linkedDefects!) {
        _partLines.add(
          _PartLineForm(
            description: d.description,
          ),
        );
      }
    }
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
    _endOdometerController.text = order.workOrderDetails?.endOdometer ?? '';
    _odometerUnit = OdometerDisplayUnit.fromApiValue(
      order.workOrderDetails?.odometerDisplayUnit,
    );
    _costController.text =
        order.workOrderDetails?.estimatedCost?.toString() ?? '';
    _hoursController.text = order.workOrderDetails?.hours ?? '';
    _totalLabourCostController.text = order.totalLabourCost?.toString() ?? '';
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
    _scrollController.dispose();
    _issueController.dispose();
    _locationController.dispose();
    _odometerController.dispose();
    _endOdometerController.dispose();
    _costController.dispose();
    _hoursController.dispose();
    _totalLabourCostController.dispose();
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
      _entityTypes = (typesRes.data ?? [])
          .where((t) => t.name.trim().toLowerCase() != 'driver')
          .toList();
      _technicians = techRes.data ?? [];
      final partsData = partsRes.data;
      _partTypes = partsData?.types ?? [];
      _parts = partsData?.parts ?? [];
      _loadingMeta = false;

      if (_entityTypeId == null && _entityTypes.isNotEmpty) {
        _entityTypeId = _entityTypes.first.id;
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
    } else if (existing == null &&
        (widget.linkedDefects?.isNotEmpty ?? false) &&
        mounted) {
      final defectId = widget.linkedDefects!.first.defectId;
      final prefillRes = await MaintenanceService.instance
          .getWorkOrderFromSourcePrefill(sourceId: defectId);
      final prefill = prefillRes.isSuccess ? prefillRes.data : null;

      final targetUnitNumber = prefill?.unitNumber?.trim() ??
          widget.linkedDefects!.first.unitNumber?.trim();
      final targetEntityTypeId = prefill?.entityTypeId;

      if (prefill?.priority != null) {
        final p = WorkOrderPriority.fromCode(prefill!.priority);
        if (mounted) setState(() => _priority = p);
      }

      if ((prefill?.issueDescription?.trim().isNotEmpty ?? false) &&
          mounted) {
        _issueController.text = prefill!.issueDescription!.trim();
      }

      if (targetEntityTypeId != null &&
          _entityTypes.any((t) => t.id == targetEntityTypeId)) {
        if (mounted) setState(() => _entityTypeId = targetEntityTypeId);
        await _loadEntities(targetEntityTypeId);
      }

      if (targetUnitNumber != null && targetUnitNumber.isNotEmpty) {
        EntityModel? matchedEntity;
        try {
          matchedEntity = _entities.firstWhere((e) => e.name == targetUnitNumber);
        } catch (_) {}

        if (matchedEntity == null) {
          for (final type in _entityTypes) {
            if (type.id == _entityTypeId) continue;
            final otherRes =
                await MaintenanceService.instance.getEntities(type.id);
            if (otherRes.isSuccess && otherRes.data != null) {
              try {
                final found = otherRes.data!
                    .firstWhere((e) => e.name == targetUnitNumber);
                if (mounted) {
                  setState(() {
                    _entityTypeId = type.id;
                    _entities = otherRes.data!;
                  });
                }
                matchedEntity = found;
                break;
              } catch (_) {}
            }
          }
        }

        if (matchedEntity != null && mounted) {
          setState(() {
            _selectedEntityId = matchedEntity!.id;
          });
          _fetchOdometer();
          _loadEvents();
        }
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
    _loadEventUploads();
  }

  Future<void> _loadEventUploads() async {
    final ids = _events.map((e) => e.id).toList();
    if (ids.isEmpty) {
      setState(() => _eventUploads = {});
      return;
    }
    setState(() => _uploadsLoading = true);
    final result =
        await MaintenanceService.instance.getMaintenanceIssueUploads(ids);
    if (!mounted) return;
    setState(() {
      _uploadsLoading = false;
      _eventUploads = result.data ?? {};
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Issue description already has text',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text(
          'Append this event\'s description, or replace the existing text?',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Replace'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
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

  Future<void> _pickPendingAttachments() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
      allowMultiple: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    setState(() => _pendingAttachments.addAll(picked.files));
  }

  Future<void> _pickPendingAttachmentFromCamera() async {
    try {
      final photo = await ImagePicker().pickImage(source: ImageSource.camera);
      if (photo == null) return;
      final bytes = await photo.readAsBytes();
      setState(() {
        _pendingAttachments.add(PlatformFile(
          path: photo.path,
          name: photo.name,
          size: bytes.length,
          bytes: bytes,
        ));
      });
    } catch (e) {
      AppToast.showError('Failed to capture image: $e');
    }
  }

  Future<void> _scanPendingAttachment() async {
    try {
      final pages = await CunningDocumentScanner.getPictures(
        noOfPages: 1,
        scannerSource: ScannerSource.camera,
      );
      if (pages == null || pages.isEmpty) return;
      final path = pages.first;
      final file = File(path);
      final bytes = await file.readAsBytes();
      setState(() {
        _pendingAttachments.add(PlatformFile(
          path: path,
          name: path.split('/').last,
          size: bytes.length,
          bytes: bytes,
        ));
      });
    } catch (e) {
      AppToast.showError('Failed to scan document: $e');
    }
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
      setState(() => _odometerController.text = result.data!);
    } else if (mounted) {
      ApiFeedback.showError(result, fallback: 'Failed to load odometer');
    }
  }

  Future<void> _fetchEndOdometer() async {
    final unit = _selectedEntity;
    if (unit == null) return;

    setState(() => _fetchingEndOdometer = true);
    final result = await MaintenanceService.instance.fetchSamsaraOdometer(
      unitNumber: unit.name,
      entityTypeId: _entityTypeId,
      vin: unit.vinNumber,
    );
    if (!mounted) return;

    setState(() => _fetchingEndOdometer = false);

    if (result.isSuccess && result.data != null) {
      setState(() => _endOdometerController.text = result.data!);
    } else if (mounted) {
      ApiFeedback.showError(result, fallback: 'Failed to load odometer');
    }
  }

  String? get _odometerRangeError {
    final start = double.tryParse(_odometerController.text.trim());
    final end = double.tryParse(_endOdometerController.text.trim());
    if (start == null || end == null) return null;
    if (end < start) return 'End Odometer cannot be less than Start Odometer';
    return null;
  }

  bool _allRepairsNotStarted() =>
      _partLines.isEmpty ||
      _partLines.every((l) => l.repairStatus == RepairStatus.notStarted);

  bool _allRepairsCompleted() =>
      _partLines.isNotEmpty &&
      _partLines.every((l) => l.repairStatus == RepairStatus.completed);

  /// Mirrors web's `getRepairsCompletionError` part-assignment check for a
  /// Technician/Lead Technician — Flutter has no separate work-order-level
  /// inventory list (only per-repair-line parts), so this checks repair
  /// lines directly, matching web's own fallback path for that case.
  bool _hasAnyRepairPart() => _partLines.any((l) => l.partId != null);

  void _recalculateEstimatedCost() {
    if (_isEstimatedCostManual) return;
    double totalCost = 0;
    for (final line in _partLines) {
      if (line.partId != null) {
        PartSummary? part;
        for (final p in _parts) {
          if (p.id == line.partId) {
            part = p;
            break;
          }
        }
        if (part != null && part.unitCost != null) {
          final qty = double.tryParse(line.quantityController.text.trim()) ?? 0;
          totalCost += part.unitCost! * qty;
        }
      }
    }
    if (totalCost > 0) {
      _settingCostProgrammatically = true;
      _costController.text = totalCost.toStringAsFixed(2);
      _settingCostProgrammatically = false;
    }
  }

  bool get _isCompletedRestrictedEdit =>
      widget.isEdit && _status == WorkOrderStatus.completed;

  bool get _isTrailerUnit => (_entityTypeId ?? 1) == 2;

  bool get _showOdometerFields => !_isTrailerUnit && !(_isPm ?? false);

  void _onStatusChanged(WorkOrderStatus? next) {
    if (next == null) return;

    if (next == WorkOrderStatus.inProgress && _allRepairsNotStarted()) {
      AppToast.showError(
        'Work order cannot be set to In Progress while all repairs are Not Started',
      );
      setState(() => _statusFieldGen++);
      return;
    }
    if (next == WorkOrderStatus.completed) {
      if (isTechnicianOrLeadTechnicianRole(
            AuthService.instance.currentUser?.role,
          ) &&
          !_hasAnyRepairPart()) {
        AppToast.showError(
          'At least one inventory part must be assigned before completing the Work Order.',
        );
        setState(() => _statusFieldGen++);
        return;
      }
      if (!_allRepairsCompleted()) {
        AppToast.showError(
          'All repairs must be completed before closing the work order',
        );
        setState(() => _statusFieldGen++);
        return;
      }
    }

    final wasCompleted = _status == WorkOrderStatus.completed;
    setState(() {
      _status = next;
      _statusFieldGen++;
      if (next == WorkOrderStatus.completed) {
        _endDate = DateTime.now();
      } else if (wasCompleted) {
        _endDate = null;
      }
    });

    if (next == WorkOrderStatus.completed &&
        _showOdometerFields &&
        _endOdometerController.text.trim().isEmpty) {
      _fetchEndOdometer();
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.primary,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) onPicked(picked);
  }

  WorkOrderFormPayload _buildPayload() {
    return WorkOrderFormPayload(
      unitNumber: _selectedEntity!.name,
      issueDescription: _issueController.text.trim(),
      status: _status.code,
      isPreventativeMaintenance: _isPm ?? false,
      entityTypeId: _entityTypeId!,
      priority: (_priority ?? WorkOrderPriority.medium).code,
      assignee: _assigneeId ?? AuthService.instance.currentUser?.id ?? 0,
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
      odometerDisplayUnit: _odometerUnit.apiValue,
      hours: _hoursController.text.trim(),
      totalLabourHours: num.tryParse(_hoursController.text.trim()),
      totalLabourCost: num.tryParse(_totalLabourCostController.text.trim()),
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
      pmInspectionResults: (_isPm ?? false) ? _pmResults : const [],
      pmTireMeasurements: (_isPm ?? false) ? _tireMeasurements : const [],
      pmDefects: (_isPm ?? false) ? _defects : const [],
    );
  }

  void _reduceInventoryForUsedParts() {
    for (final line in _partLines) {
      if (line.partId != null) {
        final usedQty = int.tryParse(line.quantityController.text.trim()) ?? 0;
        if (usedQty > 0) {
          PartSummary? part;
          for (final p in _parts) {
            if (p.id == line.partId) {
              part = p;
              break;
            }
          }
          if (part != null) {
            final currentQty = part.quantity ?? 0;
            final newQty =
                (currentQty - usedQty) < 0 ? 0 : (currentQty - usedQty);
            InventoryService.instance.updatePart(
              id: part.id,
              typeId: part.typeId,
              code: part.code,
              quantity: newQty.toInt(),
            );
          }
        }
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      AppToast.showError('Please check highlighted fields');
      return;
    }
    if (_entityTypeId == null || _selectedEntity == null) {
      AppToast.showError('Complete all required fields (Unit Type & Unit Number)');
      return;
    }
    _assigneeId ??= AuthService.instance.currentUser?.id ?? 0;

    final rangeError = _odometerRangeError;
    if (rangeError != null) {
      AppToast.showError(rangeError);
      return;
    }

    if (_startDate != null && _dueDate != null && _dueDate!.isBefore(_startDate!)) {
      AppToast.showError('Due Date must be on or after Start Date');
      return;
    }

    final deferredLineMissingNotes = _partLines.any(
      (l) =>
          l.repairStatus == RepairStatus.deferred &&
          l.repairNotesController.text.trim().isEmpty,
    );
    if (deferredLineMissingNotes) {
      AppToast.showError('Note is required when repair status is Deferred');
      return;
    }

    setState(() => _submitting = true);
    final payload = _buildPayload();

    if (widget.isEdit) {
      final result = await MaintenanceService.instance.updateWorkOrder(
        widget.existing!.id,
        payload,
      );
      if (!mounted) return;
      setState(() => _submitting = false);
      if (!result.isSuccess) {
        ApiFeedback.showError(result, fallback: 'Save failed');
        return;
      }
      _reduceInventoryForUsedParts();
      AppToast.showSuccess('Work order updated');
      Navigator.of(context).pop(true);
      return;
    }

    final linkedDefects = widget.linkedDefects;
    final result = (linkedDefects != null && linkedDefects.isNotEmpty)
        ? await MaintenanceService.instance.createWorkOrderFromSource(
            sourceId: linkedDefects.first.defectId,
            payload: payload,
            linkedIssueParts: linkedDefects
                .map(
                  (d) => WorkOrderPartPayload(
                    usedPart: null,
                    usageDescription: d.description,
                    repairStatus: RepairStatus.notStarted,
                    linkedIssueId: d.defectId,
                  ),
                )
                .toList(),
          )
        : await MaintenanceService.instance.createWorkOrder(payload);
    if (!mounted) return;
    if (!result.isSuccess) {
      setState(() => _submitting = false);
      ApiFeedback.showError(result, fallback: 'Save failed');
      return;
    }
    _reduceInventoryForUsedParts();

    final newId = result.data ?? 0;
    if (newId > 0 && _pendingAttachments.isNotEmpty) {
      final paths = _pendingAttachments
          .map((f) => f.path)
          .whereType<String>()
          .toList();
      if (paths.isNotEmpty) {
        final uploadResult =
            await MaintenanceService.instance.uploadWorkOrderAttachments(
          workOrderId: newId,
          filePaths: paths,
        );
        if (!uploadResult.isSuccess) {
          AppToast.showError(
            'Work order created, but attachments failed to upload.',
          );
        }
      }
    }

    if (!mounted) return;
    setState(() => _submitting = false);
    AppToast.showSuccess('Work order created');
    Navigator.of(context).pop(true);
  }

  void _addPartLine() {
    setState(() => _partLines.add(_PartLineForm()));
  }

  void _scrollToSection(int index) {
    setState(() => _activeNavIndex = index);
    final context = _sectionKeys[index].currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        alignment: 0.04,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientPageBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
          title: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isEdit ? 'Edit Work Order' : 'Create Work Order',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      widget.isEdit
                          ? 'Update details, repairs & status'
                          : 'Fill in vehicle, issue & repair details',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.isEdit)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    widget.existing?.workOrderNumber ?? '#${widget.existing?.id}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
        ),
        body: _loadingMeta
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // ── Quick-Jump Section Navigation Bar ──
                  Container(
                    height: 46,
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _QuickNavChip(
                          icon: Icons.directions_bus_outlined,
                          label: 'Unit & Source',
                          isSelected: _activeNavIndex == 0,
                          onTap: () => _scrollToSection(0),
                        ),
                        const SizedBox(width: 8),
                        _QuickNavChip(
                          icon: Icons.calendar_month_outlined,
                          label: 'Schedule & Meter',
                          isSelected: _activeNavIndex == 1,
                          onTap: () => _scrollToSection(1),
                        ),
                        const SizedBox(width: 8),
                        _QuickNavChip(
                          icon: Icons.build_circle_outlined,
                          label: 'Details & Repairs',
                          isSelected: _activeNavIndex == 2,
                          onTap: () => _scrollToSection(2),
                        ),
                        const SizedBox(width: 8),
                        _QuickNavChip(
                          icon: Icons.assignment_outlined,
                          label: 'Checklist & Media',
                          isSelected: _activeNavIndex == 3,
                          onTap: () => _scrollToSection(3),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Form(
                      key: _formKey,
                      child: ListView(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        children: [
                          // ── SECTION 1: UNIT & SOURCE ──
                          _ModernSectionCard(
                            key: _sectionKeys[0],
                            icon: Icons.directions_bus_rounded,
                            iconColor: const Color(0xFF2563EB),
                            title: 'Work Order Source',
                            subtitle:
                                'Select a unit to load source events and linked defects.',
                            children: [
                              _StyledDropdownField<int>(
                                label: 'Unit Type *',
                                hint: 'Select Unit Type',
                                value: _entityTypeId,
                                enabled: !widget.isEdit &&
                                    (widget.linkedDefects == null ||
                                        widget.linkedDefects!.isEmpty),
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
                              _StyledDropdownField<int>(
                                label: 'Unit Number *',
                                hint: 'Select Unit Number',
                                value: _selectedEntityId,
                                enabled: !widget.isEdit,
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
                              const SizedBox(height: 4),
                              Text(
                                'Priority *',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              _PriorityPillSelector(
                                priority: _priority,
                                enabled: _entityTypeId != null,
                                onChanged: (p) => setState(() => _priority = p),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'Work Order Type *',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              _WorkOrderTypeSelector(
                                isPm: _isPm ?? false,
                                enabled: !widget.isEdit && _entityTypeId != null,
                                onChanged: (val) {
                                  setState(() => _isPm = val);
                                  if ((_isPm ?? false) && _pmCategories.isEmpty) {
                                    _loadPmChecklist(_entityTypeId ?? 1);
                                  }
                                },
                              ),
                              if (_selectedEntityId != null) ...[
                                const SizedBox(height: 14),
                                _EventsSection(
                                  loading: _eventsLoading,
                                  events: _events,
                                  linkedIds: _linkedEventIds,
                                  uploads: _eventUploads,
                                  uploadsLoading: _uploadsLoading,
                                  onTap: _linkEvent,
                                  vin: _selectedEntity?.vinNumber,
                                  unitNumber: _selectedEntity?.name,
                                ),
                              ],
                            ],
                          ),

                          const SizedBox(height: 16),

                          // ── SECTION 2: SCHEDULE & METERING ──
                          _ModernSectionCard(
                            key: _sectionKeys[1],
                            icon: Icons.schedule_rounded,
                            iconColor: const Color(0xFFD97706),
                            title: 'Schedule & Odometer',
                            subtitle:
                                'Set status, key dates, meter readings and labour cost.',
                            children: [
                              _StyledDropdownField<WorkOrderStatus>(
                                key: ValueKey('status_${_status.code}_$_statusFieldGen'),
                                label: 'Status *',
                                value: _status,
                                items: (widget.isEdit
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
                                onChanged: _onStatusChanged,
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: _ModernDateField(
                                      label: 'Start Date *',
                                      value: _startDate,
                                      onTap: () => _pickDate(
                                        initial: _startDate,
                                        onPicked: (d) => setState(() => _startDate = d),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _ModernDateField(
                                      label: 'Due Date',
                                      value: _dueDate,
                                      onTap: () => _pickDate(
                                        initial: _dueDate,
                                        onPicked: (d) => setState(() => _dueDate = d),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (_status == WorkOrderStatus.completed) ...[
                                _ModernDateField(
                                  label: 'End Date *',
                                  value: _endDate,
                                  enabled: false,
                                  onTap: () {},
                                ),
                              ],
                              if (_showOdometerFields) ...[
                                _OdometerField(
                                  label: 'Start Odometer',
                                  kmController: _odometerController,
                                  unit: _odometerUnit,
                                  onUnitChanged: (u) =>
                                      setState(() => _odometerUnit = u),
                                  onKmChanged: () => setState(() {}),
                                  loading: _fetchingOdometer,
                                  onFetch: _fetchOdometer,
                                ),
                                const SizedBox(height: 8),
                                _OdometerField(
                                  label: 'End Odometer',
                                  kmController: _endOdometerController,
                                  unit: _odometerUnit,
                                  onUnitChanged: (u) =>
                                      setState(() => _odometerUnit = u),
                                  onKmChanged: () => setState(() {}),
                                  enabled: _status == WorkOrderStatus.completed,
                                  disabledHint: 'Available when status is Completed',
                                  loading: _fetchingEndOdometer,
                                  onFetch: _fetchEndOdometer,
                                  errorText: _odometerRangeError,
                                ),
                              ],
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _hoursController,
                                      decoration: InputDecoration(
                                        labelText: 'Total Labour Hours',
                                        prefixIcon: Icon(Icons.access_time_rounded,
                                            size: 18, color: AppColors.textSecondary),
                                        filled: true,
                                        fillColor: AppColors.inputFill,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(color: AppColors.border),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(color: AppColors.border),
                                        ),
                                      ),
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _totalLabourCostController,
                                      decoration: InputDecoration(
                                        labelText: 'Total Labour Cost',
                                        prefixText: '\$ ',
                                        prefixIcon: Icon(Icons.attach_money_rounded,
                                            size: 18, color: AppColors.textSecondary),
                                        filled: true,
                                        fillColor: AppColors.inputFill,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(color: AppColors.border),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(color: AppColors.border),
                                        ),
                                      ),
                                      keyboardType: const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          if (widget.linkedDefects?.isNotEmpty ?? false) ...[
                            const SizedBox(height: 16),
                            WebInfoBanner(
                              title: 'Linked to DVIR defect${widget.linkedDefects!.length == 1 ? '' : 's'}',
                              message: widget.linkedDefects!.length == 1
                                  ? 'This work order will be linked back to the source defect.'
                                  : '${widget.linkedDefects!.length} selected defects will each be added as a repair line on this work order.',
                            ),
                          ],

                          const SizedBox(height: 16),

                          // ── SECTION 3: DETAILS & REPAIRS ──
                          _ModernSectionCard(
                            key: _sectionKeys[2],
                            icon: Icons.build_circle_rounded,
                            iconColor: const Color(0xFF7C3AED),
                            title: 'Details & Repairs',
                            trailing: OutlinedButton.icon(
                              onPressed: _isCompletedRestrictedEdit ? null : _addPartLine,
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Add Repair'),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                              ),
                            ),
                            children: [
                              TextFormField(
                                controller: _issueController,
                                decoration: InputDecoration(
                                  labelText: 'Issue Description *',
                                  hintText: 'Describe the problem or service required...',
                                  alignLabelWithHint: true,
                                  filled: true,
                                  fillColor: AppColors.inputFill,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: AppColors.border),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: AppColors.border),
                                  ),
                                ),
                                maxLines: 3,
                                validator: (v) => v == null || v.trim().isEmpty
                                    ? 'Required'
                                    : null,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _notesController,
                                decoration: InputDecoration(
                                  labelText: 'General Notes',
                                  hintText: 'Enter additional instructions or notes...',
                                  alignLabelWithHint: true,
                                  filled: true,
                                  fillColor: AppColors.inputFill,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: AppColors.border),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: AppColors.border),
                                  ),
                                ),
                                maxLines: 2,
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Text(
                                    'REPAIR LINES',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.8,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${_partLines.length}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              if (_isCompletedRestrictedEdit)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.warning.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppColors.warning.withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.info_outline,
                                          size: 18, color: AppColors.warning),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Work order is completed — only hours and repair notes can be edited.',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (_partLines.isEmpty)
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: AppColors.inputFill.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.border,
                                      style: BorderStyle.solid,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(Icons.build_circle_outlined,
                                          size: 32, color: AppColors.textSecondary),
                                      const SizedBox(height: 6),
                                      Text(
                                        'No repair lines added yet',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textSecondary,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Tap "+ Add Repair" above to add parts & labor tasks.',
                                        style: TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                ..._partLines.asMap().entries.map((entry) =>
                                    _buildPartLineCard(entry.key, entry.value)),
                            ],
                          ),

                          // ── SECTION 4: PM INSPECTION (IF PM SELECTED) ──
                          if (_isPm ?? false) ...[
                            const SizedBox(height: 16),
                            _ModernSectionCard(
                              key: _sectionKeys[3],
                              icon: Icons.checklist_rounded,
                              iconColor: const Color(0xFF059669),
                              title: 'PM Inspection Checklist',
                              subtitle:
                                  'Complete safety & mechanical check items.',
                              children: [
                                if (_pmLoading)
                                  const Center(child: CircularProgressIndicator())
                                else if (_pmCategories.isEmpty)
                                  Text(
                                    'No PM checklist available for this unit type',
                                    style: TextStyle(color: AppColors.textSecondary),
                                  )
                                else ...[
                                  PmInspectionSection(
                                    categories: _pmCategories,
                                    results: _pmResults,
                                    isTrailer: (_entityTypeId ?? 1) == 2,
                                    onChanged: () => setState(() {}),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Tire & Brake Measurements',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TireBrakeGrid(
                                    measurements: _tireMeasurements,
                                    onChanged: () => setState(() {}),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'PM Defects',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
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

                          const SizedBox(height: 16),

                          // ── SECTION 5: ATTACHMENTS & FINANCIALS ──
                          _ModernSectionCard(
                            key: (_isPm ?? false) ? null : _sectionKeys[3],
                            icon: Icons.attach_file_rounded,
                            iconColor: const Color(0xFF2563EB),
                            title: 'Attachments & Financials',
                            subtitle:
                                'Upload documents or photos and set estimated cost.',
                            children: [
                              if (widget.isEdit) ...[
                                if (widget.existing!.attachments.isEmpty)
                                  Text(
                                    'No attachments uploaded yet',
                                    style: TextStyle(color: AppColors.textSecondary),
                                  )
                                else
                                  for (final a in widget.existing!.attachments)
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 6),
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: AppColors.inputFill,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: AppColors.border),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.insert_drive_file_outlined,
                                              size: 20,
                                              color: AppColors.primary),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              a.displayName,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                const SizedBox(height: 10),
                                OutlinedButton.icon(
                                  onPressed: _uploadAttachment,
                                  icon: const Icon(Icons.upload_rounded, size: 18),
                                  label: const Text('Upload Attachment'),
                                  style: OutlinedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ] else ...[
                                WebFileUploadZone(
                                  fileName: _pendingAttachments.isEmpty
                                      ? null
                                      : '${_pendingAttachments.length} file'
                                          '${_pendingAttachments.length > 1 ? 's' : ''} selected',
                                  subtitle:
                                      'Supported formats: Images (JPG, PNG) and PDF',
                                  onBrowse: _pickPendingAttachments,
                                  onCamera: _pickPendingAttachmentFromCamera,
                                  onScan: _scanPendingAttachment,
                                ),
                                if (_pendingAttachments.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  for (var i = 0; i < _pendingAttachments.length; i++)
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 6),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: AppColors.cardElevated,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: AppColors.border),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            isPreviewableImagePath(
                                                    _pendingAttachments[i].path)
                                                ? Icons.image_outlined
                                                : Icons.insert_drive_file_outlined,
                                            size: 18,
                                            color: isPreviewableImagePath(
                                                    _pendingAttachments[i].path)
                                                ? AppColors.primary
                                                : AppColors.textSecondary,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: InkWell(
                                              onTap: isPreviewableImagePath(
                                                      _pendingAttachments[i].path)
                                                  ? () => showLocalImagePreview(
                                                      context,
                                                      _pendingAttachments[i].path!)
                                                  : null,
                                              child: Text(
                                                _pendingAttachments[i].name,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                  color: isPreviewableImagePath(
                                                          _pendingAttachments[i]
                                                              .path)
                                                      ? AppColors.primary
                                                      : null,
                                                ),
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.close,
                                                size: 16,
                                                color: AppColors.textSecondary),
                                            onPressed: () => setState(
                                              () => _pendingAttachments.removeAt(i),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ],
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _costController,
                                decoration: InputDecoration(
                                  labelText: 'Estimated Total Cost *',
                                  prefixText: '\$ ',
                                  prefixIcon: Icon(Icons.payments_outlined,
                                      size: 18, color: AppColors.textSecondary),
                                  filled: true,
                                  fillColor: AppColors.inputFill,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: AppColors.border),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: AppColors.border),
                                  ),
                                ),
                                keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                onChanged: (_) {
                                  if (!_settingCostProgrammatically) {
                                    _isEstimatedCostManual = true;
                                  }
                                },
                                validator: (v) => v == null || v.trim().isEmpty
                                    ? 'Required'
                                    : null,
                              ),
                              if (_status == WorkOrderStatus.completed) ...[
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _resolutionController,
                                  decoration: InputDecoration(
                                    labelText: 'Resolution Notes (Completed)',
                                    hintText: 'Describe how the issue was resolved...',
                                    alignLabelWithHint: true,
                                    filled: true,
                                    fillColor: AppColors.inputFill,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: AppColors.border),
                                    ),
                                  ),
                                  maxLines: 3,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
        bottomNavigationBar: _loadingMeta
            ? null
            : Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, -4),
                    ),
                  ],
                  border: Border(
                    top: BorderSide(color: AppColors.border),
                  ),
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(color: AppColors.border),
                          ),
                          onPressed: _submitting
                              ? null
                              : () => Navigator.pop(context),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          onPressed: _submitting ? null : _submit,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            backgroundColor: AppColors.primary,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
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
                                      ? 'Save Changes'
                                      : 'Create Work Order',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Colors.white,
                                  ),
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

  Widget _buildPartLineCard(int index, _PartLineForm line) {
    final filteredParts = _parts
        .where((p) => line.partTypeId == null || p.typeId == line.partTypeId)
        .toList();
    final restricted = _isCompletedRestrictedEdit;
    final deferredMissingNotes = line.repairStatus == RepairStatus.deferred &&
        line.repairNotesController.text.trim().isEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: deferredMissingNotes ? AppColors.danger : AppColors.border,
          width: deferredMissingNotes ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.build_outlined, size: 13, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Repair Line #${index + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _RepairStatusBadge(status: line.repairStatus),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  visualDensity: VisualDensity.compact,
                  onPressed: restricted
                      ? null
                      : () => setState(() {
                            line.dispose();
                            _partLines.remove(line);
                          }),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: line.descriptionController,
              enabled: !restricted,
              decoration: InputDecoration(
                labelText: 'Repair Task Description *',
                hintText: 'e.g. Replace front left brake pad',
                filled: true,
                fillColor: AppColors.inputFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.border),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<RepairPerformedBy>(
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Repaired By *',
                      filled: true,
                      fillColor: AppColors.inputFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                    ),
                    initialValue: line.repairPerformedBy,
                    items: RepairPerformedBy.values
                        .map((p) => DropdownMenuItem(
                              value: p,
                              child: Text(
                                p.label,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: restricted
                        ? null
                        : (v) => setState(() =>
                            line.repairPerformedBy = v ?? line.repairPerformedBy),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<RepairStatus>(
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Repair Status',
                      filled: true,
                      fillColor: AppColors.inputFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                    ),
                    initialValue: line.repairStatus,
                    items: RepairStatus.values
                        .map((s) => DropdownMenuItem(
                              value: s,
                              child: Text(
                                s.label,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: restricted
                        ? null
                        : (v) => setState(() {
                              line.repairStatus = v ?? line.repairStatus;
                              if (line.repairStatus != RepairStatus.notStarted &&
                                  _status == WorkOrderStatus.notStarted) {
                                _status = WorkOrderStatus.inProgress;
                              }
                            }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<int>(
              isExpanded: true,
              decoration: InputDecoration(
                labelText: line.repairStatus != RepairStatus.deferred &&
                        line.repairStatus != RepairStatus.notStarted
                    ? 'Assign Technician *'
                    : 'Assign Technician',
                filled: true,
                fillColor: AppColors.inputFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.border),
                ),
              ),
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
                      child: Text(t.name, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: restricted
                  ? null
                  : (v) => setState(() => line.assignedTechnicianId = v),
              validator: (v) => v == null &&
                      line.repairStatus != RepairStatus.deferred &&
                      line.repairStatus != RepairStatus.notStarted
                  ? 'Required unless repair status is Deferred'
                  : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: line.repairNotesController,
              decoration: InputDecoration(
                labelText: deferredMissingNotes ? 'Notes *' : 'Notes',
                helperText: deferredMissingNotes
                    ? 'Note is required when repair status is Deferred'
                    : null,
                helperStyle: const TextStyle(color: AppColors.danger, fontSize: 11),
                filled: true,
                fillColor: AppColors.inputFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.border),
                ),
              ),
              maxLines: 2,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            WebSearchableDropdownField<PartTypeSummary?>(
              label: 'Part Category',
              value: _partTypes
                  .where((t) => t.id == line.partTypeId)
                  .firstOrNull,
              items: [null, ..._partTypes],
              itemLabel: (t) => t?.name ?? 'Select Category',
              hint: 'Select Category',
              onChanged: restricted
                  ? (_) {}
                  : (v) => setState(() {
                        line.partTypeId = v?.id;
                        line.partId = null;
                        _recalculateEstimatedCost();
                      }),
            ),
            const SizedBox(height: 8),
            WebSearchableDropdownField<PartSummary?>(
              label: 'Inventory Part',
              value: filteredParts
                  .where((p) => p.id == line.partId)
                  .firstOrNull,
              items: [null, ...filteredParts],
              itemLabel: (p) =>
                  p != null ? '${p.code} (In Stock: ${p.quantity ?? 0})' : 'Select Part',
              hint: 'Select Part',
              onChanged: restricted
                  ? (_) {}
                  : (v) => setState(() {
                        line.partId = v?.id;
                        _recalculateEstimatedCost();
                      }),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: line.hoursController,
                    readOnly: line.repairStatus == RepairStatus.inProgress,
                    decoration: InputDecoration(
                      labelText: 'Hours',
                      helperText: line.repairStatus == RepairStatus.inProgress
                          ? 'Read-only while in progress'
                          : null,
                      filled: true,
                      fillColor: AppColors.inputFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: line.quantityController,
                    enabled: !restricted,
                    decoration: InputDecoration(
                      labelText: 'Quantity *',
                      filled: true,
                      fillColor: AppColors.inputFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {
                      _recalculateEstimatedCost();
                    }),
                  ),
                ),
              ],
            ),
            if (line.repairPerformedBy == RepairPerformedBy.external) ...[
              const SizedBox(height: 10),
              TextFormField(
                controller: line.vendorNameController,
                enabled: !restricted,
                decoration: InputDecoration(
                  labelText: 'Vendor Name',
                  hintText: 'e.g. Acme Fleet Repairs',
                  filled: true,
                  fillColor: AppColors.inputFill,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _recalculateEstimatedCost();
                  });
                  AppToast.showSuccess('Repair details updated');
                },
                icon: const Icon(Icons.check_circle_outline, size: 16),
                label: const Text('Update Cost Calculation'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── MODERN UI WIDGETS & SECTIONS ──

class _QuickNavChip extends StatelessWidget {
  const _QuickNavChip({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : AppColors.cardElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModernSectionCard extends StatelessWidget {
  const _ModernSectionCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.children,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, thickness: 1),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _StyledDropdownField<T> extends StatelessWidget {
  const _StyledDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
    this.validator,
    this.enabled = true,
  });

  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? hint;
  final String? Function(T?)? validator;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<T>(
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: AppColors.inputFill,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.border),
          ),
        ),
        initialValue: value,
        hint: hint != null ? Text(hint!) : null,
        items: items,
        onChanged: enabled ? onChanged : null,
        validator: validator,
        menuMaxHeight: 320,
      ),
    );
  }
}

class _ModernDateField extends StatelessWidget {
  const _ModernDateField({
    required this.label,
    required this.value,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final text = value != null
        ? DateFormat('MM-dd-yyyy').format(value!)
        : 'Select date';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            filled: true,
            fillColor: AppColors.inputFill,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.border),
            ),
            suffixIcon: Icon(
              Icons.calendar_month_outlined,
              size: 20,
              color: enabled ? AppColors.primary : AppColors.textSecondary,
            ),
            enabled: enabled,
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontWeight: value != null ? FontWeight.w600 : FontWeight.normal,
              color: value != null ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _PriorityPillSelector extends StatelessWidget {
  const _PriorityPillSelector({
    required this.priority,
    required this.enabled,
    required this.onChanged,
  });

  final WorkOrderPriority? priority;
  final bool enabled;
  final ValueChanged<WorkOrderPriority> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: WorkOrderPriority.values.map((p) {
        final isSelected = priority == p;
        Color pillColor;
        IconData iconData;
        switch (p) {
          case WorkOrderPriority.low:
            pillColor = const Color(0xFF10B981);
            iconData = Icons.keyboard_arrow_down_rounded;
            break;
          case WorkOrderPriority.medium:
            pillColor = const Color(0xFFF59E0B);
            iconData = Icons.remove_rounded;
            break;
          case WorkOrderPriority.high:
            pillColor = const Color(0xFFEF4444);
            iconData = Icons.priority_high_rounded;
            break;
        }

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: InkWell(
              onTap: enabled ? () => onChanged(p) : null,
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? pillColor : pillColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? pillColor : pillColor.withValues(alpha: 0.3),
                    width: isSelected ? 1.5 : 1.0,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: pillColor.withValues(alpha: 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      iconData,
                      size: 14,
                      color: isSelected ? Colors.white : pillColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      p.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : pillColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _WorkOrderTypeSelector extends StatelessWidget {
  const _WorkOrderTypeSelector({
    required this.isPm,
    required this.enabled,
    required this.onChanged,
  });

  final bool isPm;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: enabled ? () => onChanged(false) : null,
              borderRadius: BorderRadius.circular(9),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: !isPm ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: !isPm
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.build_rounded,
                      size: 15,
                      color: !isPm ? Colors.white : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Repair',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: !isPm ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: enabled ? () => onChanged(true) : null,
              borderRadius: BorderRadius.circular(9),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isPm ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: isPm
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.checklist_rtl_rounded,
                      size: 16,
                      color: isPm ? Colors.white : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Preventive Maint.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isPm ? Colors.white : AppColors.textPrimary,
                      ),
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
}

class _RepairStatusBadge extends StatelessWidget {
  const _RepairStatusBadge({required this.status});

  final RepairStatus status;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    Color dot;
    switch (status) {
      case RepairStatus.completed:
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF15803D);
        dot = const Color(0xFF22C55E);
        break;
      case RepairStatus.inProgress:
        bg = const Color(0xFFDBEAFE);
        fg = const Color(0xFF1D4ED8);
        dot = const Color(0xFF3B82F6);
        break;
      case RepairStatus.deferred:
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFB91C1C);
        dot = const Color(0xFFEF4444);
        break;
      default:
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF475569);
        dot = const Color(0xFF94A3B8);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: dot,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            status.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _EventsSection extends StatefulWidget {
  const _EventsSection({
    required this.loading,
    required this.events,
    required this.linkedIds,
    required this.uploads,
    required this.uploadsLoading,
    required this.onTap,
    this.vin,
    this.unitNumber,
  });

  final bool loading;
  final List<MaintenanceIssueSummary> events;
  final Set<int> linkedIds;
  final Map<int, List<MaintenanceIssueUpload>> uploads;
  final bool uploadsLoading;
  final ValueChanged<MaintenanceIssueSummary> onTap;
  final String? vin;
  final String? unitNumber;

  @override
  State<_EventsSection> createState() => _EventsSectionState();
}

class _EventsSectionState extends State<_EventsSection> {
  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (widget.events.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.inputFill,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          'No linked DVIR defects or fault codes found for this unit.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Unit Defects & Events (Tap to link description)',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 8),
        SourceEventsDetailsLink(
          events: widget.events,
          vin: widget.vin,
          unitNumber: widget.unitNumber,
        ),
        const SizedBox(height: 8),
        for (final e in widget.events) _EventCard(
          issue: e,
          linked: widget.linkedIds.contains(e.id),
          uploads: widget.uploads[e.id] ?? const [],
          uploadsLoading: widget.uploadsLoading,
          onTap: () => widget.onTap(e),
        ),
      ],
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.issue,
    required this.linked,
    required this.uploads,
    required this.uploadsLoading,
    required this.onTap,
  });

  final MaintenanceIssueSummary issue;
  final bool linked;
  final List<MaintenanceIssueUpload> uploads;
  final bool uploadsLoading;
  final VoidCallback onTap;

  static String _formatSource(String source) {
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

  static String _formatReportedDate(String? value) {
    if (value == null || value.isEmpty) return '—';
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    return DateFormat('MM-dd-yyyy hh:mm a').format(parsed.toLocal());
  }

  void _openImagePreview(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ImagePreviewSheet(
        uploads: uploads,
        loading: uploadsLoading,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.cardElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: linked ? AppColors.primary : AppColors.border,
          width: linked ? 1.6 : 1.0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    issue.issueSource.toUpperCase().contains('FAULT')
                        ? Icons.report_gmailerrorred_outlined
                        : Icons.assignment_late_outlined,
                    size: 20,
                    color: linked ? AppColors.primary : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      issue.issueName ??
                          issue.defect ??
                          issue.issueDescription ??
                          'Issue #${issue.id}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
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
                  if (linked)
                    Icon(Icons.check_circle, size: 18, color: AppColors.primary),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if ((issue.category ?? '').isNotEmpty)
                    _EventChip(label: 'Category', value: issue.category!),
                  _EventChip(
                    label: 'Type',
                    value: _formatSource(issue.issueSource),
                  ),
                  if ((issue.status ?? '').isNotEmpty)
                    _EventStatusChip(status: issue.status!),
                  if ((issue.severity ?? '').isNotEmpty)
                    _EventSeverityChip(severity: issue.severity!),
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
              if ((issue.reportedDate ?? '').isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Reported: ${_formatReportedDate(issue.reportedDate)}',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EventChip extends StatelessWidget {
  const _EventChip({required this.label, required this.value});

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

class _EventStatusChip extends StatelessWidget {
  const _EventStatusChip({required this.status});

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

class _EventSeverityChip extends StatelessWidget {
  const _EventSeverityChip({required this.severity});

  final String severity;

  @override
  Widget build(BuildContext context) {
    final normalized = severity.toUpperCase();
    final milMatch = RegExp(r'MIL:\s*(\d+)').firstMatch(normalized);
    final milLevel = milMatch != null ? int.tryParse(milMatch.group(1)!) : null;

    Color bg;
    Color fg;
    if (normalized.contains('HIGH') || (milLevel != null && milLevel >= 2)) {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFB91C1C);
    } else if (normalized.contains('MEDIUM') || milLevel == 1) {
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

class _ImagePreviewSheet extends StatefulWidget {
  const _ImagePreviewSheet({required this.uploads, required this.loading});

  final List<MaintenanceIssueUpload> uploads;
  final bool loading;

  @override
  State<_ImagePreviewSheet> createState() => _ImagePreviewSheetState();
}

class _ImagePreviewSheetState extends State<_ImagePreviewSheet> {
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
                            color: isSelected
                                ? AppColors.primary
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(
                            images[i].signedUrl!,
                            fit: BoxFit.cover,
                          ),
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

class _OdometerField extends StatefulWidget {
  const _OdometerField({
    required this.label,
    required this.kmController,
    required this.unit,
    required this.onUnitChanged,
    this.onKmChanged,
    this.enabled = true,
    this.loading = false,
    this.onFetch,
    this.errorText,
    this.disabledHint,
  });

  final String label;
  final TextEditingController kmController;
  final OdometerDisplayUnit unit;
  final ValueChanged<OdometerDisplayUnit> onUnitChanged;
  final VoidCallback? onKmChanged;
  final bool enabled;
  final bool loading;
  final VoidCallback? onFetch;
  final String? errorText;
  final String? disabledHint;

  @override
  State<_OdometerField> createState() => _OdometerFieldState();
}

class _OdometerFieldState extends State<_OdometerField> {
  late final TextEditingController _displayController;
  bool _syncingFromKm = false;

  @override
  void initState() {
    super.initState();
    _displayController = TextEditingController(
      text: kmStringToDisplayValue(widget.kmController.text, widget.unit),
    );
    widget.kmController.addListener(_syncFromKmController);
  }

  void _syncFromKmController() {
    if (_syncingFromKm) return;
    final display =
        kmStringToDisplayValue(widget.kmController.text, widget.unit);
    if (display != _displayController.text) {
      _displayController.text = display;
    }
  }

  @override
  void didUpdateWidget(covariant _OdometerField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kmController != widget.kmController) {
      oldWidget.kmController.removeListener(_syncFromKmController);
      widget.kmController.addListener(_syncFromKmController);
    }
    if (oldWidget.unit != widget.unit) {
      _displayController.text =
          kmStringToDisplayValue(widget.kmController.text, widget.unit);
    }
  }

  void _handleDisplayChanged(String value) {
    _syncingFromKm = true;
    widget.kmController.text = displayValueToKmString(value, widget.unit);
    _syncingFromKm = false;
    widget.onKmChanged?.call();
  }

  @override
  void dispose() {
    widget.kmController.removeListener(_syncFromKmController);
    _displayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: TextFormField(
                controller: _displayController,
                enabled: widget.enabled,
                onChanged: _handleDisplayChanged,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: widget.label,
                  errorText: widget.errorText,
                  filled: true,
                  fillColor: AppColors.inputFill,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  prefixIcon: Icon(Icons.speed_rounded, size: 20, color: AppColors.textSecondary),
                  suffixIcon: SizedBox(
                    width: 85,
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<OdometerDisplayUnit>(
                        value: widget.unit,
                        isDense: true,
                        items: OdometerDisplayUnit.values
                            .map(
                              (u) => DropdownMenuItem(
                                value: u,
                                child: Text(
                                  u.label,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: widget.enabled
                            ? (u) {
                                if (u != null) widget.onUnitChanged(u);
                              }
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (widget.onFetch != null) ...[
              const SizedBox(width: 8),
              IconButton.filledTonal(
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  foregroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  minimumSize: const Size(48, 48),
                ),
                onPressed: widget.enabled && !widget.loading
                    ? widget.onFetch
                    : null,
                icon: widget.loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.gps_fixed_rounded),
                tooltip: 'Fetch live Samsara odometer',
              ),
            ],
          ],
        ),
        if (!widget.enabled && widget.disabledHint != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(
              widget.disabledHint!,
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ),
      ],
    );
  }
}

class _PartLineForm {
  _PartLineForm({
    this.id,
    this.partTypeId,
    this.partId,
    String quantity = '1',
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
