import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/services/auth_service.dart';
import 'package:rapide_nforce/services/report_service.dart';
import 'package:rapide_nforce/ui/fleet_maintenance_report_screen.dart';
import 'package:rapide_nforce/ui/ocr_audit_logs_screen.dart';
import 'package:rapide_nforce/ui/widgets/web_ui.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  bool get _isSuperAdmin {
    final role = AuthService.instance.currentUser?.role.toUpperCase() ?? '';
    return role.contains('SUPER_ADMIN') || role.contains('SUPER ADMIN');
  }

  @override
  Widget build(BuildContext context) {
    final reports = ReportService.availableReports
        .where((r) => !r.superAdminOnly || _isSuperAdmin)
        .toList();

    return WebPageBody(
      child: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(
            child: WebPageHeader(
              title: 'Reports',
              subtitle: 'Generate comprehensive fleet reports',
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  if (i == 0) {
                    return const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Generate New Report',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                  }
                  final report = reports[i - 1];
                  return _ReportCard(
                    report: report,
                    onTap: report.enabled
                        ? () => _openReport(context, report.id)
                        : null,
                  );
                },
                childCount: reports.length + 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openReport(BuildContext context, String reportId) {
    switch (reportId) {
      case 'fleet-maintenance':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const FleetMaintenanceReportScreen(),
          ),
        );
      case 'ocr-audit':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const OcrAuditLogsScreen()),
        );
    }
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report, this.onTap});

  final ReportDefinition report;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderLight),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(report.icon, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        report.description,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        report.category,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (enabled)
                  Icon(
                    Icons.chevron_right,
                    color: AppColors.textSecondary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
