import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/core/utils/api_feedback.dart';
import 'package:rapide_nforce/core/utils/app_toast.dart';
import 'package:rapide_nforce/models/import_result_model.dart';
import 'package:rapide_nforce/services/auth_service.dart';
import 'package:rapide_nforce/services/trailer_service.dart';
import 'package:rapide_nforce/ui/widgets/gradient_page_background.dart';
import 'package:rapide_nforce/ui/widgets/web_form_field.dart';
import 'package:rapide_nforce/ui/widgets/web_ui.dart';

/// Bundled copy of the web app's sample import workbook
/// (`public/templates/rapidenforce-trailer-template.xlsx`), so mobile users
/// get the same "download sample template" convenience the web Import page
/// offers alongside the required-columns list.
const _kTrailerTemplateAsset = 'assets/templates/rapidenforce-trailer-template.xlsx';
const _kTrailerTemplateFileName = 'rapidenforce-trailer-template.xlsx';

const _kTrailerImportHeaders = [
  'Unit Number',
  'VIN',
  'Start Date',
  'Status',
  'Plate Number',
  'Country',
  'State',
];

class TrailerImportScreen extends StatefulWidget {
  const TrailerImportScreen({super.key});

  @override
  State<TrailerImportScreen> createState() => _TrailerImportScreenState();
}

class _TrailerImportScreenState extends State<TrailerImportScreen> {
  String? _fileName;
  String? _filePath;
  bool _importing = false;
  bool _downloadingTemplate = false;
  ImportResult? _result;

  Future<void> _downloadTemplate() async {
    if (_downloadingTemplate) return;
    setState(() => _downloadingTemplate = true);
    try {
      final data = await rootBundle.load(_kTrailerTemplateAsset);
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      final tempDir = await getTemporaryDirectory();
      final savePath = '${tempDir.path}/$_kTrailerTemplateFileName';
      await File(savePath).writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      final result = await OpenFilex.open(savePath);
      if (result.type != ResultType.done && mounted) {
        AppToast.showError('Could not open template: ${result.message}');
      }
    } catch (_) {
      if (mounted) AppToast.showError('Could not download sample template');
    } finally {
      if (mounted) setState(() => _downloadingTemplate = false);
    }
  }

  Future<void> _pickFile() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.first;
    if (file.path == null) {
      AppToast.showError('Could not read the selected file');
      return;
    }
    setState(() {
      _fileName = file.name;
      _filePath = file.path;
      _result = null;
    });
  }

  Future<void> _import() async {
    final path = _filePath;
    final name = _fileName;
    if (path == null || name == null) return;

    setState(() => _importing = true);
    final result = await TrailerService.instance.importExcel(
      filePath: path,
      fileName: name,
      companyId: AuthService.instance.selectedCompanyId,
    );
    if (!mounted) return;
    setState(() => _importing = false);

    if (!result.isSuccess) {
      ApiFeedback.showError(result, fallback: 'Failed to import file');
      return;
    }

    setState(() => _result = result.data);
    final r = result.data!;
    if (r.successCount == 0) {
      AppToast.showError(r.message ?? 'No rows were imported');
    } else if (r.failedCount > 0) {
      AppToast.showError(
        r.message ?? '${r.successCount} imported, ${r.failedCount} failed',
      );
    } else {
      AppToast.showSuccess(
        r.message ?? '${r.successCount} trailers imported successfully',
      );
    }
  }

  void _reset() {
    setState(() {
      _fileName = null;
      _filePath = null;
      _result = null;
    });
  }

  Widget _statTile(String label, int value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return GradientPageBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Import Trailers', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            WebInfoBanner(
              title: 'Required columns',
              message: _kTrailerImportHeaders.join(', '),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _downloadingTemplate ? null : _downloadTemplate,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: _downloadingTemplate
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.textSecondary,
                        ),
                      )
                    : const Icon(Icons.download_outlined, size: 16),
                label: const Text(
                  'Download Sample Template',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 14),
            WebFileUploadZone(
              fileName: _fileName,
              onBrowse: _pickFile,
              subtitle: 'Click to browse. Supported: .xlsx, .xls (max 15MB)',
            ),
            const SizedBox(height: 20),
            if (result != null) ...[
              Row(
                children: [
                  _statTile('Total', result.totalCount, AppColors.textPrimary),
                  const SizedBox(width: 8),
                  _statTile('Success', result.successCount, AppColors.statusCompleted),
                  const SizedBox(width: 8),
                  _statTile('Failed', result.failedCount, AppColors.danger),
                  const SizedBox(width: 8),
                  _statTile('Skipped', result.skippedCount, AppColors.textSecondary),
                ],
              ),
              if (result.errors.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Failed rows',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: result.errors.map((e) {
                      return ListTile(
                        dense: true,
                        leading: e.row != null
                            ? CircleAvatar(
                                radius: 12,
                                backgroundColor: AppColors.danger.withValues(alpha: 0.15),
                                child: Text(
                                  '${e.row}',
                                  style: TextStyle(fontSize: 10, color: AppColors.danger),
                                ),
                              )
                            : null,
                        title: Text(
                          e.message,
                          style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                        ),
                        subtitle: e.column != null
                            ? Text(
                                'Column: ${e.column}',
                                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              )
                            : null,
                      );
                    }).toList(),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _reset,
                      child: const Text('Import Another File'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: WebPrimaryButton(
                      label: 'Done',
                      onPressed: () => Navigator.pop(context, result.successCount > 0),
                    ),
                  ),
                ],
              ),
            ] else
              WebPrimaryButton(
                label: 'Import Excel',
                loading: _importing,
                onPressed: (_filePath == null || _importing) ? null : _import,
              ),
          ],
        ),
      ),
    );
  }
}
