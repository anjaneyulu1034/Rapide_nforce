import 'package:intl/intl.dart';
import 'package:rapide_nforce/models/document_model.dart';

class CarrierModel {
  const CarrierModel({
    required this.id,
    required this.name,
    this.dba,
    this.email,
    this.phone,
    this.consentStatus,
    this.startDate,
    this.cvorNumber,
    this.nscNumber,
    this.usdotNumber,
    this.mcNumber,
    this.isActive,
    this.planName,
    this.billingCycleName,
    this.address,
    this.city,
    this.province,
    this.postalCode,
    this.website,
    this.raw,
  });

  final int id;
  final String name;
  final String? dba;
  final String? email;
  final String? phone;
  final String? consentStatus;
  final String? startDate;
  final String? cvorNumber;
  final String? nscNumber;
  final String? usdotNumber;
  final String? mcNumber;
  final bool? isActive;
  final String? planName;
  final String? billingCycleName;
  final String? address;
  final String? city;
  final String? province;
  final String? postalCode;
  final String? website;
  final Map<String, dynamic>? raw;

  String get displayName => name.isNotEmpty ? name : 'Carrier #$id';

  String get statusLabel {
    if (isActive == true) return 'Active';
    if (isActive == false) return 'Inactive';
    return 'Active';
  }

  String get consentStatusLabel {
    final s = (consentStatus ?? '').trim();
    if (s.isEmpty) return '—';
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }

  factory CarrierModel.fromJson(Map<String, dynamic> json) {
    final companyDetails =
        json['companyDetails'] as Map<String, dynamic>? ?? {};
    final regulatory = json['regulatory'] as Map<String, dynamic>? ??
        (json['regulatoryProfiles'] is List &&
                (json['regulatoryProfiles'] as List).isNotEmpty
            ? (json['regulatoryProfiles'] as List).first as Map<String, dynamic>
            : null) ??
        json['regulatoryProfile'] as Map<String, dynamic>? ??
        {};
    final subscription = json['subscription'] as Map<String, dynamic>? ??
        (json['subscriptions'] is List &&
                (json['subscriptions'] as List).isNotEmpty
            ? (json['subscriptions'] as List).first as Map<String, dynamic>
            : null);

    final companyDocs = json['company_documents'] as List?;
    final companyDoc = companyDocs?.isNotEmpty == true
        ? companyDocs!.first as Map<String, dynamic>
        : json['CompanyDocuments'] as Map<String, dynamic>?;

    final addressObj = json['address'];
    String? street;
    String? city;
    String? province;
    String? postal;
    if (addressObj is Map<String, dynamic>) {
      street = addressObj['address'] as String?;
      city = addressObj['city']?.toString();
      province = addressObj['province']?.toString();
      postal = addressObj['postalCode'] as String? ??
          addressObj['postal_code'] as String?;
    } else if (addressObj is String) {
      street = addressObj;
    }

    final active = json['is_active'] ?? json['active'];
    bool? isActive;
    if (active == true || active == 1) {
      isActive = true;
    } else if (active == false || active == 0) {
      isActive = false;
    }

    final startRaw = subscription?['startDate'] as String? ??
        subscription?['start_date'] as String? ??
        companyDetails['start_date'] as String? ??
        json['start_date'] as String?;

    return CarrierModel(
      id: json['id'] as int? ?? 0,
      name: (json['name'] as String? ??
              companyDetails['legalName'] as String? ??
              json['carrier_name'] as String? ??
              '')
          .trim(),
      dba: json['dba'] as String? ??
          companyDetails['operatingName'] as String?,
      email: json['email'] as String? ??
          companyDetails['companyEmail'] as String?,
      phone: json['phone'] as String? ??
          companyDetails['phoneNumber'] as String?,
      consentStatus: companyDoc?['status'] as String?,
      startDate: _formatDate(startRaw),
      cvorNumber: regulatory['cvorNumber'] as String? ??
          json['cvor_number'] as String?,
      nscNumber: regulatory['nscNumber'] as String? ??
          json['mc_number'] as String?,
      usdotNumber: regulatory['usdotNumber'] as String? ??
          json['dot_number'] as String?,
      mcNumber: regulatory['mcNumber'] as String?,
      isActive: isActive,
      planName: subscription?['planName'] as String? ??
          (subscription?['plan'] as Map<String, dynamic>?)?['name'] as String?,
      billingCycleName: subscription?['billingCycleName'] as String? ??
          (subscription?['billingCycle'] as Map<String, dynamic>?)?['name']
              as String?,
      address: street,
      city: city,
      province: province,
      postalCode: postal,
      website: companyDetails['website'] as String?,
      raw: json,
    );
  }

  static String? _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return iso;
    return DateFormat('d MMM yyyy').format(parsed);
  }
}

class PlanOption {
  const PlanOption({required this.id, required this.name});

  final int id;
  final String name;

  factory PlanOption.fromJson(Map<String, dynamic> json) {
    return PlanOption(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
    );
  }
}

class BillingCycleOption {
  const BillingCycleOption({required this.id, required this.name});

  final int id;
  final String name;

  factory BillingCycleOption.fromJson(Map<String, dynamic> json) {
    return BillingCycleOption(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
    );
  }
}

class CarrierComplianceData {
  const CarrierComplianceData({
    required this.documents,
    required this.totalDocuments,
    required this.validDocuments,
    required this.expiringDocuments,
    required this.expiredDocuments,
  });

  final List<DocumentModel> documents;
  final int totalDocuments;
  final int validDocuments;
  final int expiringDocuments;
  final int expiredDocuments;
}
