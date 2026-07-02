import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/services/report_service.dart';
import 'package:rapide_nforce/ui/widgets/screen_state_builder.dart';

class OcrAuditLogsScreen extends StatefulWidget {
  const OcrAuditLogsScreen({super.key});

  @override
  State<OcrAuditLogsScreen> createState() => _OcrAuditLogsScreenState();
}

class _OcrAuditLogsScreenState extends State<OcrAuditLogsScreen> {
  bool _loading = true;
  String? _error;
  var _items = <OcrAuditLog>[];
  String _dateRange = '30';
  String _assetType = '';
  int _page = 1;

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
    final result = await ReportService.instance.fetchOcrAuditLogs(
      dateRange: _dateRange,
      page: _page,
      assetType: _assetType.isEmpty ? null : _assetType,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result.isSuccess) {
        _items = result.data?.items ?? [];
      } else {
        _error = result.message ?? 'Failed to load OCR audit logs';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'OCR Audit Logs',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _assetType,
                        decoration: const InputDecoration(
                          labelText: 'Asset type',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(value: '', child: Text('All assets')),
                          DropdownMenuItem(
                            value: 'Power Unit',
                            child: Text('Power Unit'),
                          ),
                          DropdownMenuItem(
                            value: 'Trailer',
                            child: Text('Trailer'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _assetType = value ?? '';
                            _page = 1;
                          });
                          _load();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _dateRange,
                        decoration: const InputDecoration(
                          labelText: 'Date range',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(value: '30', child: Text('Last 30 days')),
                          DropdownMenuItem(value: '15', child: Text('Last 15 days')),
                          DropdownMenuItem(value: '1', child: Text('Last 1 day')),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _dateRange = value;
                            _page = 1;
                          });
                          _load();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ScreenStateBuilder(
              loading: _loading,
              error: _error,
              onRetry: _load,
              isEmpty: _items.isEmpty,
              emptyMessage: 'No OCR audit logs found',
              emptyIcon: Icons.description_outlined,
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _items.length,
                  itemBuilder: (context, i) {
                    final log = _items[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  log.documentType,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              _StatusChip(status: log.status),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            log.companyName,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Attempts: ${log.processingAttempts}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          if (log.errorMessage != null &&
                              log.errorMessage!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                log.errorMessage!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.danger,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.cardWorkOrders,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
