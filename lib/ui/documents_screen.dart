import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/core/constants/app_strings.dart';
import 'package:rapide_nforce/core/utils/api_feedback.dart';
import 'package:rapide_nforce/core/utils/app_toast.dart';
import 'package:rapide_nforce/models/document_history_model.dart';
import 'package:rapide_nforce/models/document_model.dart';
import 'package:rapide_nforce/models/power_unit_model.dart';
import 'package:rapide_nforce/services/document_service.dart';
import 'package:rapide_nforce/services/permission_service.dart';
import 'package:rapide_nforce/services/power_unit_service.dart';
import 'package:rapide_nforce/ui/power_unit/power_unit_upload_document_sheet.dart';
import 'package:rapide_nforce/ui/widgets/screen_state_builder.dart';
import 'package:rapide_nforce/ui/widgets/web_form_field.dart';
import 'package:rapide_nforce/ui/widgets/web_ui.dart';
import 'package:url_launcher/url_launcher.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  bool _loading = true;
  String? _error;
  List<DocumentModel> _items = [];
  String _search = '';
  bool _canManage = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _load();
    _loadPermission();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPermission() async {
    final result = await PermissionService.instance.canCreate(
      menuUrl: '/documents',
      menuName: 'Documents',
    );
    if (!mounted) return;
    setState(() => _canManage = result.isSuccess && (result.data ?? false));
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      final next = _searchController.text.trim();
      if (next == _search) return;
      _search = next;
      _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await DocumentService.instance.fetchDocuments(
      search: _search.isEmpty ? null : _search,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result.isSuccess) {
        _items = result.data?.items ?? [];
      } else {
        _error = result.message ?? 'Failed to load documents';
      }
    });
  }

  Future<void> _downloadDocument(DocumentModel doc) async {
    final result = await DocumentService.instance.getDownloadUrl(doc.id);
    if (!mounted) return;
    if (!result.isSuccess || result.data == null || result.data!.isEmpty) {
      ApiFeedback.showError(result, fallback: 'Unable to open document');
      return;
    }
    final uri = Uri.tryParse(result.data!);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _viewDocument(DocumentModel doc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DocumentDetailsSheet(
        doc: doc,
        canManage: _canManage,
        onDownload: () => _downloadDocument(doc),
        onRenew: () => _renewDocument(doc),
      ),
    );
  }

  void _viewHistory(DocumentModel doc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _VersionHistorySheet(doc: doc),
    );
  }

  Future<void> _renewDocument(DocumentModel doc) async {
    final renewed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _RenewDocumentSheet(doc: doc),
      ),
    );
    if (renewed == true) _load();
  }

  Future<void> _confirmDelete(DocumentModel doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(
          'Delete document?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Remove "${doc.title}"? This cannot be undone.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final result = await DocumentService.instance.deleteDocument(doc.id);
    if (!mounted) return;
    if (result.isSuccess) {
      AppToast.showSuccess('Document deleted');
      _load();
    } else {
      ApiFeedback.showError(result, fallback: 'Delete failed');
    }
  }

  Future<void> _openUploadPicker() async {
    final result = await PowerUnitService.instance.fetchPowerUnits(limit: 100);
    if (!mounted) return;
    if (!result.isSuccess || result.data == null || result.data!.items.isEmpty) {
      ApiFeedback.showError(result, fallback: 'No power units available');
      return;
    }
    final units = result.data!.items;
    final selected = await showModalBottomSheet<PowerUnitModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Select a unit to upload a document for',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: units.length,
                    itemBuilder: (context, i) {
                      final unit = units[i];
                      return ListTile(
                        leading: Icon(
                          Icons.local_shipping_outlined,
                          color: AppColors.primary,
                        ),
                        title: Text(unit.unitNumber),
                        onTap: () => Navigator.pop(sheetContext, unit),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (selected == null || !mounted) return;
    final uploaded = await showPowerUnitUploadDocumentSheet(
      context: context,
      truckId: selected.id,
      unit: selected,
    );
    if (uploaded == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: _canManage
          ? FloatingActionButton.extended(
              onPressed: _openUploadPicker,
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('Upload Document'),
            )
          : null,
      body: ScreenStateBuilder(
        loading: _loading,
        error: _error,
        onRetry: _load,
        isEmpty: _items.isEmpty,
        emptyMessage: AppStrings.noData,
        emptyIcon: Icons.description_outlined,
        child: WebListPage(
          title: 'Documents',
          subtitle: '${_items.length} files',
          onRefresh: _load,
          toolbar: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by document type, entity type, or entity name...',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => _searchController.clear(),
                    ),
            ),
          ),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final doc = _items[i];
                return _DocumentCard(
                  doc: doc,
                  canManage: _canManage,
                  onView: () => _viewDocument(doc),
                  onDownload: () => _downloadDocument(doc),
                  onRenew: () => _renewDocument(doc),
                  onHistory: () => _viewHistory(doc),
                  onDelete: () => _confirmDelete(doc),
                );
              },
              childCount: _items.length,
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    if (status == 'no-expiry') {
      return Text('N/A', style: TextStyle(fontSize: 11, color: AppColors.textSecondary));
    }
    if (status == 'expired') {
      return _pill('Expired', const Color(0xFFD4183D), Colors.white);
    }
    if (status == 'active') {
      return _pill('Active', const Color(0xFFDCFCE7), const Color(0xFF15803D));
    }
    if (RegExp(r'^\d+d$').hasMatch(status)) {
      return _pill(status, const Color(0xFFF54900), Colors.white);
    }
    return _pill(status, const Color(0xFFF1F5F9), const Color(0xFF475569));
  }

  Widget _pill(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.doc,
    required this.canManage,
    required this.onView,
    required this.onDownload,
    required this.onRenew,
    required this.onHistory,
    required this.onDelete,
  });

  final DocumentModel doc;
  final bool canManage;
  final VoidCallback onView;
  final VoidCallback onDownload;
  final VoidCallback onRenew;
  final VoidCallback onHistory;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onView,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.description_outlined, size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      doc.title,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ),
                  _StatusBadge(status: doc.derivedStatus),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${doc.entityTypeName?.trim().isNotEmpty == true ? doc.entityTypeName : 'N/A'} · '
                '${doc.entityName?.trim().isNotEmpty == true ? doc.entityName : 'N/A'}',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                'Issued ${doc.issueDate} · Expires ${doc.expiryDate}',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              const Divider(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ActionBtn(icon: Icons.visibility_outlined, tooltip: 'View', onTap: onView),
                  _ActionBtn(icon: Icons.download_outlined, tooltip: 'Download', onTap: onDownload),
                  if (canManage)
                    _ActionBtn(
                      icon: Icons.upload_file_outlined,
                      tooltip: 'Upload New Version',
                      onTap: onRenew,
                    ),
                  _ActionBtn(icon: Icons.history_outlined, tooltip: 'History', onTap: onHistory),
                  _ActionBtn(
                    icon: Icons.delete_outline,
                    tooltip: 'Delete',
                    color: AppColors.danger,
                    onTap: onDelete,
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

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
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
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 20, color: color ?? AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _DocumentDetailsSheet extends StatelessWidget {
  const _DocumentDetailsSheet({
    required this.doc,
    required this.canManage,
    required this.onDownload,
    required this.onRenew,
  });

  final DocumentModel doc;
  final bool canManage;
  final VoidCallback onDownload;
  final VoidCallback onRenew;

  @override
  Widget build(BuildContext context) {
    final status = doc.derivedStatus;
    final isExpired = status == 'expired';
    final isExpiring = RegExp(r'^\d+d$').hasMatch(status);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Document Details',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: AppColors.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      doc.title,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ),
                  _StatusBadge(status: status),
                ],
              ),
              const SizedBox(height: 16),
              _DetailRow(label: 'Document Number', value: doc.documentNumber ?? '—'),
              _DetailRow(label: 'Document Type', value: doc.title),
              _DetailRow(label: 'Entity Type', value: doc.entityTypeName ?? 'N/A'),
              _DetailRow(label: 'Entity Name', value: doc.entityName ?? 'N/A'),
              _DetailRow(label: 'Issue Date', value: doc.issueDate ?? '—'),
              _DetailRow(label: 'Expiry Date', value: doc.expiryDate ?? '—'),
              if (isExpired || isExpiring) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (isExpired ? AppColors.danger : AppColors.warning)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: (isExpired ? AppColors.danger : AppColors.warning)
                          .withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: isExpired ? AppColors.danger : AppColors.warning,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isExpired
                              ? 'This document has expired. Renewal required.'
                              : 'This document is expiring soon.',
                          style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onDownload,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1A1A1A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const Text('Download'),
                    ),
                  ),
                ],
              ),
              if (canManage) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      onRenew();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.upload_rounded, size: 18),
                    label: const Text('Upload New Version'),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _VersionHistorySheet extends StatefulWidget {
  const _VersionHistorySheet({required this.doc});

  final DocumentModel doc;

  @override
  State<_VersionHistorySheet> createState() => _VersionHistorySheetState();
}

class _VersionHistorySheetState extends State<_VersionHistorySheet> {
  bool _loading = true;
  List<DocumentHistoryModel> _versions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await DocumentService.instance.getDocumentHistory(widget.doc.id);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _versions = result.data ?? [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Version History',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            widget.doc.title,
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _versions.isEmpty
                        ? Center(
                            child: Text(
                              'No version history available',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _versions.length,
                            itemBuilder: (context, i) {
                              final v = _versions[i];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: v.isCurrent
                                      ? AppColors.primary.withValues(alpha: 0.08)
                                      : null,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: v.isCurrent
                                                ? AppColors.primary
                                                : AppColors.border,
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            'Version ${v.versionNumber}'
                                            '${v.isCurrent ? ' (Current)' : ''}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: v.isCurrent
                                                  ? Colors.white
                                                  : AppColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          v.formattedUploadedAt,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'By ${v.uploadedByName ?? '—'} · '
                                      '${v.changeType ?? '—'}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    if ((v.notes ?? '').isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        v.notes!,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RenewDocumentSheet extends StatefulWidget {
  const _RenewDocumentSheet({required this.doc});

  final DocumentModel doc;

  @override
  State<_RenewDocumentSheet> createState() => _RenewDocumentSheetState();
}

class _RenewDocumentSheetState extends State<_RenewDocumentSheet> {
  late final _number = TextEditingController(text: widget.doc.documentNumber);
  late final _issueDate = TextEditingController(text: widget.doc.issueDateIso);
  late final _expiryDate = TextEditingController(text: widget.doc.expiryDateIso);
  final _notes = TextEditingController();
  String? _filePath;
  String? _fileName;
  bool _saving = false;

  @override
  void dispose() {
    _number.dispose();
    _issueDate.dispose();
    _expiryDate.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'doc', 'docx'],
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.first;
    setState(() {
      _filePath = file.path;
      _fileName = file.name;
    });
  }

  Future<void> _save() async {
    if (_issueDate.text.trim().isEmpty) {
      AppToast.showError('Select issue date');
      return;
    }
    setState(() => _saving = true);
    final result = await DocumentService.instance.renewDocument(
      documentId: widget.doc.id,
      filePath: _filePath,
      fileName: _fileName,
      issueDate: _issueDate.text.trim(),
      expiryDate: _expiryDate.text.trim().isEmpty ? null : _expiryDate.text.trim(),
      documentNumber: _number.text.trim(),
      notes: _notes.text.trim(),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (result.isSuccess) {
      AppToast.showSuccess('Document renewed');
      Navigator.pop(context, true);
    } else {
      ApiFeedback.showError(result, fallback: 'Renew failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Renew Document',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.doc.title,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${widget.doc.entityTypeName ?? 'N/A'} · ${widget.doc.entityName ?? 'N/A'}',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            WebTextFormField(controller: _number, label: 'Document Number'),
            WebDateField(controller: _issueDate, label: 'Issue Date', required: true),
            WebDateField(controller: _expiryDate, label: 'Expiry Date'),
            WebFileUploadZone(fileName: _fileName, onBrowse: _pickFile),
            const SizedBox(height: 12),
            WebTextFormField(controller: _notes, label: 'Notes', maxLines: 3),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1A1A1A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.upload_rounded, size: 18),
                    label: const Text('Renew Document'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
