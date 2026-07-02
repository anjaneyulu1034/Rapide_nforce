import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/core/constants/app_gradients.dart';
import 'package:rapide_nforce/core/utils/responsive.dart';
import 'package:intl/intl.dart';

class WebFormSection extends StatefulWidget {
  const WebFormSection({
    super.key,
    required this.title,
    required this.children,
    this.initiallyExpanded = false,
  });

  final String title;
  final List<Widget> children;
  final bool initiallyExpanded;

  @override
  State<WebFormSection> createState() => _WebFormSectionState();
}

class _WebFormSectionState extends State<WebFormSection>
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
    _expanded ? _controller.forward() : _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final pad = Responsive.scale(context, 16);
    final titleSize = Responsive.scale(context, 15);
    final isLight = Theme.of(context).brightness == Brightness.light;

    // Content column, shifted right to leave room for the accent bar
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Tappable header ──
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _toggle,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: pad, vertical: 15),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: titleSize,
                        fontWeight: FontWeight.w700,
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Divider(height: 1, thickness: 1, color: AppColors.border),
                    Padding(
                      padding: EdgeInsets.all(pad),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: widget.children,
                      ),
                    ),
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ],
    );

    return Container(
      margin: EdgeInsets.only(bottom: pad),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isLight ? AppColors.card : null,
        gradient: isLight ? null : AppGradients.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      // Stack lets the left accent bar stretch to the full card height
      // without IntrinsicHeight (which caused the overflow).
      child: Stack(
        children: [
          if (isLight)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 4,
              child: const ColoredBox(color: Color(0xFF1A1A1A)),
            ),
          Padding(
            padding: EdgeInsets.only(left: isLight ? 4 : 0),
            child: content,
          ),
        ],
      ),
    );
  }
}

class WebTextFormField extends StatelessWidget {
  const WebTextFormField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType,
    this.maxLines = 1,
    this.validator,
    this.obscureText = false,
    this.readOnly = false,
    this.onTap,
    this.onChanged,
    this.suffix,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final int maxLines;
  final String? Function(String?)? validator;
  final bool obscureText;
  final bool readOnly;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    final gap = Responsive.scale(context, 12);
    final fontSize = Responsive.scale(context, 14);
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Padding(
      padding: EdgeInsets.only(bottom: gap),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        obscureText: obscureText,
        readOnly: readOnly,
        onTap: onTap,
        onChanged: onChanged,
        style: TextStyle(color: AppColors.textPrimary, fontSize: fontSize),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          suffixIcon: suffix,
          labelStyle: TextStyle(
            color: AppColors.textSecondary,
            fontSize: fontSize - 1,
          ),
          hintStyle: TextStyle(
            color: AppColors.textSecondary,
            fontSize: fontSize - 1,
          ),
          filled: true,
          fillColor: isLight ? Colors.white : AppColors.inputFill,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1A1A1A), width: 1.5),
          ),
        ),
        validator: validator,
      ),
    );
  }
}

class WebDropdownField<T> extends StatelessWidget {
  const WebDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    this.hint = 'Select',
    this.validator,
  });

  final String label;
  final T? value;
  final List<T> items;
  final String Function(T) itemLabel;
  final ValueChanged<T?> onChanged;
  final String hint;
  final String? Function(T?)? validator;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<T>(
        initialValue: value,
        dropdownColor: AppColors.card,
        style: TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: isLight ? Colors.white : AppColors.inputFill,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1A1A1A), width: 1.5),
          ),
        ),
        hint: Text(hint, style: TextStyle(color: AppColors.textSecondary)),
        items: items
            .map(
              (item) =>
                  DropdownMenuItem(value: item, child: Text(itemLabel(item))),
            )
            .toList(),
        onChanged: onChanged,
        validator: validator,
      ),
    );
  }
}

class WebDateField extends StatelessWidget {
  const WebDateField({
    super.key,
    required this.controller,
    required this.label,
    this.validator,
    this.required = false,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final bool required;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final initial = DateTime.tryParse(controller.text) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1980),
      lastDate: DateTime(now.year + 20),
    );
    if (picked != null) {
      controller.text = DateFormat('yyyy-MM-dd').format(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WebTextFormField(
      controller: controller,
      label: required ? '$label *' : label,
      hint: 'YYYY-MM-DD',
      readOnly: true,
      onTap: () => _pick(context),
      suffix: const Icon(Icons.calendar_today_outlined, size: 18),
      validator: validator,
    );
  }
}

class WebFileUploadZone extends StatelessWidget {
  const WebFileUploadZone({
    super.key,
    required this.fileName,
    required this.onBrowse,
    this.subtitle =
        'Click to browse files. Supported: JPG, PNG, PDF (max 20MB)',
  });

  final String? fileName;
  final VoidCallback onBrowse;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    return InkWell(
      onTap: onBrowse,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 1.5),
          color: isLight
              ? const Color(0xFFF9FAFB)
              : AppColors.inputFill.withValues(alpha: 0.35),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isLight
                    ? const Color(0xFFF3F4F6)
                    : AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cloud_upload_outlined,
                size: 28,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            if (fileName != null && fileName!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                fileName!,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: BorderSide(color: const Color(0xFF1A1A1A)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: onBrowse,
              child: const Text('Browse Files'),
            ),
          ],
        ),
      ),
    );
  }
}

class WebInfoBanner extends StatelessWidget {
  const WebInfoBanner({super.key, required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
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
