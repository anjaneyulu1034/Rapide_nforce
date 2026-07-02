class CompanyModel {
  const CompanyModel({
    required this.id,
    required this.name,
  });

  final int id;
  final String name;

  factory CompanyModel.fromJson(Map<String, dynamic> json) {
    return CompanyModel(
      id: json['id'] as int? ?? int.tryParse('${json['id']}') ?? 0,
      name: (json['name'] as String? ?? '').trim(),
    );
  }
}
