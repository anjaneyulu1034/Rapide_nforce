import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/core/utils/api_feedback.dart';
import 'package:rapide_nforce/core/utils/app_toast.dart';
import 'package:rapide_nforce/models/dvir_defect_model.dart';
import 'package:rapide_nforce/services/dvir_service.dart';
import 'package:rapide_nforce/ui/dvir/dvir_detail_screen.dart';
import 'package:rapide_nforce/ui/widgets/screen_state_builder.dart';
import 'package:rapide_nforce/ui/widgets/web_form_field.dart';
import 'package:rapide_nforce/ui/widgets/web_ui.dart';

String _formatDateTime(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) return iso;
  return DateFormat('MM-dd-yyyy, hh:mm a').format(parsed.toLocal());
}

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
  // Only true once the defect's own status actually changed (resolved) —
  // lets the Defects list know whether it's worth reloading on return,
  // instead of clearing and refetching on every single back-navigation
  // (which was racing the pop transition and throwing a hit-test error).
  bool _changed = false;

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
                      _changed = true;
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
          onPressed: () => Navigator.pop(context, _changed),
        ),
        title: const Text(
          'Defect Details',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (isOpen)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: UnconstrainedBox(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _openResolveModal,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 18,
                            color: Colors.white,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Resolve Defect',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
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
                              if (d.integrationSourceCode != null &&
                                  d.integrationSourceCode!
                                      .trim()
                                      .isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    d.integrationSourceCode!.toUpperCase(),
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
                          detailRow('External Defect ID', d.externalDefectId),
                          detailRow('Severity', d.severity),
                          detailRow('Vehicle Number', d.vehicleNumber),
                          detailRow('VIN', d.vin),
                          detailRow('Company Name', d.companyName),
                          detailRow('Source System', d.integrationSourceName),
                          detailRow(
                            'Entity',
                            d.entityId != null
                                ? '${d.entityId}${d.entityTypeId != null ? ' (type ${d.entityTypeId})' : ''}'
                                : null,
                          ),
                          detailRow(
                            'Reported Date',
                            _formatDateTime(d.createdAt),
                          ),
                          detailRow(
                            'Updated Date',
                            _formatDateTime(d.updatedAt),
                          ),
                          if (d.resolvedAt != null)
                            detailRow(
                              'Resolved Date',
                              _formatDateTime(d.resolvedAt),
                            ),
                          if (d.resolvedBy != null)
                            detailRow('Resolved By', d.resolvedBy),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const WebInfoBanner(
                      title: 'Note',
                      message:
                          'Synchronized data is refreshed every 8 hours through automated polling.',
                    ),
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
