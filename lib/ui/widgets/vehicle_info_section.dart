import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/core/constants/app_strings.dart';

class VehicleInfoSection extends StatefulWidget {
  const VehicleInfoSection({
    super.key,
    required this.title,
    required this.rows,
    this.accentBg,
    this.accentBorder,
    this.titleIcon,
    this.initiallyExpanded = false,
  });

  final String title;
  final List<VehicleInfoRow> rows;
  final Color? accentBg;
  final Color? accentBorder;
  final Widget? titleIcon;
  final bool initiallyExpanded;

  @override
  State<VehicleInfoSection> createState() => _VehicleInfoSectionState();
}

class _VehicleInfoSectionState extends State<VehicleInfoSection>
    with SingleTickerProviderStateMixin {
  late bool _expanded;
  late AnimationController _controller;
  late Animation<double> _rotation;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: _expanded ? 1.0 : 0.0,
    );
    _rotation = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = widget.rows;
    final rowWidgets = <Widget>[];
    for (var i = 0; i < rows.length; i += 2) {
      final left = rows[i];
      final right = i + 1 < rows.length ? rows[i + 1] : null;
      rowWidgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      left.label.toUpperCase(),
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      left.value.isEmpty ? AppStrings.noData : left.value,
                      style: TextStyle(
                        color: left.valueColor ?? AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: right != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            right.label.toUpperCase(),
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            right.value.isEmpty
                                ? AppStrings.noData
                                : right.value,
                            style: TextStyle(
                              color: right.valueColor ?? AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: widget.accentBg ?? AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: widget.accentBorder ?? AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Tappable header ──
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _toggle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 15,
                  ),
                  child: Row(
                    children: [
                      if (widget.titleIcon != null) ...[
                        widget.titleIcon!,
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          widget.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      RotationTransition(
                        turns: _rotation,
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppColors.textSecondary,
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // ── Collapsible content ──
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: _expanded
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: AppColors.border,
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                          child: Column(children: rowWidgets),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class VehicleInfoRow {
  const VehicleInfoRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;
}
