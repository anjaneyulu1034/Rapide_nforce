import 'dart:io';

import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/core/constants/app_gradients.dart';
import 'package:rapide_nforce/core/utils/compact_date_picker.dart';
import 'package:rapide_nforce/core/utils/responsive.dart';
import 'package:intl/intl.dart';

bool isPreviewableImagePath(String? path) {
  if (path == null || path.isEmpty) return false;
  final lower = path.toLowerCase();
  return lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.png');
}

/// Full-screen preview for a locally selected image, opened by tapping the
/// file name under a [WebFileUploadZone] (or an attachment row) once a
/// picked file looks like an image.
void showLocalImagePreview(BuildContext context, String path) {
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Stack(
        alignment: Alignment.topRight,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: InteractiveViewer(
              child: Image.file(File(path), fit: BoxFit.contain),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(6),
            child: Material(
              color: Colors.black54,
              shape: const CircleBorder(),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Renders a field label, coloring a trailing " *" red so required fields
/// are visually distinct (plain [Text] can't mix colors within one string).
Widget buildFieldLabel(String label, double fontSize) {
  final trimmed = label.trimRight();
  if (!trimmed.endsWith('*')) {
    return Text(
      label,
      style: TextStyle(color: AppColors.textSecondary, fontSize: fontSize - 1),
    );
  }
  final base = trimmed.substring(0, trimmed.length - 1).trimRight();
  return RichText(
    text: TextSpan(
      style: TextStyle(color: AppColors.textSecondary, fontSize: fontSize - 1),
      children: [
        TextSpan(text: base),
        const TextSpan(
          text: ' *',
          style: TextStyle(
            color: AppColors.danger,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}

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
    _rotation = Tween<double>(
      begin: 0.0,
      end: 0.5,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
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
              child: ColoredBox(color: AppColors.gold),
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
    this.autovalidateMode,
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
  final AutovalidateMode? autovalidateMode;

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
        autovalidateMode: autovalidateMode,
        style: TextStyle(
          color: Colors.black,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          label: buildFieldLabel(label, fontSize),
          hintText: hint,
          suffixIcon: suffix,
          hintStyle: TextStyle(
            color: Colors.black,
            fontSize: fontSize - 1,
          ),
          filled: true,
          fillColor: isLight ? Colors.white : AppColors.inputFill,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.black),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.black),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.black, width: 1.5),
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
        isExpanded: true,
        dropdownColor: AppColors.card,
        style: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          label: buildFieldLabel(label, 15),
          filled: true,
          fillColor: isLight ? Colors.white : AppColors.inputFill,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.black),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.black),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.black, width: 1.5),
          ),
        ),
        hint: Text(hint, style: const TextStyle(color: Colors.black)),
        items: items
            .map(
              (item) => DropdownMenuItem(
                value: item,
                child: Text(itemLabel(item), overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(),
        onChanged: onChanged,
        validator: validator,
      ),
    );
  }
}

/// A dropdown-styled field that opens a searchable, scrollable bottom sheet
/// instead of the native dropdown menu — better for long option lists.
class WebSearchableDropdownField<T> extends StatelessWidget {
  const WebSearchableDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    this.hint = 'Select',
    this.searchHint = 'Search...',
  });

  final String label;
  final T? value;
  final List<T> items;
  final String Function(T) itemLabel;
  final ValueChanged<T?> onChanged;
  final String hint;
  final String searchHint;

  Future<void> _open(BuildContext context) async {
    final selected = await showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SearchableListSheet<T>(
        title: label,
        items: items,
        itemLabel: itemLabel,
        searchHint: searchHint,
      ),
    );
    if (selected != null) onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final selectedLabel = value != null ? itemLabel(value as T) : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _open(context),
        child: InputDecorator(
          decoration: InputDecoration(
            label: buildFieldLabel(label, 15),
            filled: true,
            fillColor: isLight ? Colors.white : AppColors.inputFill,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.black),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.black),
            ),
            suffixIcon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.textSecondary,
            ),
          ),
          child: Text(
            selectedLabel ?? hint,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchableListSheet<T> extends StatefulWidget {
  const _SearchableListSheet({
    required this.title,
    required this.items,
    required this.itemLabel,
    required this.searchHint,
  });

  final String title;
  final List<T> items;
  final String Function(T) itemLabel;
  final String searchHint;

  @override
  State<_SearchableListSheet<T>> createState() =>
      _SearchableListSheetState<T>();
}

class _SearchableListSheetState<T> extends State<_SearchableListSheet<T>> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? widget.items
        : widget.items
              .where(
                (i) => widget
                    .itemLabel(i)
                    .toLowerCase()
                    .contains(_query.toLowerCase()),
              )
              .toList();

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                widget.title,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: widget.searchHint,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.inputFill,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: filtered.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No matches',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final item = filtered[i];
                        return ListTile(
                          title: Text(widget.itemLabel(item)),
                          onTap: () => Navigator.pop(context, item),
                        );
                      },
                    ),
            ),
          ],
        ),
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
    this.firstDate,
    this.lastDate,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final bool required;
  /// Defaults to 1980 / now+20y. Pass [lastDate]: today for fields that
  /// can't be a future date (e.g. Purchase Date).
  final DateTime? firstDate;
  final DateTime? lastDate;
  /// Called with the new `yyyy-MM-dd` text after a date is picked — use
  /// this to react to the change (e.g. re-validate a dependent field).
  final ValueChanged<String>? onChanged;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final minDate = firstDate ?? DateTime(1980);
    final maxDate = lastDate ?? DateTime(now.year + 20);
    var initial = DateTime.tryParse(controller.text) ?? now;
    if (initial.isAfter(maxDate)) initial = maxDate;
    if (initial.isBefore(minDate)) initial = minDate;
    final picked = await showCompactDatePicker(
      context: context,
      initialDate: initial,
      firstDate: minDate,
      lastDate: maxDate,
    );
    if (picked != null) {
      final text = DateFormat('yyyy-MM-dd').format(picked);
      controller.text = text;
      onChanged?.call(text);
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
    this.onCamera,
    this.onScan,
    this.filePath,
    this.subtitle = 'Click to browse files.',
  });

  final String? fileName;
  final VoidCallback onBrowse;

  /// When set, shows a "Camera" action alongside Browse (and Scan below).
  final VoidCallback? onCamera;

  /// When set, shows a "Scan to File" action that runs real document
  /// scanning (edge detection + crop) instead of a raw photo.
  final VoidCallback? onScan;

  /// Local path of the selected file, if any — when it looks like an image,
  /// tapping the file name previews it full-screen.
  final String? filePath;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final showPickerActions = onCamera != null || onScan != null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.textSecondary.withValues(alpha: 0.35),
          width: 1.5,
        ),
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
            if (isPreviewableImagePath(filePath))
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => showLocalImagePreview(context, filePath!),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.image_outlined,
                        size: 15,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          fileName!,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Text(
                fileName!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
          const SizedBox(height: 14),
          if (showPickerActions)
            Row(
              children: [
                if (onCamera != null)
                  Expanded(
                    child: _PickerActionButton(
                      icon: Icons.camera_alt_outlined,
                      label: 'Camera',
                      color: const Color(0xFF7C3AED),
                      bg: const Color(0xFFF3E8FF),
                      onTap: onCamera!,
                    ),
                  ),
                if (onCamera != null) const SizedBox(width: 8),
                Expanded(
                  child: _PickerActionButton(
                    icon: Icons.folder_open_outlined,
                    label: 'File',
                    color: const Color(0xFF0284C7),
                    bg: const Color(0xFFE0F2FE),
                    onTap: onBrowse,
                  ),
                ),
                if (onScan != null) const SizedBox(width: 8),
                if (onScan != null)
                  Expanded(
                    child: _PickerActionButton(
                      icon: Icons.document_scanner_outlined,
                      label: 'Scan',
                      color: const Color(0xFF15803D),
                      bg: const Color(0xFFDCFCE7),
                      onTap: onScan!,
                    ),
                  ),
              ],
            )
          else
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
    );
  }
}

class _PickerActionButton extends StatelessWidget {
  const _PickerActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.bg,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color bg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isLight ? bg : color.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
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
          Icon(Icons.info_outline, color: AppColors.primary, size: 20),
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
