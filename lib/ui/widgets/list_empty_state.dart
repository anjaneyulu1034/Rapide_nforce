import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';

class ListEmptyState extends StatelessWidget {
  const ListEmptyState({
    super.key,
    required this.message,
    required this.icon,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF990000)),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
