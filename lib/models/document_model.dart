import 'package:intl/intl.dart';

class DocumentModel {
  const DocumentModel({
    required this.id,
    required this.title,
    required this.category,
    required this.uploadedOn,
    this.entityName,
    this.status,
    this.expiryDate,
  });

  final int id;
  final String title;
  final String category;
  final String uploadedOn;
  final String? entityName;
  final String? status;
  final String? expiryDate;

  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    final title = json['name'] as String? ??
        json['fileName'] as String? ??
        json['documentNumber'] as String? ??
        json['title'] as String? ??
        'Document';

    final category = json['documentCategory'] as String? ??
        json['category'] as String? ??
        json['type'] as String? ??
        json['entityTypeName'] as String? ??
        'General';

    final uploaded = json['uploadedDate'] as String? ??
        json['updateddate'] as String? ??
        json['uploaded_on'] as String?;

    return DocumentModel(
      id: int.tryParse(json['id']?.toString() ?? '') ??
          json['id'] as int? ??
          0,
      title: title,
      category: category,
      uploadedOn: _formatDate(uploaded),
      entityName: json['entityName'] as String? ?? json['entity'] as String?,
      status: json['status']?.toString(),
      expiryDate: json['expiryDate'] as String?,
    );
  }

  static String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return iso;
    return DateFormat('d MMM yyyy').format(parsed.toLocal());
  }
}
