import 'package:intl/intl.dart';

class DocumentHistoryModel {
  const DocumentHistoryModel({
    required this.versionNumber,
    required this.isCurrent,
    this.uploadedAt,
    this.uploadedByName,
    this.changeType,
    this.notes,
    this.fileUrl,
  });

  final int versionNumber;
  final bool isCurrent;
  final String? uploadedAt;
  final String? uploadedByName;
  final String? changeType;
  final String? notes;
  final String? fileUrl;

  String get formattedUploadedAt {
    if (uploadedAt == null || uploadedAt!.isEmpty) return '—';
    final parsed = DateTime.tryParse(uploadedAt!);
    if (parsed == null) return uploadedAt!;
    return DateFormat('MM-dd-yyyy').format(parsed);
  }

  factory DocumentHistoryModel.fromJson(Map<String, dynamic> json) {
    return DocumentHistoryModel(
      versionNumber: (json['versionNumber'] as num?)?.toInt() ?? 0,
      isCurrent: json['isCurrent'] as bool? ?? false,
      uploadedAt: json['uploadedAt']?.toString(),
      uploadedByName: json['uploadedByName']?.toString(),
      changeType: json['changeType']?.toString(),
      notes: json['notes']?.toString(),
      fileUrl: json['fileUrl']?.toString() ?? json['filePath']?.toString(),
    );
  }
}
