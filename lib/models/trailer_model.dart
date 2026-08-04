import 'package:rapide_nforce/core/constants/app_strings.dart';
import 'package:rapide_nforce/core/utils/date_format.dart';

class TrailerModel {
  const TrailerModel({
    required this.id,
    required this.name,
    required this.trailerNumber,
    required this.type,
    required this.status,
    this.vinNumber,
    this.licensePlate,
    this.make,
    this.model,
    this.year,
    this.state,
    this.registrationExpiry,
    this.odometer,
    this.annualInspectionDue,
    this.pmDueDate,
    this.color,
    this.purchaseDate,
    this.purchasePrice,
    this.registrationNumber,
    this.ownership,
    this.ownerName,
    this.ownerEmail,
    this.ownerPhone,
    this.ownerAddress,
    this.specType,
    this.specLength,
    this.specWidth,
    this.specHeight,
    this.specCapacity,
    this.specGvwr,
    this.cviExpiry,
    this.imsNumber,
    this.nextInspectionDue,
    this.inspectionDate,
    this.certificateNumber,
    this.expiryDate,
    this.inspectorName,
    this.inspectorLicense,
    this.inspectionFacility,
    this.facilityNumber,
    this.criticalDefects,
    this.majorDefects,
    this.advisoryItems,
    this.inspectionSummary,
    this.fuelCard,
    this.bridgeTransponder,
    this.assignedTruck,
    this.maintenancePolicy,
    this.pmDueOdometer,
    this.countryId,
    this.cityId,
    this.startDate,
    this.companyId,
    this.companyName,
  });

  final int id;
  final String name;
  final String trailerNumber;
  final String type;
  final String status;
  final String? vinNumber;
  final String? licensePlate;
  final String? make;
  final String? model;
  final int? year;
  final String? state;
  final String? registrationExpiry;
  final int? odometer;
  final String? annualInspectionDue;
  final String? pmDueDate;
  final String? color;
  final String? purchaseDate;
  final num? purchasePrice;
  final String? registrationNumber;
  final String? ownership;
  final String? ownerName;
  final String? ownerEmail;
  final String? ownerPhone;
  final String? ownerAddress;
  final String? specType;
  final String? specLength;
  final String? specWidth;
  final String? specHeight;
  final String? specCapacity;
  final String? specGvwr;
  final String? cviExpiry;
  final String? imsNumber;
  final String? nextInspectionDue;
  final String? inspectionDate;
  final String? certificateNumber;
  final String? expiryDate;
  final String? inspectorName;
  final String? inspectorLicense;
  final String? inspectionFacility;
  final String? facilityNumber;
  final int? criticalDefects;
  final int? majorDefects;
  final int? advisoryItems;
  final String? inspectionSummary;
  final String? fuelCard;
  final String? bridgeTransponder;
  final String? assignedTruck;
  final String? maintenancePolicy;
  final int? pmDueOdometer;
  final int? countryId;
  final int? cityId;
  final String? startDate;
  final int? companyId;
  final String? companyName;

  bool get isActive =>
      status.toLowerCase() == 'active' || status == '1';

  String get shortState {
    if (state == null || state!.trim().isEmpty) return '—';
    final clean = state!.trim();
    if (clean.length <= 3) return clean.toUpperCase();
    final lower = clean.toLowerCase();
    switch (lower) {
      case 'ontario': return 'ON';
      case 'alberta': return 'AB';
      case 'british columbia': return 'BC';
      case 'quebec':
      case 'québec': return 'QC';
      case 'manitoba': return 'MB';
      case 'saskatchewan': return 'SK';
      case 'nova scotia': return 'NS';
      case 'new brunswick': return 'NB';
      case 'newfoundland and labrador':
      case 'newfoundland': return 'NL';
      case 'prince edward island': return 'PE';
      case 'northwest territories': return 'NT';
      case 'nunavut': return 'NU';
      case 'yukon': return 'YT';
      case 'alabama': return 'AL';
      case 'alaska': return 'AK';
      case 'arizona': return 'AZ';
      case 'arkansas': return 'AR';
      case 'california': return 'CA';
      case 'colorado': return 'CO';
      case 'connecticut': return 'CT';
      case 'delaware': return 'DE';
      case 'florida': return 'FL';
      case 'georgia': return 'GA';
      case 'hawaii': return 'HI';
      case 'idaho': return 'ID';
      case 'illinois': return 'IL';
      case 'indiana': return 'IN';
      case 'iowa': return 'IA';
      case 'kansas': return 'KS';
      case 'kentucky': return 'KY';
      case 'louisiana': return 'LA';
      case 'maine': return 'ME';
      case 'maryland': return 'MD';
      case 'massachusetts': return 'MA';
      case 'michigan': return 'MI';
      case 'minnesota': return 'MN';
      case 'mississippi': return 'MS';
      case 'missouri': return 'MO';
      case 'montana': return 'MT';
      case 'nebraska': return 'NE';
      case 'nevada': return 'NV';
      case 'new hampshire': return 'NH';
      case 'new jersey': return 'NJ';
      case 'new mexico': return 'NM';
      case 'new york': return 'NY';
      case 'north carolina': return 'NC';
      case 'north dakota': return 'ND';
      case 'ohio': return 'OH';
      case 'oklahoma': return 'OK';
      case 'oregon': return 'OR';
      case 'pennsylvania': return 'PA';
      case 'rhode island': return 'RI';
      case 'south carolina': return 'SC';
      case 'south dakota': return 'SD';
      case 'tennessee': return 'TN';
      case 'texas': return 'TX';
      case 'utah': return 'UT';
      case 'vermont': return 'VT';
      case 'virginia': return 'VA';
      case 'washington': return 'WA';
      case 'west virginia': return 'WV';
      case 'wisconsin': return 'WI';
      case 'wyoming': return 'WY';
      default:
        return clean.length >= 2 ? clean.substring(0, 2).toUpperCase() : clean.toUpperCase();
    }
  }

  static String displayOrDash(String? v) =>
      (v == null || v.trim().isEmpty) ? AppStrings.noData : v;

  factory TrailerModel.fromJson(Map<String, dynamic> json) {
    final active = json['active'];
    final status = active == 1 || active == true
        ? 'Active'
        : active == 0 || active == false
            ? 'Inactive'
            : _str(json['status']) ?? 'Active';

    final unit = _str(json['trailerUnit']) ??
        _str(json['trailer_unit']) ??
        _str(json['name']) ??
        '';

    return TrailerModel(
      id: _toInt(json['id']) ?? 0,
      name: unit,
      trailerNumber: unit,
      type: _str(json['vehicleType']) ??
          _str(json['vehicle_type']) ??
          _str(json['type']) ??
          'Trailer',
      status: status,
      vinNumber: _str(json['vinNumber']) ?? _str(json['vin_number']),
      licensePlate: _str(json['licensePlateNumber']) ??
          _str(json['license_plate_number']) ??
          _str(json['plateNumber']),
      make: _str(json['make']),
      model: _str(json['model']),
      year: _toInt(json['year']),
      state: _str(json['state']) ?? _str(json['plateProvince']),
      registrationExpiry: _fmt(
          _str(json['registrationExpiry']) ?? _str(json['registration_expiry'])),
      odometer: _toInt(json['odometer']),
      annualInspectionDue: _fmt(_str(json['annualInspectionDue']) ??
          _str(json['annual_inspection_due']) ??
          _str(json['nextYearDate'])),
      pmDueDate:
          _fmt(_str(json['pmDueDate']) ?? _str(json['pm_due_date'])),
      color: _str(json['color']),
      purchaseDate:
          _fmt(_str(json['purchaseDate']) ?? _str(json['purchase_date'])),
      purchasePrice: json['purchasePrice'] is num
          ? json['purchasePrice'] as num
          : num.tryParse(json['purchasePrice']?.toString() ?? ''),
      registrationNumber:
          _str(json['registrationNumber']) ?? _str(json['rin']),
      ownership: _str(json['ownership']),
      ownerName: _str(json['ownerName']) ?? _str(json['owner_name']),
      ownerEmail: _str(json['ownerEmail']) ?? _str(json['owner_email']),
      ownerPhone: _str(json['ownerPhone']) ?? _str(json['owner_phone']),
      ownerAddress:
          _str(json['ownerAddress']) ?? _str(json['owner_address']),
      specType: _str(json['specType']),
      specLength: _str(json['specLength']),
      specWidth: _str(json['specWidth']),
      specHeight: _str(json['specHeight']),
      specCapacity: _str(json['specCapacity']),
      specGvwr: _str(json['specGvwr']),
      cviExpiry:
          _fmt(_str(json['cviExpiry']) ?? _str(json['cvi_expiry'])),
      imsNumber: _str(json['imsNumber']),
      nextInspectionDue: _fmt(_str(json['nextInspectionDue'])),
      inspectionDate: _fmt(_str(json['inspectionDate'])),
      certificateNumber: _str(json['certificateNumber']),
      expiryDate:
          _fmt(_str(json['expiryDate']) ?? _str(json['expiry_date'])),
      inspectorName: _str(json['inspectorName']),
      inspectorLicense: _str(json['inspectorLicense']),
      inspectionFacility: _str(json['inspectionFacility']),
      facilityNumber: _str(json['facilityNumber']),
      criticalDefects: _toInt(json['criticalDefects']),
      majorDefects: _toInt(json['majorDefects']),
      advisoryItems: _toInt(json['advisoryItems']),
      inspectionSummary: _str(json['inspectionSummary']),
      fuelCard: _str(json['fuelCard']),
      bridgeTransponder: _str(json['bridgeTransponder']),
      assignedTruck: json['assignedTruck']?.toString(),
      maintenancePolicy: _str(json['maintenancePolicy']),
      pmDueOdometer: _toInt(json['pmDueOdometer']),
      countryId: _toInt(json['countryId']) ?? _toInt(json['country_id']),
      cityId: _toInt(json['cityId']) ?? _toInt(json['city_id']),
      startDate: _str(json['startDate']) ?? _str(json['start_date']),
      companyId: _toInt(json['companyId']) ?? _toInt(json['company_id']),
      companyName: _str(json['companyName']) ?? _str(json['company_name']),
    );
  }

  // Safe string extraction — avoids cast failures when API sends unexpected types
  static String? _str(dynamic v) {
    if (v == null) return null;
    if (v is String) return v.isEmpty ? null : v;
    return v.toString();
  }

  static String? _fmt(String? iso) => formatDateMMDDYYYY(iso);

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }
}
