import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';

/// Speed-dial FAB for the Work Orders tab: a single "+" button that expands
/// on tap to reveal "Create via Voice" and "Create Manually" options.
class WorkOrderCreateFab extends StatefulWidget {
  const WorkOrderCreateFab({
    super.key,
    required this.onVoiceTap,
    required this.onManualTap,
  });

  final VoidCallback onVoiceTap;
  final VoidCallback onManualTap;

  @override
  State<WorkOrderCreateFab> createState() => _WorkOrderCreateFabState();
}

class _WorkOrderCreateFabState extends State<WorkOrderCreateFab> {
  static const _brandRed = Color(0xFF990000);

  bool _expanded = false;

  void _toggle() => setState(() => _expanded = !_expanded);

  void _select(VoidCallback action) {
    setState(() => _expanded = false);
    action();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: Alignment.bottomRight,
          child: _expanded
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _OptionPill(
                        label: 'Create via Voice',
                        icon: Icons.mic_rounded,
                        filled: false,
                        onTap: () => _select(widget.onVoiceTap),
                      ),
                      const SizedBox(height: 10),
                      _OptionPill(
                        label: 'Create Manually',
                        icon: Icons.edit_rounded,
                        filled: true,
                        onTap: () => _select(widget.onManualTap),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
        FloatingActionButton(
          heroTag: 'work_order_fab_toggle',
          onPressed: _toggle,
          backgroundColor: _brandRed,
          foregroundColor: Colors.white,
          elevation: 4,
          child: AnimatedRotation(
            turns: _expanded ? 0.125 : 0,
            duration: const Duration(milliseconds: 200),
            child: Icon(_expanded ? Icons.close : Icons.add, size: 28),
          ),
        ),
      ],
    );
  }
}

class _OptionPill extends StatelessWidget {
  const _OptionPill({
    required this.label,
    required this.icon,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback onTap;

  static const _brandRed = Color(0xFF990000);

  @override
  Widget build(BuildContext context) {
    final bg = filled ? _brandRed : AppColors.card;
    final fg = filled ? Colors.white : AppColors.textPrimary;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(24),
            border: filled ? null : Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
