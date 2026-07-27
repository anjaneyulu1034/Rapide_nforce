import 'package:flutter/material.dart';

/// Shared status/severity tones — colors mirror the Work Orders card's
/// status badges (see [WorkOrderStatus]/[WorkOrderPriority] in
/// work_order_model.dart) so badges look identical across screens.
enum BadgeTone { success, info, warning, purple, danger, neutral }

class StatusBadgeColors {
  StatusBadgeColors._();

  static const Map<BadgeTone, (Color bg, Color text, Color accent)> _tones = {
    BadgeTone.success: (
      Color(0xFFDCFCE7),
      Color(0xFF008236),
      Color(0xFF16A34A),
    ),
    BadgeTone.info: (Color(0xFFDBEAFE), Color(0xFF1447E6), Color(0xFF3B82F6)),
    BadgeTone.warning: (
      Color(0xFFFFF7ED),
      Color(0xFFEA580C),
      Color(0xFFF59E0B),
    ),
    BadgeTone.purple: (Color(0xFFEDE9FE), Color(0xFF6D28D9), Color(0xFF7C3AED)),
    BadgeTone.danger: (Color(0xFFFEE2E2), Color(0xFF991B1B), Color(0xFFDC2626)),
    BadgeTone.neutral: (
      Color(0xFFF3F4F6),
      Color(0xFF374151),
      Color(0xFF9CA3AF),
    ),
  };

  static const Color dangerBorderLight = Color(0xFFFCA5A5);

  static Color bg(BadgeTone tone) => _tones[tone]!.$1;
  static Color text(BadgeTone tone) => _tones[tone]!.$2;
  static Color accent(BadgeTone tone) => _tones[tone]!.$3;
}

/// Rounded pill badge — same visual style (padding/radius/weight) as the
/// Work Orders card's status badge, for use anywhere a status/severity
/// needs to render consistently with that screen.
class MiniStatusBadge extends StatelessWidget {
  const MiniStatusBadge({
    super.key,
    required this.label,
    required this.tone,
    this.borderColor,
    this.dense = false,
  });

  final String label;
  final BadgeTone tone;
  final Color? borderColor;

  /// Smaller padding/font for tighter layouts (e.g. stacked badges on a
  /// card) — the default size matches the Work Orders card badge.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 6 : 9,
        vertical: dense ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: StatusBadgeColors.bg(tone),
        borderRadius: BorderRadius.circular(20),
        border: borderColor != null ? Border.all(color: borderColor!) : null,
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: StatusBadgeColors.text(tone),
          fontSize: dense ? 9.5 : 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
