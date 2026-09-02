import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/core/utils/app_toast.dart';
import 'package:rapide_nforce/services/ocr_service.dart';
import 'package:rapide_nforce/ui/widgets/gradient_page_background.dart';
import 'package:rapide_nforce/ui/widgets/web_form_field.dart';

/// Web parity for `allowedDocumentTypeValues={['Part Invoice']}` on the
/// "Upload Documents" drawer (`DocumentUpload` in `Documentupload.tsx`) —
/// the only document type accepted wherever this sheet is used (Inventory
/// ▸ Add Part's "Upload Invoice", and the work order Add Part popup's
/// "Upload Invoice"). Both call sites reach the same web component with
/// this same restriction, so this list is shared rather than duplicated.
const List<String> kPartInvoiceDocumentTypes = ['Part Invoice'];

class _UploadDocRow {
  String? documentType;
  String? filePath;
  String? fileName;
}

/// Web parity for the "Upload Documents" drawer (`Documentupload.tsx`)
/// reached from any "Upload Invoice" ▸ Browse Files button — a Document
/// Type (locked to "Part Invoice") + Browse File row per file, with
/// add/remove rows and a single Submit. Unlike web, this sheet does not run
/// OCR itself: it just collects one or more `(documentType, file)` pairs and
/// hands them back so the caller can run its own OCR + result handling
/// (mirrors [OcrUploadDocItem], the shape `OcrService.uploadAndExtractPartInvoiceOcr`
/// already takes). Returns `null` if the user closes the sheet without
/// submitting.
Future<List<OcrUploadDocItem>?> showPartInvoiceUploadDocumentsSheet(
  BuildContext context, {
  int maxFiles = 6,
}) {
  return Navigator.push<List<OcrUploadDocItem>>(
    context,
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _PartInvoiceUploadDocumentsSheet(maxFiles: maxFiles),
    ),
  );
}

class _PartInvoiceUploadDocumentsSheet extends StatefulWidget {
  const _PartInvoiceUploadDocumentsSheet({required this.maxFiles});

  final int maxFiles;

  @override
  State<_PartInvoiceUploadDocumentsSheet> createState() =>
      _PartInvoiceUploadDocumentsSheetState();
}

class _PartInvoiceUploadDocumentsSheetState
    extends State<_PartInvoiceUploadDocumentsSheet> {
  final List<_UploadDocRow> _rows = [_UploadDocRow()];

  void _addRow() {
    if (_rows.length >= widget.maxFiles) return;
    setState(() => _rows.add(_UploadDocRow()));
  }

  void _removeRow(_UploadDocRow row) => setState(() => _rows.remove(row));

  Future<void> _pickFileForRow(_UploadDocRow row) async {
    if ((row.documentType ?? '').isEmpty) {
      AppToast.showError('Please select a document type first.');
      return;
    }
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.first;
    if (file.path == null) return;
    setState(() {
      row.filePath = file.path;
      row.fileName = file.name;
    });
  }

  void _submit() {
    final validRows =
        _rows.where((r) => r.filePath != null && r.documentType != null).toList();
    if (validRows.isEmpty) {
      AppToast.showError('Please browse and select at least one document before submitting.');
      return;
    }
    Navigator.pop(
      context,
      validRows
          .map((r) => OcrUploadDocItem(
                filePath: r.filePath!,
                fileName: r.fileName!,
                documentType: r.documentType!,
              ))
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GradientPageBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Upload Documents',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  children: [
                    Text(
                      'Attach required files and confirm to trigger OCR extraction.',
                      style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Supported formats: JPG, JPEG, PNG, PDF',
                      style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    for (var i = 0; i < _rows.length; i++)
                      _buildRowCard(_rows[i], isLast: i == _rows.length - 1),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration:
                    BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text(
                      'Submit',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRowCard(_UploadDocRow row, {required bool isLast}) {
    final typeLocked = row.fileName != null;
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
          Text(
            'Document Type',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          IgnorePointer(
            ignoring: typeLocked,
            child: Opacity(
              opacity: typeLocked ? 0.6 : 1,
              child: WebDropdownField<String>(
                label: '',
                value: row.documentType,
                items: kPartInvoiceDocumentTypes,
                itemLabel: (v) => v,
                hint: 'Select document type',
                onChanged: (v) => setState(() => row.documentType = v),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: row.fileName == null
                    ? SizedBox(
                        height: 40,
                        child: FilledButton(
                          onPressed:
                              (row.documentType ?? '').isEmpty ? null : () => _pickFileForRow(row),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Browse File',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                      )
                    : Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: AppColors.inputFill,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.description_outlined, size: 16, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                row.fileName!,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _removeRow(row),
                icon: Icon(Icons.close, size: 18, color: AppColors.danger),
                tooltip: 'Remove document',
              ),
              if (isLast)
                IconButton(
                  onPressed: _rows.length >= widget.maxFiles ? null : _addRow,
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  color: AppColors.primary,
                  tooltip: 'Add document',
                ),
            ],
          ),
        ],
      ),
    );
  }
}
