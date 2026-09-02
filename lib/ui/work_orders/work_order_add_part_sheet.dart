import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/core/constants/tax_regions.dart';
import 'package:rapide_nforce/core/utils/app_toast.dart';
import 'package:rapide_nforce/core/utils/part_tax_estimator.dart';
import 'package:rapide_nforce/models/part_models.dart';
import 'package:rapide_nforce/models/work_order_model.dart';
import 'package:rapide_nforce/services/auth_service.dart';
import 'package:rapide_nforce/services/inventory_service.dart';
import 'package:rapide_nforce/services/maintenance_service.dart';
import 'package:rapide_nforce/services/ocr_service.dart';
import 'package:rapide_nforce/ui/widgets/barcode_scanner_sheet.dart';
import 'package:rapide_nforce/ui/widgets/gradient_page_background.dart';
import 'package:rapide_nforce/ui/widgets/part_invoice_upload_documents_sheet.dart';
import 'package:rapide_nforce/ui/widgets/web_form_field.dart';

/// One row to append to the work order's "Inventory Parts (Optional)" list
/// once [showWorkOrderAddPartSheet] resolves — `partTypeId`/`partId` null
/// means "just add a blank dropdown row" (the "Select from Inventory"
/// choice), matching the screen's existing `_InventoryPartRow` shape.
class NewInventoryPartEntry {
  const NewInventoryPartEntry({this.partTypeId, this.partId, this.quantity = 1});

  final int? partTypeId;
  final int? partId;
  final int quantity;
}

/// Result of the Add Part sheet — the caller must adopt [partTypes]/[parts]
/// (freshly reloaded when the sheet created or upserted inventory) before
/// appending [entries], so cost lookups against the refreshed part list work.
class WorkOrderAddPartResult {
  const WorkOrderAddPartResult({
    required this.partTypes,
    required this.parts,
    required this.entries,
  });

  final List<PartTypeSummary> partTypes;
  final List<PartSummary> parts;
  final List<NewInventoryPartEntry> entries;
}

/// Web parity for `AddPartChoiceModal` + `PartInvoiceOcrReviewModal` +
/// `ManualAddPartForm` (`CreateWorkOrderDrawer.tsx`) — a single sheet
/// offering the two ways web's popup adds a part to a work order's
/// Inventory Parts section: scan/browse an invoice via OCR and review the
/// extracted rows, or manually create a brand-new part type/part. (Picking
/// an *existing* part is handled by the work order screen's own always
/// visible quick-add row, not this popup — matching web exactly.) Both
/// paths reuse the same upsert-by-code endpoint as Inventory ▸ Add Part
/// (`InventoryService.createParts` → `POST /maintenance/parts`).
Future<WorkOrderAddPartResult?> showWorkOrderAddPartSheet(
  BuildContext context, {
  required List<PartTypeSummary> partTypes,
}) {
  return Navigator.push<WorkOrderAddPartResult>(
    context,
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _AddPartSheet(partTypes: partTypes),
    ),
  );
}

enum _Step { choice, ocrReview, manual }

/// One editable row shared by the OCR-review and manual-entry steps.
/// [partType] drives the manual step's dropdown; [partTypeNameController]
/// carries the (editable) free-text type name extracted by OCR. Only one of
/// the two is populated depending on which step created the row —
/// [effectivePartTypeName] resolves whichever applies at submit time.
class _PendingPartRow {
  _PendingPartRow({this.selected = true})
      : partTypeNameController = TextEditingController(),
        codeController = TextEditingController(),
        qtyController = TextEditingController(text: '1'),
        costController = TextEditingController();

  PartTypeSummary? partType;
  final TextEditingController partTypeNameController;
  final TextEditingController codeController;
  final TextEditingController qtyController;
  final TextEditingController costController;
  double? totalCostOverride;
  bool selected;

  String get effectivePartTypeName =>
      partType?.name.trim() ?? partTypeNameController.text.trim();

  double get quantity => double.tryParse(qtyController.text.trim()) ?? 0;
  double get cost => double.tryParse(costController.text.trim()) ?? 0;
  double get rowTotal => totalCostOverride ?? (quantity * cost);

  void dispose() {
    partTypeNameController.dispose();
    codeController.dispose();
    qtyController.dispose();
    costController.dispose();
  }
}

class _AddPartSheet extends StatefulWidget {
  const _AddPartSheet({required this.partTypes});

  final List<PartTypeSummary> partTypes;

  @override
  State<_AddPartSheet> createState() => _AddPartSheetState();
}

class _AddPartSheetState extends State<_AddPartSheet> {
  late List<PartTypeSummary> _partTypes = widget.partTypes;

  _Step _step = _Step.choice;
  bool _submitting = false;

  final List<_PendingPartRow> _ocrRows = [];
  final TextEditingController _invoiceNumberController = TextEditingController();
  final TextEditingController _vendorNameController = TextEditingController();
  int? _invoiceFileUploadId;
  bool _selectAll = true;

  final List<_PendingPartRow> _manualRows = [_PendingPartRow()];
  final TextEditingController _manualInvoiceNumberController = TextEditingController();
  final TextEditingController _manualLocalRateController = TextEditingController();
  String? _manualInvoiceFilePath;
  String? _manualInvoiceFileName;
  List<VendorModel> _vendors = [];
  List<PartTaxRateModel> _taxRates = [];
  VendorModel? _selectedVendor;
  bool _loadingManualLookups = false;
  String _destinationCountry = 'CA';
  String _destinationState = 'ON';
  String _originCountry = '';
  String _originState = '';
  bool _taxExempt = false;

  double get _manualSubtotal => _manualRows.fold(0.0, (sum, r) => sum + r.rowTotal);

  @override
  void dispose() {
    for (final row in _ocrRows) {
      row.dispose();
    }
    for (final row in _manualRows) {
      row.dispose();
    }
    _invoiceNumberController.dispose();
    _vendorNameController.dispose();
    _manualInvoiceNumberController.dispose();
    _manualLocalRateController.dispose();
    super.dispose();
  }

  void _close([WorkOrderAddPartResult? result]) => Navigator.pop(context, result);

  // ── Upload Invoice / OCR ──

  /// Opens the shared "Upload Documents" sheet (Document Type + Browse File
  /// gate, web parity for `Documentupload.tsx`'s drawer) and, once the user
  /// submits one or more files there, runs OCR on all of them.
  Future<void> _openUploadDocumentsStep() async {
    final documents = await showPartInvoiceUploadDocumentsSheet(context, maxFiles: 6);
    if (documents == null || documents.isEmpty || !mounted) return;
    await _runOcrExtraction(documents);
  }

  Future<void> _scanInvoiceWithCamera() async {
    try {
      final pages = await CunningDocumentScanner.getPictures(
        noOfPages: 1,
        scannerSource: ScannerSource.camera,
      );
      if (pages == null || pages.isEmpty) return;
      final path = pages.first;
      final name = path.split('/').last;
      await _handlePickedInvoice(path, name.contains('.') ? name : '$name.jpg');
    } catch (e) {
      AppToast.showError('Scanner error: $e');
    }
  }

  void _showExtractingDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: AppColors.card,
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Extracting invoice data…',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handlePickedInvoice(String path, String name) => _runOcrExtraction([
        OcrUploadDocItem(filePath: path, fileName: name, documentType: 'Part Invoice'),
      ]);

  /// Shared OCR pipeline for both the Capture flow (single scanned page)
  /// and the "Upload Documents" step (one or more browsed files) —
  /// mirrors web's `handlePartInvoiceOcrScan`.
  Future<void> _runOcrExtraction(List<OcrUploadDocItem> documents) async {
    _showExtractingDialog();
    final result = await OcrService.instance.uploadAndExtractPartInvoiceOcr(
      documents: documents,
      companyId: AuthService.instance.selectedCompanyId,
    );

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    if (result == null || result.prefill.isEmpty) {
      AppToast.showError(
        'Could not extract data from that invoice — you can still add parts manually.',
      );
      return;
    }

    for (final row in _ocrRows) {
      row.dispose();
    }
    _ocrRows.clear();
    _invoiceFileUploadId = result.invoiceFileUploadId;
    _invoiceNumberController.text = result.prefill.invoiceNumber ?? '';
    _vendorNameController.text = result.prefill.vendorName ?? '';
    _selectAll = true;

    for (final item in result.prefill.items) {
      final row = _PendingPartRow();
      row.partTypeNameController.text = item.partTypeName ?? '';
      row.codeController.text = item.code ?? '';
      final qty = double.tryParse(item.quantity ?? '');
      if (qty != null && qty > 0) {
        row.qtyController.text =
            qty == qty.roundToDouble() ? qty.toInt().toString() : qty.toStringAsFixed(2);
      }
      final cost = double.tryParse(item.cost ?? '');
      if (cost != null) row.costController.text = cost.toStringAsFixed(2);
      final total = double.tryParse(item.totalCost ?? '');
      if (total != null) row.totalCostOverride = total;
      _ocrRows.add(row);
    }

    if (_ocrRows.isEmpty) {
      AppToast.showError('No line items were found on that invoice.');
      return;
    }

    setState(() => _step = _Step.ocrReview);
  }

  void _removeOcrRow(_PendingPartRow row) {
    setState(() {
      _ocrRows.remove(row);
      row.dispose();
    });
  }

  void _toggleSelectAll(bool value) {
    setState(() {
      _selectAll = value;
      for (final row in _ocrRows) {
        row.selected = value;
      }
    });
  }

  // ── Manually Add New Part ──

  /// Loads the Vendor / Tax rate catalogs the "Tax & Shipping Destination"
  /// section needs — same lookups as Inventory ▸ Add Part
  /// (`add_part_screen.dart:_loadLookups`) — before switching into the
  /// manual step, so the dropdowns aren't empty on first paint.
  Future<void> _openManualStep() async {
    setState(() {
      _step = _Step.manual;
      _loadingManualLookups = true;
    });
    final vendorsFuture = InventoryService.instance.fetchVendors();
    final taxRatesFuture = InventoryService.instance.fetchPartTaxRates();
    final vendorsRes = await vendorsFuture;
    final taxRatesRes = await taxRatesFuture;
    if (!mounted) return;
    setState(() {
      _loadingManualLookups = false;
      _vendors = vendorsRes.data ?? [];
      _taxRates = taxRatesRes.data ?? [];
    });
  }

  void _addManualRow() => setState(() => _manualRows.add(_PendingPartRow()));

  void _removeManualRow(_PendingPartRow row) {
    if (_manualRows.length <= 1) return;
    setState(() => _manualRows.remove(row));
    row.dispose();
  }

  Future<void> _scanManualRowCode(_PendingPartRow row) async {
    final value = await showBarcodeScannerSheet(context);
    if (value == null || value.isEmpty) return;
    setState(() => row.codeController.text = value);
  }

  /// Attaches a raw invoice file to the manual submit without running OCR —
  /// mirrors web's `ManualAddPartForm` ("optionally attach an invoice file
  /// (no OCR)"), distinct from the OCR-driven "Upload Invoice" choice card.
  Future<void> _pickManualInvoiceFile() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.first;
    if (file.path == null) return;
    setState(() {
      _manualInvoiceFilePath = file.path;
      _manualInvoiceFileName = file.name;
    });
  }

  void _removeManualInvoiceFile() {
    setState(() {
      _manualInvoiceFilePath = null;
      _manualInvoiceFileName = null;
    });
  }

  Future<void> _openAddPartType(_PendingPartRow row) async {
    final nameController = TextEditingController();
    final triggerController = TextEditingController(text: '5');
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Add Part Type',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Part Type Name *'),
              ),
              TextFormField(
                controller: triggerController,
                decoration: const InputDecoration(labelText: 'Low Stock Trigger'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  if (nameController.text.trim().isEmpty) {
                    AppToast.showError('Enter a part type name');
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                child: const Text('Add Part Type'),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
    if (added != true) return;
    final name = nameController.text.trim();
    final trigger = int.tryParse(triggerController.text.trim()) ?? 5;

    final createdProduct = await InventoryService.instance.createProduct(name: name);
    if (!createdProduct.isSuccess) {
      AppToast.showError(createdProduct.message ?? 'Failed to create part type');
      return;
    }
    final createdType = await InventoryService.instance.createPartType(
      name: name,
      lowStockTrigger: trigger,
    );
    if (!createdType.isSuccess || createdType.data == null) {
      AppToast.showError(createdType.message ?? 'Failed to create part type');
      return;
    }
    final newType = PartTypeSummary(id: createdType.data!.id, name: name);
    if (!mounted) return;
    setState(() {
      _partTypes = [..._partTypes, newType];
      row.partType = newType;
    });
    AppToast.showSuccess('Part type "$name" added');
  }

  // ── Shared submit ──

  Future<int?> _resolveTypeId(String name, Map<String, int> cache) async {
    final key = name.trim().toLowerCase();
    if (key.isEmpty) return null;
    if (cache.containsKey(key)) return cache[key];

    final existing = _partTypes.where((t) => t.name.trim().toLowerCase() == key).firstOrNull;
    if (existing != null) {
      cache[key] = existing.id;
      return existing.id;
    }

    final companyId = AuthService.instance.selectedCompanyIdInt;
    final createdProduct =
        await InventoryService.instance.createProduct(name: name.trim(), companyId: companyId);
    if (!createdProduct.isSuccess) return null;
    final createdType = await InventoryService.instance.createPartType(
      name: name.trim(),
      lowStockTrigger: 5,
      companyId: companyId,
    );
    if (createdType.isSuccess && createdType.data != null && createdType.data!.id > 0) {
      cache[key] = createdType.data!.id;
      _partTypes = [..._partTypes, PartTypeSummary(id: createdType.data!.id, name: name.trim())];
      return createdType.data!.id;
    }
    return null;
  }

  Future<void> _submitRows(
    List<_PendingPartRow> rows, {
    String? invoiceNumber,
    String? vendorName,
    int? partVendorId,
    int? invoiceFileUploadId,
    String? invoiceFilePath,
    String destinationCountry = 'CA',
    String destinationState = 'ON',
    String? originCountry,
    String? originState,
    bool taxExempt = false,
    double? additionalLocalRate,
  }) async {
    final codes = <String>{};
    for (final row in rows) {
      if (row.effectivePartTypeName.isEmpty) {
        AppToast.showError('Enter a Part Type for every row.');
        return;
      }
      final code = row.codeController.text.trim();
      if (code.isEmpty) {
        AppToast.showError('Enter a Code for every row.');
        return;
      }
      if (!codes.add(code.toLowerCase())) {
        AppToast.showError('Duplicate part code: $code');
        return;
      }
      final qty = int.tryParse(row.qtyController.text.trim());
      if (qty == null || qty < 1) {
        AppToast.showError('Enter a valid quantity for code "$code".');
        return;
      }
    }

    setState(() => _submitting = true);

    final cache = <String, int>{};
    final drafts = <PartDraft>[];
    final companyId = AuthService.instance.selectedCompanyIdInt;
    final trimmedInvoiceNumber = (invoiceNumber ?? '').trim();
    final trimmedVendorName = (vendorName ?? '').trim();

    for (final row in rows) {
      final typeId = await _resolveTypeId(row.effectivePartTypeName, cache);
      if (typeId == null) {
        if (!mounted) return;
        setState(() => _submitting = false);
        AppToast.showError('Could not resolve part type "${row.effectivePartTypeName}".');
        return;
      }
      final qty = int.parse(row.qtyController.text.trim());
      final cost = double.tryParse(row.costController.text.trim());
      final total = row.totalCostOverride ??
          (cost != null ? double.parse((qty * cost).toStringAsFixed(2)) : null);

      drafts.add(PartDraft(
        typeId: typeId,
        code: row.codeController.text.trim(),
        quantity: qty,
        cost: cost,
        totalCost: total,
        invoiceNumber: trimmedInvoiceNumber.isEmpty ? null : trimmedInvoiceNumber,
        vendorName: trimmedVendorName.isEmpty ? null : trimmedVendorName,
        partVendorId: partVendorId,
        companyId: companyId,
        destinationCountry: destinationCountry,
        destinationState: destinationState,
        originCountry: (originCountry ?? '').isEmpty ? null : originCountry,
        originState: (originState ?? '').isEmpty ? null : originState,
        taxExempt: taxExempt,
        additionalLocalRate: destinationCountry == 'US' ? additionalLocalRate : null,
      ));
    }

    final created = await InventoryService.instance.createParts(
      parts: drafts,
      invoiceFilePath: invoiceFileUploadId == null ? invoiceFilePath : null,
      invoiceFileUploadId: invoiceFileUploadId,
      companyId: companyId,
    );

    if (!mounted) return;
    if (!created.isSuccess) {
      setState(() => _submitting = false);
      AppToast.showError(created.message ?? 'Failed to add parts.');
      return;
    }

    final refreshed = await MaintenanceService.instance.getPartsSummary(companyId: companyId);
    if (!mounted) return;
    setState(() => _submitting = false);

    if (!refreshed.isSuccess || refreshed.data == null) {
      AppToast.showError(
        'Parts were created, but the list could not be refreshed. Reopen the form to reload.',
      );
      return;
    }

    final freshTypes = refreshed.data!.types;
    final freshParts = refreshed.data!.parts;

    final entries = <NewInventoryPartEntry>[];
    for (final row in rows) {
      if (!row.selected) continue;
      final code = row.codeController.text.trim().toLowerCase();
      final match = freshParts.where((p) => p.code.trim().toLowerCase() == code).firstOrNull;
      if (match == null) continue;
      final qty = int.tryParse(row.qtyController.text.trim()) ?? 1;
      entries.add(NewInventoryPartEntry(partTypeId: match.typeId, partId: match.id, quantity: qty));
    }

    AppToast.showSuccess(
      entries.isNotEmpty
          ? '${drafts.length} part${drafts.length == 1 ? '' : 's'} added to inventory. '
              '${entries.length} added to this work order.'
          : '${drafts.length} part${drafts.length == 1 ? '' : 's'} added to inventory.',
    );

    _close(WorkOrderAddPartResult(partTypes: freshTypes, parts: freshParts, entries: entries));
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    return GradientPageBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(icon: const Icon(Icons.close), onPressed: () => _close()),
          title: Text(
            switch (_step) {
              _Step.choice => 'Add Part',
              _Step.ocrReview => 'Review Extracted Parts',
              _Step.manual => 'Manually Add Part',
            },
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          leadingWidth: _step == _Step.choice ? null : 72,
          actions: _step == _Step.choice
              ? null
              : [
                  TextButton(
                    onPressed: () => setState(() => _step = _Step.choice),
                    child: const Text('Back'),
                  ),
                ],
        ),
        body: SafeArea(
          child: switch (_step) {
            _Step.choice => _buildChoiceStep(),
            _Step.ocrReview => _buildOcrReviewStep(),
            _Step.manual => _buildManualStep(),
          },
        ),
      ),
    );
  }

  Widget _buildChoiceStep() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Choose how you want to add parts to this work order.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 20),
        _ChoiceCard(
          icon: Icons.file_upload_outlined,
          title: 'Upload Invoice',
          subtitle:
              'Upload or scan an invoice and we\'ll extract the parts details using OCR.',
          onTap: null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                onPressed: _openUploadDocumentsStep,
                icon: const Icon(Icons.description_outlined, size: 16),
                label: const Text('Browse'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _scanInvoiceWithCamera,
                icon: const Icon(Icons.camera_alt_outlined, size: 16),
                label: const Text('Capture'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _ChoiceCard(
          icon: Icons.add_box_outlined,
          title: 'Manually Add New Part',
          subtitle: 'Create a brand-new part type/part and add it to this work order.',
          onTap: _openManualStep,
        ),
      ],
    );
  }

  Widget _buildOcrReviewStep() {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            children: [
              TextFormField(
                controller: _invoiceNumberController,
                decoration: InputDecoration(
                  labelText: 'Invoice Number',
                  filled: true,
                  fillColor: AppColors.inputFill,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _vendorNameController,
                decoration: InputDecoration(
                  labelText: 'Vendor Name',
                  filled: true,
                  fillColor: AppColors.inputFill,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Checkbox(
                    value: _selectAll,
                    onChanged: (v) => _toggleSelectAll(v ?? false),
                  ),
                  Expanded(
                    child: Text(
                      'Check rows to add those parts to this work order. All rows are '
                      'still added to inventory either way.',
                      style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
              for (final row in List<_PendingPartRow>.from(_ocrRows))
                _buildOcrRowCard(row),
            ],
          ),
        ),
        _buildSubmitBar(
          label: 'Add to Work Order',
          onPressed: _ocrRows.isEmpty
              ? null
              : () => _submitRows(
                    _ocrRows,
                    invoiceNumber: _invoiceNumberController.text,
                    vendorName: _vendorNameController.text,
                    invoiceFileUploadId: _invoiceFileUploadId,
                  ),
        ),
      ],
    );
  }

  Widget _buildOcrRowCard(_PendingPartRow row) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Checkbox(
                value: row.selected,
                onChanged: (v) => setState(() => row.selected = v ?? false),
              ),
              Expanded(
                child: TextFormField(
                  controller: row.partTypeNameController,
                  decoration: const InputDecoration(labelText: 'Part Type *', isDense: true),
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, size: 18, color: AppColors.danger),
                tooltip: 'Remove row',
                onPressed: () => _removeOcrRow(row),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: TextFormField(
                    controller: row.codeController,
                    decoration: const InputDecoration(labelText: 'Code *', isDense: true),
                  ),
                ),
              ),
              Expanded(
                child: TextFormField(
                  controller: row.qtyController,
                  decoration: const InputDecoration(labelText: 'Qty *', isDense: true),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => row.totalCostOverride = null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: TextFormField(
                    controller: row.costController,
                    decoration:
                        const InputDecoration(labelText: 'Cost per qty', isDense: true),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() => row.totalCostOverride = null),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Total: \$${row.rowTotal.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildManualStep() {
    if (_loadingManualLookups) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            children: [
              Text(
                'PARTS TO ADD',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),
              for (var i = 0; i < _manualRows.length; i++)
                _buildManualRowCard(_manualRows[i], i),
              OutlinedButton.icon(
                onPressed: _addManualRow,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Row'),
              ),
              const SizedBox(height: 20),
              Text(
                'UPLOAD INVOICE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),
              if (_manualInvoiceFileName == null)
                OutlinedButton.icon(
                  onPressed: _pickManualInvoiceFile,
                  icon: const Icon(Icons.file_upload_outlined, size: 18),
                  label: const Text('Browse files'),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.inputFill,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.description_outlined, size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _manualInvoiceFileName!,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: _removeManualInvoiceFile,
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 6),
              Text(
                'Optionally attach the source invoice file (no OCR).',
                style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _manualInvoiceNumberController,
                decoration: InputDecoration(
                  labelText: 'Invoice Number',
                  filled: true,
                  fillColor: AppColors.inputFill,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              WebSearchableDropdownField<VendorModel?>(
                label: 'Vendor',
                value: _selectedVendor,
                items: [null, ..._vendors],
                itemLabel: (v) => v?.name ?? 'Select vendor',
                hint: 'Select vendor',
                onChanged: (v) => setState(() => _selectedVendor = v),
              ),
              const SizedBox(height: 8),
              Text(
                'TAX & SHIPPING DESTINATION',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),
              WebDropdownField<String>(
                label: 'Ship-to Country',
                value: _destinationCountry,
                items: const ['CA', 'US'],
                itemLabel: (c) => c == 'CA' ? 'Canada (CA)' : 'United States (US)',
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _destinationCountry = v;
                    _destinationState = v == 'US' ? 'TX' : 'ON';
                  });
                },
              ),
              WebSearchableDropdownField<String>(
                label: 'Ship-to State/Province',
                value: _destinationState,
                items: (_destinationCountry == 'US' ? kUsStates : kCaProvinces)
                    .map((o) => o.value)
                    .toList(),
                itemLabel: (code) => (_destinationCountry == 'US' ? kUsStates : kCaProvinces)
                    .firstWhere((o) => o.value == code, orElse: () => TaxRegionOption(code, code))
                    .label,
                onChanged: (v) => setState(() => _destinationState = v ?? _destinationState),
              ),
              Row(
                children: [
                  Checkbox(
                    value: _taxExempt,
                    onChanged: (v) => setState(() => _taxExempt = v ?? false),
                  ),
                  Text('Tax Exempt', style: TextStyle(color: AppColors.textPrimary)),
                ],
              ),
              if (_destinationCountry == 'US') ...[
                TextFormField(
                  controller: _manualLocalRateController,
                  decoration: InputDecoration(
                    labelText: 'Additional Local Rate (e.g. 0.02)',
                    filled: true,
                    fillColor: AppColors.inputFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 12),
                  child: Text(
                    'Only for US places where local tax applies. Enter as decimal.',
                    style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                  ),
                ),
              ],
              WebDropdownField<String>(
                label: 'Origin Country (Optional)',
                value: _originCountry.isEmpty ? null : _originCountry,
                items: const ['CA', 'US'],
                itemLabel: (c) => c == 'CA' ? 'Canada (CA)' : 'United States (US)',
                hint: 'Select origin country...',
                onChanged: (v) => setState(() {
                  _originCountry = v ?? '';
                  _originState = '';
                }),
              ),
              if (_originCountry.isNotEmpty)
                WebSearchableDropdownField<String>(
                  label: 'Origin State/Province (Optional)',
                  value: _originState.isEmpty ? null : _originState,
                  items: (_originCountry == 'US' ? kUsStates : kCaProvinces)
                      .map((o) => o.value)
                      .toList(),
                  itemLabel: (code) => (_originCountry == 'US' ? kUsStates : kCaProvinces)
                      .firstWhere((o) => o.value == code, orElse: () => TaxRegionOption(code, code))
                      .label,
                  hint: 'Select origin state/province...',
                  onChanged: (v) => setState(() => _originState = v ?? ''),
                ),
              if (_manualSubtotal > 0) _buildManualTaxSummary(),
            ],
          ),
        ),
        _buildSubmitBar(
          label: 'Add Part${_manualRows.length > 1 ? 's' : ''}',
          onPressed: () => _submitRows(
            _manualRows,
            invoiceNumber: _manualInvoiceNumberController.text,
            vendorName: _selectedVendor?.name,
            partVendorId: _selectedVendor?.id,
            invoiceFilePath: _manualInvoiceFilePath,
            destinationCountry: _destinationCountry,
            destinationState: _destinationState,
            originCountry: _originCountry,
            originState: _originState,
            taxExempt: _taxExempt,
            additionalLocalRate: double.tryParse(_manualLocalRateController.text.trim()),
          ),
        ),
      ],
    );
  }

  Widget _buildManualTaxSummary() {
    final estimate = PartTaxEstimator.estimate(
      subtotal: _manualSubtotal,
      destinationCountry: _destinationCountry,
      destinationState: _destinationState,
      originCountry: _originCountry,
      taxExempt: _taxExempt,
      additionalLocalRate: _destinationCountry == 'US'
          ? (double.tryParse(_manualLocalRateController.text.trim()) ?? 0)
          : 0,
      taxRates: _taxRates,
    );
    final total = _manualSubtotal + estimate.taxAmount;

    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ESTIMATED TAX SUMMARY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          _summaryRow('Subtotal:', '\$${_manualSubtotal.toStringAsFixed(2)}'),
          _summaryRow(
            'Estimated Tax (${estimate.taxType} ${(estimate.taxRate * 100).toStringAsFixed(1)}%):',
            '\$${estimate.taxAmount.toStringAsFixed(2)}',
          ),
          const Divider(height: 20),
          _summaryRow('Total (Est.):', '\$${total.toStringAsFixed(2)}', bold: true),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: bold ? 14 : 12,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: bold ? 14 : 12,
                fontWeight: FontWeight.w800,
                color: bold ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      );

  Widget _buildManualRowCard(_PendingPartRow row, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Part ${index + 1}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              if (_manualRows.length > 1)
                IconButton(
                  icon: Icon(Icons.delete_outline, size: 20, color: AppColors.danger),
                  tooltip: 'Remove row',
                  onPressed: () => _removeManualRow(row),
                ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: WebSearchableDropdownField<PartTypeSummary?>(
                  label: 'Part Type *',
                  value: row.partType,
                  items: [null, ..._partTypes],
                  itemLabel: (t) => t?.name ?? 'Select Part Type',
                  hint: 'Select Part Type',
                  onChanged: (v) => setState(() => row.partType = v),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                color: AppColors.primary,
                tooltip: 'Add new part type',
                onPressed: () => _openAddPartType(row),
              ),
            ],
          ),
          TextFormField(
            controller: row.codeController,
            decoration: InputDecoration(
              labelText: 'Code *',
              filled: true,
              fillColor: AppColors.inputFill,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.border),
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.qr_code_scanner),
                tooltip: 'Scan barcode',
                onPressed: () => _scanManualRowCode(row),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: TextFormField(
                    controller: row.qtyController,
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
                    onChanged: (_) => setState(() => row.totalCostOverride = null),
                  ),
                ),
              ),
              Expanded(
                child: TextFormField(
                  controller: row.costController,
                  decoration: InputDecoration(
                    labelText: 'Cost per qty',
                    filled: true,
                    fillColor: AppColors.inputFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() => row.totalCostOverride = null),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Cost',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  '\$${row.rowTotal.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitBar({required String label, required VoidCallback? onPressed}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: FilledButton(
          onPressed: _submitting ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: _submitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(height: 10),
                    trailing!,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
