import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/models/power_unit_model.dart';

class PowerUnitSummaryCards extends StatelessWidget {
  const PowerUnitSummaryCards({super.key, required this.unit});

  final PowerUnitModel unit;

  int? _daysUntil(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;
    final parsed = DateTime.tryParse(dateStr.replaceAll('/', '-'));
    if (parsed == null) {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        final m = int.tryParse(parts[0]);
        final d = int.tryParse(parts[1]);
        final y = int.tryParse(parts[2]);
        if (m != null && d != null && y != null) {
          return DateTime(y, m, d).difference(DateTime.now()).inDays;
        }
      }
      return null;
    }
    return parsed.difference(DateTime.now()).inDays;
  }

  @override
  Widget build(BuildContext context) {
    final regDays = _daysUntil(unit.registrationExpiry);
    final inspDays = _daysUntil(unit.annualInspectionDue ?? unit.nextInspectionDue);

    // Format Odometer with commas
    String odometerStr = '—';
    if (unit.odometer != null) {
      final regExp = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
      odometerStr = '${unit.odometer!.toString().replaceAllMapped(regExp, (Match m) => '${m[1]},')} km';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _SummaryCard(
                    label: 'ODOMETER',
                    value: odometerStr,
                    icon: Icons.local_shipping_outlined,
                    iconColor: const Color(0xFF374151),
                    cardBg: const Color(0xFFF1F5F9),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryCard(
                    label: 'REGISTRATION',
                    value: unit.registrationExpiry ?? '—',
                    icon: Icons.circle,
                    iconColor: const Color(0xFFE22D2D),
                    cardBg: const Color(0xFFFFF1F2),
                    sub: regDays != null
                        ? (regDays < 0 ? '${regDays.abs()} DAYS OVERDUE' : '$regDays DAYS REMAINING')
                        : null,
                    subBg: regDays != null
                        ? (regDays < 0 ? const Color(0xFFFFDAD6) : const Color(0xFFE2E8F0))
                        : null,
                    subTextColor: regDays != null
                        ? (regDays < 0 ? const Color(0xFFBA1A1A) : const Color(0xFF475569))
                        : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _SummaryCard(
                    label: 'NEXT INSPECTION',
                    value: unit.annualInspectionDue ?? unit.nextInspectionDue ?? '—',
                    icon: Icons.assignment_turned_in_outlined,
                    iconColor: const Color(0xFF374151),
                    cardBg: const Color(0xFFF1F5F9),
                    sub: inspDays != null
                        ? (inspDays < 0 ? 'OVERDUE' : '$inspDays DAYS REMAINING')
                        : null,
                    subBg: inspDays != null
                        ? (inspDays < 0 ? const Color(0xFFFFDAD6) : const Color(0xFFDCFCE7))
                        : null,
                    subTextColor: inspDays != null
                        ? (inspDays < 0 ? const Color(0xFFBA1A1A) : const Color(0xFF15803D))
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryCard(
                    label: 'FUEL EFFICIENCY',
                    value: '8.4 L/100km',
                    icon: Icons.local_gas_station_outlined,
                    iconColor: const Color(0xFF16A34A),
                    cardBg: const Color(0xFFECFDF5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    this.cardBg,
    this.sub,
    this.subBg,
    this.subTextColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color? cardBg;
  final String? sub;
  final Color? subBg;
  final Color? subTextColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: (cardBg != null && Theme.of(context).brightness == Brightness.light)
            ? cardBg!
            : AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: icon == Icons.circle ? 8 : 16,
            color: iconColor,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
          if (sub != null) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: subBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                sub!,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: subTextColor,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
