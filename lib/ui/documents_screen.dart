import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_strings.dart';
import 'package:rapide_nforce/core/utils/api_feedback.dart';
import 'package:rapide_nforce/models/document_model.dart';
import 'package:rapide_nforce/services/document_service.dart';
import 'package:rapide_nforce/ui/widgets/fleet_list_card.dart';
import 'package:rapide_nforce/ui/widgets/screen_state_builder.dart';
import 'package:rapide_nforce/ui/widgets/web_ui.dart';
import 'package:url_launcher/url_launcher.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  bool _loading = true;
  String? _error;
  List<DocumentModel> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await DocumentService.instance.fetchDocuments();
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

  Future<void> _openDocument(DocumentModel doc) async {
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

  @override
  Widget build(BuildContext context) {
    return ScreenStateBuilder(
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
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) {
              final doc = _items[i];
              return FleetListCard(
                title: doc.title,
                subtitle: '${doc.category} · ${doc.uploadedOn}',
                leading: const Icon(Icons.description_outlined),
                onTap: () => _openDocument(doc),
              );
            },
            childCount: _items.length,
          ),
        ),
      ),
    );
  }
}
