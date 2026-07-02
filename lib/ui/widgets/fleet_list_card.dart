import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';

class FleetListCard extends StatelessWidget {
  const FleetListCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.leading,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;
  final Widget? leading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        leading: leading,
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        trailing: trailing ?? const Icon(Icons.chevron_right, size: 20),
      ),
    );
  }
}
