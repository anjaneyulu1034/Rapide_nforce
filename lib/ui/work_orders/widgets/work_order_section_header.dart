import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';

/// Numbered section heading — matches web `EnhancedSectionHeading`.
class WorkOrderSectionHeader extends StatelessWidget {
  const WorkOrderSectionHeader({
    super.key,
    required this.number,
    required this.title,
    this.subtitle,
    this.vin,
  });

  final int number;
  final String title;
  final String? subtitle;
  final String? vin;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$number',
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text.rich(
                  TextSpan(
                    text: title.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      letterSpacing: 0.5,
                    ),
                    children: [
                      if (vin != null) ...[
                        const TextSpan(text: ' '),
                        TextSpan(
                          text: '(VIN: $vin)',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}
