import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';

/// Compact circular icon button — same visual style as the Work Orders
/// card's edit/delete actions, for reuse on other card-style list rows.
class IconOnlyButton extends StatelessWidget {
  const IconOnlyButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.danger = false,
    this.color,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool danger;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final resolvedColor = !enabled
        ? AppColors.textSecondary.withValues(alpha: 0.3)
        : danger
        ? AppColors.danger
        : color ?? AppColors.textSecondary;

    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 19, color: resolvedColor),
        ),
      ),
    );
  }
}
