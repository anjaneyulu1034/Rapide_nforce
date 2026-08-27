import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/core/constants/tax_regions.dart';
import 'package:rapide_nforce/core/utils/app_toast.dart';
import 'package:rapide_nforce/core/utils/part_tax_estimator.dart';
import 'package:rapide_nforce/models/part_models.dart';
import 'package:rapide_nforce/services/auth_service.dart';
import 'package:rapide_nforce/services/inventory_service.dart';
import 'package:rapide_nforce/services/ocr_service.dart';
import 'package:rapide_nforce/ui/widgets/barcode_scanner_sheet.dart';
import 'package:rapide_nforce/ui/widgets/web_form_field.dart';
import 'package:rapide_nforce/ui/widgets/web_ui.dart';

/// Mutable state for one row of the "Parts to Add" grid. Owned by
/// [_AddPartScreenState] for the lifetime of the screen — controllers are
/// created once per row and disposed when the row is removed or the screen
/// closes.
class _PartRow {
  _PartRow({required this.id});

  final String id;
  ProductModel? product;
  final TextEditingController codeController = TextEditingController();
  final TextEditingController qtyController = TextEditingController(text: '1');
  final TextEditingController costController = TextEditingController();

  /// Set when an OCR-extracted line item supplied an explicit total —
  /// cleared as soon as the user edits quantity or cost (mirrors web's
  /// `delete next.totalCost` on row edit).
  double? totalCostOverride;

  /// Set after a failed submit if the server reports this row's code as a
  /// duplicate already in inventory.
  String? codeError;

  double get quantity => double.tryParse(qtyController.text.trim()) ?? 0;
  double get cost => double.tryParse(costController.text.trim()) ?? 0;
  double get rowTotal => totalCostOverride ?? (quantity * cost);

  bool get isPristine =>
      product == null && codeController.text.trim().isEmpty && costController.text.trim().isEmpty;

  void dispose() {
    codeController.dispose();
    qtyController.dispose();
    costController.dispose();
  }
}

/// Multi-row "Add Part" screen for Inventory ▸ Parts — full parity with the
/// web app's Add Part drawer (`InventoryTab.tsx`): dynamic part rows with
/// barcode scan, invoice upload with OCR auto-fill, vendor selection, and a
/// live "Estimated Tax Summary" preview ahead of a Tax & Shipping
/// Destination section. Edit Part (`PartFormScreen`) is unchanged — it
/// stays a simpler single-part form, matching how the web app treats Add
/// and Edit differently.
class AddPartScreen extends StatefulWidget {
  const AddPartScreen({super.key});

  @override
  State<AddPartScreen> createState() => _AddPartScreenState();
}

class _AddPartScreenState extends State<AddPartScreen> {
  final List<_PartRow> _rows = [];
  int _rowIdCounter = 0;

  List<ProductModel> _products = [];
  List<PartTypeModel> _partTypes = [];
  List<VendorModel> _vendors = [];
  List<PartTaxRateModel> _taxRates = [];
  bool _loadingLookups = true;

  final TextEditingController _invoiceController = TextEditingController();
  final TextEditingController _localRateController = TextEditingController();

  VendorModel? _selectedVendor;
  String? _ocrVendorNameUnmatched;

  String? _invoiceFilePath;
  String? _invoiceFileName;
  int? _invoiceFileUploadId;

  // Ship-to defaults to CA/ON (web defaults from the company's own address —
  // skipped here to avoid a CarrierModel addition for a value the user can
  // change in two taps).
  String _destinationCountry = 'CA';
  String _destinationState = 'ON';
  String _originCountry = '';
  String _originState = '';
  bool _taxExempt = false;

  bool _saving = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _rows.add(_PartRow(id: _nextRowId()));
    _loadLookups();
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    _invoiceController.dispose();
    _localRateController.dispose();
    super.dispose();
  }

  String _nextRowId() => 'row_${_rowIdCounter++}';

  double get _subtotal => _rows.fold(0.0, (sum, r) => sum + r.rowTotal);

  Future<void> _loadLookups() async {
    final productsFuture = InventoryService.instance.fetchProducts();
    final partTypesFuture = InventoryService.instance.fetchPartTypes(page: 1, limit: 1000);
    final vendorsFuture = InventoryService.instance.fetchVendors();
    final taxRatesFuture = InventoryService.instance.fetchPartTaxRates();

    final productsResult = await productsFuture;
    final partTypesResult = await partTypesFuture;
    final vendorsResult = await vendorsFuture;
    final taxRatesResult = await taxRatesFuture;

    if (!mounted) return;
    setState(() {
      _loadingLookups = false;
      _products = productsResult.data ?? [];
      _partTypes = partTypesResult.data?.items ?? [];
      _vendors = vendorsResult.data ?? [];
      _taxRates = taxRatesResult.data ?? [];
    });
  }

  void _addRow() => setState(() => _rows.add(_PartRow(id: _nextRowId())));

  void _removeRow(_PartRow row) {
    if (_rows.length <= 1) return;
    setState(() => _rows.remove(row));
    row.dispose();
  }

  Future<void> _scanRowCode(_PartRow row) async {
    final value = await showBarcodeScannerSheet(context);
    if (value == null || value.isEmpty) return;
    final alreadyUsed =
        _rows.any((r) => r != row && r.codeController.text.trim() == value);
    if (alreadyUsed) {
      AppToast.showError('Code "$value" is already used by another row.');
      return;
    }
    setState(() {
      row.codeController.text = value;
      row.codeError = null;
    });
  }

  Future<void> _openAddPartType(_PartRow row) async {
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
              WebTextFormField(controller: nameController, label: 'Part Type Name *'),
              WebTextFormField(
                controller: triggerController,
                label: 'Low Stock Trigger',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              WebPrimaryButton(
                label: 'Add Part Type',
                onPressed: () {
                  if (nameController.text.trim().isEmpty) {
                    AppToast.showError('Enter a part type name');
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
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

    final created = await InventoryService.instance.createProduct(name: name);
    if (!created.isSuccess || created.data == null) {
      AppToast.showError(created.message ?? 'Failed to create part type');
      return;
    }
    await InventoryService.instance.createPartType(name: name, lowStockTrigger: trigger);
    if (!mounted) return;
    setState(() {
      _products = [..._products, created.data!];
      row.product = created.data;
    });
    AppToast.showSuccess('Part type "$name" added');
  }

  // ── Upload Invoice / OCR ──

  Future<void> _pickInvoiceFile() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.first;
    if (file.path == null) return;
    await _handlePickedInvoice(file.path!, file.name);
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

  void _removeInvoiceFile() {
    setState(() {
      _invoiceFilePath = null;
      _invoiceFileName = null;
      _invoiceFileUploadId = null;
    });
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

  Future<void> _handlePickedInvoice(String path, String name) async {
    setState(() {
      _invoiceFilePath = path;
      _invoiceFileName = name;
      _invoiceFileUploadId = null;
    });

    _showExtractingDialog();
    final result = await OcrService.instance.uploadAndExtractPartInvoiceOcr(
      documents: [
        OcrUploadDocItem(filePath: path, fileName: name, documentType: 'Part Invoice'),
      ],
      companyId: AuthService.instance.selectedCompanyId,
    );

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    if (result == null) {
      AppToast.showError(
        'Could not auto-fill from the invoice — you can still enter parts manually.',
      );
      return;
    }
    _invoiceFileUploadId = result.invoiceFileUploadId;
    await _applyInvoicePrefill(result.prefill);
    if (!mounted) return;
    AppToast.showSuccess('Invoice scanned — review the auto-filled rows below.');
  }

  Future<void> _applyInvoicePrefill(PartInvoiceOcrPrefill prefill) async {
    final newRows = <_PartRow>[];
    for (final item in prefill.items) {
      final row = _PartRow(id: _nextRowId());
      if ((item.code ?? '').isNotEmpty) row.codeController.text = item.code!;
      final qty = double.tryParse(item.quantity ?? '');
      if (qty != null && qty > 0) {
        row.qtyController.text =
            qty == qty.roundToDouble() ? qty.toInt().toString() : qty.toStringAsFixed(2);
      }
      final cost = double.tryParse(item.cost ?? '');
      if (cost != null) row.costController.text = cost.toStringAsFixed(2);
      final total = double.tryParse(item.totalCost ?? '');
      if (total != null) row.totalCostOverride = total;

      final typeName = item.partTypeName?.trim();
      if (typeName != null && typeName.isNotEmpty) {
        final match =
            _products.where((p) => p.name.toLowerCase() == typeName.toLowerCase()).firstOrNull;
        if (match != null) {
          row.product = match;
        } else {
          final created = await InventoryService.instance.createProduct(name: typeName);
          if (created.isSuccess && created.data != null) {
            await InventoryService.instance.createPartType(name: typeName, lowStockTrigger: 5);
            _products = [..._products, created.data!];
            row.product = created.data;
          }
        }
      }
      newRows.add(row);
    }

    if (!mounted) return;
    setState(() {
      final invoiceNum = prefill.invoiceNumber;
      if (_invoiceController.text.trim().isEmpty && (invoiceNum ?? '').isNotEmpty) {
        _invoiceController.text = invoiceNum!;
      }

      final vendorFromOcr = prefill.vendorName;
      if (_selectedVendor == null &&
          _ocrVendorNameUnmatched == null &&
          (vendorFromOcr ?? '').isNotEmpty) {
        final match =
            _vendors.where((v) => v.name.toLowerCase() == vendorFromOcr!.toLowerCase()).firstOrNull;
        if (match != null) {
          _selectedVendor = match;
        } else {
          _ocrVendorNameUnmatched = vendorFromOcr;
        }
      }

      if (newRows.isNotEmpty) {
        if (_rows.length == 1 && _rows.first.isPristine) {
          _rows.removeAt(0).dispose();
        }
        _rows.addAll(newRows);
      }
    });
  }

  // ── Submit ──

  Future<int?> _resolveTypeId(String productName, Map<String, int> cache) async {
    final key = productName.trim().toLowerCase();
    if (cache.containsKey(key)) return cache[key];

    final existing = _partTypes.where((t) => t.name.trim().toLowerCase() == key).firstOrNull;
    if (existing != null) {
      cache[key] = existing.id;
      return existing.id;
    }

    final created =
        await InventoryService.instance.createPartType(name: productName, lowStockTrigger: 5);
    if (created.isSuccess && created.data != null && created.data!.id > 0) {
      cache[key] = created.data!.id;
      _partTypes = [..._partTypes, created.data!];
      return created.data!.id;
    }

    final refreshed = await InventoryService.instance.fetchPartTypes(page: 1, limit: 1000);
    final match = refreshed.data?.items.where((t) => t.name.trim().toLowerCase() == key).firstOrNull;
    if (match != null) {
      _partTypes = refreshed.data!.items;
      cache[key] = match.id;
      return match.id;
    }
    return null;
  }

  Future<void> _submit() async {
    setState(() => _submitError = null);

    final codes = <String>{};
    for (final row in _rows) {
      row.codeError = null;
      final code = row.codeController.text.trim();
      if (code.isEmpty) {
        setState(() => _submitError = 'Every row needs a Code.');
        return;
      }
      if (!codes.add(code.toLowerCase())) {
        setState(() => _submitError = 'Duplicate part code found: $code');
        return;
      }
      final qty = int.tryParse(row.qtyController.text.trim());
      if (qty == null || qty < 1) {
        setState(() => _submitError = 'Enter a valid quantity (1 or more) for code "$code".');
        return;
      }
      if (row.product == null) {
        setState(() => _submitError = 'Select a part type for code "$code".');
        return;
      }
    }

    setState(() => _saving = true);

    final cache = <String, int>{};
    final drafts = <PartDraft>[];
    final companyId = AuthService.instance.selectedCompanyIdInt;
    final vendorName = _selectedVendor?.name ?? _ocrVendorNameUnmatched;
    final invoiceNumber = _invoiceController.text.trim();
    final localRate = double.tryParse(_localRateController.text.trim());

    for (final row in _rows) {
      final typeId = await _resolveTypeId(row.product!.name, cache);
      if (typeId == null) {
        if (!mounted) return;
        setState(() {
          _saving = false;
          _submitError = 'Could not resolve part type "${row.product!.name}".';
        });
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
        invoiceNumber: invoiceNumber.isEmpty ? null : invoiceNumber,
        vendorName: vendorName,
        partVendorId: _selectedVendor?.id,
        companyId: companyId,
        destinationCountry: _destinationCountry,
        destinationState: _destinationState,
        originCountry: _originCountry.isEmpty ? null : _originCountry,
        originState: _originState.isEmpty ? null : _originState,
        taxExempt: _taxExempt,
        additionalLocalRate: _destinationCountry == 'US' ? localRate : null,
      ));
    }

    final result = await InventoryService.instance.createParts(
      parts: drafts,
      invoiceFilePath: _invoiceFileUploadId == null ? _invoiceFilePath : null,
      invoiceFileUploadId: _invoiceFileUploadId,
      companyId: companyId,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (!result.isSuccess) {
      final message = result.message ?? 'Failed to create parts.';
      final dupMatch =
          RegExp(r"Part with code '([^']+)' already exists", caseSensitive: false).firstMatch(message);
      if (dupMatch != null) {
        final dupCode = dupMatch.group(1);
        final row = _rows.where((r) => r.codeController.text.trim() == dupCode).firstOrNull;
        setState(() {
          row?.codeError = 'Code already exists in inventory.';
          _submitError = message;
        });
      } else {
        setState(() => _submitError = message);
      }
      AppToast.showError(message);
      return;
    }

    AppToast.showSuccess('${drafts.length} part(s) created successfully.');
    Navigator.pop(context, true);
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Add Part')),
      body: WebPageBody(
        child: _loadingLookups
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  WebFormSection(
                    title: 'Parts to Add',
                    initiallyExpanded: true,
                    children: [
                      for (var i = 0; i < _rows.length; i++)
                        _PartRowCard(
                          row: _rows[i],
                          index: i,
                          products: _products,
                          productsLoading: _loadingLookups,
                          canRemove: _rows.length > 1,
                          onRemove: () => _removeRow(_rows[i]),
                          onProductChanged: (v) => setState(() => _rows[i].product = v),
                          onAddType: () => _openAddPartType(_rows[i]),
                          onScan: () => _scanRowCode(_rows[i]),
                          onFieldChanged: () => setState(() {}),
                        ),
                      OutlinedButton.icon(
                        onPressed: _addRow,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Row'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                  WebFormSection(
                    title: 'Upload Invoice',
                    initiallyExpanded: true,
                    children: [
                      WebFileUploadZone(
                        fileName: _invoiceFileName,
                        filePath: _invoiceFilePath,
                        onBrowse: _pickInvoiceFile,
                        onScan: _scanInvoiceWithCamera,
                        subtitle: 'Click to browse files.\n'
                            'Supported formats: images (JPG, PNG) and PDF.',
                      ),
                      if (_invoiceFileName != null)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: _removeInvoiceFile,
                            icon: const Icon(Icons.close, size: 16),
                            label: const Text('Remove'),
                          ),
                        ),
                      const SizedBox(height: 6),
                      Text(
                        'Uploading an invoice will attempt to auto-fill part rows above via OCR.',
                        style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      WebTextFormField(
                        controller: _invoiceController,
                        label: 'Invoice Number',
                        hint: 'Enter invoice number',
                      ),
                      WebSearchableDropdownField<VendorModel?>(
                        label: 'Vendor',
                        value: _selectedVendor,
                        items: [null, ..._vendors],
                        itemLabel: (v) => v?.name ?? 'Select vendor',
                        hint: 'Select vendor',
                        onChanged: (v) => setState(() {
                          _selectedVendor = v;
                          if (v != null) _ocrVendorNameUnmatched = null;
                        }),
                      ),
                      if (_selectedVendor == null && _ocrVendorNameUnmatched != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            'From invoice: $_ocrVendorNameUnmatched '
                            '(no matching vendor record — pick one above if available).',
                            style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                          ),
                        ),
                    ],
                  ),
                  WebFormSection(
                    title: 'Tax & Shipping Destination',
                    initiallyExpanded: true,
                    children: [
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
                        WebTextFormField(
                          controller: _localRateController,
                          label: 'Additional Local Rate (e.g. 0.02)',
                          hint: '0.00',
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => setState(() {}),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12, top: 0),
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
                    ],
                  ),
                  if (_subtotal > 0) _buildTaxSummary(),
                  if (_submitError != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        _submitError!,
                        style: const TextStyle(color: AppColors.danger, fontSize: 12.5),
                      ),
                    ),
                  WebPrimaryButton(
                    label: 'Create Part${_rows.length > 1 ? 's' : ''}',
                    loading: _saving,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 20),
                ],
              ),
      ),
    );
  }

  Widget _buildTaxSummary() {
    final estimate = PartTaxEstimator.estimate(
      subtotal: _subtotal,
      destinationCountry: _destinationCountry,
      destinationState: _destinationState,
      originCountry: _originCountry,
      taxExempt: _taxExempt,
      additionalLocalRate: _destinationCountry == 'US'
          ? (double.tryParse(_localRateController.text.trim()) ?? 0)
          : 0,
      taxRates: _taxRates,
    );
    final total = _subtotal + estimate.taxAmount;

    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 16),
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
          _summaryRow('Subtotal:', '\$${_subtotal.toStringAsFixed(2)}'),
          _summaryRow(
            'Estimated Tax (${estimate.taxType} ${(estimate.taxRate * 100).toStringAsFixed(1)}%):',
            '\$${estimate.taxAmount.toStringAsFixed(2)}',
          ),
          const Divider(height: 20),
          _summaryRow('Total (Est.):', '\$${total.toStringAsFixed(2)}', bold: true),
          const SizedBox(height: 8),
          Text(
            'This is an estimated preview. Final tax calculation is finalized and '
            'stored upon submit.',
            style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
          ),
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
}

class _PartRowCard extends StatelessWidget {
  const _PartRowCard({
    required this.row,
    required this.index,
    required this.products,
    required this.productsLoading,
    required this.canRemove,
    required this.onRemove,
    required this.onProductChanged,
    required this.onAddType,
    required this.onScan,
    required this.onFieldChanged,
  });

  final _PartRow row;
  final int index;
  final List<ProductModel> products;
  final bool productsLoading;
  final bool canRemove;
  final VoidCallback onRemove;
  final ValueChanged<ProductModel?> onProductChanged;
  final VoidCallback onAddType;
  final VoidCallback onScan;
  final VoidCallback onFieldChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: row.codeError != null
              ? AppColors.danger.withValues(alpha: 0.5)
              : AppColors.border,
        ),
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
              if (canRemove)
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.danger),
                  tooltip: 'Remove row',
                  onPressed: onRemove,
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: WebSearchableDropdownField<ProductModel?>(
                  label: 'Part Type Name *',
                  value: row.product,
                  items: [null, ...products],
                  itemLabel: (p) => p?.name ?? 'Select Part Type',
                  hint: 'Select Part Type',
                  isLoading: productsLoading,
                  onChanged: onProductChanged,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  color: AppColors.primary,
                  tooltip: 'Add new part type',
                  onPressed: onAddType,
                ),
              ),
            ],
          ),
          WebTextFormField(
            controller: row.codeController,
            label: 'Code *',
            hint: 'e.g., TEST-TEST',
            suffix: IconButton(
              icon: const Icon(Icons.qr_code_scanner),
              tooltip: 'Scan barcode',
              onPressed: onScan,
            ),
            onChanged: (_) {
              row.codeError = null;
              onFieldChanged();
            },
          ),
          if (row.codeError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8, top: 0),
              child: Text(
                row.codeError!,
                style: const TextStyle(color: AppColors.danger, fontSize: 11.5),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: WebTextFormField(
                  controller: row.qtyController,
                  label: 'Quantity *',
                  keyboardType: TextInputType.number,
                  onChanged: (_) {
                    row.totalCostOverride = null;
                    onFieldChanged();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: WebTextFormField(
                  controller: row.costController,
                  label: 'Cost per qty',
                  hint: '0.00',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) {
                    row.totalCostOverride = null;
                    onFieldChanged();
                  },
                ),
              ),
            ],
          ),
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
}
