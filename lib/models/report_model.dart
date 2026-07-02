class ReportModel {
  const ReportModel({
    required this.id,
    required this.title,
    required this.period,
    required this.summary,
    required this.value,
    required this.trendPercent,
  });

  final int id;
  final String title;
  final String period;
  final String summary;
  final String value;
  final double trendPercent;

  factory ReportModel.fromJson(Map<String, dynamic> json) {
    return ReportModel(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      period: json['period'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      value: json['value']?.toString() ?? '0',
      trendPercent: (json['trend_percent'] as num?)?.toDouble() ?? 0,
    );
  }
}
