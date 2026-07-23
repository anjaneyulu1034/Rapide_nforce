import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/ui/widgets/ocr_document_upload_sheet.dart';

/// Matches web's Add Truck/Add Trailer step 1: an empty "Click to browse
/// files" card when nothing's attached yet, or a summary of the documents
/// committed via the Upload Documents sheet with an "Add More" affordance.
class DocumentUploadSection extends StatelessWidget {
  const DocumentUploadSection({
    super.key,
    required this.documents,
    required this.onOpenSheet,
    required this.onRemove,
  });

  final List<OcrDocumentEntry> documents;
  final VoidCallback onOpenSheet;
  final ValueChanged<OcrDocumentEntry> onRemove;

  @override
  Widget build(BuildContext context) {
    if (documents.isEmpty) {
      return GestureDetector(
        onTap: onOpenSheet,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.textSecondary.withValues(alpha: 0.35),
              width: 1.5,
            ),
            color: AppColors.inputFill.withValues(alpha: 0.35),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
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
                'Click to browse files',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                'Supported formats: Images (JPG, PNG) and PDF',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onOpenSheet,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF4B633D),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                icon: const Icon(Icons.description_outlined, size: 18),
                label: const Text(
                  'Browse Files',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        color: AppColors.inputFill.withValues(alpha: 0.35),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final doc in documents)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doc.fileName,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          doc.documentType,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: AppColors.danger),
                    onPressed: () => onRemove(doc),
                  ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onOpenSheet,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add More'),
            ),
          ),
        ],
      ),
    );
  }
}
