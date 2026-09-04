import 'dart:async';
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
import 'package:rapide_nforce/ui/work_orders/widgets/voice_translation_field.dart';
import 'package:rapide_nforce/ui/work_orders/work_order_add_part_sheet.dart';
import 'package:rapide_nforce/ui/work_orders/work_order_upload_attachment_sheet.dart';
import 'package:rapide_nforce/ui/widgets/audit_trail_dialog.dart';
import 'package:rapide_nforce/ui/widgets/gradient_page_background.dart';
import 'package:rapide_nforce/ui/widgets/web_form_field.dart';
import 'package:rapide_nforce/models/work_order_model.dart';
import 'package:rapide_nforce/core/utils/role_utils.dart';
import 'package:rapide_nforce/models/maintenance_policy_model.dart';
import 'package:rapide_nforce/services/auth_service.dart';
import 'package:rapide_nforce/services/fleet_lookup_service.dart';
import 'package:rapide_nforce/services/inventory_service.dart';
import 'package:rapide_nforce/services/maintenance_service.dart';
import 'package:rapide_nforce/services/voice_translation_service.dart';

class WorkOrderFormScreen extends StatefulWidget {
  const WorkOrderFormScreen({
    super.key,
    this.existing,
    this.initialIssueDescription,
    this.linkedDefects,
    this.initialUnitNumber,
  });

  final WorkOrderModel? existing;
  final String? initialIssueDescription;
  // Pre-selects the Unit field on open — used when launching "Create Work
  // Order" from a vehicle's detail screen, matching web's `unitNumber` query
  // param on the work order route (`VehicleDetail.tsx`'s Create Work Order
  // action). Ignored when `existing` or `linkedDefects` is set — those
  // already drive their own unit selection.
  final String? initialUnitNumber;
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

  // One id per form session, reused across every voice recording made here
  // and linked to the work order after it's created — mirrors web's
  // `voiceSessionIdRef` (`CreateWorkOrderDrawer.tsx`).
  late final String _voiceSessionId;

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
  final List<_InventoryPartRow> _inventoryPartRows = [];
  final List<PlatformFile> _pendingAttachments = [];

  // ── Inventory Parts quick-add staging row — mirrors web's persistent
  // Part Type / Part Name / Quantity / "+" row above the Inventory Parts
  // list (`newRepairPartTypeId`/`newRepairPartId`/`newRepairQuantity` in
  // `CreateWorkOrderDrawer.tsx`), kept separate from the "+ Add Part" popup
  // which only offers Upload Invoice / Manually Add New Part.
  int? _quickAddPartTypeId;
  int? _quickAddPartId;
  final TextEditingController _quickAddQuantityController =
      TextEditingController(text: '1');
  String? _quickAddError;

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
    _voiceSessionId = widget.existing?.id != null
        ? 'wo_${widget.existing!.id}'
        : generateVoiceSessionId();
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
        _partLines.add(_PartLineForm(description: d.description));
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
    _quickAddQuantityController.dispose();
    for (final line in _partLines) {
      line.dispose();
    }
    for (final row in _inventoryPartRows) {
      row.dispose();
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

      // Web parity for `resolveAssigneeSelection` (`workOrderAssignee.ts`) —
      // once technicians are loaded, any repair line still missing an
      // assignee (e.g. lines pre-created from a linked DVIR defect) defaults
      // to the logged-in Technician, matching web's "Assign To" auto-fill.
      if (widget.existing == null) {
        final defaultTechId = _resolveLoggedInTechnicianAssigneeId();
        if (defaultTechId != null) {
          for (final line in _partLines) {
            line.assignedTechnicianId ??= defaultTechId;
          }
        }
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

      final targetUnitNumber = (prefill?.unitNumber?.trim().isNotEmpty ?? false)
          ? prefill!.unitNumber!.trim()
          : (widget.linkedDefects!.first.unitNumber?.trim() ?? '');
      final targetVin = (prefill?.vin?.trim().isNotEmpty ?? false)
          ? prefill!.vin!.trim()
          : (widget.linkedDefects!.first.vin?.trim() ?? '');

      if (prefill?.priority != null) {
        final p = WorkOrderPriority.fromCode(prefill!.priority);
        if (mounted) setState(() => _priority = p);
      }

      if ((prefill?.issueDescription?.trim().isNotEmpty ?? false) && mounted) {
        _issueController.text = prefill!.issueDescription!.trim();
      }

      // Resolve which Unit Type to prefill: the defect's own entityTypeId if
      // it's a known type, else fall back to "Power Unit" by name, else the
      // first non-driver type — mirrors web's `matchingType` fallback chain
      // (`CreateWorkOrderDrawer.tsx`) so a defect with a null/stale
      // entityTypeId still lands on a sensible Unit Type instead of
      // whatever the form's arbitrary default happened to be.
      final rawTargetEntityTypeId = prefill?.entityTypeId;
      final resolvedType =
          (rawTargetEntityTypeId != null
              ? _entityTypes
                    .where((t) => t.id == rawTargetEntityTypeId)
                    .firstOrNull
              : null) ??
          _entityTypes
              .where((t) => t.name.trim().toLowerCase() == 'power unit')
              .firstOrNull ??
          _entityTypes.firstOrNull;

      if (resolvedType != null && resolvedType.id != _entityTypeId) {
        if (mounted) setState(() => _entityTypeId = resolvedType.id);
        await _loadEntities(resolvedType.id);
      } else if (resolvedType != null && _entities.isEmpty) {
        await _loadEntities(resolvedType.id);
      }

      if (targetUnitNumber.isNotEmpty) {
        final normalizedTarget = targetUnitNumber.toLowerCase();
        final normalizedVin = targetVin.toLowerCase();

        // 1. Match by unit number AND VIN — mirrors web's first pass.
        EntityModel? matchedEntity = _entities.where((e) {
          final name = e.name.trim().toLowerCase();
          final vin = (e.vinNumber ?? '').trim().toLowerCase();
          return name == normalizedTarget &&
              (normalizedVin.isEmpty || vin == normalizedVin);
        }).firstOrNull;

        // 2. Fallback: unit number only, case-insensitive/trimmed (the
        // previous exact `==` compare here silently failed to prefill
        // whenever casing/whitespace differed from the defect record).
        matchedEntity ??= _entities
            .where((e) => e.name.trim().toLowerCase() == normalizedTarget)
            .firstOrNull;

        // 3. Fallback: search every other entity type for a name match, in
        // case the resolved type above was wrong for this company's data.
        if (matchedEntity == null) {
          for (final type in _entityTypes) {
            if (type.id == _entityTypeId) continue;
            final otherRes = await MaintenanceService.instance.getEntities(
              type.id,
            );
            if (!otherRes.isSuccess || otherRes.data == null) continue;
            final found = otherRes.data!
                .where((e) => e.name.trim().toLowerCase() == normalizedTarget)
                .firstOrNull;
            if (found != null) {
              if (mounted) {
                setState(() {
                  _entityTypeId = type.id;
                  _entities = otherRes.data!;
                });
              }
              matchedEntity = found;
              break;
            }
          }
        }

        // 4. Last resort: this vehicle isn't in the currently-scoped entity
        // list at all (e.g. belongs to a different company) — still show
        // the defect's own unit number/VIN as a synthetic entry rather than
        // leaving Unit Number blank, matching web's `placeholderEntity`
        // fallback exactly.
        if (matchedEntity == null) {
          matchedEntity = EntityModel(
            id: -DateTime.now().millisecondsSinceEpoch,
            name: targetUnitNumber,
            vinNumber: targetVin.isEmpty ? null : targetVin,
          );
          if (mounted) {
            setState(() => _entities = [..._entities, matchedEntity!]);
          }
        }

        if (mounted) {
          setState(() => _selectedEntityId = matchedEntity!.id);
          _fetchOdometer();
          _loadEvents();
        }
      }
    } else if (existing == null &&
        (widget.linkedDefects?.isEmpty ?? true) &&
        (widget.initialUnitNumber?.trim().isNotEmpty ?? false) &&
        mounted) {
      final targetUnitNumber = widget.initialUnitNumber!.trim();
      final normalizedTarget = targetUnitNumber.toLowerCase();
      EntityModel? matchedEntity = _entities
          .where((e) => e.name.trim().toLowerCase() == normalizedTarget)
          .firstOrNull;

      if (matchedEntity == null) {
        for (final type in _entityTypes) {
          if (type.id == _entityTypeId) continue;
          final otherRes = await MaintenanceService.instance.getEntities(
            type.id,
          );
          if (!otherRes.isSuccess || otherRes.data == null) continue;
          final found = otherRes.data!
              .where((e) => e.name.trim().toLowerCase() == normalizedTarget)
              .firstOrNull;
          if (found != null) {
            if (mounted) {
              setState(() {
                _entityTypeId = type.id;
                _entities = otherRes.data!;
              });
            }
            matchedEntity = found;
            break;
          }
        }
      }

      if (matchedEntity != null && mounted) {
        setState(() => _selectedEntityId = matchedEntity!.id);
        _fetchOdometer();
        _loadEvents();
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

  Future<void> _loadPmChecklist(
    int entityTypeId, {
    WorkOrderModel? existingOrder,
  }) async {
    setState(() => _pmLoading = true);
    final result = await MaintenanceService.instance.getPMInspectionItems(
      entityTypeId: entityTypeId,
    );
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
      companyId: AuthService.instance.selectedCompanyIdInt,
    );
    final pendingEvents = await _buildPendingPolicyEvents(unit);
    if (!mounted) return;
    setState(() {
      _eventsLoading = false;
      _events = [...(result.data ?? []), ...pendingEvents];
    });
    if (!result.isSuccess) {
      ApiFeedback.showError(result, fallback: 'Failed to load source events');
    }
    _loadEventUploads();
  }

  Future<void> _loadEventUploads() async {
    final ids = _events.map((e) => e.id).toList();
    if (ids.isEmpty) {
      setState(() => _eventUploads = {});
      return;
    }
    setState(() => _uploadsLoading = true);
    final result = await MaintenanceService.instance.getMaintenanceIssueUploads(
      ids,
    );
    if (!mounted) return;
    setState(() {
      _uploadsLoading = false;
      _eventUploads = result.data ?? {};
    });
  }

  static String _normalizeScheduleKey(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[\s_-]+'), '')
      .replaceAll(RegExp(r'[^a-z0-9]'), '');

  /// Synthesizes "Pending" source-event rows from the unit's assigned
  /// maintenance-policy schedule — these aren't real DVIR/fault-code/manual
  /// issue rows, they're a client-side projection of which policy panels
  /// are due, mirroring web's inline synthesis in
  /// `CreateWorkOrderDrawer.tsx` (search "issueSource: 'POLICY'"). A panel
  /// is skipped once the vehicle has a matching, still-current
  /// `maintenanceRecords[]` entry (a recent `lastDate` or a future
  /// `nextDate`).
  Future<List<MaintenanceIssueSummary>> _buildPendingPolicyEvents(
    EntityModel unit,
  ) async {
    if (_entityTypeId == null) return const [];

    final policiesResult = await FleetLookupService.instance
        .fetchMaintenancePolicyConfigs(entityTypeId: _entityTypeId);
    final policies = policiesResult.data ?? const [];
    if (policies.isEmpty) return const [];

    MaintenancePolicyModel? matched;
    final policyRef = unit.maintenancePolicy?.trim();
    if (policyRef != null && policyRef.isNotEmpty) {
      for (final p in policies) {
        if (p.name.trim().toLowerCase() == policyRef.toLowerCase() ||
            p.id.toString() == policyRef) {
          matched = p;
          break;
        }
      }
    }
    matched ??= policies.where((p) {
      final list = (_entityTypeId == 2) ? p.usedInTrailers : p.usedInTrucks;
      return list.any(
        (u) => u.trim().toLowerCase() == unit.name.trim().toLowerCase(),
      );
    }).firstOrNull;
    if (matched == null) return const [];

    final records = unit.maintenanceRecords;
    final result = <MaintenanceIssueSummary>[];

    for (final schedule in matched.schedules) {
      for (final panel in schedule.panels) {
        final panelCode = (panel.scheduleTypeCode ?? panel.type).trim();
        final panelName = (panel.scheduleTypeName ?? '').trim();
        final normCode = _normalizeScheduleKey(panelCode);
        final normName = _normalizeScheduleKey(panelName);

        MaintenanceRecordRef? matchedRecord;
        for (final r in records) {
          if (panel.scheduleTypeId != null &&
              r.scheduleTypeId == panel.scheduleTypeId) {
            matchedRecord = r;
            break;
          }
          final rCode = _normalizeScheduleKey(r.typeCode ?? '');
          final rName = _normalizeScheduleKey(r.typeName ?? '');
          if ((normCode.isNotEmpty &&
                  (normCode == rCode || normCode == rName)) ||
              (normName.isNotEmpty &&
                  (normName == rName || normName == rCode))) {
            matchedRecord = r;
            break;
          }
        }

        var upToDate = false;
        if (matchedRecord != null) {
          final lastDate = DateTime.tryParse(matchedRecord.lastDate ?? '');
          final nextDate = DateTime.tryParse(matchedRecord.nextDate ?? '');
          final hasRecentLastDate = lastDate != null;
          final hasFutureNextDate =
              nextDate != null && nextDate.isAfter(DateTime.now());
          upToDate = hasRecentLastDate || hasFutureNextDate;
        }
        if (upToDate) continue;

        final defectName = (panel.scheduleTypeName?.isNotEmpty ?? false)
            ? panel.scheduleTypeName!
            : ((panel.scheduleTypeCode?.isNotEmpty ?? false)
                  ? panel.scheduleTypeCode!
                  : panel.type);
        final scheduleLabel = schedule.name.isNotEmpty
            ? schedule.name
            : (schedule.scheduleNumber?.toString() ?? '');
        final reference =
            schedule.scheduleNumber?.toString() ?? schedule.id.toString();

        result.add(
          MaintenanceIssueSummary(
            id: 'policy-${matched.id}-${schedule.id}-${panel.type}'.hashCode,
            issueSource: 'POLICY',
            issueName: defectName,
            issueDescription: '',
            defect: defectName,
            category: scheduleLabel,
            status: 'pending',
            externalReference: reference,
            reportedDate: null,
            reportedBy: '',
          ),
        );
      }
    }
    return result;
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
        title: Text(
          'Issue description already has text',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
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
        _pendingAttachments.add(
          PlatformFile(
            path: photo.path,
            name: photo.name,
            size: bytes.length,
            bytes: bytes,
          ),
        );
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
        _pendingAttachments.add(
          PlatformFile(
            path: path,
            name: path.split('/').last,
            size: bytes.length,
            bytes: bytes,
          ),
        );
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
  bool _hasAnyRepairPart() =>
      _partLines.any((l) => l.partId != null) ||
      _inventoryPartRows.any((r) => r.partId != null);

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
    for (final row in _inventoryPartRows) {
      if (row.partId != null) {
        PartSummary? part;
        for (final p in _parts) {
          if (p.id == row.partId) {
            part = p;
            break;
          }
        }
        if (part != null && part.unitCost != null) {
          final qty = double.tryParse(row.quantityController.text.trim()) ?? 0;
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
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: AppColors.primary),
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
      parts: [
        ..._partLines
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
            ),
        // Standalone "Inventory Parts (Optional)" rows — not tied to a
        // repair, so no repair status/technician/notes. The backend only
        // treats parts as repair-only when a top-level `inventoryParts` key
        // is present in the request; since we don't send one, these are
        // accepted the same way as any other part-usage row.
        ..._inventoryPartRows
            .where((r) => r.partId != null)
            .map(
              (r) => WorkOrderPartPayload(
                usedPart: r.partId,
                usageDescription: '',
                quantity: num.tryParse(r.quantityController.text.trim()) ?? 1,
                partTypeId: r.partTypeId,
              ),
            ),
      ],
      pmInspectionResults: (_isPm ?? false) ? _pmResults : const [],
      pmTireMeasurements: (_isPm ?? false) ? _tireMeasurements : const [],
      pmDefects: (_isPm ?? false) ? _defects : const [],
    );
  }

  void _reduceInventoryForUsedParts() {
    final usages = <(int? partId, TextEditingController qtyController)>[
      for (final line in _partLines) (line.partId, line.quantityController),
      for (final row in _inventoryPartRows)
        (row.partId, row.quantityController),
    ];
    for (final (partId, qtyController) in usages) {
      if (partId == null) continue;
      final usedQty = int.tryParse(qtyController.text.trim()) ?? 0;
      if (usedQty <= 0) continue;
      PartSummary? part;
      for (final p in _parts) {
        if (p.id == partId) {
          part = p;
          break;
        }
      }
      if (part != null) {
        final currentQty = part.quantity ?? 0;
        final newQty = (currentQty - usedQty) < 0 ? 0 : (currentQty - usedQty);
        InventoryService.instance.updatePart(
          id: part.id,
          typeId: part.typeId,
          code: part.code,
          quantity: newQty.toInt(),
        );
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      AppToast.showError('Please check highlighted fields');
      return;
    }
    if (_entityTypeId == null || _selectedEntity == null) {
      AppToast.showError(
        'Complete all required fields (Unit Type & Unit Number)',
      );
      return;
    }
    // Web parity for `validateForm`'s `errors.priority = 'Priority is
    // required'` (`CreateWorkOrderDrawer.tsx`) — the pill selector has no
    // default for a brand-new work order, so without this check `_priority`
    // could silently fall back to Medium at submit time instead of blocking.
    if (_priority == null) {
      AppToast.showError('Priority is required');
      return;
    }
    _assigneeId ??= AuthService.instance.currentUser?.id ?? 0;

    final rangeError = _odometerRangeError;
    if (rangeError != null) {
      AppToast.showError(rangeError);
      return;
    }

    if (_dueDate == null) {
      AppToast.showError('Due Date is required');
      return;
    }
    if (_startDate != null && _dueDate!.isBefore(_startDate!)) {
      AppToast.showError('Due Date must be on or after Start Date');
      return;
    }

    // Web parity for `getRepairsValidationError` (`CreateWorkOrderDrawer
    // .tsx`) — every work order needs at least one repair line, and every
    // repair line needs a valid (0 or greater) Hours value.
    if (_partLines.isEmpty) {
      AppToast.showError('At least one repair is required');
      return;
    }
    final invalidHoursLine = _partLines.any((l) {
      final hours = double.tryParse(l.hoursController.text.trim());
      return hours == null || hours < 0;
    });
    if (invalidHoursLine) {
      AppToast.showError('Hours are required for each repair (0 or greater)');
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
    if (newId > 0) {
      // Best-effort: link this session's voice recordings (made before the
      // work order existed) to the now-created id — mirrors web's
      // post-create `voiceTranslationService.linkSession` call.
      unawaited(
        VoiceTranslationService.instance.linkSession(
          workOrderId: newId,
          sessionId: _voiceSessionId,
        ),
      );
    }
    if (newId > 0 && _pendingAttachments.isNotEmpty) {
      final paths = _pendingAttachments
          .map((f) => f.path)
          .whereType<String>()
          .toList();
      if (paths.isNotEmpty) {
        final uploadResult = await MaintenanceService.instance
            .uploadWorkOrderAttachments(workOrderId: newId, filePaths: paths);
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

  /// Web parity for `resolveLoggedInTechnicianAssigneeId` (`workOrderAssignee
  /// .ts`) — the logged-in user only self-assigns a new repair line when
  /// their role is Technician (an Admin/Dispatcher creating a work order for
  /// someone else shouldn't have the field silently defaulted to themself).
  int? _resolveLoggedInTechnicianAssigneeId() {
    final user = AuthService.instance.currentUser;
    if (user == null || !isTechnicianRole(user.role) || _technicians.isEmpty) {
      return null;
    }
    final match = _technicians
        .where((t) => (t.userId != 0 && t.userId == user.id) || t.id == user.id)
        .firstOrNull;
    if (match == null) return null;
    return match.userId != 0 ? match.userId : match.id;
  }

  void _addPartLine() {
    setState(
      () => _partLines.add(
        _PartLineForm(
          assignedTechnicianId: _resolveLoggedInTechnicianAssigneeId(),
        ),
      ),
    );
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    widget.existing?.workOrderNumber ??
                        '#${widget.existing?.id}',
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
            : Form(
                key: _formKey,
                child: ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    // ── SECTION 1: WORK ORDER SOURCE ──
                    _ModernSectionCard(
                      sectionNumber: 1,
                      icon: Icons.directions_bus_rounded,
                      iconColor: const Color(0xFF2563EB),
                      title: 'Work Order Source',
                      subtitle:
                          'Select a unit to load source events and linked defects.',
                      trailing: (widget.linkedDefects?.isNotEmpty ?? false)
                          ? _ViewAuditTrailButton(
                              onPressed: () => showAuditTrailDialog(
                                context,
                                entityType: 'dvir_defect',
                                entityId: widget.linkedDefects!.first.defectId,
                                subtitle:
                                    'DVIR Defect ${widget.linkedDefects!.first.defectId}',
                              ),
                            )
                          : null,
                      children: [
                        _StyledDropdownField<int>(
                          label: 'Unit Type *',
                          hint: 'Select Unit Type',
                          value: _entityTypeId,
                          enabled:
                              !widget.isEdit &&
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

                    // ── SECTION 2: WORK ORDER DETAILS ──
                    _ModernSectionCard(
                      sectionNumber: 2,
                      icon: Icons.schedule_rounded,
                      iconColor: const Color(0xFFD97706),
                      title: 'Work Order Details',
                      subtitle:
                          'Set status, key dates, meter readings and labour cost.',
                      children: [
                        _StyledDropdownField<WorkOrderStatus>(
                          key: ValueKey(
                            'status_${_status.code}_$_statusFieldGen',
                          ),
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
                                  onPicked: (d) =>
                                      setState(() => _startDate = d),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _ModernDateField(
                                label: 'Due Date *',
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
                                  prefixIcon: Icon(
                                    Icons.access_time_rounded,
                                    size: 18,
                                    color: AppColors.textSecondary,
                                  ),
                                  filled: true,
                                  fillColor: AppColors.inputFill,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: AppColors.border,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: AppColors.border,
                                    ),
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
                                  prefixIcon: Icon(
                                    Icons.attach_money_rounded,
                                    size: 18,
                                    color: AppColors.textSecondary,
                                  ),
                                  filled: true,
                                  fillColor: AppColors.inputFill,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: AppColors.border,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: AppColors.border,
                                    ),
                                  ),
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
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
                        title:
                            'Linked to DVIR defect${widget.linkedDefects!.length == 1 ? '' : 's'}',
                        message: widget.linkedDefects!.length == 1
                            ? 'This work order will be linked back to the source defect.'
                            : '${widget.linkedDefects!.length} selected defects will each be added as a repair line on this work order.',
                      ),
                    ],

                    const SizedBox(height: 16),

                    // ── PM INSPECTION CHECKLIST (IF PM SELECTED) ──
                    // Slots in between Work Order Details and Repairs,
                    // matching web's insertion point (not one of its 8
                    // numbered sections either — it's a conditional
                    // block gated on Work Order Type = Preventive
                    // Maintenance).
                    if (_isPm ?? false) ...[
                      _ModernSectionCard(
                        icon: Icons.checklist_rounded,
                        iconColor: const Color(0xFF059669),
                        title: 'PM Inspection Checklist',
                        subtitle: 'Complete safety & mechanical check items.',
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
                                  PmDefectModel(rowNo: _defects.length + 1),
                                ),
                              ),
                              onRemove: (i) =>
                                  setState(() => _defects.removeAt(i)),
                              onChanged: () => setState(() {}),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── SECTION 3: REPAIRS ──
                    _ModernSectionCard(
                      sectionNumber: 3,
                      icon: Icons.build_circle_rounded,
                      iconColor: const Color(0xFF7C3AED),
                      title: 'Repairs',
                      trailing: OutlinedButton.icon(
                        onPressed: _isCompletedRestrictedEdit
                            ? null
                            : _addPartLine,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Repair'),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                        ),
                      ),
                      children: [
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
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
                                Icon(
                                  Icons.info_outline,
                                  size: 18,
                                  color: AppColors.warning,
                                ),
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
                                Icon(
                                  Icons.build_circle_outlined,
                                  size: 32,
                                  color: AppColors.textSecondary,
                                ),
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
                          ..._partLines.asMap().entries.map(
                            (entry) =>
                                _buildPartLineCard(entry.key, entry.value),
                          ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ── SECTION 4: INVENTORY PARTS (OPTIONAL) ──
                    _ModernSectionCard(
                      sectionNumber: 4,
                      icon: Icons.inventory_2_rounded,
                      iconColor: const Color(0xFF0EA5E9),
                      title: 'Inventory Parts (Optional)',
                      subtitle:
                          'Add parts consumed by this work order that aren\'t tied to a specific repair.',
                      children: [
                        _buildQuickAddInventoryPartRow(),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: _isCompletedRestrictedEdit
                                  ? null
                                  : () => _openAddPartSheet(),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Add Part'),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Click the + button to add more parts.',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_inventoryPartRows.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          for (var i = 0; i < _inventoryPartRows.length; i++)
                            _buildInventoryPartRowCard(
                              i,
                              _inventoryPartRows[i],
                            ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ── SECTION 5: NOTES ──
                    _ModernSectionCard(
                      sectionNumber: 5,
                      icon: Icons.notes_rounded,
                      iconColor: const Color(0xFF7C3AED),
                      title: 'Notes',
                      children: [
                        VoiceNotesRecorderRow(
                          fieldName: 'notes',
                          sessionId: _voiceSessionId,
                          workOrderId: widget.existing?.id,
                          onTranscribed: (text) => setState(() {
                            final current = _notesController.text.trim();
                            _notesController.text = current.isEmpty
                                ? text
                                : '$current $text';
                          }),
                        ),
                        TextFormField(
                          controller: _notesController,
                          decoration: InputDecoration(
                            hintText: 'Enter any additional notes...',
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
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ── SECTION 6: ESTIMATED COST ──
                    _ModernSectionCard(
                      sectionNumber: 6,
                      icon: Icons.payments_rounded,
                      iconColor: const Color(0xFF16A34A),
                      title: 'Estimated Cost',
                      children: [
                        TextFormField(
                          controller: _costController,
                          decoration: InputDecoration(
                            labelText: 'Estimated Cost *',
                            prefixText: '\$ ',
                            prefixIcon: Icon(
                              Icons.payments_outlined,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
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
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? 'Required' : null,
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ── SECTION 7: ATTACHMENTS ──
                    _ModernSectionCard(
                      sectionNumber: 7,
                      icon: Icons.attach_file_rounded,
                      iconColor: const Color(0xFF2563EB),
                      title: 'Attachments',
                      subtitle: 'Upload documents or photos.',
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
                                    Icon(
                                      Icons.insert_drive_file_outlined,
                                      size: 20,
                                      color: AppColors.primary,
                                    ),
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
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.cardElevated,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isPreviewableImagePath(
                                            _pendingAttachments[i].path,
                                          )
                                          ? Icons.image_outlined
                                          : Icons.insert_drive_file_outlined,
                                      size: 18,
                                      color:
                                          isPreviewableImagePath(
                                            _pendingAttachments[i].path,
                                          )
                                          ? AppColors.primary
                                          : AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: InkWell(
                                        onTap:
                                            isPreviewableImagePath(
                                              _pendingAttachments[i].path,
                                            )
                                            ? () => showLocalImagePreview(
                                                context,
                                                _pendingAttachments[i].path!,
                                              )
                                            : null,
                                        child: Text(
                                          _pendingAttachments[i].name,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color:
                                                isPreviewableImagePath(
                                                  _pendingAttachments[i].path,
                                                )
                                                ? AppColors.primary
                                                : null,
                                          ),
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.close,
                                        size: 16,
                                        color: AppColors.textSecondary,
                                      ),
                                      onPressed: () => setState(
                                        () => _pendingAttachments.removeAt(i),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ],
                      ],
                    ),

                    // ── SECTION 8: RESOLUTION (COMPLETED WORK ORDERS) ──
                    // Always shown, matching web's `EnhancedResolutionSection` —
                    // only the field's enabled state / placeholder toggle on
                    // status, the section itself never disappears.
                    const SizedBox(height: 16),
                    _ModernSectionCard(
                      sectionNumber: 8,
                      icon: Icons.task_alt_rounded,
                      iconColor: const Color(0xFF16A34A),
                      title: 'Resolution (Completed Work Orders)',
                      children: [
                        TextFormField(
                          controller: _resolutionController,
                          enabled: _status == WorkOrderStatus.completed,
                          decoration: InputDecoration(
                            labelText: 'Resolution Notes',
                            hintText: _status == WorkOrderStatus.completed
                                ? 'Enter resolution notes'
                                : 'Available when work order is completed',
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
                    ),
                  ],
                ),
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
                  border: Border(top: BorderSide(color: AppColors.border)),
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
    final restricted = _isCompletedRestrictedEdit;
    final deferredMissingNotes =
        line.repairStatus == RepairStatus.deferred &&
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.build_outlined,
                        size: 13,
                        color: AppColors.primary,
                      ),
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
            if (!restricted)
              VoiceNotesRecorderRow(
                fieldName: 'repair_description_${line.id ?? index}',
                sessionId: _voiceSessionId,
                workOrderId: widget.existing?.id,
                onTranscribed: (text) => setState(() {
                  final current = line.descriptionController.text.trim();
                  line.descriptionController.text = current.isEmpty
                      ? text
                      : '$current $text';
                }),
              ),
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
                        .map(
                          (p) => DropdownMenuItem(
                            value: p,
                            child: Text(
                              p.label,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: restricted
                        ? null
                        : (v) => setState(
                            () => line.repairPerformedBy =
                                v ?? line.repairPerformedBy,
                          ),
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
                        .map(
                          (s) => DropdownMenuItem(
                            value: s,
                            child: Text(
                              s.label,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
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
                labelText:
                    line.repairStatus != RepairStatus.deferred &&
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
              initialValue:
                  _technicians.any(
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
              validator: (v) =>
                  v == null &&
                      line.repairStatus != RepairStatus.deferred &&
                      line.repairStatus != RepairStatus.notStarted
                  ? 'Required unless repair status is Deferred'
                  : null,
            ),
            const SizedBox(height: 10),
            if (!restricted)
              VoiceNotesRecorderRow(
                fieldName: 'repair_notes_${line.id ?? index}',
                sessionId: _voiceSessionId,
                workOrderId: widget.existing?.id,
                onTranscribed: (text) => setState(() {
                  final current = line.repairNotesController.text.trim();
                  line.repairNotesController.text = current.isEmpty
                      ? text
                      : '$current $text';
                }),
              ),
            TextFormField(
              controller: line.repairNotesController,
              decoration: InputDecoration(
                labelText: deferredMissingNotes ? 'Notes *' : 'Notes',
                helperText: deferredMissingNotes
                    ? 'Note is required when repair status is Deferred'
                    : null,
                helperStyle: const TextStyle(
                  color: AppColors.danger,
                  fontSize: 11,
                ),
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: line.hoursController,
                    readOnly: line.repairStatus == RepairStatus.inProgress,
                    enabled: !restricted,
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
                // Web parity for the "External" checkbox next to Hours
                // (`CreateWorkOrderDrawer.tsx`'s repair row3) — a quick
                // toggle kept in sync with the "Repaired By" dropdown above,
                // rather than a separate field of its own.
                InkWell(
                  onTap: restricted
                      ? null
                      : () => setState(() {
                          line.repairPerformedBy =
                              line.repairPerformedBy ==
                                  RepairPerformedBy.external
                              ? RepairPerformedBy.internal
                              : RepairPerformedBy.external;
                        }),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value:
                            line.repairPerformedBy ==
                            RepairPerformedBy.external,
                        onChanged: restricted
                            ? null
                            : (v) => setState(() {
                                line.repairPerformedBy = (v ?? false)
                                    ? RepairPerformedBy.external
                                    : RepairPerformedBy.internal;
                              }),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        'External',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
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

  /// Commits the always-visible quick-add row (Part Type / Part Name /
  /// Quantity + "+") into `_inventoryPartRows` — web parity for
  /// `addInventoryPart()` in `CreateWorkOrderDrawer.tsx`, kept separate from
  /// the "+ Add Part" popup (which only offers Upload Invoice / Manually Add
  /// New Part, matching web's `AddPartChoiceModal`).
  void _commitQuickAddPart() {
    if (_quickAddPartTypeId == null) {
      setState(() => _quickAddError = 'Please select a Part Type');
      return;
    }
    final filtered = _parts
        .where((p) => p.typeId == _quickAddPartTypeId)
        .toList();
    if (filtered.isNotEmpty && _quickAddPartId == null) {
      setState(() => _quickAddError = 'Please select a Part');
      return;
    }
    final qty = int.tryParse(_quickAddQuantityController.text.trim());
    if (qty == null || qty < 1 || qty > 100) {
      setState(() => _quickAddError = 'Quantity must be between 1 and 100');
      return;
    }
    final isDuplicate =
        _quickAddPartId != null &&
        _inventoryPartRows.any((r) => r.partId == _quickAddPartId);
    if (isDuplicate) {
      setState(() => _quickAddError = 'This item is already added');
      return;
    }

    setState(() {
      final row = _InventoryPartRow()
        ..partTypeId = _quickAddPartTypeId
        ..partId = _quickAddPartId;
      row.quantityController.text = qty.toString();
      _inventoryPartRows.add(row);

      _quickAddPartTypeId = null;
      _quickAddPartId = null;
      _quickAddQuantityController.text = '1';
      _quickAddError = null;
      _recalculateEstimatedCost();
    });
  }

  Widget _buildQuickAddInventoryPartRow() {
    final restricted = _isCompletedRestrictedEdit;
    final filteredParts = _quickAddPartTypeId == null
        ? _parts
        : _parts.where((p) => p.typeId == _quickAddPartTypeId).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WebSearchableDropdownField<PartTypeSummary?>(
          label: 'Part Type',
          value: _partTypes
              .where((t) => t.id == _quickAddPartTypeId)
              .firstOrNull,
          items: [null, ..._partTypes],
          itemLabel: (t) => t?.name ?? 'Select',
          hint: 'Select',
          onChanged: restricted
              ? (_) {}
              : (v) => setState(() {
                  _quickAddPartTypeId = v?.id;
                  _quickAddPartId = null;
                  _quickAddError = null;
                }),
        ),
        const SizedBox(height: 8),
        WebSearchableDropdownField<PartSummary?>(
          label: 'Part Name',
          value: filteredParts
              .where((p) => p.id == _quickAddPartId)
              .firstOrNull,
          items: [null, ...filteredParts],
          itemLabel: (p) => p != null
              ? '${p.code} (In Stock: ${p.quantity ?? 0})'
              : 'Select Part',
          hint: 'Select Part',
          onChanged: restricted
              ? (_) {}
              : (v) => setState(() {
                  _quickAddPartId = v?.id;
                  _quickAddError = null;
                }),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: _quickAddQuantityController,
                enabled: !restricted,
                decoration: InputDecoration(
                  labelText: 'Quantity',
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
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: SizedBox(
                width: 40,
                height: 40,
                child: FilledButton(
                  onPressed: restricted ? null : _commitQuickAddPart,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: EdgeInsets.zero,
                    shape: const CircleBorder(),
                  ),
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
        if (_quickAddError != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _quickAddError!,
              style: const TextStyle(color: AppColors.danger, fontSize: 11.5),
            ),
          ),
      ],
    );
  }

  /// Opens the "Add Part" sheet — web parity for `AddPartChoiceModal`
  /// (Upload Invoice via OCR, or manually creating a brand-new part
  /// type/part). Selecting an *existing* part is handled by the always
  /// visible quick-add row above ([_buildQuickAddInventoryPartRow]), not
  /// this popup — matching web, where the popup only ever offers those two
  /// choices. Both may create/upsert real inventory records, so the sheet
  /// hands back refreshed `_partTypes`/`_parts` that must be adopted before
  /// the new rows are appended — otherwise [_recalculateEstimatedCost]'s
  /// lookup by `partId` would miss them.
  Future<void> _openAddPartSheet() async {
    final result = await showWorkOrderAddPartSheet(
      context,
      partTypes: _partTypes,
    );
    if (result == null || !mounted) return;
    setState(() {
      _partTypes = result.partTypes;
      _parts = result.parts;
      for (final entry in result.entries) {
        final row = _InventoryPartRow()
          ..partTypeId = entry.partTypeId
          ..partId = entry.partId;
        row.quantityController.text = entry.quantity.toString();
        _inventoryPartRows.add(row);
      }
      _recalculateEstimatedCost();
    });
  }

  /// One row of the standalone "Inventory Parts (Optional)" section — a
  /// part usage entry with no attached repair. Submitted alongside repair
  /// lines in the same `parts` payload array (see `_buildPayload`); the
  /// backend only splits parts into a separate `inventoryParts` bucket when
  /// that key is present in the request, so appending these to `parts`
  /// keeps the existing repair-line submit path completely unchanged.
  Widget _buildInventoryPartRowCard(int index, _InventoryPartRow row) {
    final restricted = _isCompletedRestrictedEdit;
    final filteredParts = row.partTypeId == null
        ? _parts
        : _parts.where((p) => p.typeId == row.partTypeId).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Part ${index + 1}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, size: 18, color: AppColors.danger),
                tooltip: 'Remove part',
                onPressed: restricted
                    ? null
                    : () {
                        setState(() {
                          _inventoryPartRows.removeAt(index).dispose();
                          _recalculateEstimatedCost();
                        });
                      },
              ),
            ],
          ),
          WebSearchableDropdownField<PartTypeSummary?>(
            label: 'Part Type',
            value: _partTypes.where((t) => t.id == row.partTypeId).firstOrNull,
            items: [null, ..._partTypes],
            itemLabel: (t) => t?.name ?? 'Select',
            hint: 'Select',
            onChanged: restricted
                ? (_) {}
                : (v) => setState(() {
                    row.partTypeId = v?.id;
                    row.partId = null;
                    _recalculateEstimatedCost();
                  }),
          ),
          const SizedBox(height: 8),
          WebSearchableDropdownField<PartSummary?>(
            label: 'Part Name',
            value: filteredParts.where((p) => p.id == row.partId).firstOrNull,
            items: [null, ...filteredParts],
            itemLabel: (p) => p != null
                ? '${p.code} (In Stock: ${p.quantity ?? 0})'
                : 'Select Part',
            hint: 'Select Part',
            onChanged: restricted
                ? (_) {}
                : (v) => setState(() {
                    row.partId = v?.id;
                    _recalculateEstimatedCost();
                  }),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: row.quantityController,
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
            onChanged: (_) => setState(() => _recalculateEstimatedCost()),
          ),
        ],
      ),
    );
  }
}

// ── MODERN UI WIDGETS & SECTIONS ──

/// Web parity for the "View Audit Trail" pill shown in the Work Order
/// Source section header when the work order was opened from a DVIR defect
/// (`CreateWorkOrderDrawer.tsx`'s `EnhancedSectionHeading` action slot).
class _ViewAuditTrailButton extends StatelessWidget {
  const _ViewAuditTrailButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.receipt_long_outlined, size: 15, color: Colors.white),
              SizedBox(width: 5),
              Text(
                'View Audit Trail',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
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

class _ModernSectionCard extends StatelessWidget {
  const _ModernSectionCard({
    super.key,
    this.sectionNumber,
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.children,
  });

  /// Matches web's numbered section headers (1 Work Order Source … 8
  /// Resolution) so the two apps read as the same screen.
  final int? sectionNumber;
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
              if (sectionNumber != null) ...[
                Container(
                  width: 22,
                  height: 22,
                  margin: const EdgeInsets.only(top: 7),
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.chromeBlue,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$sectionNumber',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
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
              color: value != null
                  ? AppColors.textPrimary
                  : AppColors.textSecondary,
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
                  color: isSelected
                      ? pillColor
                      : pillColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? pillColor
                        : pillColor.withValues(alpha: 0.3),
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
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
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
    final hasVin = widget.vin != null && widget.vin!.trim().isNotEmpty;
    final headerText = hasVin
        ? 'SOURCE EVENTS FOR THIS VEHICLE (VIN: ${widget.vin})'
        : 'SOURCE EVENTS FOR THIS VEHICLE';

    if (widget.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          headerText,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        if (widget.events.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.inputFill,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'No linked DVIR defects, fault codes, or pending policy schedules found for this unit.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          )
        else ...[
          Text(
            'Tap an event to link its description into Issue Description.',
            style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          SourceEventsDetailsLink(
            events: widget.events,
            vin: widget.vin,
            unitNumber: widget.unitNumber,
          ),
          const SizedBox(height: 8),
          for (final e in widget.events)
            _EventCard(
              issue: e,
              linked: widget.linkedIds.contains(e.id),
              uploads: widget.uploads[e.id] ?? const [],
              uploadsLoading: widget.uploadsLoading,
              onTap: () => widget.onTap(e),
            ),
        ],
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
      case 'POLICY':
        return 'Pending Schedule';
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
      builder: (_) =>
          _ImagePreviewSheet(uploads: uploads, loading: uploadsLoading),
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
                    Icon(
                      Icons.check_circle,
                      size: 18,
                      color: AppColors.primary,
                    ),
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
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              if ((issue.reportedDate ?? '').isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Reported: ${_formatReportedDate(issue.reportedDate)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
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
    } else if (normalized.contains('complete') ||
        normalized.contains('resolved')) {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF15803D);
    } else if (normalized.contains('not started') ||
        normalized.contains('open')) {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFF92400E);
    } else {
      bg = const Color(0xFFF1F5F9);
      fg = const Color(0xFF475569);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
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
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
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
    final selected = images.isNotEmpty
        ? images[_selectedIndex.clamp(0, images.length - 1)]
        : null;

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
                border: Border.all(
                  color: AppColors.border,
                  style: BorderStyle.solid,
                ),
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
    final display = kmStringToDisplayValue(
      widget.kmController.text,
      widget.unit,
    );
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
      _displayController.text = kmStringToDisplayValue(
        widget.kmController.text,
        widget.unit,
      );
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
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
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
                  prefixIcon: Icon(
                    Icons.speed_rounded,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
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
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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

/// One row of the standalone "Inventory Parts (Optional)" section — a part
/// usage entry not tied to any repair line.
class _InventoryPartRow {
  _InventoryPartRow() : quantityController = TextEditingController(text: '1');

  int? partTypeId;
  int? partId;
  final TextEditingController quantityController;

  void dispose() => quantityController.dispose();
}
