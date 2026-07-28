import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/core/utils/api_feedback.dart';
import 'package:rapide_nforce/core/utils/app_toast.dart';
import 'package:rapide_nforce/models/power_unit_import_result_model.dart';
import 'package:rapide_nforce/models/truck_permit_model.dart';
import 'package:rapide_nforce/services/auth_service.dart';
import 'package:rapide_nforce/services/fleet_lookup_service.dart';
import 'package:rapide_nforce/services/power_unit_service.dart';
import 'package:rapide_nforce/ui/widgets/gradient_page_background.dart';
import 'package:rapide_nforce/ui/widgets/web_form_field.dart';
import 'package:rapide_nforce/ui/widgets/web_ui.dart';

/// Bulk-import Power Units from an Excel workbook — mirrors the web's
/// `PowerUnitUploadPage` (`/powerunit/import`, `POST /trucks/bulk-import`).
class PowerUnitImportScreen extends StatefulWidget {
  const PowerUnitImportScreen({super.key});

  @override
  State<PowerUnitImportScreen> createState() => _PowerUnitImportScreenState();
}

class _PowerUnitImportScreenState extends State<PowerUnitImportScreen> {
  String? _fileName;
  String? _filePath;
  bool _importing = false;
  PowerUnitImportResult? _result;

  List<LookupOption> _countries = [];
  int? _countryId;

  @override
  void initState() {
    super.initState();
    _loadCountries();
  }

  Future<void> _loadCountries() async {
    final result = await FleetLookupService.instance.fetchCountries();
    if (!mounted) return;
    if (result.isSuccess) {
      setState(() => _countries = result.data ?? []);
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
    final result = await PowerUnitService.instance.bulkImport(
      filePath: path,
      fileName: name,
      countryId: _countryId,
      companyId: AuthService.instance.selectedCompanyId,
    );
    if (!mounted) return;
    setState(() => _importing = false);

    if (!result.isSuccess) {
      ApiFeedback.showError(result, fallback: 'Failed to import power units');
      return;
    }

    setState(() => _result = result.data);
    final r = result.data!;
    if (r.failed == 0) {
      AppToast.showSuccess('Created ${r.created} power unit(s) successfully');
    } else if (r.created == 0) {
      AppToast.showError('Import failed for all ${r.total} row(s)');
    } else {
      AppToast.showError(
        'Created ${r.created} of ${r.total}; ${r.failed} failed',
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
          title: const Text(
            'Power Unit Upload',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            const WebInfoBanner(
              title: 'Sheet "Power unit" (row 1 = headers)',
              message:
                  'Unit Number · VIN · Make · Model · Year · Color · Purchase '
                  'Date · Purchase Price · Start Date · Status · Plate Number '
                  '· Country · State · City · Registration Expiry · '
                  'Transmission · Maintenance Policy · Telematics '
                  'Status/Provider · ELD Provider · Inspection fields',
            ),
            const SizedBox(height: 12),
            const WebInfoBanner(
              title: 'Optional sheet "Policy" (matched by row order)',
              message:
                  'CVIP/Annual Inspection Due · Last Inspection · Current '
                  'Odometer · Next PM Due · Next PM Odometer · Permit '
                  'Type/Number · Issue/Expiry Date',
            ),
            const SizedBox(height: 12),
            const WebInfoBanner(
              title: 'Required (a row is skipped if any is missing)',
              message:
                  'Unit Number · VIN · Start Date · Status · Plate Number · '
                  'Country · State. Country/State/City are matched by name. '
                  'Status accepts "Active"/"Inactive".',
            ),
            const SizedBox(height: 20),
            Text(
              'Fallback country (optional)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            WebDropdownField<int>(
              label: 'Fallback Country',
              value: _countryId,
              items: _countries.map((c) => c.id).toList(),
              itemLabel: (id) => _countries.firstWhere((c) => c.id == id).name,
              hint: 'Use the Country column from the file',
              onChanged: (v) => setState(() => _countryId = v),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Only applied to rows where the Country column is empty or unmatched.',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 20),
            WebFileUploadZone(
              fileName: _fileName,
              onBrowse: _pickFile,
              subtitle: 'Click to browse. Supported: .xlsx, .xls (max 20MB)',
            ),
            const SizedBox(height: 20),
            if (result != null) ...[
              Row(
                children: [
                  _statTile('Total', result.total, AppColors.textPrimary),
                  const SizedBox(width: 8),
                  _statTile('Created', result.created, AppColors.statusCompleted),
                  const SizedBox(width: 8),
                  _statTile('Failed', result.failed, AppColors.danger),
                ],
              ),
              if (result.results.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Row results',
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
                    children: result.results.map((r) {
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 12,
                          backgroundColor: (r.success
                                  ? AppColors.statusCompleted
                                  : AppColors.danger)
                              .withValues(alpha: 0.15),
                          child: Text(
                            '${r.rowNumber}',
                            style: TextStyle(
                              fontSize: 10,
                              color: r.success
                                  ? AppColors.statusCompleted
                                  : AppColors.danger,
                            ),
                          ),
                        ),
                        title: Text(
                          [
                            r.unitNumber,
                            r.vin,
                          ].where((s) => s != null && s.isNotEmpty).join(' · ').isEmpty
                              ? (r.success ? 'Created' : 'Failed')
                              : [r.unitNumber, r.vin]
                                  .where((s) => s != null && s.isNotEmpty)
                                  .join(' · '),
                          style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                        ),
                        subtitle: Text(
                          r.message,
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
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
                      onPressed: () => Navigator.pop(context, result.created > 0),
                    ),
                  ),
                ],
              ),
            ] else
              WebPrimaryButton(
                label: 'Import Power Units',
                loading: _importing,
                onPressed: (_filePath == null || _importing) ? null : _import,
              ),
          ],
        ),
      ),
    );
  }
}
