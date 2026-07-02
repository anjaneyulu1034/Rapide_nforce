class ExpiringDocumentModel {
  const ExpiringDocumentModel({
    required this.id,
    this.documentType,
    this.expiryDate,
    this.vehicleId,
    this.vehicleUnit,
    this.unitType,
    this.entityTypeName,
    this.companyName,
    this.createdAt,
  });

  final dynamic id;
  final String? documentType;
  final String? expiryDate;
  final int? vehicleId;
  final String? vehicleUnit;
  final String? unitType;
  final String? entityTypeName;
  final String? companyName;
  final String? createdAt;

  factory ExpiringDocumentModel.fromJson(Map<String, dynamic> json) {
    return ExpiringDocumentModel(
      id: json['id'] ?? json['documentId'],
      documentType: json['documentType'] as String? ??
          json['document_type'] as String?,
      expiryDate: json['expiryDate'] as String? ??
          json['expiry_date'] as String?,
      vehicleId: (json['vehicleId'] as num?)?.toInt() ??
          (json['vehicle_id'] as num?)?.toInt(),
      vehicleUnit: json['vehicleUnit'] as String? ??
          json['vehicle_unit'] as String?,
      unitType: json['unitType'] as String? ?? json['unit_type'] as String?,
      entityTypeName: json['entityTypeName'] as String? ??
          json['entity_type_name'] as String?,
      companyName: json['companyName'] as String? ??
          json['company_name'] as String?,
      createdAt: json['createdAt'] as String? ?? json['created_at'] as String?,
    );
  }
}
