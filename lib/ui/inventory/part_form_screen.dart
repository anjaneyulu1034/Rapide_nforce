import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/core/utils/app_toast.dart';
import 'package:rapide_nforce/models/part_models.dart';
import 'package:rapide_nforce/services/inventory_service.dart';
import 'package:rapide_nforce/ui/inventory/widgets/inventory_stock_badge.dart';
import 'package:rapide_nforce/ui/widgets/web_ui.dart';

class PartFormScreen extends StatefulWidget {
  const PartFormScreen({super.key, this.part, this.initialPartTypeId});

  final PartModel? part;
  final int? initialPartTypeId;

  bool get isEdit => part != null;

  @override
  State<PartFormScreen> createState() => _PartFormScreenState();
}

class _PartFormScreenState extends State<PartFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeController;
  late final TextEditingController _qtyController;
  late final TextEditingController _costController;
  late final TextEditingController _invoiceController;

  List<PartTypeModel> _partTypes = [];
  int? _selectedTypeId;
  bool _loadingTypes = true;
  bool _saving = false;

  String? _invoiceFilePath;
  String? _invoiceFileName;

  @override
  void initState() {
    super.initState();
    final p = widget.part;
    _codeController = TextEditingController(text: p?.code ?? '');
    _qtyController = TextEditingController(text: '${p?.quantity ?? 1}');
    _costController = TextEditingController(
      text: p?.cost != null ? p!.cost!.toStringAsFixed(2) : '',
    );
    _invoiceController = TextEditingController(text: p?.invoiceNumber ?? '');
    _selectedTypeId = p?.typeId ?? widget.initialPartTypeId;
    _loadTypes();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _qtyController.dispose();
    _costController.dispose();
    _invoiceController.dispose();
    super.dispose();
  }

  Future<void> _loadTypes() async {
    final result = await InventoryService.instance.fetchPartTypes(
      page: 1,
      limit: 1000,
    );
    if (!mounted) return;
    setState(() {
      _loadingTypes = false;
      _partTypes = result.data?.items ?? [];
      _selectedTypeId ??= _partTypes.isNotEmpty ? _partTypes.first.id : null;
    });
  }

  double? _parseCost() {
    final t = _costController.text.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  Future<void> _pickInvoiceFile() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.first;
    if (file.path == null) return;
    setState(() {
      _invoiceFilePath = file.path;
      _invoiceFileName = file.name;
    });
    AppToast.showSuccess('Invoice document attached: ${file.name}');
  }

  Future<void> _scanWithCamera() async {
    try {
      final pages = await CunningDocumentScanner.getPictures(
        noOfPages: 1,
        scannerSource: ScannerSource.camera,
      );
      if (pages == null || pages.isEmpty) return;
      final path = pages.first;
      final name = path.split('/').last;
      final cleanName = name.contains('.') ? name : '$name.jpg';
      setState(() {
        _invoiceFilePath = path;
        _invoiceFileName = cleanName;
      });
      AppToast.showSuccess('Document scanned with camera & attached!');
    } catch (e) {
      AppToast.showError('Scanner error: $e');
    }
  }

  Future<void> _captureWithCamera() async {
    try {
      final photo = await ImagePicker().pickImage(source: ImageSource.camera);
      if (photo == null) return;
      setState(() {
        _invoiceFilePath = photo.path;
        _invoiceFileName = photo.name;
      });
      AppToast.showSuccess('Photo captured & attached: ${photo.name}');
    } catch (e) {
      AppToast.showError('Camera capture error: $e');
    }
  }

  Future<void> _showScanOptionsModal() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Scan & Attach Document',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 8),

                // Live Camera Document Scanner
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF990000).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.document_scanner_outlined,
                      color: Color(0xFF990000),
                      size: 22,
                    ),
                  ),
                  title: const Text(
                    'Scan Document with Camera Viewfinder',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Use live camera scanner viewfinder with crop boundaries',
                    style: TextStyle(fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _scanWithCamera();
                  },
                ),
                const SizedBox(height: 6),

                // Camera Photo
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E7490).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.camera_alt_outlined,
                      color: Color(0xFF0E7490),
                      size: 22,
                    ),
                  ),
                  title: const Text(
                    'Take Photo with Camera',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Capture barcode or document photo using camera',
                    style: TextStyle(fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _captureWithCamera();
                  },
                ),
                const SizedBox(height: 6),

                // Device File Browser
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceTertiary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.folder_open_outlined,
                      color: AppColors.textPrimary,
                      size: 22,
                    ),
                  ),
                  title: const Text(
                    'Choose File from Device',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Select PDF, PNG, JPG document from file storage',
                    style: TextStyle(fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickInvoiceFile();
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  void _removeInvoiceFile() {
    setState(() {
      _invoiceFilePath = null;
      _invoiceFileName = null;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTypeId == null) {
      AppToast.showError('Select a part type');
      return;
    }

    setState(() => _saving = true);
    final qty = int.parse(_qtyController.text.trim());
    final cost = _parseCost();
    final total = cost != null
        ? double.parse((qty * cost).toStringAsFixed(2))
        : null;

    final result = widget.isEdit
        ? await InventoryService.instance.updatePart(
            id: widget.part!.id,
            typeId: _selectedTypeId!,
            code: _codeController.text.trim(),
            quantity: qty,
            cost: cost,
            totalCost: total,
            invoiceNumber: _invoiceController.text.trim().isEmpty
                ? null
                : _invoiceController.text.trim(),
            invoiceFilePath: _invoiceFilePath,
          )
        : await InventoryService.instance.createPart(
            typeId: _selectedTypeId!,
            code: _codeController.text.trim(),
            quantity: qty,
            cost: cost,
            totalCost: total,
            invoiceNumber: _invoiceController.text.trim().isEmpty
                ? null
                : _invoiceController.text.trim(),
            invoiceFilePath: _invoiceFilePath,
          );

    if (!mounted) return;
    setState(() => _saving = false);

    if (!result.isSuccess) {
      AppToast.showError(result.message ?? 'Save failed');
      return;
    }

    AppToast.showSuccess(widget.isEdit ? 'Part updated' : 'Part created');
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: Text(widget.isEdit ? 'Edit Part' : 'Add Part')),
      body: WebPageBody(
        child: _loadingTypes
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonFormField<int>(
                          initialValue: _selectedTypeId,
                          decoration: const InputDecoration(
                            labelText: 'Part type',
                          ),
                          items: _partTypes
                              .map(
                                (t) => DropdownMenuItem(
                                  value: t.id,
                                  child: Text(t.name),
                                ),
                              )
                              .toList(),
                          onChanged: widget.isEdit
                              ? null
                              : (v) => setState(() => _selectedTypeId = v),
                          validator: (v) =>
                              v == null ? 'Select part type' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _codeController,
                          readOnly: widget.isEdit && widget.part!.isProtected,
                          decoration: const InputDecoration(
                            labelText: 'Part code',
                          ),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Code is required'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _qtyController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Quantity *',
                          ),
                          onChanged: (_) => setState(() {}),
                          validator: (v) {
                            final n = int.tryParse(v?.trim() ?? '');
                            if (n == null || n < 0) {
                              return 'Enter valid quantity';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _costController,
                                keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'Cost',
                                  prefixText: '\$ ',
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLight.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppColors.primary.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Total Cost',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '\$${(((int.tryParse(_qtyController.text.trim()) ?? 0) * (double.tryParse(_costController.text.trim()) ?? 0.0))).toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            IconButton(
                              icon: const Icon(Icons.qr_code_scanner),
                              tooltip: 'Scan document / barcode',
                              style: IconButton.styleFrom(
                                backgroundColor: const Color(0xFF990000),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: _scanWithCamera,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Upload Invoice',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (widget.isEdit &&
                            widget.part!.hasInvoiceFile &&
                            _invoiceFileName == null) ...[
                          InkWell(
                            onTap: () => openInventoryInvoiceLink(
                              widget.part!.invoiceLink,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.insert_drive_file_outlined,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'View current invoice',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              OutlinedButton.icon(
                                onPressed: _showScanOptionsModal,
                                icon: const Icon(Icons.upload_file, size: 18),
                                label: Text(
                                  _invoiceFileName == null &&
                                          widget.isEdit &&
                                          widget.part!.hasInvoiceFile
                                      ? 'Replace file'
                                      : 'Choose file',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _invoiceFileName ??
                                      (widget.isEdit &&
                                              widget.part!.hasInvoiceFile
                                          ? 'No new file chosen (JPEG, PNG, PDF)'
                                          : 'No file chosen (JPEG, PNG, PDF)'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _invoiceFileName != null
                                        ? AppColors.primary
                                        : AppColors.textSecondary,
                                    fontWeight: _invoiceFileName != null
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (_invoiceFileName != null)
                                IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  tooltip: 'Remove file',
                                  onPressed: _removeInvoiceFile,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _invoiceController,
                          decoration: const InputDecoration(
                            labelText: 'Invoice number (optional)',
                            hintText: 'Enter invoice number',
                          ),
                        ),
                        const SizedBox(height: 28),
                        WebPrimaryButton(
                          label: widget.isEdit ? 'Save Changes' : 'Create Part',
                          loading: _saving,
                          onPressed: _save,
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
