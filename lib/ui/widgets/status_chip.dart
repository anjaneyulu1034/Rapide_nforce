import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';

enum StatusChipTone { success, danger, warning, neutral }

class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    this.tone = StatusChipTone.neutral,
  });

  final String label;
  final StatusChipTone tone;

  factory StatusChip.active(String label) {
    return StatusChip(label: label, tone: StatusChipTone.success);
  }

  factory StatusChip.inactive(String label) {
    return StatusChip(label: label, tone: StatusChipTone.danger);
  }

  factory StatusChip.consent(String status) {
    final normalized = status.trim().toLowerCase();
    if (normalized == 'approved') {
      return StatusChip(label: status, tone: StatusChipTone.success);
    }
    if (normalized == 'rejected') {
      return StatusChip(label: status, tone: StatusChipTone.danger);
    }
    if (normalized.isEmpty || normalized == '—' || normalized == '-') {
      return StatusChip(label: '—', tone: StatusChipTone.neutral);
    }
    return StatusChip(label: status, tone: StatusChipTone.warning);
  }

  Color get _bg {
    switch (tone) {
      case StatusChipTone.success:
        return AppColors.statusCompleted.withValues(alpha: 0.15);
      case StatusChipTone.danger:
        return AppColors.danger.withValues(alpha: 0.15);
      case StatusChipTone.warning:
        return AppColors.warning.withValues(alpha: 0.15);
      case StatusChipTone.neutral:
        return AppColors.surfaceTertiary;
    }
  }

  Color get _fg {
    switch (tone) {
      case StatusChipTone.success:
        return AppColors.statusCompleted;
      case StatusChipTone.danger:
        return AppColors.danger;
      case StatusChipTone.warning:
        return AppColors.warning;
      case StatusChipTone.neutral:
        return AppColors.textSecondary;
    }
  }

  Color get _border {
    switch (tone) {
      case StatusChipTone.success:
        return AppColors.statusCompleted.withValues(alpha: 0.35);
      case StatusChipTone.danger:
        return AppColors.danger.withValues(alpha: 0.35);
      case StatusChipTone.warning:
        return AppColors.warning.withValues(alpha: 0.35);
      case StatusChipTone.neutral:
        return AppColors.border;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _fg,
        ),
      ),
    );
  }
}
