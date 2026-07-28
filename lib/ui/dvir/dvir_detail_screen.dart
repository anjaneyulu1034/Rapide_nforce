import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/models/dvir_defect_model.dart';
import 'package:rapide_nforce/models/dvir_report_model.dart';
import 'package:rapide_nforce/services/dvir_service.dart';
import 'package:rapide_nforce/ui/dvir/dvir_defect_detail_screen.dart';
import 'package:rapide_nforce/ui/widgets/screen_state_builder.dart';
import 'package:rapide_nforce/ui/widgets/web_form_field.dart';
import 'package:rapide_nforce/ui/widgets/web_ui.dart';

String _formatDateTime(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) return iso;
  return DateFormat('MM-dd-yyyy, hh:mm a').format(parsed.toLocal());
}

String _formatInspectionType(String? type) {
  if (type == null || type.trim().isEmpty) return 'Unknown';
  final normalized = type.replaceAll(RegExp(r'[_-]'), '').toLowerCase();
  if (normalized == 'pretrip') return 'Pre-Trip';
  if (normalized == 'posttrip') return 'Post-Trip';
  final t = type.trim();
  return t[0].toUpperCase() + t.substring(1);
}

String _formatReportStatus(String? status) {
  if (status == null || status.trim().isEmpty) return 'Unknown';
  final normalized = status.trim().toLowerCase();
  if (normalized == 'safe' || normalized == 'acceptable') return 'Safe';
  if (normalized == 'unsafe' || normalized == 'unsatisfactory') return 'Unsafe';
  final s = status.trim();
  return s[0].toUpperCase() + s.substring(1);
}

String _formatSyncMethod(String? method) {
  if (method == null || method.trim().isEmpty) return 'Unknown';
  final normalized = method.trim().toUpperCase();
  if (normalized == 'POLLING') return 'Polling';
  if (normalized == 'WEBHOOK') return 'Webhook';
  final m = method.trim();
  return m[0].toUpperCase() + m.substring(1).toLowerCase();
}

String _formatSyncStatus(String? status) {
  if (status == null || status.trim().isEmpty) return 'Unknown';
  return status
      .trim()
      .toLowerCase()
      .split('_')
      .map((p) => p.isEmpty ? p : p[0].toUpperCase() + p.substring(1))
      .join(' ');
}

class DvirDetailScreen extends StatefulWidget {
  const DvirDetailScreen({super.key, required this.reportId});

  final String reportId;

  @override
  State<DvirDetailScreen> createState() => _DvirDetailScreenState();
}

class _DvirDetailScreenState extends State<DvirDetailScreen> {
  bool _loading = true;
  String? _error;
  DvirReportModel? _report;

  bool _defectsLoading = false;
  List<DvirDefectModel> _defects = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await DvirService.instance.fetchReportById(widget.reportId);
    if (!mounted) return;

    if (!result.isSuccess) {
      setState(() {
        _loading = false;
        _error = result.message ?? 'Failed to load report details';
      });
      return;
    }

    setState(() {
      _loading = false;
      _report = result.data;
    });

    if ((result.data?.defectCount ?? 0) > 0) {
      _loadDefects();
    }
  }

  Future<void> _loadDefects() async {
    setState(() => _defectsLoading = true);

    final result = await DvirService.instance.fetchDefects(
      syncedDvirReportId: widget.reportId,
      limit: 100,
    );
    if (!mounted) return;

    setState(() {
      _defectsLoading = false;
      if (result.isSuccess) {
        _defects = result.data!.items;
      }
    });
  }

  Widget detailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value != null && value.trim().isNotEmpty ? value.trim() : '—',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = _report;
    final statusLabel = _formatReportStatus(r?.reportStatus);
    final statusColor = statusLabel.toLowerCase() == 'unsafe'
        ? const Color(0xFFBA1A1A)
        : statusLabel.toLowerCase() == 'safe'
            ? const Color(0xFF2E7D32)
            : AppColors.textSecondary;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Inspection Details',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      body: ScreenStateBuilder(
        loading: _loading,
        error: _error,
        onRetry: _load,
        child: r == null
            ? const SizedBox()
            : WebPageBody(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Main overview card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'Vehicle: ${r.vehicleNumber}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (r.integrationSourceCode != null &&
                                  r.integrationSourceCode!.trim().isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    r.integrationSourceCode!.toUpperCase(),
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  statusLabel.toUpperCase(),
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24, thickness: 1),
                          detailRow('Reported Date', _formatDateTime(r.reportedAt)),
                          detailRow('Driver Name', r.driverName),
                          detailRow('Driver Ext ID', r.driverExternalId),
                          detailRow('VIN', r.vin),
                          detailRow('Company Name', r.companyName),
                          detailRow('Inspection Type', _formatInspectionType(r.inspectionType)),
                          detailRow('Safety Status', _formatReportStatus(r.safetyStatus)),
                          detailRow('Source', r.integrationSourceName),
                          detailRow('Sync Method', _formatSyncMethod(r.syncMethod)),
                          detailRow('External Report ID', r.externalReportId),
                          detailRow(
                            'Entity',
                            r.entityId != null
                                ? '${r.entityId}${r.entityTypeId != null ? ' (type ${r.entityTypeId})' : ''}'
                                : null,
                          ),
                          detailRow('Defect Count', r.defectCount.toString()),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Sync status card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Status',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          const Divider(height: 20, thickness: 1),
                          detailRow('Sync Status', _formatSyncStatus(r.syncStatus)),
                          detailRow('Processed At', _formatDateTime(r.processedAt)),
                          detailRow('Last Synced At', _formatDateTime(r.lastSyncedAt)),
                          detailRow('Created At', _formatDateTime(r.createdAt)),
                          detailRow('Updated At', _formatDateTime(r.updatedAt)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const WebInfoBanner(
                      title: 'Note',
                      message:
                          'Synchronized data is refreshed every 8 hours through automated polling.',
                    ),
                    // Defects header if any
                    if (r.defectCount > 0) ...[
                      const Text(
                        'Report Defects',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_defectsLoading)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_defects.isNotEmpty)
                        ..._defects.map((defect) {
                          final (dotBg, dotFg) = defect.isOpen
                              ? (const Color(0xFFFEE2E2), const Color(0xFFB91C1C))
                              : (const Color(0xFFDCFCE7), const Color(0xFF15803D));
                          return InkWell(
                            onTap: () async {
                              final changed = await Navigator.of(context).push<bool>(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      DvirDefectDetailScreen(defectId: defect.id),
                                ),
                              );
                              if (changed == true && mounted) _loadDefects();
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.card,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          defect.defectName,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: dotBg,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          defect.defectStatus.toUpperCase(),
                                          style: TextStyle(
                                            color: dotFg,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Code: ${defect.defectCode}',
                                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                  ),
                                  if (defect.defectDescription != null &&
                                      defect.defectDescription!.trim().isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      defect.defectDescription!,
                                      style:
                                          TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        })
                      else
                        Container(
                          padding: const EdgeInsets.all(16),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.borderLight),
                          ),
                          child: Text(
                            'Defect details are unavailable right now. Pull to refresh to try again.',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}
