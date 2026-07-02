class CustomerModel {
  const CustomerModel({
    required this.id,
    required this.name,
    required this.company,
    required this.phone,
    required this.email,
    required this.city,
    required this.totalOrders,
    required this.lastOrderDate,
  });

  final int id;
  final String name;
  final String company;
  final String phone;
  final String email;
  final String city;
  final int totalOrders;
  final DateTime lastOrderDate;

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    return CustomerModel(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      company: json['company'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
      city: json['city'] as String? ?? '',
      totalOrders: json['total_orders'] as int? ?? 0,
      lastOrderDate:
          DateTime.tryParse(json['last_order_date'] as String? ?? '') ??
              DateTime.now(),
    );
  }
}
