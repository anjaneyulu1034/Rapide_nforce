import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/models/work_order_model.dart';
import 'package:rapide_nforce/ui/dvir/dvir_screen.dart';
import 'package:rapide_nforce/ui/fault_codes_screen.dart';

/// Matches the web's `SOURCE_EVENTS_PAGE_SIZE` so a vehicle with e.g. 100
/// linked defects paginates instead of rendering one long unbounded list.
const int sourceEventsPageSize = 5;

/// Compact prev/next pager for a paginated Source Events list.
class SourceEventsPager extends StatelessWidget {
  const SourceEventsPager({
    super.key,
    required this.page,
    required this.totalPages,
    required this.onPageChanged,
  });

  final int page;
  final int totalPages;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 1) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: page > 1 ? () => onPageChanged(page - 1) : null,
            icon: const Icon(Icons.chevron_left, size: 20),
          ),
          Text(
            'Page $page of $totalPages',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: page < totalPages ? () => onPageChanged(page + 1) : null,
            icon: const Icon(Icons.chevron_right, size: 20),
          ),
        ],
      ),
    );
  }
}

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
