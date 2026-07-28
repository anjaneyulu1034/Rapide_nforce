import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/models/fault_code_model.dart';

class FaultCodeDetailSheet extends StatelessWidget {
  const FaultCodeDetailSheet({super.key, required this.item});

  final FaultCodeModel item;

  static void show(BuildContext context, FaultCodeModel item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FaultCodeDetailSheet(item: item),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return '—';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      return DateFormat('MMM dd, yyyy, hh:mm a').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final overviewTitle = (item.vehicleNumber != '—' && item.vehicleNumber.isNotEmpty)
        ? item.vehicleNumber
        : (item.faultName != null && item.faultName!.trim().isNotEmpty)
            ? item.faultName!.trim()
            : item.faultCode;

    final description = (item.faultDescription.trim().isNotEmpty)
        ? item.faultDescription.trim()
        : (item.faultName != null && item.faultName!.trim().isNotEmpty)
            ? item.faultName!.trim()
            : 'No description provided.';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Handle bar
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Top Header Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Fault Code Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Content Scroll
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badges row
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (item.integrationSourceCode != null &&
                            item.integrationSourceCode!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0E7490),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              item.integrationSourceCode!.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        _StatusPill(status: item.formattedStatus),
                        _SeverityBadge(item: item),
                        if (item.syncStatus != null && item.syncStatus!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white10 : Colors.grey[100],
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: isDark ? Colors.white24 : Colors.grey[300]!),
                            ),
                            child: Text(
                              'Sync: ${item.syncStatus}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : Colors.grey[800],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Title & Code Box
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      overviewTitle,
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Last detected ${_formatDate(item.detectedAt)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F3ED),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFB8D4C8)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text(
                                      'FAULT CODE',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.1,
                                        color: Color(0xFF0E7490),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item.faultCode,
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF2F5E4E),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Description Panel
                    _SectionCard(
                      title: 'Description',
                      isDark: isDark,
                      child: Text(
                        description,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.4,
                          color: isDark ? Colors.white.withValues(alpha: 0.8) : const Color(0xFF334155),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Stats grid
                    Row(
                      children: [
                        Expanded(
                          child: _SummaryTile(
                            label: 'Occurrences',
                            value: '${item.occurrenceCount ?? 1}',
                            subtitle: (item.occurrenceCount ?? 1) == 1
                                ? 'Reported occurrence'
                                : 'Reported occurrences',
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _SummaryTile(
                            label: 'Fault Status',
                            valueWidget: _StatusPill(status: item.formattedStatus),
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Vehicle & Company Card
                    _SectionCard(
                      title: 'Vehicle & Company',
                      isDark: isDark,
                      child: Column(
                        children: [
                          _DetailRow('Vehicle Number', item.vehicleNumber, isDark: isDark),
                          _DetailRow('VIN', item.vin ?? '—', isDark: isDark),
                          _DetailRow(
                            'Integration Source',
                            item.integrationSourceName ?? item.integrationSourceCode ?? '—',
                            isDark: isDark,
                          ),
                          _DetailRow('Sync Method', item.syncMethod ?? '—', isDark: isDark),
                          if (item.companyName != null && item.companyName!.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark ? Colors.white10 : Colors.grey[200]!,
                                ),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: const Color(0xFF1E293B),
                                    child: Text(
                                      item.companyName![0].toUpperCase(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.companyName!,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          ),
                                        ),
                                        Text(
                                          'Fleet Operator',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Fault Details Card
                    _SectionCard(
                      title: 'Fault Details',
                      isDark: isDark,
                      child: Column(
                        children: [
                          _DetailRow('Fault Code', item.faultCode, isDark: isDark),
                          _DetailRow('SPN', item.spn ?? '—', isDark: isDark),
                          _DetailRow('FMI', item.fmi ?? '—', isDark: isDark),
                          _DetailRow('External Fault ID', item.externalFaultId ?? '—', isDark: isDark),
                          _DetailRow('Severity', item.severity ?? '—', isDark: isDark),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Status & Timestamps
                    _SectionCard(
                      title: 'Status & Timestamps',
                      isDark: isDark,
                      child: Column(
                        children: [
                          _DetailRow('Fault Status', item.formattedStatus, isDark: isDark),
                          _DetailRow('Sync Status', item.syncStatus ?? '—', isDark: isDark),
                          _DetailRow('First Detected', _formatDate(item.firstDetectedAt), isDark: isDark),
                          _DetailRow('Last Detected', _formatDate(item.lastDetectedAt), isDark: isDark),
                          _DetailRow('Processed At', _formatDate(item.processedAt), isDark: isDark),
                          _DetailRow('Last Synced At', _formatDate(item.lastSyncedAt), isDark: isDark),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 30-day retention notice
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF78350F).withValues(alpha: 0.2)
                            : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFFF59E0B).withValues(alpha: 0.3)
                              : const Color(0xFFFCD34D),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 20,
                            color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Synchronized for the last 30 days',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? const Color(0xFFFBBF24) : const Color(0xFF92400E),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Fault code data view is limited to the past 30 days.',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    required this.isDark,
  });

  final String title;
  final Widget child;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    this.value,
    this.subtitle,
    this.valueWidget,
    required this.isDark,
  });

  final String label;
  final String? value;
  final String? subtitle;
  final Widget? valueWidget;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white60 : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 6),
          if (valueWidget != null)
            valueWidget!
          else if (value != null)
            Text(
              value!,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 10.5,
                color: isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value, {required this.isDark});

  final String label;
  final String value;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final isEmpty = value == '—' || value.trim().isEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white60 : const Color(0xFF64748B),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isEmpty ? FontWeight.normal : FontWeight.w600,
                fontStyle: isEmpty ? FontStyle.italic : FontStyle.normal,
                color: isEmpty
                    ? (isDark ? Colors.white38 : const Color(0xFF94A3B8))
                    : (isDark ? Colors.white : const Color(0xFF1E293B)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final n = status.toLowerCase();
    Color bg;
    Color fg;
    Color border;

    if (n == 'active' || n == 'open') {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF15803D);
      border = const Color(0xFFBBF7D0);
    } else if (n == 'resolved') {
      bg = const Color(0xFFEDE9FE);
      fg = const Color(0xFF6D28D9);
      border = const Color(0xFFDDD6FE);
    } else if (n == 'cleared') {
      bg = const Color(0xFFCFFAFE);
      fg = const Color(0xFF0E7490);
      border = const Color(0xFFA5F3FC);
    } else {
      bg = const Color(0xFFF1F5F9);
      fg = const Color(0xFF334155);
      border = const Color(0xFFE2E8F0);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }
}

class _SeverityBadge extends StatelessWidget {
  const _SeverityBadge({required this.item});

  final FaultCodeModel item;

  @override
  Widget build(BuildContext context) {
    final codeSev = item.parsedCodeSeverity;
    if (codeSev != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${codeSev.label} :',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              codeSev.value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF7C3AED),
              ),
            ),
          ],
        ),
      );
    }

    final sev = item.severity?.trim();
    if (sev == null || sev.isEmpty) {
      return const SizedBox.shrink();
    }

    final n = sev.toLowerCase();
    Color bg = const Color(0xFFF1F5F9);
    Color fg = const Color(0xFF475569);
    Color border = const Color(0xFFE2E8F0);

    if (n == 'critical' || n == 'high') {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFB91C1C);
      border = const Color(0xFFFECACA);
    } else if (n == 'medium') {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFFB45309);
      border = const Color(0xFFFDE68A);
    } else if (n == 'low') {
      bg = const Color(0xFFE0F2FE);
      fg = const Color(0xFF0369A1);
      border = const Color(0xFFBAE6FD);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Text(
        sev[0].toUpperCase() + sev.substring(1),
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }
}
