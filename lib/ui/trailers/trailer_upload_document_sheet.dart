import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/core/constants/app_gradients.dart';
import 'package:rapide_nforce/core/utils/api_feedback.dart';
import 'package:rapide_nforce/core/utils/app_toast.dart';
import 'package:rapide_nforce/models/trailer_model.dart';
import 'package:rapide_nforce/models/truck_document_model.dart';
import 'package:rapide_nforce/services/auth_service.dart';
import 'package:rapide_nforce/services/fleet_lookup_service.dart';
import 'package:rapide_nforce/services/trailer_service.dart';
import 'package:rapide_nforce/ui/widgets/gradient_page_background.dart';
import 'package:rapide_nforce/ui/widgets/web_form_field.dart';

Future<bool?> showTrailerUploadDocumentSheet({
  required BuildContext context,
  required int trailerId,
  required TrailerModel trailer,
}) {
  return Navigator.push<bool>(
    context,
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) =>
          _TrailerUploadDocumentSheet(trailerId: trailerId, trailer: trailer),
    ),
  );
}

/// The "Documents" tab's upload/edit sheet — mirrors the web's
/// `UploadDocumentModal` component (components/vehicles/UploadDocumentModal.tsx),
/// which is a simpler flow than the Compliance tab's category-first upload:
/// just Document Type (with an "Other" + custom-type option), Document
/// Number, Issue/Expiry Date, File, and Notes — no Document Category and no
/// separate Document Name field. Pass [doc] to edit/replace an existing
/// document, matching the web component's `editData` prop. Mirrors the
/// Power Unit screen's `showPowerUnitDocsTabUploadSheet`.
Future<bool?> showTrailerDocsTabUploadSheet({
  required BuildContext context,
  required int trailerId,
  required TrailerModel trailer,
  TruckDocumentModel? doc,
}) {
  return Navigator.push<bool>(
    context,
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _SimpleUploadDocumentSheet(
        trailerId: trailerId,
        trailer: trailer,
        doc: doc,
      ),
    ),
  );
}

class _SimpleUploadDocumentSheet extends StatefulWidget {
  const _SimpleUploadDocumentSheet({
    required this.trailerId,
    required this.trailer,
    this.doc,
  });

  final int trailerId;
  final TrailerModel trailer;
  final TruckDocumentModel? doc;

  @override
  State<_SimpleUploadDocumentSheet> createState() =>
      _SimpleUploadDocumentSheetState();
}

class _SimpleUploadDocumentSheetState
    extends State<_SimpleUploadDocumentSheet> {
  final _customTypeCtrl = TextEditingController();
  late final _number = TextEditingController(text: widget.doc?.documentNumber);
  late final _issueDate =
      TextEditingController(text: widget.doc?.issueDateIso);
  late final _expiryDate =
      TextEditingController(text: widget.doc?.expiryDateIso);
  late final _notes = TextEditingController(text: widget.doc?.notes);

  bool get _isEditing => widget.doc != null;

  List<String> _docTypes = [];
  String? _docType;
  bool _loadingTypes = true;

  String? _newFilePath;
  String? _newFileName;
  bool _fileRemoved = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadDocTypes();
  }

  @override
  void dispose() {
    _customTypeCtrl.dispose();
    _number.dispose();
    _issueDate.dispose();
    _expiryDate.dispose();
    _notes.dispose();
    super.dispose();
  }

  /// Mirrors the web's `getComplianceDocumentTypes(true, entityTypeId)` call
  /// — every active trailer document type, with no category filter.
  Future<void> _loadDocTypes() async {
    setState(() => _loadingTypes = true);
    final result =
        await FleetLookupService.instance.fetchComplianceDocumentTypes(
      entityTypeId: 2,
    );
    if (!mounted) return;
    final types = List<String>.from(result.data ?? const ['Other']);
    final existingType = widget.doc?.documentType;
    setState(() {
      _loadingTypes = false;
      _docTypes = types;
      if (existingType != null && existingType.isNotEmpty) {
        if (types.contains(existingType)) {
          _docType = existingType;
        } else {
          // Not in the official list — show as "Other" with the original
          // value prefilled, matching the web behavior.
          _docType = 'Other';
          _customTypeCtrl.text = existingType;
        }
      }
    });
  }

  Future<void> _pickFile() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.first;
    setState(() {
      _newFilePath = file.path;
      _newFileName = file.name;
      _fileRemoved = false;
    });
  }

  Future<void> _pickFromCamera() async {
    try {
      final photo = await ImagePicker().pickImage(source: ImageSource.camera);
      if (photo == null) return;
      setState(() {
        _newFilePath = photo.path;
        _newFileName = photo.name;
        _fileRemoved = false;
      });
    } catch (e) {
      AppToast.showError('Failed to capture image: $e');
    }
  }

  Future<void> _scanToFile() async {
    try {
      final pages = await CunningDocumentScanner.getPictures(
        noOfPages: 1,
        scannerSource: ScannerSource.camera,
      );
      if (pages == null || pages.isEmpty) return;
      final path = pages.first;
      setState(() {
        _newFilePath = path;
        _newFileName = path.split('/').last;
        _fileRemoved = false;
      });
    } catch (e) {
      AppToast.showError('Failed to scan document: $e');
    }
  }

  Future<void> _submit() async {
    final effectiveType = _docType == 'Other'
        ? _customTypeCtrl.text.trim().toUpperCase()
        : _docType ?? '';
    if (effectiveType.isEmpty) {
      AppToast.showError('Select document type');
      return;
    }
    if (_issueDate.text.trim().isEmpty) {
      AppToast.showError('Select issue date');
      return;
    }
    if (!_isEditing && _newFilePath == null) {
      AppToast.showError('Select a file to upload');
      return;
    }
    if ((widget.trailer.vinNumber ?? '').isEmpty) {
      AppToast.showError('VIN is required');
      return;
    }

    setState(() => _saving = true);
    // Location isn't user-editable here — it mirrors the web modal, which
    // fixes it from the vehicle type (With Trailer for trailers).
    final result = _isEditing
        ? await TrailerService.instance.updateDocument(
            trailerId: widget.trailerId,
            documentId: widget.doc!.id,
            vinNumber: widget.trailer.vinNumber!,
            documentType: effectiveType,
            location: 'With Trailer',
            issueDate: _issueDate.text.trim(),
            expiryDate: _expiryDate.text.trim().isEmpty
                ? null
                : _expiryDate.text.trim(),
            documentNumber: _number.text.trim(),
            notes: _notes.text.trim(),
            filePath: _newFilePath,
            fileName: _newFileName,
            companyId: AuthService.instance.selectedCompanyId,
          )
        : await TrailerService.instance.uploadDocumentFull(
            trailerId: widget.trailerId,
            filePath: _newFilePath!,
            fileName: _newFileName ?? 'document',
            vinNumber: widget.trailer.vinNumber!,
            documentType: effectiveType,
            location: 'With Trailer',
            issueDate: _issueDate.text.trim(),
            expiryDate: _expiryDate.text.trim().isEmpty
                ? null
                : _expiryDate.text.trim(),
            documentNumber:
                _number.text.trim().isEmpty ? null : _number.text.trim(),
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
            companyId: AuthService.instance.selectedCompanyId,
          );

    if (!mounted) return;
    setState(() => _saving = false);
    if (result.isSuccess) {
      AppToast.showSuccess(
        _isEditing ? 'Document updated' : 'Document uploaded',
      );
      Navigator.pop(context, true);
    } else {
      ApiFeedback.showError(
        result,
        fallback: _isEditing ? 'Update failed' : 'Upload failed',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final currentFileName =
        _fileRemoved ? null : (_newFileName ?? widget.doc?.fileName);

    return GradientPageBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            _isEditing
                ? 'Edit document for ${widget.trailer.trailerNumber}'
                : 'Upload a new document for ${widget.trailer.trailerNumber}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SectionCard(
                title: 'Document Type',
                children: [
                  if (_loadingTypes)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    WebSearchableDropdownField<String>(
                      label: 'Document Type *',
                      searchHint: 'Search document types...',
                      value: _docType,
                      items: _docTypes,
                      itemLabel: (v) => v,
                      onChanged: (v) => setState(() {
                        _docType = v;
                        if (v != 'Other') _customTypeCtrl.clear();
                      }),
                    ),
                  if (_docType == 'Other')
                    WebTextFormField(
                      controller: _customTypeCtrl,
                      label: 'Custom Document Type *',
                      hint: 'Enter custom document type',
                    ),
                ],
              ),
              _SectionCard(
                title: 'Document Details',
                children: [
                  WebTextFormField(
                    controller: _number,
                    label: 'Document Number',
                  ),
                  WebDateField(
                    controller: _issueDate,
                    label: 'Issue Date',
                    required: true,
                  ),
                  WebDateField(controller: _expiryDate, label: 'Expiry Date'),
                ],
              ),
              _SectionCard(
                title: 'File & Notes',
                children: [
                  WebFileUploadZone(
                    fileName: currentFileName,
                    filePath: _newFilePath,
                    onBrowse: _pickFile,
                    onCamera: _pickFromCamera,
                    onScan: _scanToFile,
                  ),
                  if (_isEditing && currentFileName != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              currentFileName,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => setState(() {
                              _newFilePath = null;
                              _newFileName = null;
                              _fileRemoved = true;
                            }),
                            child: const Text('Remove'),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  WebTextFormField(
                    controller: _notes,
                    label: 'Notes',
                    maxLines: 3,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed:
                          _saving ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1A1A1A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.upload_rounded, size: 18),
                      label: Text(
                        _isEditing ? 'Update Document' : 'Upload Document',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrailerUploadDocumentSheet extends StatefulWidget {
  const _TrailerUploadDocumentSheet({
    required this.trailerId,
    required this.trailer,
  });

  final int trailerId;
  final TrailerModel trailer;

  @override
  State<_TrailerUploadDocumentSheet> createState() =>
      _TrailerUploadDocumentSheetState();
}

class _TrailerUploadDocumentSheetState
    extends State<_TrailerUploadDocumentSheet> {
  final _docNameCtrl = TextEditingController();
  final _customTypeCtrl = TextEditingController();
  final _number = TextEditingController();
  final _issueDate = TextEditingController();
  final _expiryDate = TextEditingController();
  final _notes = TextEditingController();

  List<String> _categories = [];
  String? _category;
  bool _loadingCategories = true;

  List<String> _docTypes = [];
  String? _docType;
  bool _loadingTypes = false;

  String? _filePath;
  String? _fileName;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _docNameCtrl.dispose();
    _customTypeCtrl.dispose();
    _number.dispose();
    _issueDate.dispose();
    _expiryDate.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final result =
        await FleetLookupService.instance.fetchComplianceDocumentCategories();
    if (!mounted) return;
    setState(() {
      _loadingCategories = false;
      _categories = result.data ?? [];
    });
  }

  Future<void> _onCategoryChanged(String category) async {
    setState(() {
      _category = category;
      _docTypes = [];
      _docType = null;
      _docNameCtrl.clear();
      _customTypeCtrl.clear();
      _loadingTypes = true;
    });
    final result = await FleetLookupService.instance
        .fetchComplianceDocumentTypes(
            entityTypeId: 2, documentCategory: category);
    if (!mounted) return;
    setState(() {
      _loadingTypes = false;
      _docTypes = result.data ?? ['Other'];
    });
  }

  Future<void> _pickFile() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'doc', 'docx'],
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.first;
    setState(() {
      _filePath = file.path;
      _fileName = file.name;
    });
  }

  Future<void> _pickFromCamera() async {
    try {
      final photo = await ImagePicker().pickImage(source: ImageSource.camera);
      if (photo == null) return;
      setState(() {
        _filePath = photo.path;
        _fileName = photo.name;
      });
    } catch (e) {
      AppToast.showError('Failed to capture image: $e');
    }
  }

  Future<void> _scanToFile() async {
    try {
      final pages = await CunningDocumentScanner.getPictures(
        noOfPages: 1,
        scannerSource: ScannerSource.camera,
      );
      if (pages == null || pages.isEmpty) return;
      final path = pages.first;
      setState(() {
        _filePath = path;
        _fileName = path.split('/').last;
      });
    } catch (e) {
      AppToast.showError('Failed to scan document: $e');
    }
  }

  Future<void> _upload() async {
    if (_category == null || _category!.isEmpty) {
      AppToast.showError('Select document category');
      return;
    }
    final effectiveType = _docType == 'Other'
        ? _customTypeCtrl.text.trim().toUpperCase()
        : _docType ?? '';
    if (effectiveType.isEmpty) {
      AppToast.showError('Select document type');
      return;
    }
    if (_docNameCtrl.text.trim().isEmpty) {
      AppToast.showError('Enter document name');
      return;
    }
    if (_issueDate.text.trim().isEmpty) {
      AppToast.showError('Select issue date');
      return;
    }
    if (_filePath == null) {
      AppToast.showError('Select a file to upload');
      return;
    }
    if ((widget.trailer.vinNumber ?? '').isEmpty) {
      AppToast.showError('VIN is required');
      return;
    }

    setState(() => _uploading = true);
    final result = await TrailerService.instance.uploadDocumentFull(
      trailerId: widget.trailerId,
      filePath: _filePath!,
      fileName: _fileName ?? 'document',
      vinNumber: widget.trailer.vinNumber!,
      documentType: effectiveType,
      documentCategory: _category,
      location: 'Carrier Binder',
      issueDate: _issueDate.text.trim(),
      expiryDate:
          _expiryDate.text.trim().isEmpty ? null : _expiryDate.text.trim(),
      documentNumber:
          _number.text.trim().isEmpty ? null : _number.text.trim(),
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      companyId: AuthService.instance.selectedCompanyId,
    );
    if (!mounted) return;
    setState(() => _uploading = false);
    if (result.isSuccess) {
      AppToast.showSuccess('Document uploaded');
      Navigator.pop(context, true);
    } else {
      ApiFeedback.showError(result, fallback: 'Upload failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return GradientPageBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Upload New Document',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              Text(
                widget.trailer.trailerNumber,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: AppGradients.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.upload_file_rounded,
                          size: 22, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Trailer: ${widget.trailer.trailerNumber}',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Supported: PDF, JPG, PNG, DOC (max 20 MB)',
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
              _SectionCard(
                title: 'Document Classification',
                children: [
                  if (_loadingCategories)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    WebDropdownField<String>(
                      label: 'Document Category *',
                      value: _category,
                      items: _categories,
                      itemLabel: (v) => v,
                      onChanged: (v) {
                        if (v != null && v != _category) _onCategoryChanged(v);
                      },
                    ),
                  if (_category != null)
                    if (_loadingTypes)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else
                      WebDropdownField<String>(
                        label: 'Document Type',
                        value: _docType,
                        items: _docTypes,
                        itemLabel: (v) => v,
                        onChanged: (v) => setState(() {
                          _docType = v;
                          if (v != null && v != 'Other') {
                            _docNameCtrl.text = v;
                            _customTypeCtrl.clear();
                          } else if (v == 'Other') {
                            _docNameCtrl.clear();
                            _customTypeCtrl.clear();
                          }
                        }),
                      ),
                  if (_docType == 'Other')
                    WebTextFormField(
                      controller: _customTypeCtrl,
                      label: 'Custom Document Type *',
                      onChanged: (v) {
                        final upper = v.toUpperCase();
                        if (_customTypeCtrl.text != upper) {
                          _customTypeCtrl.value = TextEditingValue(
                            text: upper,
                            selection: TextSelection.collapsed(
                                offset: upper.length),
                          );
                        }
                        setState(() => _docNameCtrl.text = upper);
                      },
                    ),
                  if (_docType != null)
                    WebTextFormField(
                      controller: _docNameCtrl,
                      label: 'Document Name *',
                    ),
                ],
              ),
              _SectionCard(
                title: 'Document Details',
                children: [
                  WebTextFormField(
                      controller: _number, label: 'Document Number'),
                  WebDateField(
                      controller: _issueDate,
                      label: 'Issue Date',
                      required: true),
                  WebDateField(
                      controller: _expiryDate, label: 'Expiry Date'),
                ],
              ),
              _SectionCard(
                title: 'File & Notes',
                children: [
                  WebFileUploadZone(
                    fileName: _fileName,
                    filePath: _filePath,
                    onBrowse: _pickFile,
                    onCamera: _pickFromCamera,
                    onScan: _scanToFile,
                  ),
                  const SizedBox(height: 12),
                  WebTextFormField(
                      controller: _notes, label: 'Notes', maxLines: 3),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed:
                          _uploading ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _uploading ? null : _upload,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1A1A1A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: _uploading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.upload_rounded, size: 18),
                      label: const Text('Upload',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppGradients.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}
