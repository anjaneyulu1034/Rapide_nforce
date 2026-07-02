class TruckPermitModel {
  const TruckPermitModel({
    this.id,
    required this.permitType,
    required this.permitNumber,
    required this.issueDate,
    required this.expiryDate,
  });

  final int? id;
  final String permitType;
  final String permitNumber;
  final String issueDate;
  final String expiryDate;

  factory TruckPermitModel.fromJson(Map<String, dynamic> json) {
    return TruckPermitModel(
      id: json['id'] as int?,
      permitType: json['permitType'] as String? ??
          json['permit_type'] as String? ??
          '',
      permitNumber: json['permitNumber'] as String? ??
          json['permit_number'] as String? ??
          '',
      issueDate: json['issueDate'] as String? ??
          json['issue_date'] as String? ??
          '',
      expiryDate: json['expiryDate'] as String? ??
          json['expiry_date'] as String? ??
          '',
    );
  }

  Map<String, dynamic> toPayload() => {
        if (id != null) 'id': id,
        'permitType': permitType,
        'permitNumber': permitNumber,
        'issueDate': issueDate,
        'expiryDate': expiryDate,
      };
}

class LookupOption {
  const LookupOption({required this.id, required this.name, this.extra});

  final int id;
  final String name;
  final String? extra;

  factory LookupOption.fromJson(Map<String, dynamic> json) {
    return LookupOption(
      id: json['id'] as int? ?? 0,
      name: (json['name'] as String? ?? '').trim(),
      extra: json['code'] as String?,
    );
  }
}
