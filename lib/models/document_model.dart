import 'package:intl/intl.dart';

class DocumentModel {
  const DocumentModel({
    required this.id,
    required this.title,
    required this.category,
    required this.uploadedOn,
    this.entityName,
    this.entityTypeName,
    this.documentNumber,
    this.status,
    this.expiryDate,
    this.issueDate,
    this.expiryDateIso,
    this.issueDateIso,
  });

  final int id;
  final String title;
  final String category;
  final String uploadedOn;
  final String? entityName;
  final String? entityTypeName;
  final String? documentNumber;
  final String? status;
  final String? expiryDate;
  final String? issueDate;
  final String? expiryDateIso;
  final String? issueDateIso;

  /// Derived like the web's `deriveStatus`: 'expired' | 'Xd' | 'active' | 'no-expiry'.
  String get derivedStatus {
    if (expiryDateIso == null || expiryDateIso!.isEmpty) return 'no-expiry';
    final expiry = DateTime.tryParse(expiryDateIso!);
    if (expiry == null) return 'no-expiry';
    final daysLeft = DateTime(expiry.year, expiry.month, expiry.day)
        .difference(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day))
        .inDays;
    if (daysLeft < 0) return 'expired';
    if (daysLeft <= 45) return '${daysLeft}d';
    return 'active';
  }

  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    final title = json['documentType'] as String? ??
        json['title'] as String? ??
        json['documentNumber'] as String? ??
        json['name'] as String? ??
        json['fileName'] as String? ??
        'Document';

    final category = json['documentCategory'] as String? ??
        json['category'] as String? ??
        json['type'] as String? ??
        json['entityTypeName'] as String? ??
        'General';

    final uploaded = json['uploadedDate'] as String? ??
        json['updateddate'] as String? ??
        json['uploaded_on'] as String?;

    final issueRaw = json['issueDate'] as String?;
    final expiryRaw = json['expiryDate'] as String?;

    return DocumentModel(
      id: int.tryParse(json['id']?.toString() ?? '') ??
          json['id'] as int? ??
          0,
      title: title,
      category: category,
      uploadedOn: _formatDate(uploaded),
      entityName: json['entityName'] as String? ??
          json['vehicleUnit'] as String? ??
          json['entity'] as String?,
      entityTypeName: json['entityTypeName'] as String?,
      documentNumber: json['documentNumber'] as String?,
      status: json['status']?.toString(),
      expiryDate: _formatDate(expiryRaw),
      issueDate: _formatDate(issueRaw),
      expiryDateIso: expiryRaw,
      issueDateIso: issueRaw,
    );
  }

  static String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return iso;
    return DateFormat('d MMM yyyy').format(parsed);
  }
}
