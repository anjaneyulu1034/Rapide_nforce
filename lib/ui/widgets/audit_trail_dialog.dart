import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/models/audit_trail_model.dart';
import 'package:rapide_nforce/services/maintenance_service.dart';

/// Web parity for the "View Audit Trail" popup shown on the Create Work
/// Order screen when it was opened from a DVIR defect (or, via the same
/// `AuditTrail` component, on other entities) — `AuditTrail.tsx` +
/// `CreateWorkOrderDrawer.tsx`'s modal wrapper around it. [title] mirrors
/// web's fixed "Audit Trail" heading; [subtitle] mirrors the
/// `{entityType} {entityId}` line under it (e.g. "DVIR Defect 87").
Future<void> showAuditTrailDialog(
  BuildContext context, {
  required String entityType,
  required String entityId,
  required String subtitle,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _AuditTrailDialog(
      entityType: entityType,
      entityId: entityId,
      subtitle: subtitle,
    ),
  );
}

class _AuditTrailDialog extends StatefulWidget {
  const _AuditTrailDialog({
    required this.entityType,
    required this.entityId,
    required this.subtitle,
  });

  final String entityType;
  final String entityId;
  final String subtitle;

  @override
  State<_AuditTrailDialog> createState() => _AuditTrailDialogState();
}

class _AuditTrailDialogState extends State<_AuditTrailDialog> {
  final List<AuditTrailEntry> _entries = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _page = 1;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    _fetch(1);
  }

  Future<void> _fetch(int page, {bool append = false}) async {
    setState(() {
      if (append) {
        _loadingMore = true;
      } else {
        _loading = true;
        _error = null;
      }
    });

    final result = await MaintenanceService.instance.getEntityAuditTrail(
      entityType: widget.entityType,
      entityId: widget.entityId,
      page: page,
    );

    if (!mounted) return;

    if (!result.isSuccess) {
      setState(() {
        _loading = false;
        _loadingMore = false;
        if (!append) _error = result.message ?? 'Failed to load audit trail';
      });
      return;
    }

    final data = result.data!;
    setState(() {
      _loading = false;
      _loadingMore = false;
      if (append) {
        _entries.addAll(data.items);
      } else {
        _entries
          ..clear()
          ..addAll(data.items);
      }
      _page = data.page;
      _totalPages = data.totalPages;
    });
  }

  void _loadMore() {
    if (_loadingMore || _page >= _totalPages) return;
    _fetch(_page + 1, append: true);
  }

  (IconData, Color) _eventIcon(AuditTrailEntry entry) {
    final details = entry.details.toLowerCase();
    if (entry.eventType == 'link_removed') {
      return (Icons.close_rounded, const Color(0xFFF97316));
    }
    final isStatusChange = entry.eventType == 'status_changed';
    if (isStatusChange &&
        (details.contains('completed') || details.contains('repaired'))) {
      return (Icons.check_circle_rounded, const Color(0xFF16A34A));
    }
    if (isStatusChange && details.contains('in progress')) {
      return (Icons.check_circle_rounded, const Color(0xFF2563EB));
    }
    return (Icons.check_circle_rounded, const Color(0xFF0891B2));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.card,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AUDIT TRAIL',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 20),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _error != null
                  ? Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: AppColors.danger, fontSize: 13),
                      ),
                    )
                  : _entries.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(28),
                      child: Text(
                        'No audit trail entries found.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                      itemCount: _entries.length,
                      separatorBuilder: (_, _) =>
                          Divider(height: 20, color: AppColors.border),
                      itemBuilder: (context, index) =>
                          _buildEntry(_entries[index]),
                    ),
            ),
            if (!_loading && _page < _totalPages)
              Padding(
                padding: const EdgeInsets.only(bottom: 16, top: 4),
                child: TextButton(
                  onPressed: _loadingMore ? null : _loadMore,
                  child: _loadingMore
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text('Load More (Page ${_page + 1} of $_totalPages)'),
                ),
              )
            else
              const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildEntry(AuditTrailEntry entry) {
    final (icon, color) = _eventIcon(entry);
    final parsed = DateTime.tryParse(entry.createdAt);
    final dateStr = parsed != null ? DateFormat('MM-dd-yyyy').format(parsed.toLocal()) : '';
    final timeStr = parsed != null ? DateFormat('hh:mm a').format(parsed.toLocal()) : '';
    final actor = entry.isSystem ? 'System' : (entry.actorUsername ?? 'System');
    final roleLabel = entry.isSystem ? '(System)' : (entry.actorRole != null ? '(${entry.actorRole})' : '');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    dateStr,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    timeStr,
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  CircleAvatar(
                    radius: 9,
                    backgroundColor: AppColors.surfaceTertiary,
                    child: Icon(
                      entry.isSystem ? Icons.settings : Icons.person,
                      size: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    actor,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (roleLabel.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Text(
                      roleLabel,
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                entry.details,
                style: TextStyle(fontSize: 12.5, color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
