enum LeadStatus { hot, warm, cold }

class LeadModel {
  const LeadModel({
    required this.id,
    required this.name,
    required this.company,
    required this.phone,
    required this.status,
    required this.source,
    required this.createdAt,
  });

  final int id;
  final String name;
  final String company;
  final String phone;
  final LeadStatus status;
  final String source;
  final DateTime createdAt;

  factory LeadModel.fromJson(Map<String, dynamic> json) {
    return LeadModel(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      company: json['company'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      status: _statusFrom(json['status'] as String?),
      source: json['source'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  static LeadStatus _statusFrom(String? value) {
    switch (value?.toLowerCase()) {
      case 'hot':
        return LeadStatus.hot;
      case 'cold':
        return LeadStatus.cold;
      default:
        return LeadStatus.warm;
    }
  }

  String get statusLabel {
    switch (status) {
      case LeadStatus.hot:
        return 'Hot';
      case LeadStatus.warm:
        return 'Warm';
      case LeadStatus.cold:
        return 'Cold';
    }
  }
}
