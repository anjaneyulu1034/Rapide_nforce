enum LiveDealStage { negotiation, proposal, closing }

class LiveDealModel {
  const LiveDealModel({
    required this.id,
    required this.dealName,
    required this.customer,
    required this.value,
    required this.stage,
    required this.probability,
    required this.expectedCloseDate,
  });

  final int id;
  final String dealName;
  final String customer;
  final double value;
  final LiveDealStage stage;
  final int probability;
  final DateTime expectedCloseDate;

  factory LiveDealModel.fromJson(Map<String, dynamic> json) {
    return LiveDealModel(
      id: json['id'] as int? ?? 0,
      dealName: json['deal_name'] as String? ?? '',
      customer: json['customer'] as String? ?? '',
      value: (json['value'] as num?)?.toDouble() ?? 0,
      stage: _stageFrom(json['stage'] as String?),
      probability: json['probability'] as int? ?? 0,
      expectedCloseDate:
          DateTime.tryParse(json['expected_close_date'] as String? ?? '') ??
              DateTime.now(),
    );
  }

  static LiveDealStage _stageFrom(String? value) {
    switch (value?.toLowerCase()) {
      case 'proposal':
        return LiveDealStage.proposal;
      case 'closing':
        return LiveDealStage.closing;
      default:
        return LiveDealStage.negotiation;
    }
  }

  String get stageLabel {
    switch (stage) {
      case LiveDealStage.negotiation:
        return 'Negotiation';
      case LiveDealStage.proposal:
        return 'Proposal';
      case LiveDealStage.closing:
        return 'Closing';
    }
  }
}
