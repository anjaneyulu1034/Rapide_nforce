import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/core/constants/app_gradients.dart';
import 'package:rapide_nforce/core/utils/api_feedback.dart';
import 'package:rapide_nforce/core/utils/app_toast.dart';
import 'package:rapide_nforce/models/power_unit_model.dart';
import 'package:rapide_nforce/services/auth_service.dart';
import 'package:rapide_nforce/services/fleet_lookup_service.dart';
import 'package:rapide_nforce/services/power_unit_service.dart';
import 'package:rapide_nforce/ui/widgets/gradient_page_background.dart';
import 'package:rapide_nforce/ui/widgets/web_form_field.dart';

Future<bool?> showPowerUnitUploadDocumentSheet({
  required BuildContext context,
  required int truckId,
  required PowerUnitModel unit,
}) {
  return Navigator.push<bool>(
    context,
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _UploadDocumentSheet(truckId: truckId, unit: unit),
    ),
  );
}

class _UploadDocumentSheet extends StatefulWidget {
  const _UploadDocumentSheet({required this.truckId, required this.unit});

  final int truckId;
  final PowerUnitModel unit;

  @override
  State<_UploadDocumentSheet> createState() => _UploadDocumentSheetState();
}

class _UploadDocumentSheetState extends State<_UploadDocumentSheet> {
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
        .fetchComplianceDocumentTypes(entityTypeId: 1, documentCategory: category);
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
    if ((widget.unit.vinNumber ?? '').isEmpty) {
      AppToast.showError('VIN is required');
      return;
    }

    setState(() => _uploading = true);
    final result = await PowerUnitService.instance.uploadDocumentFull(
      truckId: widget.truckId,
      filePath: _filePath!,
      fileName: _fileName ?? 'document',
      vinNumber: widget.unit.vinNumber!,
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
                widget.unit.unitNumber,
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
              // Unit info card
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
                        color: const Color(0xFF374151),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.upload_file_rounded,
                        size: 22,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Unit: ${widget.unit.unitNumber}',
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

              // Section 1: Document Classification
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
                            selection:
                                TextSelection.collapsed(offset: upper.length),
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

              // Section 2: Document Details
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

              // Section 3: File & Notes
              _SectionCard(
                title: 'File & Notes',
                children: [
                  WebFileUploadZone(
                    fileName: _fileName,
                    onBrowse: _pickFile,
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
                          _uploading ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _uploading ? null : _upload,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF374151),
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
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.upload_rounded, size: 18),
                      label: const Text(
                        'Upload',
                        style: TextStyle(fontWeight: FontWeight.w700),
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
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}
