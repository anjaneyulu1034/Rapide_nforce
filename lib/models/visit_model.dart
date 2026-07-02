enum VisitStatus { scheduled, inProgress, completed, cancelled }

class VisitModel {
  const VisitModel({
    required this.id,
    required this.customerName,
    required this.address,
    required this.purpose,
    required this.scheduledAt,
    required this.status,
  });

  final int id;
  final String customerName;
  final String address;
  final String purpose;
  final DateTime scheduledAt;
  final VisitStatus status;

  factory VisitModel.fromJson(Map<String, dynamic> json) {
    return VisitModel(
      id: json['id'] as int? ?? 0,
      customerName: json['customer_name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      purpose: json['purpose'] as String? ?? '',
      scheduledAt: DateTime.tryParse(json['scheduled_at'] as String? ?? '') ??
          DateTime.now(),
      status: _statusFrom(json['status'] as String?),
    );
  }

  static VisitStatus _statusFrom(String? value) {
    switch (value?.toLowerCase()) {
      case 'in_progress':
        return VisitStatus.inProgress;
      case 'completed':
        return VisitStatus.completed;
      case 'cancelled':
        return VisitStatus.cancelled;
      default:
        return VisitStatus.scheduled;
    }
  }

  String get statusLabel {
    switch (status) {
      case VisitStatus.scheduled:
        return 'Scheduled';
      case VisitStatus.inProgress:
        return 'In Progress';
      case VisitStatus.completed:
        return 'Completed';
      case VisitStatus.cancelled:
        return 'Cancelled';
    }
  }
}
