import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/api_constants.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/core/constants/app_strings.dart';
import 'package:rapide_nforce/core/utils/document_download_service.dart';
import 'package:rapide_nforce/models/truck_document_model.dart';

/// Shared "documents tab" building blocks — used by both the Power Unit and
/// Trailer detail screens so the two stay in sync instead of drifting.

String documentStatus(TruckDocumentModel d) {
  final expiry = DateTime.tryParse(d.expiryDateIso ?? '');
  if (expiry != null) {
    final daysLeft = expiry.difference(DateTime.now()).inDays;
    if (daysLeft < 0) return 'expired';
    if (daysLeft <= 30) return 'expiring';
    return 'active';
  }
  final s = (d.statusLabel ?? '').toLowerCase();
  if (s == 'expired') return 'expired';
  if (s.contains('expir')) return 'expiring';
  return 'active';
}

(Color, Color) documentStatusColors(String status) {
  switch (status) {
    case 'expired':
      return (const Color(0xFFBA1A1A), const Color(0xFFFCE8E8));
    case 'expiring':
      return (const Color(0xFF8B5E00), const Color(0xFFFFF3E0));
    default:
      return (const Color(0xFF1B7A3E), const Color(0xFFE6F4EC));
  }
}

String documentStatusLabel(String status) {
  switch (status) {
    case 'expired':
      return 'Expired';
    case 'expiring':
      return 'Expiring';
    default:
      return 'Active';
  }
}

// ---------------------------------------------------------------------------
// Status filter chip box (ACTIVE / EXPIRING / EXPIRED counts)
// ---------------------------------------------------------------------------

class StatusChipBox extends StatelessWidget {
  const StatusChipBox({
    super.key,
    required this.label,
    required this.count,
    required this.textColor,
    required this.bgColor,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final Color textColor;
  final Color bgColor;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? textColor : textColor.withValues(alpha: 0.35),
              width: selected ? 1.8 : 1.0,
            ),
          ),
          child: Column(
            children: [
              Text(
                '$count',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: textColor,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small icon action button (used in the doc card action row)
// ---------------------------------------------------------------------------

class DocActionBtn extends StatelessWidget {
  const DocActionBtn({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.color,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 20, color: color ?? AppColors.textSecondary),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Document card with action buttons (View / Download / Replace / History / Delete)
// ---------------------------------------------------------------------------

class DocCard extends StatelessWidget {
  const DocCard({
    super.key,
    required this.doc,
    required this.canReplace,
    required this.canDelete,
    required this.onView,
    required this.onDelete,
    required this.onReplace,
    required this.onVersionHistory,
    required this.onDownload,
  });

  final TruckDocumentModel doc;
  final bool canReplace;
  final bool canDelete;
  final VoidCallback onView;
  final VoidCallback onDelete;
  final VoidCallback onReplace;
  final VoidCallback onVersionHistory;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final status = documentStatus(doc);
    final (textColor, bgColor) = documentStatusColors(status);
    final expiryHighlight = status == 'expired' || status == 'expiring';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 54,
                  decoration: BoxDecoration(
                    color: AppColors.border.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.description_outlined,
                    size: 24,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              doc.documentType ?? doc.fileName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: bgColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              documentStatusLabel(status),
                              style: TextStyle(
                                color: textColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '#${doc.documentNumber ?? 'N/A'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            'ISSUED',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            doc.issueDate ?? 'N/A',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Text(
                            'EXPIRES',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            doc.expiryDate ?? 'N/A',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: expiryHighlight
                                  ? const Color(0xFFBA1A1A)
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                DocActionBtn(
                  icon: Icons.visibility_outlined,
                  tooltip: 'View',
                  onTap: onView,
                ),
                DocActionBtn(
                  icon: Icons.download_outlined,
                  tooltip: 'Download',
                  onTap: onDownload,
                ),
                if (canReplace)
                  DocActionBtn(
                    icon: Icons.upload_file_outlined,
                    tooltip: 'Replace',
                    onTap: onReplace,
                  ),
                DocActionBtn(
                  icon: Icons.history_outlined,
                  tooltip: 'Version history',
                  onTap: onVersionHistory,
                ),
                if (canDelete)
                  DocActionBtn(
                    icon: Icons.delete_outline,
                    tooltip: 'Delete',
                    color: const Color(0xFFBA1A1A),
                    onTap: onDelete,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sheet section / label / row primitives
// ---------------------------------------------------------------------------

class SheetSection extends StatelessWidget {
  const SheetSection({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class SheetLabel extends StatelessWidget {
  const SheetLabel({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }
}

class SheetRow extends StatelessWidget {
  const SheetRow({
    super.key,
    required this.label,
    required this.value,
    this.valueBold = false,
    this.valueFontSize = 14,
  });

  final String label;
  final String value;
  final bool valueBold;
  final double valueFontSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SheetLabel(label: label),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: valueFontSize,
            fontWeight: valueBold ? FontWeight.w700 : FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class VTag extends StatelessWidget {
  const VTag({super.key, required this.label, required this.color, required this.bg});

  final String label;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Document Details bottom sheet
// ---------------------------------------------------------------------------

class DocumentDetailsSheet extends StatelessWidget {
  const DocumentDetailsSheet({
    super.key,
    required this.doc,
    required this.unitNumber,
    this.entityBasePath = ApiConstants.trucks,
  });

  final TruckDocumentModel doc;
  final String unitNumber;
  final String entityBasePath;

  @override
  Widget build(BuildContext context) {
    final status = documentStatus(doc);
    final (textColor, bgColor) = documentStatusColors(status);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Document details',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'View complete information and download',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: AppColors.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: AppColors.border),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(16),
                children: [
                  SheetSection(
                    children: [
                      SheetRow(
                        label: 'DOCUMENT TYPE',
                        value: doc.documentType ?? doc.fileName,
                        valueBold: true,
                        valueFontSize: 15,
                      ),
                      const SizedBox(height: 10),
                      SheetLabel(label: 'STATUS'),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: bgColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  margin: const EdgeInsets.only(right: 5),
                                  decoration: BoxDecoration(
                                    color: textColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Text(
                                  documentStatusLabel(status),
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SheetSection(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: SheetRow(
                              label: 'DOCUMENT NUMBER',
                              value: doc.documentNumber ?? AppStrings.noData,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: SheetRow(
                              label: 'UPLOADED BY',
                              value: AppStrings.noData,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: SheetRow(
                              label: 'ISSUE DATE',
                              value: doc.issueDate ?? AppStrings.noData,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: SheetRow(
                              label: 'EXPIRY DATE',
                              value: doc.expiryDate ?? AppStrings.noData,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SheetRow(
                        label: 'UPLOADED DATE',
                        value: doc.updatedOn ?? AppStrings.noData,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SheetSection(
                    children: [
                      SheetLabel(label: 'FILE'),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.border.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFFBA1A1A),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Center(
                                child: Text(
                                  'PDF',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    doc.fileName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Tap to preview',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (doc.notes != null && doc.notes!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    SheetSection(
                      children: [
                        SheetLabel(label: 'NOTES'),
                        const SizedBox(height: 4),
                        Text(
                          doc.notes!,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 80),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                MediaQuery.of(context).padding.bottom + 16,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () =>
                          DocumentDownloadService.instance.downloadAndOpen(
                            context: context,
                            truckId: doc.truckId,
                            documentId: doc.id,
                            displayFileName: doc.fileName,
                            entityBasePath: entityBasePath,
                          ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF4B633D),
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.download_outlined, size: 18),
                      label: const Text('Download'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Version History bottom sheet
// ---------------------------------------------------------------------------

class VersionHistorySheet extends StatelessWidget {
  const VersionHistorySheet({
    super.key,
    required this.doc,
    required this.unitNumber,
    this.entityBasePath = ApiConstants.trucks,
  });

  final TruckDocumentModel doc;
  final String unitNumber;
  final String entityBasePath;

  @override
  Widget build(BuildContext context) {
    final status = documentStatus(doc);
    final (textColor, bgColor) = documentStatusColors(status);

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Version history',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '$unitNumber · ${doc.documentType ?? doc.fileName}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: AppColors.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: AppColors.border),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  VTag(
                                    label: 'Current',
                                    color: const Color(0xFF1A56DB),
                                    bg: const Color(0xFFE8F0FE),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Version 1',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  VTag(
                                    label: 'Latest',
                                    color: AppColors.textSecondary,
                                    bg: AppColors.border.withValues(alpha: 0.4),
                                  ),
                                  const Spacer(),
                                  InkWell(
                                    onTap: () {},
                                    borderRadius: BorderRadius.circular(6),
                                    child: Padding(
                                      padding: const EdgeInsets.all(6),
                                      child: Icon(
                                        Icons.visibility_outlined,
                                        size: 18,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  InkWell(
                                    onTap: () => DocumentDownloadService
                                        .instance
                                        .downloadAndOpen(
                                          context: context,
                                          truckId: doc.truckId,
                                          documentId: doc.id,
                                          displayFileName: doc.fileName,
                                          entityBasePath: entityBasePath,
                                        ),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Padding(
                                      padding: const EdgeInsets.all(6),
                                      child: Icon(
                                        Icons.download_outlined,
                                        size: 18,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: SheetRow(
                                      label: 'DOCUMENT NUMBER',
                                      value: doc.documentNumber ?? AppStrings.noData,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        SheetLabel(label: 'DOCUMENT STATUS'),
                                        const SizedBox(height: 3),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: bgColor,
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: Text(
                                            documentStatusLabel(status),
                                            style: TextStyle(
                                              color: textColor,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: SheetRow(
                                      label: 'ISSUE DATE',
                                      value: doc.issueDate ?? AppStrings.noData,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: SheetRow(
                                      label: 'EXPIRY DATE',
                                      value: doc.expiryDate ?? AppStrings.noData,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(
                                    Icons.person_outline,
                                    size: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: SheetRow(
                                      label: 'UPLOADED BY',
                                      value: AppStrings.noData,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Icon(
                                    Icons.calendar_today_outlined,
                                    size: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: SheetRow(
                                      label: 'UPLOADED DATE',
                                      value: doc.updatedOn ?? AppStrings.noData,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Divider(height: 1, color: AppColors.border),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'No older versions',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                MediaQuery.of(context).padding.bottom + 12,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total: 1',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    'Current: 1',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    'Updated: ${doc.updatedOn ?? 'N/A'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
