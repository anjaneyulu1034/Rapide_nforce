class ImportRowError {
  const ImportRowError({this.row, this.column, required this.message});

  final int? row;
  final String? column;
  final String message;

  factory ImportRowError.fromJson(dynamic json) {
    if (json is String) return ImportRowError(message: json);
    final map = json is Map ? json : <String, dynamic>{};
    final message = map['message'] ?? map['error'] ?? map['reason'];
    final row = map['row'] ?? map['rowNumber'] ?? map['line'];
    final column = map['column'] ?? map['field'];
    return ImportRowError(
      row: row is int ? row : int.tryParse(row?.toString() ?? ''),
      column: column?.toString(),
      message: message?.toString() ?? 'Unknown error',
    );
  }
}

class ImportResult {
  const ImportResult({
    required this.totalCount,
    required this.successCount,
    required this.failedCount,
    required this.skippedCount,
    required this.errors,
    this.message,
  });

  final int totalCount;
  final int successCount;
  final int failedCount;
  final int skippedCount;
  final List<ImportRowError> errors;
  final String? message;

  factory ImportResult.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic v) => v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;
    final rawErrors =
        json['errors'] ?? json['failedRows'] ?? json['rowErrors'] ?? json['failures'];
    return ImportResult(
      totalCount: toInt(
        json['totalCount'] ?? json['total'] ?? json['totalRows'] ?? json['processedCount'],
      ),
      successCount: toInt(
        json['successCount'] ?? json['importedCount'] ?? json['success'] ?? json['successful'],
      ),
      failedCount: toInt(
        json['failedCount'] ?? json['failed'] ?? json['errorCount'] ?? json['errorsCount'],
      ),
      skippedCount: toInt(json['skippedCount'] ?? json['skipped'] ?? json['skippedRows']),
      errors: rawErrors is List
          ? rawErrors.map(ImportRowError.fromJson).toList()
          : const [],
      message: json['message'] as String?,
    );
  }
}
