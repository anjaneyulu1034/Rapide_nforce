import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/core/utils/api_feedback.dart';
import 'package:rapide_nforce/core/utils/app_toast.dart';
import 'package:rapide_nforce/models/import_result_model.dart';
import 'package:rapide_nforce/services/auth_service.dart';
import 'package:rapide_nforce/services/trailer_service.dart';
import 'package:rapide_nforce/ui/widgets/gradient_page_background.dart';
import 'package:rapide_nforce/ui/widgets/web_form_field.dart';
import 'package:rapide_nforce/ui/widgets/web_ui.dart';

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
  ImportResult? _result;

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
