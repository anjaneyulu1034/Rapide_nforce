import 'package:flutter/material.dart';
import 'package:rapide_nforce/models/work_order_model.dart';
import 'package:rapide_nforce/ui/dvir/dvir_screen.dart';
import 'package:rapide_nforce/ui/fault_codes_screen.dart';

bool _isDvirSource(String source) => source.toUpperCase().contains('DVIR');
bool _isFaultCodeSource(String source) => source.toUpperCase().contains('FAULT');

/// Mirrors the web's `resolveSourceEventDetailsTarget`: jumps to the Fault
/// Codes screen when every event is telematics-sourced, otherwise to DVIR —
/// pre-filtered by this vehicle's VIN/unit number, same as the web's
/// `?search=` / `?vin=` query params.
class SourceEventsDetailsLink extends StatelessWidget {
  const SourceEventsDetailsLink({
    super.key,
    required this.events,
    this.vin,
    this.unitNumber,
  });

  final List<MaintenanceIssueSummary> events;
  final String? vin;
  final String? unitNumber;

  @override
  Widget build(BuildContext context) {
    final hasDvir = events.any((e) => _isDvirSource(e.issueSource));
    final hasFaultCodes = events.any((e) => _isFaultCodeSource(e.issueSource));
    final targetsFaultCodes = hasFaultCodes && !hasDvir;

    final search = (vin?.trim().isNotEmpty ?? false)
        ? vin!.trim()
        : (unitNumber?.trim() ?? '');
    final enabled = search.isNotEmpty;

    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: enabled
            ? () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      appBar: AppBar(
                        title: Text(targetsFaultCodes ? 'Fault Codes' : 'DVIR'),
                      ),
                      body: targetsFaultCodes
                          ? FaultCodesScreen(initialSearch: search)
                          : DvirScreen(initialSearch: search),
                    ),
                  ),
                );
              }
            : null,
        child: Text(
          targetsFaultCodes ? 'View Fault Codes ↗' : 'View DVIR Details ↗',
        ),
      ),
    );
  }
}
