import 'package:intl/intl.dart';

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

  bool get isActive =>
      status.toLowerCase() == 'active' || status == '1';

  static String displayOrDash(String? v) =>
      (v == null || v.trim().isEmpty) ? '—' : v;

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
    );
  }

  // Safe string extraction — avoids cast failures when API sends unexpected types
  static String? _str(dynamic v) {
    if (v == null) return null;
    if (v is String) return v.isEmpty ? null : v;
    return v.toString();
  }

  static String? _fmt(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return iso;
    return DateFormat('MM-dd-yyyy').format(parsed);
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }
}
