class DriverModel {
  const DriverModel({
    required this.id,
    this.driverId,
    this.companyId,
    this.driverName,
    this.driverLastname,
    this.driverLicense,
    this.address,
    this.mobile,
    this.email,
    this.alternativeemail,
    this.phoneCan,
    this.phoneUsa,
    this.applicationDate,
    this.hireDate,
    this.inactiveDate,
    this.canadaOnly,
    this.usaOnly,
    this.driverType,
    this.ownerOperatorName,
    this.incorporationName,
    this.hst,
    this.directDepositDetails,
    this.licenseExpiry,
    this.province,
    this.country,
    this.sin,
    this.medicalDueDate,
    this.fastCardNumber,
    this.fastCartExpiry,
    this.passport,
    this.nationality,
    this.passportExpiry,
    this.workPermit,
    this.workPermitExpiry,
    this.abstractDate,
    this.cvor,
    this.cvorAbstractDate,
    this.pspDate,
    this.policeClearanceDate,
    this.roadtestDate,
    this.annualReviewDate,
    this.active,
    this.updatedOn,
    this.licenseClass,
    this.yearsOfExperience,
    this.licenseIssueDate,
    this.licenseRestrictions,
    this.licenseEndorsements,
    this.streetAddress,
    this.city,
    this.driverProvince,
    this.postalCode,
    this.raw,
  });

  final int id;
  final String? driverId;
  final int? companyId;
  final String? driverName;
  final String? driverLastname;
  final String? driverLicense;
  final String? address;
  final String? mobile;
  final String? email;
  final String? alternativeemail;
  final String? phoneCan;
  final String? phoneUsa;
  final String? applicationDate;
  final String? hireDate;
  final String? inactiveDate;
  final String? canadaOnly;
  final String? usaOnly;
  final String? driverType;
  final String? ownerOperatorName;
  final String? incorporationName;
  final String? hst;
  final String? directDepositDetails;
  final String? licenseExpiry;
  final String? province;
  final String? country;
  final String? sin;
  final String? medicalDueDate;
  final String? fastCardNumber;
  final String? fastCartExpiry;
  final String? passport;
  final String? nationality;
  final String? passportExpiry;
  final String? workPermit;
  final String? workPermitExpiry;
  final String? abstractDate;
  final String? cvor;
  final String? cvorAbstractDate;
  final String? pspDate;
  final String? policeClearanceDate;
  final String? roadtestDate;
  final String? annualReviewDate;
  final int? active;
  final String? updatedOn;
  final String? licenseClass;
  final int? yearsOfExperience;
  final String? licenseIssueDate;
  final String? licenseRestrictions;
  final String? licenseEndorsements;
  final String? streetAddress;
  final String? city;
  final String? driverProvince;
  final String? postalCode;
  final Map<String, dynamic>? raw;

  String get fullName {
    final first = (driverName ?? '').trim();
    final last = (driverLastname ?? '').trim();
    if (first.isEmpty && last.isEmpty) return 'Driver #$id';
    if (first.isEmpty) return last;
    if (last.isEmpty) return first;
    return '$first $last';
  }

  bool get isActive => active == 1;

  factory DriverModel.fromJson(Map<String, dynamic> json) {
    String? formatDate(dynamic value) {
      if (value == null) return null;
      if (value is String) {
        if (value.length >= 10) return value.substring(0, 10);
        return value;
      }
      return value.toString();
    }

    return DriverModel(
      id: json['id'] as int? ?? 0,
      driverId: json['driver_id'] as String?,
      companyId: json['company_id'] as int?,
      driverName: json['driver_name'] as String?,
      driverLastname: json['driver_lastname'] as String? ?? json['driver_lastName'] as String?,
      driverLicense: json['driver_license'] as String?,
      address: json['address'] as String?,
      mobile: json['mobile'] as String?,
      email: json['email'] as String?,
      alternativeemail: json['alternativeemail'] as String? ?? json['alternativeEmail'] as String?,
      phoneCan: json['phone_can'] as String? ?? json['phoneCanada'] as String?,
      phoneUsa: json['phone_usa'] as String? ?? json['phoneUSA'] as String?,
      applicationDate: formatDate(json['application_date'] ?? json['applicationDate']),
      hireDate: formatDate(json['hire_date'] ?? json['hireDate']),
      inactiveDate: formatDate(json['inactive_date'] ?? json['inactiveDate']),
      canadaOnly: json['canada_only'] as String? ?? (json['canadaOnly'] == true ? 'Yes' : 'No'),
      usaOnly: json['usa_only'] as String? ?? (json['usaOnly'] == true ? 'Yes' : 'No'),
      driverType: json['driver_type'] as String? ?? json['driverType'] as String?,
      ownerOperatorName: json['owner_operator_name'] as String? ?? json['ownerOperatorName'] as String?,
      incorporationName: json['incorporation_name'] as String? ?? json['incorporation'] as String?,
      hst: json['hst'] as String?,
      directDepositDetails: json['direct_deposit_details'] as String? ?? json['directDepositDetails'] as String?,
      licenseExpiry: formatDate(json['license_expiry'] ?? json['licenseExpiry']),
      province: json['province'] as String?,
      country: json['country'] as String?,
      sin: json['sin'] as String?,
      medicalDueDate: formatDate(json['medical_due_date'] ?? json['medicalDueDate']),
      fastCardNumber: json['fast_card_number'] as String? ?? json['fastCardNumber'] as String?,
      fastCartExpiry: formatDate(json['fast_cart_expiry'] ?? json['fastCardExpiry']),
      passport: json['passport'] as String?,
      nationality: json['nationality'] as String?,
      passportExpiry: formatDate(json['passport_expiry'] ?? json['passportExpiry']),
      workPermit: json['work_permit'] as String? ?? json['workPermit'] as String?,
      workPermitExpiry: formatDate(json['work_permit_expiry'] ?? json['workPermitExpiry']),
      abstractDate: formatDate(json['abstract_date'] ?? json['abstractDate']),
      cvor: json['cvor'] as String?,
      cvorAbstractDate: formatDate(json['cvor_abstract_date'] ?? json['cvorAbstractDate']),
      pspDate: formatDate(json['psp_date'] ?? json['pspDate']),
      policeClearanceDate: formatDate(json['police_clearance_date'] ?? json['policeClearanceDate']),
      roadtestDate: formatDate(json['roadtest_date'] ?? json['roadtestDate']),
      annualReviewDate: formatDate(json['annual_review_date'] ?? json['annualReviewDate']),
      active: json['active'] as int?,
      updatedOn: json['updated_on'] as String?,
      licenseClass: json['license_class'] as String?,
      yearsOfExperience: json['years_of_experience'] as int? ?? int.tryParse(json['yearsOfExperience']?.toString() ?? '0'),
      licenseIssueDate: formatDate(json['license_issue_date']),
      licenseRestrictions: json['license_restrictions'] as String?,
      licenseEndorsements: json['license_endorsements'] as String?,
      streetAddress: json['street_address'] as String?,
      city: json['city'] as String?,
      driverProvince: json['driver_province'] as String?,
      postalCode: json['postal_code'] as String?,
      raw: json,
    );
  }
}
