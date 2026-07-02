import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/services/report_service.dart';
import 'package:rapide_nforce/ui/widgets/screen_state_builder.dart';

class FleetMaintenanceReportScreen extends StatefulWidget {
  const FleetMaintenanceReportScreen({super.key});

  @override
  State<FleetMaintenanceReportScreen> createState() =>
      _FleetMaintenanceReportScreenState();
}

class _FleetMaintenanceReportScreenState
    extends State<FleetMaintenanceReportScreen> {
  bool _loading = true;
  String? _error;
  var _rows = <FleetMaintenanceRow>[];
  String _timeframe = 'Last 30 Days';
  String _assetType = ReportService.assetTypePowerUnit;

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
    final result = await ReportService.instance.fetchFleetMaintenanceReport(
      timeframe: _timeframe,
      assetType: _assetType,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result.isSuccess) {
        _rows = result.data ?? [];
      } else {
        _error = result.message ?? 'Failed to load fleet maintenance report';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Fleet Maintenance Report',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
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
                      DropdownMenuItem(
                        value: ReportService.assetTypePowerUnit,
                        child: Text('Power Unit'),
                      ),
                      DropdownMenuItem(
                        value: ReportService.assetTypeTrailer,
                        child: Text('Trailer'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _assetType = value);
                      _load();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _timeframe,
                    decoration: const InputDecoration(
                      labelText: 'Timeframe',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Last 30 Days',
                        child: Text('Last 30 days'),
                      ),
                      DropdownMenuItem(
                        value: 'Last 15 Days',
                        child: Text('Last 15 days'),
                      ),
                      DropdownMenuItem(
                        value: 'Last 7 Days',
                        child: Text('Last 7 days'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _timeframe = value);
                      _load();
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ScreenStateBuilder(
              loading: _loading,
              error: _error,
              onRetry: _load,
              isEmpty: _rows.isEmpty,
              emptyMessage: 'No maintenance data found',
              emptyIcon: Icons.local_shipping_outlined,
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _rows.length,
                  itemBuilder: (context, i) {
                    final row = _rows[i];
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
                          Text(
                            row.unitNo,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          _DetailLine(label: 'VIN', value: row.vin),
                          _DetailLine(label: 'Plate', value: row.plate),
                          _DetailLine(label: 'Make', value: row.make),
                          _DetailLine(label: 'Model', value: row.model),
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

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 13,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
