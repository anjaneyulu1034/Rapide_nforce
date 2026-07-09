import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/models/dvir_report_model.dart';
import 'package:rapide_nforce/services/dvir_service.dart';
import 'package:rapide_nforce/ui/widgets/screen_state_builder.dart';
import 'package:rapide_nforce/ui/widgets/web_ui.dart';

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
    final statusColor = r?.reportStatus.toLowerCase() == 'unsafe' ? const Color(0xFFBA1A1A) : const Color(0xFF2E7D32);

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
                              Text(
                                'Vehicle: ${r.vehicleNumber}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  r.reportStatus.toUpperCase(),
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
                          detailRow('Reported Date', r.reportedAt),
                          detailRow('Driver Name', r.driverName),
                          detailRow('Driver Ext ID', r.driverExternalId),
                          detailRow('VIN', r.vin),
                          detailRow('Company Name', r.companyName),
                          detailRow('Inspection Type', r.inspectionType),
                          detailRow('Source', r.integrationSourceName),
                          detailRow('Defect Count', r.defectCount.toString()),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
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
                      // Defects from raw data
                      if (r.raw?['defects'] is List)
                        ...(r.raw?['defects'] as List).map((defect) {
                          final name = defect['defectName']?.toString() ?? 'Defect';
                          final code = defect['defectCode']?.toString() ?? '—';
                          final desc = defect['defectDescription']?.toString() ?? 'No description provided';
                          return Container(
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
                                    Text(
                                      name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    Text(
                                      'Code: $code',
                                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  desc,
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                ),
                              ],
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
                            'Please view the defects tab for details of individual defects.',
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
