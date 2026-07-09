import 'package:intl/intl.dart';

class TruckDocumentModel {
  const TruckDocumentModel({
    required this.id,
    required this.truckId,
    required this.fileName,
    this.fileType,
    this.documentType,
    this.documentCategory,
    this.location,
    this.issueDate,
    this.expiryDate,
    this.issueDateIso,
    this.expiryDateIso,
    this.documentNumber,
    this.notes,
    this.updatedOn,
    this.statusLabel,
    this.fileUrl,
  });

  final int id;
  final int truckId;
  final String fileName;
  final String? fileType;
  final String? documentType;
  final String? documentCategory;
  final String? location;
  final String? issueDate;
  final String? expiryDate;
  /// Raw (unformatted) ISO dates — used to prefill editable date fields.
  final String? issueDateIso;
  final String? expiryDateIso;
  final String? documentNumber;
  final String? notes;
  final String? updatedOn;
  final String? statusLabel;
  final String? fileUrl;

  factory TruckDocumentModel.fromJson(Map<String, dynamic> json) {
    final issueRaw = json['issueDate'] as String? ?? json['issue_date'] as String?;
    final expiryRaw =
        json['expiryDate'] as String? ?? json['expiry_date'] as String?;
    return TruckDocumentModel(
      id: json['id'] as int? ?? 0,
      truckId: json['truckId'] as int? ?? json['truck_id'] as int? ?? 0,
      fileName: json['fileName'] as String? ??
          json['file_name'] as String? ??
          json['additionalDocFileName'] as String? ??
          'Document',
      fileType: json['fileType'] as String? ?? json['file_type'] as String?,
      documentType:
          json['documentType'] as String? ?? json['document_type'] as String?,
      documentCategory: json['documentCategory'] as String? ??
          json['document_category'] as String?,
      location: json['location'] as String?,
      issueDate: _formatDate(issueRaw),
      expiryDate: _formatDate(expiryRaw),
      issueDateIso: _isoDate(issueRaw),
      expiryDateIso: _isoDate(expiryRaw),
      documentNumber: json['documentNumber'] as String? ??
          json['document_number'] as String?,
      notes: json['notes'] as String?,
      updatedOn: _formatDate(
        json['updatedOn'] as String? ?? json['updated_on'] as String?,
      ),
      statusLabel: json['status']?.toString(),
      fileUrl: json['fileUrl'] as String? ?? json['file_url'] as String?,
    );
  }

  static String? _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return iso;
    return DateFormat('d MMM yyyy').format(parsed);
  }

  static String? _isoDate(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return null;
    return DateFormat('yyyy-MM-dd').format(parsed);
  }
}
