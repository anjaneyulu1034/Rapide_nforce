import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/core/utils/api_feedback.dart';
import 'package:rapide_nforce/core/utils/app_toast.dart';
import 'package:rapide_nforce/models/dvir_defect_model.dart';
import 'package:rapide_nforce/services/dvir_service.dart';
import 'package:rapide_nforce/ui/dvir/dvir_detail_screen.dart';
import 'package:rapide_nforce/ui/widgets/screen_state_builder.dart';
import 'package:rapide_nforce/ui/widgets/web_ui.dart';

class DvirDefectDetailScreen extends StatefulWidget {
  const DvirDefectDetailScreen({super.key, required this.defectId});

  final String defectId;

  @override
  State<DvirDefectDetailScreen> createState() => _DvirDefectDetailScreenState();
}

class _DvirDefectDetailScreenState extends State<DvirDefectDetailScreen> {
  bool _loading = true;
  String? _error;
  DvirDefectModel? _defect;

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

    final result = await DvirService.instance.fetchDefectById(widget.defectId);
    if (!mounted) return;

    if (!result.isSuccess) {
      setState(() {
        _loading = false;
        _error = result.message ?? 'Failed to load defect details';
      });
      return;
    }

    setState(() {
      _loading = false;
      _defect = result.data;
    });
  }

  Future<void> _openResolveModal() async {
    final noteController = TextEditingController();
    final nameController = TextEditingController();
    String status = 'repaired';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            backgroundColor: AppColors.card,
            title: const Text(
              'Resolve DVIR Defect',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Resolution Status',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.surfaceTertiary,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'repaired',
                        child: Text('Repaired / Corrected'),
                      ),
                      DropdownMenuItem(
                        value: 'no_repair_needed',
                        child: Text('No Repair Needed'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setModalState(() => status = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Mechanic / Technician Name',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      hintText: 'Enter technician name...',
                      filled: true,
                      fillColor: AppColors.surfaceTertiary,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Repair Notes',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: noteController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText:
                          'Describe actions taken to fix or verify defect...',
                      filled: true,
                      fillColor: AppColors.surfaceTertiary,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  final res = await DvirService.instance.resolveDefect(
                    widget.defectId,
                    mechanicNote: noteController.text.trim(),
                    mechanicName: nameController.text.trim(),
                    status: status,
                  );
                  if (ctx.mounted) {
                    if (res.isSuccess) {
                      AppToast.showSuccess('Defect resolved successfully');
                      Navigator.pop(ctx, true);
                    } else {
                      ApiFeedback.showError(res);
                    }
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                ),
                child: const Text('Mark Resolved'),
              ),
            ],
          );
        },
      ),
    );

    if (result == true) {
      _load();
    }
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
    final d = _defect;
    final isOpen = d?.isOpen ?? false;
    final statusColor = isOpen
        ? const Color(0xFFBA1A1A)
        : const Color(0xFF2E7D32);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Defect Details',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (isOpen)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.icon(
                onPressed: _openResolveModal,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Resolve Defect'),
              ),
            ),
        ],
      ),
      body: ScreenStateBuilder(
        loading: _loading,
        error: _error,
        onRetry: _load,
        child: d == null
            ? const SizedBox()
            : WebPageBody(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Overview card
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
                                  d.defectName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  d.defectStatus.toUpperCase(),
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
                          detailRow('Defect Code', d.defectCode),
                          detailRow('Severity', d.severity),
                          detailRow('Vehicle Number', d.vehicleNumber),
                          detailRow('VIN', d.vin),
                          detailRow('Company Name', d.companyName),
                          detailRow('Source System', d.integrationSourceName),
                          detailRow('Reported Date', d.createdAt),
                          if (d.resolvedAt != null)
                            detailRow('Resolved Date', d.resolvedAt),
                          if (d.resolvedBy != null)
                            detailRow('Resolved By', d.resolvedBy),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Description Panel
                    if (d.defectDescription != null &&
                        d.defectDescription!.trim().isNotEmpty) ...[
                      const Text(
                        'Description',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          d.defectDescription!,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    // Action button to view linked DVIR Report
                    if (d.syncedDvirReportId != null)
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => DvirDetailScreen(
                                reportId: d.syncedDvirReportId!,
                              ),
                            ),
                          );
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.description_outlined),
                        label: const Text(
                          'View Linked Inspection Report',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}
