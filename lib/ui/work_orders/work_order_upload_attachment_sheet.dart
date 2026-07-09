import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/core/utils/api_feedback.dart';
import 'package:rapide_nforce/core/utils/app_toast.dart';
import 'package:rapide_nforce/services/maintenance_service.dart';
import 'package:rapide_nforce/ui/widgets/gradient_page_background.dart';
import 'package:rapide_nforce/ui/widgets/web_form_field.dart';

Future<bool?> showWorkOrderUploadAttachmentSheet({
  required BuildContext context,
  required int workOrderId,
}) {
  return Navigator.push<bool>(
    context,
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _UploadAttachmentSheet(workOrderId: workOrderId),
    ),
  );
}

class _UploadAttachmentSheet extends StatefulWidget {
  const _UploadAttachmentSheet({required this.workOrderId});

  final int workOrderId;

  @override
  State<_UploadAttachmentSheet> createState() =>
      _UploadAttachmentSheetState();
}

class _UploadAttachmentSheetState extends State<_UploadAttachmentSheet> {
  final List<PlatformFile> _files = [];
  bool _uploading = false;

  Future<void> _pickFromCamera() async {
    try {
      final picker = ImagePicker();
      final XFile? photo = await picker.pickImage(source: ImageSource.camera);
      if (photo == null) return;
      final bytes = await photo.readAsBytes();
      setState(() {
        _files.add(PlatformFile(
          path: photo.path,
          name: photo.name,
          size: bytes.length,
          bytes: bytes,
        ));
      });
    } catch (e) {
      AppToast.showError('Failed to capture image: $e');
    }
  }

  Future<void> _pickFromFiles() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'doc', 'docx'],
      allowMultiple: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    setState(() => _files.addAll(picked.files));
  }

  Future<void> _scanDocument() async {
    try {
      final picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (photo == null) return;

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const AlertDialog(
          backgroundColor: Colors.black87,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                'Scanning document...',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );

      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      Navigator.pop(context); // Dismiss dialog

      final bytes = await photo.readAsBytes();
      setState(() {
        _files.add(PlatformFile(
          path: photo.path,
          name: 'Scan_${DateTime.now().millisecondsSinceEpoch}.jpg',
          size: bytes.length,
          bytes: bytes,
        ));
      });
      AppToast.showSuccess('Document scanned successfully');
    } catch (e) {
      if (mounted) Navigator.pop(context);
      AppToast.showError('Failed to scan document: $e');
    }
  }

  Future<void> _upload() async {
    if (_files.isEmpty) {
      AppToast.showError('Select at least one file to upload');
      return;
    }
    final paths = _files.map((f) => f.path).whereType<String>().toList();
    setState(() => _uploading = true);
    final result = await MaintenanceService.instance.uploadWorkOrderAttachments(
      workOrderId: widget.workOrderId,
      filePaths: paths,
    );
    if (!mounted) return;
    setState(() => _uploading = false);
    if (result.isSuccess) {
      AppToast.showSuccess('Attachment${_files.length > 1 ? 's' : ''} uploaded');
      Navigator.pop(context, true);
    } else {
      ApiFeedback.showError(result, fallback: 'Upload failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return GradientPageBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Upload Attachment',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              WebFileUploadZone(
                fileName: _files.isEmpty
                    ? null
                    : _files.map((f) => f.name).join(', '),
                onBrowse: _pickFromFiles,
                onCamera: _pickFromCamera,
                onScan: _scanDocument,
              ),
              if (_files.isNotEmpty) ...[
                const SizedBox(height: 12),
                for (var i = 0; i < _files.length; i++)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isPreviewableImagePath(_files[i].path)
                              ? Icons.image_outlined
                              : Icons.insert_drive_file_outlined,
                          size: 18,
                          color: isPreviewableImagePath(_files[i].path)
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: isPreviewableImagePath(_files[i].path)
                                ? () => showLocalImagePreview(
                                    context, _files[i].path!)
                                : null,
                            child: Text(
                              _files[i].name,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: isPreviewableImagePath(_files[i].path)
                                    ? AppColors.primary
                                    : null,
                                decoration:
                                    isPreviewableImagePath(_files[i].path)
                                        ? TextDecoration.underline
                                        : null,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close,
                              size: 16, color: AppColors.textSecondary),
                          onPressed: () => setState(() => _files.removeAt(i)),
                        ),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed:
                          _uploading ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _uploading ? null : _upload,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1A1A1A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: _uploading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.upload_rounded, size: 18),
                      label: const Text(
                        'Upload',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
