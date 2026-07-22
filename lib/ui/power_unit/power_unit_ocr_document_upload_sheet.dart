import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/core/utils/app_toast.dart';
import 'package:rapide_nforce/services/auth_service.dart';
import 'package:rapide_nforce/services/fleet_lookup_service.dart';
import 'package:rapide_nforce/services/ocr_service.dart';
import 'package:rapide_nforce/ui/widgets/gradient_page_background.dart';
import 'package:rapide_nforce/ui/widgets/web_form_field.dart';

/// A committed row from the upload sheet — the picked file tagged with the
/// document type the user selected for it.
class OcrDocumentEntry {
  const OcrDocumentEntry({
    required this.documentType,
    required this.fileName,
    this.filePath,
  });

  final String documentType;
  final String fileName;
  final String? filePath;
}

/// Mirrors the web app's "Upload Documents" drawer shown from the Add Power
/// Unit wizard's step 1 (`DocumentUpload` in `Documentupload.tsx`): the user
/// picks a Document Type per row *before* browsing a file for that row, can
/// add/remove rows, and each file is scanned for OCR prefill data as soon as
/// it's picked. [onPrefillExtracted] is called for every document that
/// yields extracted fields, so the caller can merge them into the form as
/// they arrive — same as web applying OCR results progressively rather than
/// waiting for every row to finish.
Future<List<OcrDocumentEntry>?> showPowerUnitOcrDocumentUploadSheet({
  required BuildContext context,
  required List<OcrDocumentEntry> initialDocuments,
  required void Function(TruckOcrPrefill prefill) onPrefillExtracted,
}) {
  return Navigator.push<List<OcrDocumentEntry>>(
    context,
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _OcrDocumentUploadSheet(
        initialDocuments: initialDocuments,
        onPrefillExtracted: onPrefillExtracted,
      ),
    ),
  );
}

/// Document types that only make sense once a truck already exists (or
/// aren't OCR-relevant at intake) — mirrors web's
/// `excludedDocumentTypeValues={['Maintenance Policy', 'Part Invoice']}`.
const List<String> _kExcludedOcrDocumentTypes = [
  'Maintenance Policy',
  'Part Invoice',
];

class _DocRow {
  _DocRow({required this.id});

  final String id;
  String? documentType;
  String? filePath;
  String? fileName;
  bool uploading = false;
  bool uploaded = false;
  bool failed = false;
}

class _OcrDocumentUploadSheet extends StatefulWidget {
  const _OcrDocumentUploadSheet({
    required this.initialDocuments,
    required this.onPrefillExtracted,
  });

  final List<OcrDocumentEntry> initialDocuments;
  final void Function(TruckOcrPrefill prefill) onPrefillExtracted;

  @override
  State<_OcrDocumentUploadSheet> createState() =>
      _OcrDocumentUploadSheetState();
}

class _OcrDocumentUploadSheetState extends State<_OcrDocumentUploadSheet> {
  final List<_DocRow> _rows = [];
  List<String> _documentTypes = [];
  bool _loadingTypes = true;
  int _idCounter = 0;

  @override
  void initState() {
    super.initState();
    for (final doc in widget.initialDocuments) {
      _rows.add(
        _DocRow(id: _nextId())
          ..documentType = doc.documentType
          ..fileName = doc.fileName
          ..filePath = doc.filePath
          ..uploaded = true,
      );
    }
    _loadDocumentTypes();
  }

  String _nextId() => 'row_${_idCounter++}';

  Future<void> _loadDocumentTypes() async {
    setState(() => _loadingTypes = true);
    final result = await FleetLookupService.instance.fetchOcrDocumentTypes(
      excluded: _kExcludedOcrDocumentTypes,
    );
    if (!mounted) return;
    setState(() {
      _loadingTypes = false;
      _documentTypes = result.data ?? const [];
    });
  }

  List<String> _availableTypesFor(_DocRow row) {
    final usedByOthers = _rows
        .where((r) => r.id != row.id)
        .map((r) => r.documentType)
        .whereType<String>()
        .toSet();
    return _documentTypes.where((t) => !usedByOthers.contains(t)).toList();
  }

  void _addRow() {
    setState(() => _rows.add(_DocRow(id: _nextId())));
  }

  void _removeRow(String id) {
    setState(() => _rows.removeWhere((r) => r.id == id));
  }

  Future<void> _pickAndScan(_DocRow row) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.first;
    if (file.path == null) {
      AppToast.showError('Could not read the selected file');
      return;
    }
    setState(() {
      row.filePath = file.path;
      row.fileName = file.name;
      row.failed = false;
    });
    await _scanRow(row);
  }

  Future<void> _scanRow(_DocRow row) async {
    setState(() {
      row.uploading = true;
      row.failed = false;
    });
    final prefill = await OcrService.instance.scanAndExtract(
      filePath: row.filePath!,
      fileName: row.fileName!,
      documentType: row.documentType!,
      companyId: AuthService.instance.selectedCompanyId,
    );
    if (!mounted) return;
    setState(() {
      row.uploading = false;
      if (prefill != null) {
        row.uploaded = true;
      } else {
        row.failed = true;
      }
    });
    if (prefill != null) {
      widget.onPrefillExtracted(prefill);
    }
  }

  List<OcrDocumentEntry> _committedEntries() => _rows
      .where((r) => r.fileName != null && r.documentType != null)
      .map(
        (r) => OcrDocumentEntry(
          documentType: r.documentType!,
          fileName: r.fileName!,
          filePath: r.filePath,
        ),
      )
      .toList();

  void _close() => Navigator.pop(context, _committedEntries());

  @override
  Widget build(BuildContext context) {
    final anyUploading = _rows.any((r) => r.uploading);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: GradientPageBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: _close,
            ),
            title: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Upload Documents',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                Text(
                  'Supported formats: JPG, JPEG, PNG, PDF',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
                ),
              ],
            ),
          ),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: _rows.isEmpty
                      ? _EmptyState(loading: _loadingTypes, onAdd: _addRow)
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _rows.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final row = _rows[index];
                            return _DocRowCard(
                              row: row,
                              documentTypes: _availableTypesFor(row),
                              loadingTypes: _loadingTypes,
                              isLast: index == _rows.length - 1,
                              onTypeChanged: (v) =>
                                  setState(() => row.documentType = v),
                              onBrowse: () => _pickAndScan(row),
                              onRetry: () => _scanRow(row),
                              onRemove: () => _removeRow(row.id),
                              onAdd: _addRow,
                            );
                          },
                        ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: anyUploading ? null : _close,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF4B633D),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        _rows.isEmpty ? 'Done' : 'Submit',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
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
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.loading, required this.onAdd});

  final bool loading;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.upload_file_outlined,
              size: 40,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              'No documents yet',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Click Add Document to start uploading.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: loading ? null : onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Document'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF4B633D),
                side: const BorderSide(color: Color(0xFF4B633D)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocRowCard extends StatelessWidget {
  const _DocRowCard({
    required this.row,
    required this.documentTypes,
    required this.loadingTypes,
    required this.isLast,
    required this.onTypeChanged,
    required this.onBrowse,
    required this.onRetry,
    required this.onRemove,
    required this.onAdd,
  });

  final _DocRow row;
  final List<String> documentTypes;
  final bool loadingTypes;
  final bool isLast;
  final ValueChanged<String?> onTypeChanged;
  final VoidCallback onBrowse;
  final VoidCallback onRetry;
  final VoidCallback onRemove;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final typeLocked = row.fileName != null;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: row.failed
            ? AppColors.danger.withValues(alpha: 0.06)
            : AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: row.failed ? AppColors.danger.withValues(alpha: 0.4) : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'Document Type',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              if (row.uploading)
                _StatusChip(
                  label: 'Uploading…',
                  color: const Color(0xFF2563EB),
                )
              else if (row.failed)
                const _StatusChip(
                  label: 'Extraction Failed',
                  color: AppColors.danger,
                )
              else if (row.uploaded)
                const _StatusChip(
                  label: '✓ Uploaded',
                  color: Color(0xFF16A34A),
                ),
            ],
          ),
          const SizedBox(height: 8),
          loadingTypes
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(),
                )
              : IgnorePointer(
                  ignoring: typeLocked,
                  child: Opacity(
                    opacity: typeLocked ? 0.6 : 1,
                    child: WebSearchableDropdownField<String>(
                      label: '',
                      searchHint: 'Search document types...',
                      value: row.documentType,
                      items: documentTypes,
                      itemLabel: (v) => v,
                      onChanged: onTypeChanged,
                    ),
                  ),
                ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: row.fileName == null
                    ? SizedBox(
                        height: 40,
                        child: FilledButton(
                          onPressed: row.documentType == null
                              ? null
                              : onBrowse,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF4B633D),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Browse File',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
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
                            Icon(
                              Icons.description_outlined,
                              size: 16,
                              color: AppColors.primary,
                            ),
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
              if (row.failed)
                TextButton(
                  onPressed: onRetry,
                  child: const Text('Retry'),
                ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.close, size: 18, color: AppColors.danger),
                tooltip: 'Remove document',
              ),
              if (isLast)
                IconButton(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  color: const Color(0xFF4B633D),
                  tooltip: 'Add document',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
