enum OpportunityStatus {
  newLead,
  inProgress,
  converted,
  lost;

  static OpportunityStatus fromApi(String? value) {
    switch (value?.toLowerCase()) {
      case 'new':
      case 'new_lead':
        return OpportunityStatus.newLead;
      case 'in_progress':
      case 'active':
        return OpportunityStatus.inProgress;
      case 'converted':
      case 'won':
        return OpportunityStatus.converted;
      case 'lost':
        return OpportunityStatus.lost;
      default:
        return OpportunityStatus.newLead;
    }
  }

  String get label {
    switch (this) {
      case OpportunityStatus.newLead:
        return 'New Lead';
      case OpportunityStatus.inProgress:
        return 'In Progress';
      case OpportunityStatus.converted:
        return 'Converted';
      case OpportunityStatus.lost:
        return 'Lost';
    }
  }
}

class OpportunityModel {
  const OpportunityModel({
    required this.id,
    required this.customerName,
    required this.company,
    required this.status,
    required this.value,
    required this.lastUpdated,
    this.contactPhone,
    this.location,
    this.assignedTo,
  });

  final int id;
  final String customerName;
  final String company;
  final OpportunityStatus status;
  final double value;
  final DateTime lastUpdated;
  final String? contactPhone;
  final String? location;
  final String? assignedTo;

  factory OpportunityModel.fromJson(Map<String, dynamic> json) {
    return OpportunityModel(
      id: json['id'] as int? ?? 0,
      customerName: json['customer_name'] as String? ??
          json['customerName'] as String? ??
          '',
      company: json['company'] as String? ?? '',
      status: OpportunityStatus.fromApi(json['status'] as String?),
      value: (json['value'] as num?)?.toDouble() ?? 0,
      lastUpdated: DateTime.tryParse(json['last_updated'] as String? ?? '') ??
          DateTime.tryParse(json['lastUpdated'] as String? ?? '') ??
          DateTime.now(),
      contactPhone:
          json['contact_phone'] as String? ?? json['contactPhone'] as String?,
      location: json['location'] as String?,
      assignedTo:
          json['assigned_to'] as String? ?? json['assignedTo'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'customer_name': customerName,
        'company': company,
        'status': status.name,
        'value': value,
        'last_updated': lastUpdated.toIso8601String(),
        'contact_phone': contactPhone,
        'location': location,
        'assigned_to': assignedTo,
      };
}
